import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../data/user_profile_repository.dart';
import '../../../core/services/push_notification_service.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository();
});

class UserProfileState {
  final bool isLoading;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final String? error;
  final String? email;

  UserProfileState({
    this.isLoading = true,
    this.fullName = '',
    this.phone = '',
    this.avatarUrl,
    this.error,
    this.email,
  });

  UserProfileState copyWith({
    bool? isLoading,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? error,
    String? email,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      error: error, // Clear error if not provided
      email: email ?? this.email,
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfileState> {
  late UserProfileRepository _repository;

  @override
  UserProfileState build() {
    _repository = ref.watch(userProfileRepositoryProvider);
    Future.microtask(() => _loadProfile());
    return UserProfileState(email: Supabase.instance.client.auth.currentUser?.email);
  }

  Future<void> _loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = Supabase.instance.client.auth.currentUser; if (user == null) throw Exception('No user'); final profile = await _repository.getProfile(user.id) ?? {};
      state = state.copyWith(
        isLoading: false,
        fullName: profile['full_name'] ?? '',
        phone: profile['phone'] ?? '',
        avatarUrl: profile['avatar_url'],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> saveProfile({
    required String fullName,
    required String phone,
    XFile? newAvatarFile,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updateProfile(
        userId: Supabase.instance.client.auth.currentUser!.id,
        fullName: fullName,
        phone: phone,
        
        avatarFile: newAvatarFile,
      );
      // Reload profile to get new avatar URL if changed
      await _loadProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> changePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.changePassword(newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.deleteAccount(Supabase.instance.client.auth.currentUser!.id);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Instead of calling signout directly, we tell the auth state provider to do it.
      // Wait, UserProfileNotifier doesn't have direct access to authStateProvider since they are separate notifiers,
      // but it can read other providers via 'ref.read'.
      // Actually, it's better to just call it.
      // But wait! If we import auth_provider.dart, it might cause circular dependency if auth_provider imports user_profile_provider!
      // auth_provider DOES import user_profile_provider to invalidate it.
      // So we shouldn't import auth_provider here.
      // Instead, UserProfileScreen should call ref.read(authStateProvider.notifier).logout() directly!
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfileState>(() {
  return UserProfileNotifier();
});


