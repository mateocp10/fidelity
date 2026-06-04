import 'package:supabase_flutter/supabase_flutter.dart';

class RewardsManagementRepository {
  final SupabaseClient _supabase;

  RewardsManagementRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getRewards(String businessId) async {
    final rewardsResponse = await _supabase
        .from('rewards')
        .select('*, description')
        .eq('business_id', businessId)
        .order('earned_at', ascending: false);

    final List<Map<String, dynamic>> rewards =
        List<Map<String, dynamic>>.from(rewardsResponse);

    if (rewards.isEmpty) {
      return [];
    }

    final userIds = rewards
        .map((r) => r['user_id'] as String)
        .toSet()
        .toList();

    final profilesResponse = await _supabase
        .from('profiles')
        .select('id, full_name, avatar_url')
        .inFilter('id', userIds);

    final Map<String, Map<String, dynamic>> profileMap = {
      for (var p in profilesResponse)
        p['id'] as String: p,
    };

    final mergedRewards = rewards.map((reward) {
      final userId = reward['user_id'] as String;
      final p = profileMap[userId];
      return {
        ...reward,
        'display_name': p?['full_name'] ?? 'USUARIO',
        'avatar_url': p?['avatar_url']
      };
    }).toList();

    return mergedRewards;
  }

  Future<void> updateRewardStatus(String rewardId, String status) async {
    await _supabase
        .from('rewards')
        .update({'status': status})
        .eq('id', rewardId);
  }
}
