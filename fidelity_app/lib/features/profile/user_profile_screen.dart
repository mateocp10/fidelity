import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validators/app_validators.dart';
import '../auth/login_screen.dart';
import '../help/faqs_screen.dart';
import 'providers/user_profile_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  XFile? _newAvatarFile;

  @override
  void initState() {
    super.initState();
    final state = ref.read(userProfileProvider);
    _fullNameController = TextEditingController(text: state.fullName);
    _phoneController = TextEditingController(text: state.phone);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _newAvatarFile = image);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    final success = await ref.read(userProfileProvider.notifier).saveProfile(
      fullName: _fullNameController.text,
      phone: _phoneController.text,
      newAvatarFile: _newAvatarFile,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado'), backgroundColor: AppTheme.accentGreen),
        );
        Navigator.pop(context, true);
      } else {
        final error = ref.read(userProfileProvider).error;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error'), backgroundColor: AppTheme.accentPink),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final confirmController = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: Text('¿ELIMINAR MI CUENTA?', style: GoogleFonts.anton(fontWeight: FontWeight.w400, letterSpacing: 1)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Esta acción es irreversible y cumplimos con borrar todos tus datos personales.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              const Text('Escribe "ELIMINAR" para confirmar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: 'ELIMINAR',
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () {
                if (confirmController.text.trim().toUpperCase() == 'ELIMINAR') Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPink),
              child: const Text('ELIMINAR DEFINITIVAMENTE'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final success = await ref.read(userProfileProvider.notifier).deleteAccount();
    if (mounted) {
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        final error = ref.read(userProfileProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: AppTheme.accentPink),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVisible = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('CAMBIAR CONTRASEÑA',
              style: GoogleFonts.anton(fontWeight: FontWeight.w400, letterSpacing: 1, fontSize: 16),
              textAlign: TextAlign.center),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newPwdController,
                  obscureText: !isVisible,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    helperText: 'Mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setLocalState(() => isVisible = !isVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: AppValidators.validatePassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPwdController,
                  obscureText: !isVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (v) => AppValidators.validateConfirmPassword(v, newPwdController.text),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final success = await ref.read(userProfileProvider.notifier).changePassword(newPwdController.text);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada'), backgroundColor: AppTheme.accentGreen),
        );
      } else {
        final error = ref.read(userProfileProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: AppTheme.accentPink),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿CERRAR SESIÓN?', textAlign: TextAlign.center),
        content: const Text('¿Estás seguro que deseas salir de tu cuenta?',
            textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(userProfileProvider.notifier).logout();
    if (mounted) {
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        final error = ref.read(userProfileProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: AppTheme.accentPink),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserProfileState>(userProfileProvider, (previous, next) {
      if (previous?.fullName != next.fullName && next.fullName.isNotEmpty) {
        _fullNameController.text = next.fullName;
      }
      if (previous?.phone != next.phone && next.phone.isNotEmpty) {
        _phoneController.text = next.phone;
      }
    });

    final state = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('MI PERFIL', style: GoogleFonts.anton(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 2)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: state.isLoading ? null : _saveChanges,
            icon: const Icon(Icons.check_rounded, color: AppTheme.accentGreen, size: 28),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading && state.fullName.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.04),
                                image: _newAvatarFile != null
                                    ? DecorationImage(image: FileImage(File(_newAvatarFile!.path)), fit: BoxFit.cover)
                                    : (state.avatarUrl != null ? DecorationImage(image: NetworkImage(state.avatarUrl!), fit: BoxFit.cover) : null),
                              ),
                              child: (state.avatarUrl == null && _newAvatarFile == null)
                                  ? const Icon(Icons.person_outline, size: 50, color: Colors.black26)
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildField(_fullNameController, 'NOMBRE COMPLETO', Icons.person_outline),
                    const SizedBox(height: 24),
                    _buildField(
                      _phoneController,
                      'TELÉFONO',
                      Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(10),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildEmailReadOnly(state.email ?? ''),
                    const SizedBox(height: 32),

                    // ACCIONES DE CUENTA
                    _ProfileAction(
                      icon: Icons.lock_reset_rounded,
                      label: 'CAMBIAR CONTRASEÑA',
                      color: AppTheme.accentPurple,
                      onTap: _changePassword,
                    ),
                    const SizedBox(height: 12),
                    _ProfileAction(
                      icon: Icons.help_outline_rounded,
                      label: 'PREGUNTAS FRECUENTES',
                      color: AppTheme.accentYellow,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FaqsScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileAction(
                      icon: Icons.logout_rounded,
                      label: 'CERRAR SESIÓN',
                      color: Colors.black54,
                      onTap: _logout,
                    ),
                    const SizedBox(height: 32),
                    TextButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.black26),
                      label: const Text(
                        'ELIMINAR MI CUENTA',
                        style: TextStyle(color: Colors.black26, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                      ),
                    ),
                  ],
                )
                 
                 ,
              ),
            ),
    );
  }

  Widget _buildEmailReadOnly(String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CORREO REGISTRADO',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black38, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, size: 20, color: Colors.black26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black54),
                ),
              ),
              const Icon(Icons.lock_outline, size: 16, color: Colors.black26),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black38, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.black26),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
      ],
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}



