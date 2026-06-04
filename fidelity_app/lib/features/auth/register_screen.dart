import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart';
import '../business/create_business_screen.dart';
import '../../core/validators/app_validators.dart';
import '../../core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _selectedRole = 'client';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  XFile? _avatarFile;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final metadata = {'role': _selectedRole};
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: metadata,
      );

      if (authResponse.user == null) throw Exception('Error al crear usuario');

      final userId = authResponse.user!.id;

      // Subir Avatar si existe
      String? avatarUrl;
      if (_avatarFile != null) {
        try {
          final fileBytes = await _avatarFile!.readAsBytes();
          final fileExt = _avatarFile!.name.split('.').last.toLowerCase();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          final imagePath = '$userId/$fileName';

          await supabase.storage.from('avatars').uploadBinary(
            imagePath,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
          avatarUrl = supabase.storage.from('avatars').getPublicUrl(imagePath);
        } catch (e) {
          debugPrint('Error uploading avatar: $e');
        }
      }

      await supabase.from('profiles').upsert({
        'id': userId,
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'avatar_url': avatarUrl,
        'role': _selectedRole,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        _showSuccessToast();
        if (authResponse.session == null) {
          _showVerificationDialog();
        } else {
          Future.delayed(1500.ms, () {
            if (mounted) {
              if (_selectedRole == 'business') {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const CreateBusinessScreen()),
                  (route) => false,
                );
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(milliseconds: 2500),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGreen.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '¡CUENTA CREADA CON ÉXITO!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack),
      ),
    );
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text('¡Casi listo!', textAlign: TextAlign.center),
        content: const Text(
          'Te hemos enviado un correo de verificación. Por favor, confirma tu cuenta para continuar.',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ÚNETE A NOSOTROS'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Selector de Rol (Profesional)
                Row(
                  children: [
                    Expanded(
                      child: _RoleSelectorCard(
                        title: 'CLIENTE',
                        icon: Icons.person_outline,
                        color: AppTheme.accentYellow,
                        isSelected: _selectedRole == 'client',
                        onTap: () => setState(() => _selectedRole = 'client'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleSelectorCard(
                        title: 'NEGOCIO',
                        icon: Icons.storefront_outlined,
                        color: AppTheme.accentPurple,
                        isSelected: _selectedRole == 'business',
                        onTap: () => setState(() => _selectedRole = 'business'),
                      ),
                    ),
                  ],
                ).animate().slideY(begin: 0.2).fadeIn(),

                const SizedBox(height: 32),

                // Selector de Imagen (Solo para Clientes)
                if (_selectedRole == 'client')
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                        if (img != null) setState(() => _avatarFile = img);
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                              image: _avatarFile != null 
                                ? DecorationImage(image: FileImage(File(_avatarFile!.path)), fit: BoxFit.cover)
                                : null,
                            ),
                            child: _avatarFile == null 
                              ? const Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.black26)
                              : null,
                          ),
                          if (_avatarFile != null)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: AppTheme.accentPurple, shape: BoxShape.circle),
                                child: const Icon(Icons.edit, size: 14, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ).animate(delay: 100.ms).fadeIn().scale(),

                const SizedBox(height: 40),

                Text('DATOS PERSONALES', style: theme.textTheme.labelLarge)
                  .animate(delay: 200.ms).fadeIn(),
                
                const SizedBox(height: 20),

                // Campos del Formulario
                Column(
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        hintText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: AppValidators.validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: AppValidators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone_outlined),
                        helperText: '10 dígitos (Ecuador)',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: AppValidators.validateEcuadorPhone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Contraseña segura',
                        helperText: 'Mínimo 6 caracteres',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      validator: AppValidators.validatePassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Confirma tu contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                        ),
                      ),
                      validator: (v) => AppValidators.validateConfirmPassword(v, _passwordController.text),
                    ),
                  ],
                ).animate(delay: 300.ms).slideY(begin: 0.1).fadeIn(),

                const SizedBox(height: 48),

                // Botón Registro
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                      : Text(_selectedRole == 'business' ? 'CONFIGURAR NEGOCIO' : 'CREAR MI CUENTA'),
                ).animate(delay: 500.ms).scale(curve: Curves.easeOutBack).fadeIn(),

                const SizedBox(height: 24),

                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('¿YA TIENES CUENTA? INICIA SESIÓN'),
                ).animate(delay: 700.ms).fadeIn(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelectorCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleSelectorCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? color : Colors.black45,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isSelected ? Colors.black : Colors.black45,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
