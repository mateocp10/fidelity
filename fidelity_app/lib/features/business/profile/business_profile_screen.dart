import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/push_notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/business_category.dart';
import '../../auth/login_screen.dart';
import '../../help/business_faqs_screen.dart';
import '../widgets/location_picker_map.dart';

class BusinessProfileScreen extends StatefulWidget {
  final Map<String, dynamic> business;
  final String ownerName;

  const BusinessProfileScreen({
    super.key,
    required this.business,
    required this.ownerName,
  });

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Profile Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;

  // Business Controllers
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescriptionController;
  late TextEditingController _rewardDescriptionController;
  late TextEditingController _rewardLongDescriptionController;
  late TextEditingController _pointsRequiredController;

  String? _logoUrl;
  XFile? _newLogoFile;

  BusinessCategory? _selectedCategory;
  List<BusinessCategory> _categories = [];

  double? _latitude;
  double? _longitude;
  String? _address;

  @override
  void initState() {
    super.initState();
    _logoUrl = widget.business['logo_url'];
    _fullNameController = TextEditingController(text: widget.ownerName);
    _phoneController = TextEditingController(text: ''); // We'll fetch this

    _businessNameController = TextEditingController(
      text: widget.business['name'],
    );
    _businessDescriptionController = TextEditingController(
      text: widget.business['description'] ?? '',
    );
    _rewardDescriptionController = TextEditingController(
      text: widget.business['reward_description'] ?? '',
    );
    _rewardLongDescriptionController = TextEditingController(
      text: widget.business['reward_long_description'] ?? '',
    );
    _pointsRequiredController = TextEditingController(
      text: widget.business['points_required']?.toString() ?? '10',
    );

    _latitude = widget.business['latitude'];
    _longitude = widget.business['longitude'];
    _address = widget.business['address'];

    _loadProfileData();
    _loadCategories();
  }

