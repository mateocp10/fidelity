import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

final cardHistoryRepositoryProvider = Provider<CardHistoryRepository>((ref) {
  return CardHistoryRepository(ref.watch(supabaseClientProvider));
});

class CardHistoryRepository {
  final SupabaseClient _supabase;

  CardHistoryRepository(this._supabase);

  Future<List<List<Map<String, dynamic>>>> fetchHistory(String cardId, String businessId, DateTimeRange? range) async {
    final userId = _supabase.auth.currentUser?.id;

    var scansQuery = _supabase
        .from('scans')
        .select('*, businesses(name)')
        .eq('loyalty_card_id', cardId)
        .eq('status', 'approved');

    var rewardsQuery = _supabase
        .from('rewards')
        .select('*, description, businesses(name, reward_description), reward_transfer_history(to_user_id, profiles!reward_transfer_history_to_user_id_fkey(full_name))')
        .eq('loyalty_card_id', cardId);

    // Also fetch rewards that this user transferred OUT for this business
    var transfersOutQuery = _supabase
        .from('reward_transfer_history')
        .select('transferred_at, rewards(*, description, businesses(name, reward_description)), to_user_id, profiles!reward_transfer_history_to_user_id_fkey(full_name)')
        .eq('from_user_id', userId ?? '')
        .eq('business_id', businessId);

    if (range != null) {
      final start = range.start.toUtc().toIso8601String();
      final end = range.end.add(const Duration(days: 1)).toUtc().toIso8601String();
      scansQuery = scansQuery.gte('scanned_at', start).lt('scanned_at', end);
      rewardsQuery = rewardsQuery.gte('earned_at', start).lt('earned_at', end);
      transfersOutQuery = transfersOutQuery.gte('transferred_at', start).lt('transferred_at', end);
    }

    final responses = await Future.wait([
      scansQuery.order('scanned_at', ascending: false),
      rewardsQuery.order('earned_at', ascending: false),
      transfersOutQuery.order('transferred_at', ascending: false),
    ]);

    final activeRewards = List<Map<String, dynamic>>.from(responses[1]);
    final transferredOut = List<Map<String, dynamic>>.from(responses[2]).map((t) {
      final reward = t['rewards'] as Map<String, dynamic>? ?? {};
      // Inject transfer info so the UI can render it as a transferred reward
      reward['reward_transfer_history'] = [
        {
          'to_user_id': t['to_user_id'],
          'profiles': t['profiles']
        }
      ];
      // Override status so UI knows it's transferred
      reward['status'] = 'transferred_out';
      return reward;
    }).toList();

    // Combine and sort by earned_at desc
    final allRewards = [...activeRewards, ...transferredOut];
    allRewards.sort((a, b) {
      final dateA = DateTime.parse(a['earned_at']);
      final dateB = DateTime.parse(b['earned_at']);
      return dateB.compareTo(dateA); // descending
    });

    return [
      List<Map<String, dynamic>>.from(responses[0]),
      allRewards,
    ];
  }
}
