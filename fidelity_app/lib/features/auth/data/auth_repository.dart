import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/providers/supabase_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<void> signOut() async {
    await PushNotificationService.removeTokenFromDatabase();
    await _supabase.auth.signOut();
  }

  Future<void> refreshSession() async {
    await _supabase.auth.refreshSession();
  }

  Future<bool> isBusinessActive(String businessId) async {
    try {
      final response = await _supabase
          .from('businesses')
          .select('is_active')
          .eq('id', businessId)
          .single();
      
      return response['is_active'] ?? false;
    } catch (e) {
      // Si falla la consulta, asumimos que no está activo por seguridad
      return false;
    }
  }
}
