import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_provider.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

class DashboardRepository {
  final SupabaseClient _supabase;

  DashboardRepository(this._supabase);

  SupabaseClient get client => _supabase;

  Future<Map<String, dynamic>?> fetchBusiness(String userId) async {
    return await _supabase
        .from('businesses')
        .select('*')
        .eq('owner_id', userId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchCustomers(String businessId) async {
    final response = await _supabase
        .from('loyalty_cards')
        .select('''
          *,
          profiles(
            id,
            full_name,
            avatar_url,
            is_demo
          )
        ''')
        .eq('business_id', businessId)
        .order('updated_at', ascending: false);
        
    final cards = List<Map<String, dynamic>>.from(response);

    try {
      final rewardsResponse = await _supabase
          .from('rewards')
          .select('user_id, reward_transfer_history(from_user_id)')
          .eq('business_id', businessId);
          
      final rewards = List<Map<String, dynamic>>.from(rewardsResponse);
      
      final Map<String, int> transferCounts = {};
      for (var r in rewards) {
        if (r['reward_transfer_history'] != null && (r['reward_transfer_history'] as List).isNotEmpty) {
          var transfers = r['reward_transfer_history'] as List;
          final fromUserId = transfers.first['from_user_id'] as String;
          transferCounts[fromUserId] = (transferCounts[fromUserId] ?? 0) + 1;
        }
      }

      for (var card in cards) {
        final userId = card['user_id'] as String;
        card['rewards_transferred'] = transferCounts[userId] ?? 0;
      }
    } catch (e) {
      // Silently fail if reward_transfer_history is unavailable, default to 0
      for (var card in cards) {
        card['rewards_transferred'] = 0;
      }
    }

    return cards;
  }

  Future<List<Map<String, dynamic>>> fetchPendingScans(String businessId) async {
    final response = await _supabase
        .from('scans')
        .select('''
          *,
          profiles(
            full_name,
            avatar_url,
            is_demo
          )
        ''')
        .eq('business_id', businessId)
        .eq('status', 'pending')
        .order('scanned_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchPendingRewards(String businessId) async {
    final response = await _supabase
        .from('rewards')
        .select()
        .eq('business_id', businessId)
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addManualPoints({
    required String userId,
    required String businessId,
    required int points,
  }) async {
    await _supabase.rpc(
      'add_manual_points',
      params: {
        'p_user_id': userId,
        'p_business_id': businessId,
        'p_points': points,
      },
    );
  }

  Future<bool> approveScan({
    required String scanId,
    required String loyaltyCardId,
  }) async {
    // Retorna true si se generó un premio, false si solo se aprobaron los puntos.
    final cardResponse = await _supabase
        .from('loyalty_cards')
        .select('current_points, total_points_lifetime, rewards_claimed, user_id, businesses(id, points_required, reward_long_description)')
        .eq('id', loyaltyCardId)
        .single();

    final currentPoints = (cardResponse['current_points'] as int) + 1;
    final totalPointsLifetime = (cardResponse['total_points_lifetime'] as int) + 1;

    final business = cardResponse['businesses'];
    final pointsRequired = business != null ? (business['points_required'] as int) : 10;
    final userId = cardResponse['user_id'] as String;
    final businessId = business != null ? business['id'] as String : '';

    int pointsToUpdate = currentPoints;
    int rewardsClaimedUpdate = (cardResponse['rewards_claimed'] ?? 0) as int;
    bool rewardGenerated = false;

    final scanResponse = await _supabase
        .from('scans')
        .select('is_demo')
        .eq('id', scanId)
        .single();
    final isDemoTransaction = scanResponse['is_demo'] == true;

    if (currentPoints >= pointsRequired && businessId.isNotEmpty) {
      await _supabase.from('rewards').insert({
        'user_id': userId,
        'business_id': businessId,
        'loyalty_card_id': loyaltyCardId,
        'points_used': pointsRequired,
        'description': business?['reward_long_description'] ?? 'Premio',
        'earned_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'pending',
        'is_demo': isDemoTransaction,
      });

      pointsToUpdate = 0;
      rewardsClaimedUpdate += 1;
      rewardGenerated = true;
    }

    await _supabase
        .from('loyalty_cards')
        .update({
          'current_points': pointsToUpdate,
          'total_points_lifetime': totalPointsLifetime,
          'rewards_claimed': rewardsClaimedUpdate,
          'last_scan_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', loyaltyCardId);

    await _supabase
        .from('scans')
        .update({'status': 'approved'})
        .eq('id', scanId);

    return rewardGenerated;
  }

  Future<void> rejectScan(String scanId) async {
    await _supabase
        .from('scans')
        .update({'status': 'rejected'})
        .eq('id', scanId);
  }

  Future<void> redeemReward({
    required String userId,
    required String businessId,
    required String cardId,
  }) async {
    await _supabase.rpc(
      'redeem_reward',
      params: {
        'p_user_id': userId,
        'p_business_id': businessId,
        'p_loyalty_card_id': cardId,
      },
    );
  }
}
