import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/models/business_category.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(supabaseClientProvider));
});

class BusinessRepository {
  final SupabaseClient _supabase;

  BusinessRepository(this._supabase);

  Future<List<BusinessCategory>> getCategories() async {
    final response = await _supabase
        .from('business_categories')
        .select('id, name')
        .order('name');
    
    return (response as List).map((c) => BusinessCategory.fromJson(c)).toList();
  }

  Future<String?> uploadLogo({
    required String userId,
    required Uint8List fileBytes,
    required String fileExt,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final imagePath = '$userId/$fileName';

    String mimeType = 'image/jpeg';
    if (fileExt == 'png') { mimeType = 'image/png'; }
    else if (fileExt == 'webp') { mimeType = 'image/webp'; }
    else if (fileExt == 'gif') { mimeType = 'image/gif'; }

    await _supabase.storage.from('business-logos').uploadBinary(
      imagePath,
      fileBytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: true,
        contentType: mimeType,
      ),
    );

    return _supabase.storage.from('business-logos').getPublicUrl(imagePath);
  }

  Future<String> createBusiness({
    required String userId,
    required String name,
    String? description,
    String? logoUrl,
    String? address,
    double? latitude,
    double? longitude,
    String? categoryId,
    required String rewardDescription,
    String? rewardLongDescription,
    required int pointsRequired,
  }) async {
    final businessResponse = await _supabase.from('businesses').insert({
      'owner_id': userId,
      'name': name,
      'description': description,
      'logo_url': logoUrl,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'category_id': categoryId,
      'reward_description': rewardDescription,
      'reward_long_description': rewardLongDescription,
      'points_required': pointsRequired,
      'cooldown_hours': 4,
      'is_active': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select().single();

    return businessResponse['id'] as String;
  }

  Future<void> generateInitialQrCode(String businessId) async {
    final newQrCode = const Uuid().v4();
    await _supabase.from('qr_codes').insert({
      'business_id': businessId,
      'qr_code': newQrCode,
      'label': 'QR Principal',
      'is_active': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateBusinessRoleInAuth(String businessId) async {
    await _supabase.auth.updateUser(
      UserAttributes(data: {'role': 'business', 'business_id': businessId}),
    );
  }
}
