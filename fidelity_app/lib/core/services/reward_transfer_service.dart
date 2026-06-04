import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para transferir premios entre usuarios.
class RewardTransferService {
  final SupabaseClient _client;

  RewardTransferService(this._client);

  /// Busca un usuario por email.
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    return await _client
        .from('profiles')
        .select('id, role, email')
        .eq('email', normalizedEmail)
        .maybeSingle();
  }

  /// Transfiere un premio a otro usuario por email.
  Future<void> transferReward(String rewardId, String toEmail) async {
    final normalizedEmail = toEmail.trim().toLowerCase();

    // 1. Buscar el usuario destinatario
    final recipient = await findUserByEmail(normalizedEmail);

    if (recipient == null) {
      throw TransferException(
        'USER_NOT_FOUND',
        'El usuario no existe. Descarga Fidelity y regístrate para recibir el premio.',
      );
    }

    // 2. Verificar que es cuenta de cliente
    if (recipient['role'] != 'client') {
      throw TransferException(
        'USER_IS_NOT_CLIENT',
        'No se puede transferir un premio a una cuenta de negocio.',
      );
    }

    // 3. Obtener el premio y verificar estado
    final reward = await _client
        .from('rewards')
        .select('id, user_id, status, business_id')
        .eq('id', rewardId)
        .maybeSingle();

    if (reward == null) {
      throw TransferException('ERROR', 'El premio no existe.');
    }

    if (reward['status'] != 'approved') {
      throw TransferException(
        'ERROR',
        'Solo se pueden transferir premios aprobados.',
      );
    }

    if (reward['user_id'] == recipient['id']) {
      throw TransferException(
        'ERROR',
        'No puedes transferirte un premio a ti mismo.',
      );
    }

    final businessId = reward['business_id'] as String;

    // 4. Buscar o crear loyalty_card vía RPC
    final cardId = await _client.rpc(
      'get_or_create_loyalty_card',
      params: {
        'p_user_id': recipient['id'],
        'p_business_id': businessId,
        'p_points': 0,
      },
    );

    if (cardId == null) {
      throw TransferException(
        'ERROR',
        'No se pudo crear la tarjeta para el usuario destinatario.',
      );
    }

    // 5. Transferir el premio vía RPC
    await _client.rpc(
      'transfer_reward',
      params: {
        'p_reward_id': rewardId,
        'p_user_id': recipient['id'],
        'p_loyalty_card_id': cardId,
      },
    );
  }
}

class TransferException implements Exception {
  final String code;
  final String message;

  TransferException(this.code, this.message);

  @override
  String toString() => message;
}
