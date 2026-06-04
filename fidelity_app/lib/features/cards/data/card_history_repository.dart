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

  Future<List<List<Map<String, dynamic>>>> fetchHistory(String cardId, DateTimeRange? range) async {
    var scansQuery = _supabase
        .from('scans')
        .select('*, businesses(name)')
        .eq('loyalty_card_id', cardId)
        .eq('status', 'approved');

    var rewardsQuery = _supabase
        .from('rewards')
        .select('*, description, businesses(name, reward_description)')
        .eq('loyalty_card_id', cardId);

    if (range != null) {
      final start = range.start.toUtc().toIso8601String();
      final end = range.end.add(const Duration(days: 1)).toUtc().toIso8601String();
      scansQuery = scansQuery.gte('scanned_at', start).lt('scanned_at', end);
      rewardsQuery = rewardsQuery.gte('earned_at', start).lt('earned_at', end);
    }

    final responses = await Future.wait([
      scansQuery.order('scanned_at', ascending: false),
      rewardsQuery.order('earned_at', ascending: false),
    ]);

    return [
      List<Map<String, dynamic>>.from(responses[0]),
      List<Map<String, dynamic>>.from(responses[1]),
    ];
  }
}
