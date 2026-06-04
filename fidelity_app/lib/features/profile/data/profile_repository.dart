import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
  }) async {
    await _supabase.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', userId);
  }
}
