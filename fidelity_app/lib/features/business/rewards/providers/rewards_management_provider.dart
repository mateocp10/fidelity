import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/rewards_management_repository.dart';

final rewardsManagementRepositoryProvider = Provider<RewardsManagementRepository>((ref) {
  return RewardsManagementRepository();
});

class RewardsManagementState {
  final bool isLoading;
  final List<Map<String, dynamic>> rewards;
  final String? error;
  final String? businessId;

  RewardsManagementState({
    this.isLoading = true,
    this.rewards = const [],
    this.error,
    this.businessId,
  });

  RewardsManagementState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? rewards,
    String? error,
    String? businessId,
  }) {
    return RewardsManagementState(
      isLoading: isLoading ?? this.isLoading,
      rewards: rewards ?? this.rewards,
      error: error,
      businessId: businessId ?? this.businessId,
    );
  }
}

class RewardsManagementNotifier extends Notifier<RewardsManagementState> {
  late RewardsManagementRepository _repository;

  @override
  RewardsManagementState build() {
    _repository = ref.watch(rewardsManagementRepositoryProvider);
    return RewardsManagementState();
  }

  void init(String businessId) {
    if (state.businessId != businessId) {
      Future.microtask(() {
        state = state.copyWith(businessId: businessId);
        _loadRewards();
      });
    }
  }

  Future<void> _loadRewards() async {
    if (state.businessId == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rewards = await _repository.getRewards(state.businessId!);
      state = state.copyWith(isLoading: false, rewards: rewards);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> approveReward(String rewardId) async {
    try {
      await _repository.updateRewardStatus(rewardId, 'approved');
      await _loadRewards();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> rejectReward(String rewardId) async {
    try {
      await _repository.updateRewardStatus(rewardId, 'rejected');
      await _loadRewards();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final rewardsManagementProvider = NotifierProvider<RewardsManagementNotifier, RewardsManagementState>(() {
  return RewardsManagementNotifier();
});
