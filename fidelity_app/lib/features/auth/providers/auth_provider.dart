import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../business/dashboard/providers/dashboard_provider.dart';
import '../../business/providers/create_business_provider.dart';
import '../../business/rewards/providers/rewards_management_provider.dart';
import '../../cards/providers/card_history_provider.dart';
import '../../cards/providers/my_cards_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../scanner/providers/scanner_provider.dart';
import '../data/auth_repository.dart';
import '../../../main.dart';
import '../../../core/services/push_notification_service.dart';
import '../login_screen.dart';
import 'package:flutter/material.dart';

// Definición de estados posibles para la sesión
abstract class AuthStateStatus {}

class AuthInitial extends AuthStateStatus {}
class AuthUnauthenticated extends AuthStateStatus {}
class AuthAdmin extends AuthStateStatus {}
class AuthBusinessActive extends AuthStateStatus {}
class AuthBusinessInactive extends AuthStateStatus {}
class AuthBusinessPendingCreate extends AuthStateStatus {}
class AuthClient extends AuthStateStatus {}

class AuthNotifier extends Notifier<AuthStateStatus> {
  StreamSubscription? _authSubscription;

  void _clearSessionScopedState() {
    ref.invalidate(cardHistoryProvider);
    ref.invalidate(createBusinessProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(myCardsProvider);
    ref.invalidate(rewardsManagementProvider);
    ref.invalidate(scannerProvider);
    ref.invalidate(userProfileProvider);
  }

  @override
  AuthStateStatus build() {
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    Future.microtask(() => _init());
    return AuthInitial();
  }

  Future<void> _init() async {
    // Escuchar cambios de sesión
    _authSubscription = ref.read(authRepositoryProvider).authStateChanges.listen((data) {
      if (data.event == AuthChangeEvent.signedOut || data.session == null) {
        _clearSessionScopedState();
        state = AuthUnauthenticated();
      } else if (data.event == AuthChangeEvent.signedIn) {
        _clearSessionScopedState(); // Ensure completely fresh state on login
        checkAuth();
      } else {
        checkAuth();
      }
    });

    await checkAuth();
  }

  Future<void> checkAuth() async {
    final repository = ref.read(authRepositoryProvider);
    final session = repository.currentSession;
    if (session == null) {
      state = AuthUnauthenticated();
      return;
    }

    try {
      final user = repository.currentUser;
      if (user == null) {
        state = AuthUnauthenticated();
        return;
      }
      final userRole = user.userMetadata?['role'];

      if (userRole == 'admin') {
        state = AuthAdmin();
      } else if (userRole == 'business') {
        final businessId = user.userMetadata?['business_id'];
        if (businessId == null) {
          state = AuthBusinessPendingCreate();
        } else {
          final isActive = await repository.isBusinessActive(businessId);
          if (isActive) {
            state = AuthBusinessActive();
          } else {
            state = AuthBusinessInactive();
          }
        }
      } else {
        state = AuthClient();
      }
    } catch (e) {
      state = AuthUnauthenticated();
    }
  }

  Future<void> logout() async {
    try {
      await PushNotificationService.removeTokenFromDatabase();
    } catch (_) {}
    await ref.read(authRepositoryProvider).signOut();
    _clearSessionScopedState();
    state = AuthUnauthenticated();
    
    final context = globalNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthStateStatus>(() {
  return AuthNotifier();
});