  Future<void> _loadProfileData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final profile = await supabase
          .from('profiles')
          .select('phone')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _phoneController.text = profile['phone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile phone: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('business_categories')
          .select()
          .order('name');

      if (mounted) {
        setState(() {
          _categories = (response as List)
              .map((c) => BusinessCategory.fromJson(c))
              .toList();

          final categoryId = widget.business['category_id'];
          if (categoryId != null) {
            try {
              _selectedCategory = _categories.firstWhere(
                (c) => c.id == categoryId,
              );
            } catch (_) {}
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _rewardDescriptionController.dispose();
    _rewardLongDescriptionController.dispose();
    _pointsRequiredController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() => _newLogoFile = image);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final businessId = widget.business['id'];

      // 1. Upload Logo if changed
      String? finalLogoUrl = _logoUrl;
      if (_newLogoFile != null) {
        final fileBytes = await _newLogoFile!.readAsBytes();
        final fileExt = _newLogoFile!.name.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final imagePath = '$userId/$fileName';

        await supabase.storage
            .from('business-logos')
            .uploadBinary(
              imagePath,
              fileBytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );
        final rawUrl = supabase.storage
            .from('business-logos')
            .getPublicUrl(imagePath);
        finalLogoUrl = '$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      }

      // 2. Update Profile
      await supabase
          .from('profiles')
          .update({
            'full_name': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim(),
          })
          .eq('id', userId);

      // 3. Update Business
      await supabase
          .from('businesses')
          .update({
            'name': _businessNameController.text.trim(),
            'description': _businessDescriptionController.text.trim(),
            'logo_url': finalLogoUrl,
            'category_id': _selectedCategory?.id,
            'category': _selectedCategory?.name,
            'address': _address,
            'latitude': _latitude,
            'longitude': _longitude,
            'reward_description': _rewardDescriptionController.text.trim(),
            'reward_long_description': _rewardLongDescriptionController.text
                .trim(),
            'points_required': int.parse(_pointsRequiredController.text),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', businessId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        Navigator.pop(context, true); // Indicate success to refresh parent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final confirmController = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          title: const Text(
            '¿ELIMINAR CUENTA?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Esta acción es irreversible. Se borrarán todos tus datos, negocios, premios y puntos acumulados.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Escribe "ELIMINAR" para confirmar:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: 'ELIMINAR',
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                if (confirmController.text.trim().toUpperCase() == 'ELIMINAR') {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPink,
              ),
              child: const Text('ELIMINAR DEFINITIVAMENTE'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      // Intentamos llamar a la Edge Function (recomendado para GDPR completo)
      try {
        await supabase.functions.invoke(
          'hyper-action',
          headers: {
            'Authorization':
                'Bearer ${supabase.auth.currentSession?.accessToken}',
          },
        );
      } catch (e) {
        debugPrint('Edge Function failed, using RPC fallback: $e');
        // Fallback: Si no has desplegado la Edge Function, al menos limpiamos los datos públicos
        await supabase.rpc(
          'delete_user_data',
          params: {'user_id_param': userId},
        );
      }

      await PushNotificationService.removeTokenFromDatabase();
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.white,
        title: const Text(
          'EDITAR PERFIL',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveChanges,
            icon: const Icon(
              Icons.check_rounded,
              color: AppTheme.accentGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Logo
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Hero(
                              tag: 'business_logo',
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: _newLogoFile != null
                                      ? DecorationImage(
                                          image: FileImage(
                                            File(_newLogoFile!.path),
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : (_logoUrl != null
                                            ? DecorationImage(
                                                image: NetworkImage(_logoUrl!),
                                                fit: BoxFit.cover,
                                              )
                                            : null),
                                ),
                                child:
                                    (_logoUrl == null && _newLogoFile == null)
                                    ? const Icon(
                                        Icons.storefront_rounded,
                                        size: 50,
                                        color: Colors.black26,
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // SECTION: DATOS PERSONALES
                    _buildSectionHeader(
                      'DATOS PERSONALES',
                      Icons.person_outline_rounded,
                    ),
                    _buildTextField(
                      _fullNameController,
                      'NOMBRE COMPLETO',
                      Icons.badge_outlined,
                    ),
                    _buildTextField(
                      _phoneController,
                      'WHATSAPP / CELULAR',
                      Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(10),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),

                    const SizedBox(height: 40),

                    // SECTION: DATOS DEL NEGOCIO
                    _buildSectionHeader(
                      'DATOS DEL NEGOCIO',
                      Icons.storefront_rounded,
                    ),
                    _buildTextField(
                      _businessNameController,
                      'NOMBRE DEL NEGOCIO',
                      Icons.business_rounded,
                    ),
                    _buildTextField(
                      _businessDescriptionController,
                      'DESCRIPCIÓN BREVE',
                      Icons.description_outlined,
                      maxLines: 2,
                      isRequired: false,
                    ),

                    const SizedBox(height: 16),
                    // Category Dropdown
                    const Text(
                      'CATEGORÍA',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.black38,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<BusinessCategory>(
                          value: _selectedCategory,
                          isExpanded: true,
                          items: _categories
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(
                                    cat.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (cat) =>
                              setState(() => _selectedCategory = cat),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Location Picker
                    const Text(
                      'UBICACIÓN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.black38,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        double? tempLat = _latitude;
                        double? tempLng = _longitude;
                        String? tempAddr = _address;

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                title: const Text(
                                  'SELECCIONAR UBICACIÓN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'CONFIRMAR',
                                      style: TextStyle(
                                        color: AppTheme.accentPurple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                              body: LocationPickerMap(
                                initialLatitude: _latitude,
                                initialLongitude: _longitude,
                                initialAddress: _address,
                                onLocationSelected: (lat, lng, addr) {
                                  tempLat = lat;
                                  tempLng = lng;
                                  tempAddr = addr;
                                },
                              ),
                            ),
                          ),
                        );

                        setState(() {
                          _latitude = tempLat;
                          _longitude = tempLng;
                          _address = tempAddr;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppTheme.accentPink,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _address ?? 'SELECCIONAR EN EL MAPA',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: _address == null
                                      ? Colors.black26
                                      : Colors.black,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // SECTION: CAMPAÑA DE PUNTOS
                    _buildSectionHeader(
                      'CAMPAÑA DE PUNTOS',
                      Icons.auto_awesome_rounded,
                    ),
                    _buildTextField(
                      _rewardDescriptionController,
                      '¿QUÉ PREMIO ENTREGAS?',
                      Icons.card_giftcard_rounded,
                    ),
                    _buildTextField(
                      _rewardLongDescriptionController,
                      'DESCRIPCIÓN DEL PREMIO',
                      Icons.description_rounded,
                      maxLines: 2,
                      isRequired: false,
                    ),
                    _buildTextField(
                      _pointsRequiredController,
                      'PUNTOS NECESARIOS',
                      Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 40),

                    // FAQ
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BusinessFaqsScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accentPurple.withValues(alpha: 0.08),
                              AppTheme.accentPink.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.accentPurple.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.help_outline_rounded,
                                color: AppTheme.accentPurple,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'PREGUNTAS FRECUENTES',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Guía completa para gestionar tu negocio',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.accentPurple,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // DELETE ACCOUNT
                    Center(
                      child: TextButton.icon(
                        onPressed: _deleteAccount,
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.black26,
                        ),
                        label: const Text(
                          'ELIMINAR MI CUENTA',
                          style: TextStyle(
                            color: Colors.black26,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accentPurple),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = true,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.black38,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            inputFormatters: inputFormatters,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: Colors.black26),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (isRequired && (value == null || value.isEmpty)) {
                return 'Campo requerido';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
