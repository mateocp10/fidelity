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

    // Tarjetas con un escaneo PENDIENTE de aprobación (recién escaneado).
    // El escaneo no actualiza last_scan_at, así que sin esto la tarjeta
    // recién escaneada cae al fondo. La subimos al tope.
    final pendingScansResp = await _supabase
        .from('scans')
        .select('loyalty_card_id')
        .eq('user_id', userId)
        .eq('status', 'pending');
    final pendingScanCardIds = <String>{};
    for (final s in (pendingScansResp as List)) {
      final id = s['loyalty_card_id'];
      if (id != null) pendingScanCardIds.add(id as String);
    }
    bool hasPendingScan(Map<String, dynamic> c) =>
        pendingScanCardIds.contains(c['id']);

    // Orden por prioridad (partición estable, preserva el orden dentro del grupo):
    //   1) escaneo pendiente de aprobación (recién escaneado)
    //   2) premio ganado sin entregar
    //   3) resto (por last_scan_at)
    final group1 = all.where(hasPendingScan).toList();
    final group2 = all
        .where((c) => !hasPendingScan(c) && _hasUnclaimedReward(c))
        .toList();
    final group3 = all
        .where((c) => !hasPendingScan(c) && !_hasUnclaimedReward(c))
        .toList();
    return [...group1, ...group2, ...group3];
  }

  bool _hasUnclaimedReward(Map<String, dynamic> card) {
    final rewards = (card['rewards'] as List?) ?? const [];
    // Solo 'pending': el premio fue ganado pero el local todavía no lo entregó.
    // 'approved' significa ENTREGADO, así que ya no es un premio por reclamar.
    return rewards.any((r) => (r as Map)['status'] == 'pending');
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
