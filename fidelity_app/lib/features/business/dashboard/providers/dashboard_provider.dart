import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../data/dashboard_repository.dart';

class DashboardState {
  final bool isLoading;
  final String? error;
  final String? toastMessage;
  final bool toastIsError;
  final Map<String, dynamic>? business;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> pendingScans;
  final List<Map<String, dynamic>> pendingRewards;
  final String ownerName;

  DashboardState({
    this.isLoading = true,
    this.error,
    this.toastMessage,
    this.toastIsError = false,
    this.business,
    this.customers = const [],
    this.pendingScans = const [],
    this.pendingRewards = const [],
    this.ownerName = '',
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    String? toastMessage,
    bool? toastIsError,
    Map<String, dynamic>? business,
    List<Map<String, dynamic>>? customers,
    List<Map<String, dynamic>>? pendingScans,
    List<Map<String, dynamic>>? pendingRewards,
    String? ownerName,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      toastMessage: toastMessage,
      toastIsError: toastIsError ?? false,
      business: business ?? this.business,
      customers: customers ?? this.customers,
      pendingScans: pendingScans ?? this.pendingScans,
      pendingRewards: pendingRewards ?? this.pendingRewards,
      ownerName: ownerName ?? this.ownerName,
    );
  }
}

class DashboardNotifier extends Notifier<DashboardState> {
  RealtimeChannel? _scansChannel;
  RealtimeChannel? _rewardsChannel;
  RealtimeChannel? _loyaltyCardsChannel;

  // Debounce: una acción que toca varias tablas (scans + rewards + loyalty_cards)
  // dispara varios eventos realtime casi simultáneos. En vez de recargar por cada
  // uno, los agrupamos en UNA sola recarga.
  Timer? _reloadDebounce;
  DateTime? _lastLoadedAt;

  @override
  DashboardState build() {
    // Initial load happens after build or via a scheduled microtask
    Future.microtask(() => loadData());

    ref.onDispose(() {
      _reloadDebounce?.cancel();
      _scansChannel?.unsubscribe();
      _rewardsChannel?.unsubscribe();
      _loyaltyCardsChannel?.unsubscribe();
    });

    return DashboardState();
  }

  /// Agrupa múltiples pedidos de recarga en una sola (trailing debounce).
  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 350), () {
      loadData(silent: true);
    });
  }

  /// Recarga solo si los datos están "viejos". Útil al volver del background o
  /// re-entrar a la pantalla, sin recargar de más si recién se cargó.
  void reloadIfStale({Duration maxAge = const Duration(seconds: 20)}) {
    if (state.isLoading) return; // ya hay una carga en curso; evita duplicarla
    final last = _lastLoadedAt;
    if (last == null || DateTime.now().difference(last) > maxAge) {
      _scheduleReload();
    }
  }

  Future<void> loadData({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final repo = ref.read(dashboardRepositoryProvider);
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;

      if (userId == null) {
        state = state.copyWith(isLoading: false, error: 'User not logged in');
        return;
      }

      String ownerName = state.ownerName;
      if (ownerName.isEmpty) {
        final ownerProfile = await ref.read(supabaseClientProvider)
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        if (ownerProfile != null) {
          ownerName = ownerProfile['full_name'] ?? '';
        }
      }

      final business = await repo.fetchBusiness(userId);

      if (business == null) {
        state = state.copyWith(
          isLoading: false,
          business: null,
          ownerName: ownerName,
        );
        return;
      }

      final businessId = business['id'] as String;

      // Estas 3 consultas son independientes entre sí: las corremos en paralelo
      // en vez de una tras otra para reducir la latencia total.
      final results = await Future.wait([
        repo.fetchCustomers(businessId),
        repo.fetchPendingScans(businessId),
        repo.fetchPendingRewards(businessId),
      ]);

      state = state.copyWith(
        isLoading: false,
        business: business,
        customers: results[0],
        pendingScans: results[1],
        pendingRewards: results[2],
        ownerName: ownerName,
      );

      _lastLoadedAt = DateTime.now();
      _setupRealtimeSubscription(businessId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _setupRealtimeSubscription(String businessId) {
    if (_scansChannel != null) return;
    final supabase = ref.read(supabaseClientProvider);

    _scansChannel = supabase.channel('biz-scans:$businessId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'scans',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'business_id',
        value: businessId,
      ),
      callback: (payload) => _scheduleReload(),
    ).subscribe();

    _rewardsChannel = supabase.channel('biz-rewards:$businessId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'rewards',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'business_id',
        value: businessId,
      ),
      callback: (payload) => _scheduleReload(),
    ).subscribe();

    _loyaltyCardsChannel = supabase.channel('biz-loyalty:$businessId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'loyalty_cards',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'business_id',
        value: businessId,
      ),
      callback: (payload) => _scheduleReload(),
    ).subscribe();
  }

  Future<void> addManualPoints(String userId, int points) async {
    final businessId = state.business?['id'];
    if (businessId == null) return;

    try {
      await ref.read(dashboardRepositoryProvider).addManualPoints(
        userId: userId,
        businessId: businessId,
        points: points,
      );
      state = state.copyWith(toastMessage: '✅ ¡Puntos agregados!', toastIsError: false);
      // El realtime + debounce se encargan de recargar una sola vez.
      _scheduleReload();
    } catch (e) {
      if (e.toString().contains('PENDING_REWARD')) {
        state = state.copyWith(toastMessage: 'ERROR_PENDING_REWARD', toastIsError: true);
      } else {
        state = state.copyWith(toastMessage: 'Error inesperado', toastIsError: true);
      }
    }
  }

  Future<void> approveScan(String scanId, String loyaltyCardId) async {
    try {
      final rewardGenerated = await ref.read(dashboardRepositoryProvider).approveScan(
        scanId: scanId,
        loyaltyCardId: loyaltyCardId,
      );
      
      state = state.copyWith(
        toastMessage: rewardGenerated ? 'Escaneo aprobado. ¡Premio generado!' : 'Escaneo aprobado',
        toastIsError: false,
      );
      _scheduleReload();
    } catch (e) {
      state = state.copyWith(toastMessage: 'Error: $e', toastIsError: true);
    }
  }

  Future<void> rejectScan(String scanId) async {
    try {
      await ref.read(dashboardRepositoryProvider).rejectScan(scanId);
      state = state.copyWith(toastMessage: 'Escaneo rechazado', toastIsError: false);
      _scheduleReload();
    } catch (e) {
      state = state.copyWith(toastMessage: 'Error: $e', toastIsError: true);
    }
  }

  Future<void> redeemReward(String userId, String cardId) async {
    final businessId = state.business?['id'];
    if (businessId == null) return;

    try {
      await ref.read(dashboardRepositoryProvider).redeemReward(
        userId: userId,
        businessId: businessId,
        cardId: cardId,
      );
      state = state.copyWith(toastMessage: 'Premio canjeado', toastIsError: false);
      _scheduleReload();
    } catch (e) {
      state = state.copyWith(toastMessage: 'Error: $e', toastIsError: true);
    }
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});
