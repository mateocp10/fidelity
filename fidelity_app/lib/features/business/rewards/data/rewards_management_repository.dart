import 'package:supabase_flutter/supabase_flutter.dart';

class RewardsManagementRepository {
  final SupabaseClient _supabase;

  RewardsManagementRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getRewards(String businessId) async {
    final rewardsResponse = await _supabase
        .from('rewards')
        .select('*, reward_transfer_history(from_user_id)')
        .eq('business_id', businessId)
        .order('earned_at', ascending: false);

    final List<Map<String, dynamic>> rewards =
        List<Map<String, dynamic>>.from(rewardsResponse);

    if (rewards.isEmpty) {
      return [];
    }

    final Set<String> userIds = {};
    for (var r in rewards) {
      userIds.add(r['user_id'] as String);
      if (r['reward_transfer_history'] != null && (r['reward_transfer_history'] as List).isNotEmpty) {
        var transfers = r['reward_transfer_history'] as List;
        userIds.add(transfers.first['from_user_id'] as String);
      }
    }

    final profilesResponse = await _supabase
        .from('profiles')
        .select('id, full_name, avatar_url')
        .inFilter('id', userIds.toList());

    final Map<String, Map<String, dynamic>> profileMap = {
      for (var p in profilesResponse)
        p['id'] as String: p,
    };

    final mergedRewards = rewards.map((reward) {
      final userId = reward['user_id'] as String;
      final currentOwnerProfile = profileMap[userId];
      
      bool isTransferred = false;
      String fromName = '';
      if (reward['reward_transfer_history'] != null && (reward['reward_transfer_history'] as List).isNotEmpty) {
        var transfers = reward['reward_transfer_history'] as List;
        final fromUserId = transfers.first['from_user_id'] as String;
        final fromProfile = profileMap[fromUserId];
        fromName = fromProfile?['full_name'] ?? 'Un usuario';
        isTransferred = true;
      }

      return {
        ...reward,
        'is_transferred': isTransferred,
        'from_name': fromName,
        'display_name': currentOwnerProfile?['full_name'] ?? 'USUARIO',
        'avatar_url': currentOwnerProfile?['avatar_url']
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
