import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileRepository {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    return await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
  }

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
    XFile? avatarFile,
  }) async {
    String? finalAvatarUrl;

    if (avatarFile != null) {
      final imageExtension = avatarFile.path.split('.').last.toLowerCase();
      final imagePath = '$userId/avatar.$imageExtension';

      Uint8List? fileBytes;
      if (kIsWeb) {
        fileBytes = await avatarFile.readAsBytes();
      } else {
        fileBytes = await FlutterImageCompress.compressWithFile(
          avatarFile.path,
          minWidth: 500,
          minHeight: 500,
          quality: 70,
        );
        fileBytes ??= await File(avatarFile.path).readAsBytes();
      }

      await _supabase.storage.from('avatars').uploadBinary(
        imagePath,
        fileBytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final rawUrl = _supabase.storage.from('avatars').getPublicUrl(imagePath);
      finalAvatarUrl = '$rawUrl?t=$timestamp';
    }

    await _supabase.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
      if (finalAvatarUrl != null) 'avatar_url': finalAvatarUrl,
    }).eq('id', userId);
  }

  Future<void> deleteAccount(String userId) async {
    // Esto asume que tienes un trigger o function en Supabase, o que llamas a edge function
    // Porque el cliente no puede borrar el auth.users directamente.
    // Llama a un RPC:
    await _supabase.rpc('delete_user_account');
  }

  Future<void> changePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }
}

