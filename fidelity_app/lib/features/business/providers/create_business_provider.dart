import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../data/business_repository.dart';

// Estado para la creación
class CreateBusinessState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  CreateBusinessState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  CreateBusinessState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return CreateBusinessState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class CreateBusinessNotifier extends Notifier<CreateBusinessState> {
  @override
  CreateBusinessState build() {
    return CreateBusinessState();
  }

  Future<void> submitBusiness({
    required String fullName,
    required String phone,
    XFile? logoFile,
    required String businessName,
    String? businessDescription,
    required String address,
    required double? latitude,
    required double? longitude,
    String? categoryId,
    String? categoryName,
    required String rewardDescription,
    required int pointsRequired,
  }) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;

    if (userId == null) {
      state = state.copyWith(error: 'Usuario no autenticado', isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final businessRepo = ref.read(businessRepositoryProvider);

      // 1. Actualizar Perfil
      await profileRepo.updateProfile(
        userId: userId,
        fullName: fullName.trim(),
        phone: phone.trim(),
      );

      // 2. Subir Logo si existe
      String? logoUrl;
      if (logoFile != null) {
        final fileBytes = await logoFile.readAsBytes();
        final fileExt = logoFile.name.split('.').last.toLowerCase();
        
        logoUrl = await businessRepo.uploadLogo(
          userId: userId,
          fileBytes: fileBytes,
          fileExt: fileExt,
        );
      }

      // 3. Crear el negocio
      final businessId = await businessRepo.createBusiness(
        userId: userId,
        name: businessName.trim(),
        description: businessDescription?.trim().isEmpty ?? true ? null : businessDescription!.trim(),
        logoUrl: logoUrl,
        address: address.trim().isEmpty ? null : address.trim(),
        latitude: latitude,
        longitude: longitude,
        categoryId: categoryId,
        categoryName: categoryName,
        rewardDescription: rewardDescription.trim(),
        pointsRequired: pointsRequired,
      );

      // 4. Crear QR inicial
      await businessRepo.generateInitialQrCode(businessId);

      // 5. Actualizar Metadata de Auth
      await businessRepo.updateBusinessRoleInAuth(businessId);

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final createBusinessProvider = NotifierProvider<CreateBusinessNotifier, CreateBusinessState>(() {
  return CreateBusinessNotifier();
});
