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

  @override
  DashboardState build() {
    // Initial load happens after build or via a scheduled microtask
    Future.microtask(() => loadData());
    
    ref.onDispose(() {
      _scansChannel?.unsubscribe();
      _rewardsChannel?.unsubscribe();
      _loyaltyCardsChannel?.unsubscribe();
    });

    return DashboardState();
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

      final customers = await repo.fetchCustomers(businessId);
      final pendingScans = await repo.fetchPendingScans(businessId);
      final pendingRewards = await repo.fetchPendingRewards(businessId);

      state = state.copyWith(
        isLoading: false,
        business: business,
        customers: customers,
        pendingScans: pendingScans,
        pendingRewards: pendingRewards,
        ownerName: ownerName,
      );

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
      callback: (payload) => loadData(silent: true),
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
      callback: (payload) => loadData(silent: true),
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
      callback: (payload) => loadData(silent: true),
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
      // Wait a bit to let realtime refresh the data or force a silent reload
      Future.delayed(const Duration(milliseconds: 500), () => loadData(silent: true));
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
      await loadData(silent: true);
    } catch (e) {
      state = state.copyWith(toastMessage: 'Error: $e', toastIsError: true);
    }
  }

  Future<void> rejectScan(String scanId) async {
    try {
      await ref.read(dashboardRepositoryProvider).rejectScan(scanId);
      state = state.copyWith(toastMessage: 'Escaneo rechazado', toastIsError: false);
      await loadData(silent: true);
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
      await loadData(silent: true);
    } catch (e) {
      state = state.copyWith(toastMessage: 'Error: $e', toastIsError: true);
    }
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});
