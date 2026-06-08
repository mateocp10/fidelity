import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/reward_transfer_service.dart';
import '../data/card_history_repository.dart';

class CardHistoryState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> scans;
  final List<Map<String, dynamic>> rewards;
  final DateTimeRange? dateRange;
  
  // Modal state
  final bool isTransferLoading;
  final String? transferErrorMessage;
  final String? transferSuccessMessage;
  final bool showInviteButton;

  CardHistoryState({
    this.isLoading = true,
    this.error,
    this.scans = const [],
    this.rewards = const [],
    this.dateRange,
    this.isTransferLoading = false,
    this.transferErrorMessage,
    this.transferSuccessMessage,
    this.showInviteButton = false,
  });

  CardHistoryState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? scans,
    List<Map<String, dynamic>>? rewards,
    DateTimeRange? dateRange,
    bool? isTransferLoading,
    String? transferErrorMessage,
    String? transferSuccessMessage,
    bool? showInviteButton,
  }) {
    return CardHistoryState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      scans: scans ?? this.scans,
      rewards: rewards ?? this.rewards,
      dateRange: dateRange ?? this.dateRange,
      isTransferLoading: isTransferLoading ?? this.isTransferLoading,
      transferErrorMessage: transferErrorMessage,
      transferSuccessMessage: transferSuccessMessage,
      showInviteButton: showInviteButton ?? this.showInviteButton,
    );
  }

  CardHistoryState clearTransferMessages() {
    return copyWith(
      isTransferLoading: false,
      transferErrorMessage: null,
      transferSuccessMessage: null,
      showInviteButton: false,
    );
  }
}

class CardHistoryNotifier extends Notifier<CardHistoryState> {
  late String _cardId;
  late String _businessId;

  @override
  CardHistoryState build() {
    return CardHistoryState();
  }

  void init(String cardId, String businessId) {
    _cardId = cardId;
    _businessId = businessId;
    Future.microtask(() => loadHistory());
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await ref.read(cardHistoryRepositoryProvider).fetchHistory(_cardId, _businessId, state.dateRange);
      state = state.copyWith(
        isLoading: false,
        scans: results[0],
        rewards: results[1],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void updateDateRange(DateTimeRange? range) {
    state = state.copyWith(dateRange: range);
    loadHistory();
  }

  void clearTransferState() {
    state = state.clearTransferMessages();
  }

  Future<void> transferReward(String rewardId, String email) async {
    state = state.copyWith(
      isTransferLoading: true,
      transferErrorMessage: null,
      transferSuccessMessage: null,
      showInviteButton: false,
    );

    try {
      final supabase = ref.read(supabaseClientProvider);
      final transferService = RewardTransferService(supabase);

      final user = await transferService.findUserByEmail(email);

      if (user == null) {
        state = state.copyWith(
          isTransferLoading: false,
          transferErrorMessage: 'Esa cuenta no existe. Dile a tu fideliamigo que descargue la app y que cree una cuenta para que le puedas transferir el premio.',
          showInviteButton: true,
        );
        return;
      }

      if (user['role'] != 'client') {
        state = state.copyWith(
          isTransferLoading: false,
          transferErrorMessage: 'No se puede transferir un premio a una cuenta de negocio.',
        );
        return;
      }

      await transferService.transferReward(rewardId, email);

      state = state.copyWith(
        isTransferLoading: false,
        transferSuccessMessage: '¡Premio transferido exitosamente!',
      );

      // Recargar la lista
      loadHistory();
    } on TransferException catch (e) {
      state = state.copyWith(
        isTransferLoading: false,
        transferErrorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isTransferLoading: false,
        transferErrorMessage: 'Error al transferir. Intenta de nuevo.',
      );
    }
  }
}

final cardHistoryProvider = NotifierProvider<CardHistoryNotifier, CardHistoryState>(() {
  return CardHistoryNotifier();
});
