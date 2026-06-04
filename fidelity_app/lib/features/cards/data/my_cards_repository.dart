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
          )
        ''')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
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
