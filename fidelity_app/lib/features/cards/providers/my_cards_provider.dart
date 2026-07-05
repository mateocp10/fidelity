import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final DateTime? sessionLastViewedAt;

  MyCardsState({
    this.isLoading = true,
    this.cards = const [],
    this.userName = '',
    this.avatarUrl,
    this.error,
    this.sessionLastViewedAt,
  });

  MyCardsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? cards,
    String? userName,
    String? avatarUrl,
    String? error,
    DateTime? sessionLastViewedAt,
  }) {
    return MyCardsState(
      isLoading: isLoading ?? this.isLoading,
      cards: cards ?? this.cards,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      error: error, // Clear error if not provided
      sessionLastViewedAt: sessionLastViewedAt ?? this.sessionLastViewedAt,
    );
  }
}

class MyCardsNotifier extends Notifier<MyCardsState> {
  late MyCardsRepository _repository;
  RealtimeChannel? _cardsChannel;

  // We use events to notify the UI of celebrations or points
  void Function()? onCardCompleted;
  void Function()? onPointEarned;

  // Debounce: varios eventos realtime (loyalty_cards + rewards + scans) por una
  // misma acción se agrupan en un solo refresco.
  Timer? _refreshDebounce;

  @override
  MyCardsState build() {
    _repository = ref.watch(myCardsRepositoryProvider);
    Future.microtask(() => _loadInitialData());

    ref.onDispose(() {
      _refreshDebounce?.cancel();
      _cardsChannel?.unsubscribe();
    });

    return MyCardsState();
  }

  /// Agrupa múltiples pedidos de refresco en uno solo (trailing debounce).
  void scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 350), () {
      refreshCards(silent: true);
    });
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastViewedStr = prefs.getString('cards_last_viewed_at');
      DateTime? sessionLastViewedAt;
      if (lastViewedStr != null) {
        sessionLastViewedAt = DateTime.tryParse(lastViewedStr);
      }

      final profile = await _repository.getUserProfile();
      final String userName = profile?['full_name'] ?? '';
      final String? avatarUrl = profile?['avatar_url'];

      final cards = await _repository.getLoyaltyCards();

      state = state.copyWith(
        isLoading: false,
        userName: userName,
        avatarUrl: avatarUrl,
        cards: cards,
        sessionLastViewedAt: sessionLastViewedAt,
      );

      _setupRealtimeSubscription();
      
      // Update shared preferences for the NEXT time they open the app
      await prefs.setString('cards_last_viewed_at', DateTime.now().toUtc().toIso8601String());
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

        final cardId = newData['id'];
        final existingCard = state.cards.firstWhere((c) => c['id'] == cardId, orElse: () => <String, dynamic>{});
        final business = existingCard['businesses'] as Map<String, dynamic>?;
        final requiredPoints = business?['points_required'] as int? ?? 0;

        if (newPoints > oldPoints && newPoints >= requiredPoints && requiredPoints > 0) {
          onCardCompleted?.call();
        } else if (newPoints > oldPoints) {
          onPointEarned?.call();
        } else if (newClaimed > oldClaimed) {
          // You could optionally add an onRewardClaimed callback here if needed later
        }

        scheduleRefresh();
      },
    );
  }
}

final myCardsProvider = NotifierProvider<MyCardsNotifier, MyCardsState>(() {
  return MyCardsNotifier();
});

