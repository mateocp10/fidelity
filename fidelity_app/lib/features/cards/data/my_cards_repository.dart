import 'package:supabase_flutter/supabase_flutter.dart';

class MyCardsRepository {
  final SupabaseClient _supabase;

  MyCardsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser!.id;

  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = currentUserId;
    return await _supabase
        .from('profiles')
        .select('full_name, avatar_url')
        .eq('id', userId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getLoyaltyCards() async {
    final userId = currentUserId;
    final response = await _supabase
        .from('loyalty_cards')
        .select('''
          *,
          businesses!inner(
            id,
            name,
            category_id,
            business_categories(name),
            reward_description,
            reward_long_description,
            points_required,
            logo_url
          ),
          rewards(id, status, earned_at)
        ''')
        .eq('user_id', userId)
        .order('last_scan_at', ascending: false, nullsFirst: false)
        .order('updated_at', ascending: false);

    final all = List<Map<String, dynamic>>.from(response);

    // Las tarjetas con un premio sin reclamar (ganado o recibido por
    // transferencia) suben al tope para que el usuario lo vea primero.
    // Partición estable: preserva el orden original dentro de cada grupo.
    final withReward = all.where(_hasUnclaimedReward).toList();
    final withoutReward = all.where((c) => !_hasUnclaimedReward(c)).toList();
    return [...withReward, ...withoutReward];
  }

  bool _hasUnclaimedReward(Map<String, dynamic> card) {
    final rewards = (card['rewards'] as List?) ?? const [];
    return rewards.any((r) {
      final s = (r as Map)['status'];
      return s == 'pending' || s == 'approved';
    });
  }

  RealtimeChannel setupRealtimeSubscription({
    required void Function(Map<String, dynamic> newData, Map<String, dynamic> oldData) onCardUpdated,
  }) {
    final userId = currentUserId;
    return _supabase
        .channel('public:loyalty_cards_client')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'loyalty_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            final oldData = payload.oldRecord;
            onCardUpdated(newData, oldData);
          },
        )
        .subscribe();
  }
}
