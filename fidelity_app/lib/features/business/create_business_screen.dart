import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'widgets/business_creation/step_logo_picker.dart';
import 'widgets/business_creation/step_personal_data.dart';
import 'widgets/business_creation/step_business_data.dart';
import 'widgets/business_creation/step_campaign_data.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/business_category.dart';
import '../../core/providers/supabase_provider.dart';
import '../auth/providers/auth_provider.dart';

import 'providers/create_business_provider.dart';
import 'data/business_repository.dart';
import '../profile/data/profile_repository.dart';

class CreateBusinessScreen extends ConsumerStatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  ConsumerState<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends ConsumerState<CreateBusinessScreen> {
  int _currentStep = 0;

  // Form keys for steps
  final _personalFormKey = GlobalKey<FormState>();
  final _businessFormKey = GlobalKey<FormState>();
  final _campaignFormKey = GlobalKey<FormState>();

  // Controllers & Data
  XFile? _logoFile;
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _businessNameController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  BusinessCategory? _selectedCategory;
  List<BusinessCategory> _categories = [];
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _selectedAddress = '';

  final _rewardDescriptionController = TextEditingController();
  final _rewardLongDescriptionController = TextEditingController();
  final _pointsRequiredController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingProfileData();
      _loadCategories();
    });
  }

  Future<void> _loadCategories() async {
    try {
      final repo = ref.read(businessRepositoryProvider);
      final categories = await repo.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          if (_categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadExistingProfileData() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user != null) {
      try {
        final repo = ref.read(profileRepositoryProvider);
        final profile = await repo.getProfile(user.id);
        if (profile != null && mounted) {
          setState(() {
            _fullNameController.text = profile['full_name'] ?? '';
            _phoneController.text = profile['phone'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
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

  void _nextStep() {
    bool canContinue = false;

    if (_currentStep == 0) {
      canContinue = true;
    } else if (_currentStep == 1) {
      if (_personalFormKey.currentState!.validate()) canContinue = true;
    } else if (_currentStep == 2) {
      if (_businessFormKey.currentState!.validate()) {
        if (_selectedLatitude == null || _selectedLongitude == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes seleccionar la ubicación en el mapa'),
              backgroundColor: AppTheme.accentPink,
            ),
          );
        } else {
          canContinue = true;
        }
      }
    } else if (_currentStep == 3) {
      if (_campaignFormKey.currentState!.validate()) {
        _submitBusiness();
        return;
      }
    }

    if (canContinue && _currentStep < 3) {
      setState(() => _currentStep += 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  void _submitBusiness() {
    final pointsText = _pointsRequiredController.text.trim();
    final pointsRequired = int.tryParse(pointsText) ?? 10;

    ref.read(createBusinessProvider.notifier).submitBusiness(
      fullName: _fullNameController.text,
      phone: _phoneController.text,
      logoFile: _logoFile,
      businessName: _businessNameController.text,
      businessDescription: _businessDescriptionController.text,
      address: _selectedAddress,
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
      categoryId: _selectedCategory?.id.toString(),
      rewardDescription: _rewardDescriptionController.text,
      rewardLongDescription: _rewardLongDescriptionController.text,
      pointsRequired: pointsRequired,
    );
  }

  void _showSuccessDialog() {
    final String businessName = _businessNameController.text.trim();
    final String waMessage =
        'Hola, acabo de crear mi negocio $businessName y quiero información para activar la cuenta.';
    final String waUrl = 'https://wa.me/593995371895?text=${Uri.encodeComponent(waMessage)}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          '¡TODO LISTO!',
          style: GoogleFonts.anton(
            letterSpacing: 1,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tu negocio fue creado exitosamente.\n\nPara activarlo en la plataforma, comunícate con nosotros por WhatsApp o correo:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('mailto:fidelitysistemadefidelizacion@gmail.com')),
                icon: const Icon(Icons.email_outlined, color: Colors.blue),
                label: const Text('Enviar Correo', style: TextStyle(color: Colors.blue)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.03, duration: 1.2.seconds, curve: Curves.easeInOut),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse(waUrl)),
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                label: const Text('Contactar por WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.03, duration: 1.2.seconds, delay: 600.ms, curve: Curves.easeInOut),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authStateProvider.notifier).logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final createBusinessState = ref.watch(createBusinessProvider);

    ref.listen<CreateBusinessState>(createBusinessProvider, (previous, next) {
      if (next.error != null && (previous?.error != next.error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear negocio: ${next.error}'),
            backgroundColor: AppTheme.accentPink,
          ),
        );
      } else if (next.isSuccess && (previous?.isSuccess != next.isSuccess)) {
        _showSuccessDialog();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configurar Negocio'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false, // Prevent going back if mandatory
      ),
      body: createBusinessState.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
              ),
            )
          : Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: _nextStep,
              onStepCancel: _previousStep,
              physics: const ScrollPhysics(),
              controlsBuilder: (context, details) {
                final isLastStep = _currentStep == 3;
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isLastStep ? 'Finalizar y Crear' : 'Siguiente',
                          ),
                        ),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: details.onStepCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black54,
                          ),
                          child: const Text('Atrás'),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Logo de la Tienda'),
                  subtitle: const Text('Imagen principal de tu negocio'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0
                      ? StepState.complete
                      : StepState.indexed,
                  content: StepLogoPicker(
                    initialImage: _logoFile,
                    onImageSelected: (file) => setState(() => _logoFile = file),
                  ),
                ),
                Step(
                  title: const Text('Datos Personales'),
                  subtitle: const Text('Información de contacto'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1
                      ? StepState.complete
                      : StepState.indexed,
                  content: StepPersonalData(
                    formKey: _personalFormKey,
                    fullNameController: _fullNameController,
                    phoneController: _phoneController,
                  ),
                ),
                Step(
                  title: const Text('Datos del Negocio'),
                  subtitle: const Text('Nombre, categoría y ubicación'),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2
                      ? StepState.complete
                      : StepState.indexed,
                  content: StepBusinessData(
                    formKey: _businessFormKey,
                    nameController: _businessNameController,
                    descriptionController: _businessDescriptionController,
                    selectedCategory: _selectedCategory,
                    categories: _categories,
                    onCategoryChanged: (cat) =>
                        setState(() => _selectedCategory = cat),
                    latitude: _selectedLatitude,
                    longitude: _selectedLongitude,
                    address: _selectedAddress,
                    onLocationSelected: (lat, lng, address) {
                      setState(() {
                        _selectedLatitude = lat;
                        _selectedLongitude = lng;
                        _selectedAddress = address;
                      });
                    },
                  ),
                ),
                Step(
                  title: const Text('Datos de Campaña'),
                  subtitle: const Text('Premio principal y puntos'),
                  isActive: _currentStep >= 3,
                  state: _currentStep == 3
                      ? StepState.editing
                      : StepState.indexed,
                  content: StepCampaignData(
                    formKey: _campaignFormKey,
                    rewardController: _rewardDescriptionController,
                    rewardLongController: _rewardLongDescriptionController,
                    pointsController: _pointsRequiredController,
                  ),
                ),
              ],
            ),
    );
  }
}
