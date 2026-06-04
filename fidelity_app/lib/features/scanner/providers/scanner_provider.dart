import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/scanner_repository.dart';

class ScannerState {
  final bool isProcessing;
  final String? error;
  final String? cooldownHours;
  final bool hasPendingReward;
  final String? successBusinessName;

  ScannerState({
    this.isProcessing = false,
    this.error,
    this.cooldownHours,
    this.hasPendingReward = false,
    this.successBusinessName,
  });

  ScannerState copyWith({
    bool? isProcessing,
    String? error,
    String? cooldownHours,
    bool? hasPendingReward,
    String? successBusinessName,
  }) {
    return ScannerState(
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      cooldownHours: cooldownHours,
      hasPendingReward: hasPendingReward ?? false,
      successBusinessName: successBusinessName,
    );
  }

  ScannerState clearMessages() {
    return ScannerState(
      isProcessing: isProcessing,
      error: null,
      cooldownHours: null,
      hasPendingReward: false,
      successBusinessName: null,
    );
  }
}

class ScannerNotifier extends Notifier<ScannerState> {
  @override
  ScannerState build() {
    return ScannerState();
  }

  void reset() {
    state = state.clearMessages();
  }

  Future<void> validateScan(String qrCode) async {
    if (state.isProcessing) return;

    state = state.copyWith(isProcessing: true).clearMessages();

    try {
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final businessName = await ref.read(scannerRepositoryProvider).validateScan(qrCode, userId);

      state = state.copyWith(
        isProcessing: false,
        successBusinessName: businessName,
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('COOLDOWN_ACTIVE')) {
        final parts = e.message.split(':');
        final hours = parts.length > 1 ? parts[1] : '4';
        state = state.copyWith(
          isProcessing: false,
          cooldownHours: hours,
        );
      } else {
        state = state.copyWith(
          isProcessing: false,
          error: 'Error de base de datos: ${e.message}',
        );
      }
    } catch (e) {
      if (e.toString().contains('PENDING_REWARD')) {
        state = state.copyWith(
          isProcessing: false,
          hasPendingReward: true,
        );
      } else {
        String msg = 'Error inesperado: $e';
        if (e.toString().contains('single row') || e.toString().contains('no encontrado')) {
          msg = 'QR no válido';
        }
        state = state.copyWith(
          isProcessing: false,
          error: msg,
        );
      }
    }
  }
}

final scannerProvider = NotifierProvider<ScannerNotifier, ScannerState>(() {
  return ScannerNotifier();
});
