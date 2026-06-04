import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/my_cards_repository.dart';

final myCardsRepositoryProvider = Provider<MyCardsRepository>((ref) {
  return MyCardsRepository();
});

class MyCardsState {
  final bool isLoading;
  final List<Map<String, dynamic>> cards;
  final String userName;
  final String? avatarUrl;
  final String? error;

  MyCardsState({
    this.isLoading = true,
    this.cards = const [],
    this.userName = '',
    this.avatarUrl,
    this.error,
  });

  MyCardsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? cards,
    String? userName,
    String? avatarUrl,
    String? error,
  }) {
    return MyCardsState(
      isLoading: isLoading ?? this.isLoading,
      cards: cards ?? this.cards,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      error: error, // Clear error if not provided
    );
  }
}

class MyCardsNotifier extends Notifier<MyCardsState> {
  late MyCardsRepository _repository;
  RealtimeChannel? _cardsChannel;

  // We use events to notify the UI of celebrations or points
  void Function()? onCardCompleted;
  void Function()? onPointEarned;

  @override
  MyCardsState build() {
    _repository = ref.watch(myCardsRepositoryProvider);
    Future.microtask(() => _loadInitialData());
    
    ref.onDispose(() {
      _cardsChannel?.unsubscribe();
    });
    
    return MyCardsState();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repository.getUserProfile();
      final String userName = profile?['full_name'] ?? '';
      final String? avatarUrl = profile?['avatar_url'];

      final cards = await _repository.getLoyaltyCards();

      state = state.copyWith(
        isLoading: false,
        userName: userName,
        avatarUrl: avatarUrl,
        cards: cards,
      );

      _setupRealtimeSubscription();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refreshCards({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final cards = await _repository.getLoyaltyCards();
      
      // Also refresh profile silently
      final profile = await _repository.getUserProfile();
      final String userName = profile?['full_name'] ?? state.userName;
      final String? avatarUrl = profile?['avatar_url'] ?? state.avatarUrl;

      state = state.copyWith(
        isLoading: false,
        cards: cards,
        userName: userName,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      if (!silent) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  void _setupRealtimeSubscription() {
    if (_cardsChannel != null) return;

    _cardsChannel = _repository.setupRealtimeSubscription(
      onCardUpdated: (newData, oldData) {
        final newClaimed = (newData['rewards_claimed'] as int?) ?? 0;
        final oldClaimed = (oldData['rewards_claimed'] as int?) ?? 0;
        
        final newPoints = (newData['current_points'] as int?) ?? 0;
        final oldPoints = (oldData['current_points'] as int?) ?? 0;

        if (newClaimed > oldClaimed) {
          onCardCompleted?.call();
        } else if (newPoints > oldPoints) {
          onPointEarned?.call();
        }

        refreshCards(silent: true);
      },
    );
  }
}

final myCardsProvider = NotifierProvider<MyCardsNotifier, MyCardsState>(() {
  return MyCardsNotifier();
});

