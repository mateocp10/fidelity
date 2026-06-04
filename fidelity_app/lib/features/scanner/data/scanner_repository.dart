import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  return ScannerRepository(ref.watch(supabaseClientProvider));
});

class ScannerRepository {
  final SupabaseClient _supabase;

  ScannerRepository(this._supabase);

  Future<String> validateScan(String qrCode, String userId) async {
    // 1. Obtener la información del QR y el negocio
    final qrResponse = await _supabase
        .from('qr_codes')
        .select('id, business_id, is_active, businesses(name, reward_description, points_required, cooldown_hours, is_demo)')
        .eq('qr_code', qrCode)
        .maybeSingle();

    if (qrResponse == null) throw Exception('Código QR no encontrado');

    if (qrResponse['is_active'] != true) {
      throw Exception('Este código QR está inactivo');
    }

    final business = qrResponse['businesses'];
    final businessId = qrResponse['business_id'];

    // 2. Obtener o crear la tarjeta de fidelidad
    Map<String, dynamic> loyaltyCard;
    final cardResponse = await _supabase
        .from('loyalty_cards')
        .select()
        .eq('user_id', userId)
        .eq('business_id', businessId)
        .maybeSingle();

    if (cardResponse == null) {
      loyaltyCard = await _supabase
          .from('loyalty_cards')
          .insert({
            'user_id': userId,
            'business_id': businessId,
            'current_points': 0,
            'total_points_lifetime': 0,
            'rewards_claimed': 0,
          })
          .select()
          .single();
    } else {
      loyaltyCard = cardResponse;
    }

    // 3. Chequear si el usuario tiene un premio pendiente
    final pendingReward = await _supabase
        .from('rewards')
        .select('id')
        .eq('user_id', userId)
        .eq('business_id', businessId)
        .eq('status', 'pending')
        .maybeSingle();

    if (pendingReward != null) {
      throw Exception('PENDING_REWARD');
    }

    // 4. Chequear si la cuenta o el negocio son "demo"
    final userProfile = await _supabase
        .from('profiles')
        .select('is_demo')
        .eq('id', userId)
        .single();
        
    final isDemoAccount = (userProfile['is_demo'] == true) || (business['is_demo'] == true);

    // 5. Insertar el escaneo (puede lanzar error de cooldown por el trigger de DB)
    await _supabase.from('scans').insert({
      'user_id': userId,
      'business_id': businessId,
      'loyalty_card_id': loyaltyCard['id'],
      'qr_code_id': qrResponse['id'],
      'scanned_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
      'is_demo': isDemoAccount,
    });

    // Retorna el nombre del negocio para mostrarlo en el diálogo de éxito
    return business['name'] ?? 'Local';
  }
}
