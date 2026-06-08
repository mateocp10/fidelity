import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../qr_management/qr_management_screen.dart';
import '../rewards/rewards_management_screen.dart';
import '../profile/business_profile_screen.dart';
import '../../auth/login_screen.dart';
import '../create_business_screen.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/realtime_sync_service.dart';

import 'providers/dashboard_provider.dart';
import 'widgets/dashboard_animated_toast.dart';
import 'widgets/tabs/tab_customers.dart';
import 'widgets/tabs/tab_pending_scans.dart';
import 'widgets/tabs/tab_statistics.dart';
import '../../auth/providers/auth_provider.dart';

class BusinessDashboardScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const BusinessDashboardScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends ConsumerState<BusinessDashboardScreen> with WidgetsBindingObserver {
  static bool _welcomeShown = false;
  
  StreamSubscription<void>? _scansSub;
  StreamSubscription<void>? _rewardsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Forzamos una recarga inicial silenciosa por si venimos de una notificación push
    // en background donde el provider seguía vivo pero desactualizado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).loadData(silent: true);
      _checkWelcomeMessage();
    });

    _scansSub = RealtimeSyncService().onScansChanged.listen((_) {
      if (mounted) {
        ref.read(dashboardProvider.notifier).loadData(silent: true);
      }
    });
    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) {
      if (mounted) {
        ref.read(dashboardProvider.notifier).loadData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scansSub?.cancel();
    _rewardsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Si la app vuelve del background (ej. haciendo click en una notificación),
      // forzamos la actualización de datos para no quedarnos con info vieja.
      if (mounted) {
        ref.read(dashboardProvider.notifier).loadData(silent: true);
      }
    }
  }

  void _checkWelcomeMessage() async {
    if (_welcomeShown) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final hasSeen = user.userMetadata?['has_seen_welcome'] == true;
      if (!hasSeen) {
        _welcomeShown = true;
        if (mounted) {
          _showWelcomeDialog();
        }
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'has_seen_welcome': true}),
          );
        } catch (_) {}
      }
    }
  }

  void _showWelcomeDialog() {
    final state = ref.read(dashboardProvider);
    String ownerDisplayName = '';
    if (state.ownerName.isNotEmpty) {
      final parts = state.ownerName.trim().split(RegExp(r'\s+'));
      ownerDisplayName = parts.length >= 2 ? '${parts[0]} ${parts[1]}' : parts[0];
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Icon(Icons.storefront_rounded, color: AppTheme.accentPurple, size: 48),
            const SizedBox(height: 16),
            Text(
              '¡Bienvenido a Fidelity!',
              style: GoogleFonts.anton(
                fontSize: 24,
                color: AppTheme.accentPurple,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          '¡Hola $ownerDisplayName, tu negocio ha sido registrado y activado exitosamente!\n\nDesde aquí podrás administrar tus clientes, aprobar escaneos y gestionar los premios.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('¡Comenzar!'),
            ),
          ),
        ],
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Future<void> _pickAndUploadLogo(Map<String, dynamic> business) async {
    final ImagePicker picker = ImagePicker();

    final source = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 5, width: 40, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 32),
            const Text('FOTO DE PERFIL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
            const SizedBox(height: 32),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.accentPurple.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.photo_library_rounded, color: AppTheme.accentPurple),
              ),
              title: const Text('ELEGIR DE GALERÍA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.accentYellow.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentYellow),
              ),
              title: const Text('TOMAR FOTO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            if (business['logo_url'] != null) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.accentPink.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_rounded, color: AppTheme.accentPink),
                ),
                title: const Text('ELIMINAR FOTO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.accentPink)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );

    if (source == null) return;

    final supabase = ref.read(supabaseClientProvider);

    if (source == 'delete') {
      try {
        final userId = supabase.auth.currentUser!.id;
        final logoUrl = business['logo_url'] as String;

        final uri = Uri.parse(logoUrl);
        final pathSegments = uri.pathSegments;
        final folderIndex = pathSegments.indexOf('business-logos');
        if (folderIndex != -1 && folderIndex + 1 < pathSegments.length) {
          final objectPath = pathSegments.sublist(folderIndex + 1).join('/');
          await supabase.storage.from('business-logos').remove([objectPath]);
        }

        await supabase.from('businesses').update({'logo_url': null}).eq('owner_id', userId);

        if (mounted) {
          ref.read(dashboardProvider.notifier).loadData(silent: true);
          DashboardAnimatedToast.show(context, 'Foto eliminada exitosamente', AppTheme.accentGreen, Icons.check_circle_rounded);
        }
      } catch (e) {
        if (mounted) {
          DashboardAnimatedToast.show(context, 'Error al eliminar foto', AppTheme.accentPink, Icons.error_outline_rounded);
        }
      }
      return;
    }

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source as ImageSource,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile == null || !mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple)),
        ),
      );

      final fileBytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.name.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final userId = supabase.auth.currentUser!.id;
      final imagePath = '$userId/$fileName';

      String mimeType = 'image/jpeg';
      if (fileExt == 'png') { mimeType = 'image/png'; }
      else if (fileExt == 'webp') { mimeType = 'image/webp'; }
      else if (fileExt == 'gif') { mimeType = 'image/gif'; }

      await supabase.storage.from('business-logos').uploadBinary(
            imagePath,
            fileBytes,
            fileOptions: FileOptions(cacheControl: '3600', upsert: true, contentType: mimeType),
          );
      
      final newLogoUrl = supabase.storage.from('business-logos').getPublicUrl(imagePath);
      await supabase.from('businesses').update({'logo_url': newLogoUrl}).eq('owner_id', userId);

      if (mounted) {
        Navigator.pop(context); // close dialog
        ref.read(dashboardProvider.notifier).loadData(silent: true);
        DashboardAnimatedToast.show(context, 'Logo actualizado exitosamente', AppTheme.accentGreen, Icons.check_circle_rounded);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close dialog
        DashboardAnimatedToast.show(context, 'Error al cambiar logo', AppTheme.accentPink, Icons.error_outline_rounded);
      }
    }
  }

  void _showPendingRewardOverlay() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.accentYellow.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_rounded, size: 48, color: AppTheme.accentYellow),
              ),
              const SizedBox(height: 20),
              const Text('¡PREMIO PENDIENTE!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('Este cliente ya ganó un premio. No podés agregar más puntos hasta que lo retires y lo marques como entregado.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);

    ref.listen<DashboardState>(dashboardProvider, (previous, next) {
      if (next.toastMessage != null && next.toastMessage != previous?.toastMessage) {
        if (next.toastMessage == 'ERROR_PENDING_REWARD') {
          _showPendingRewardOverlay();
        } else {
          DashboardAnimatedToast.show(
            context,
            next.toastMessage!,
            next.toastIsError ? AppTheme.accentPink : AppTheme.accentGreen,
            next.toastIsError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          );
        }
      }
    });

    if (state.isLoading && state.business == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple)),
        ),
      );
    }

    final business = state.business;

    if (business == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi Negocio'),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(color: AppTheme.accentPurple.withValues(alpha: 0.05), shape: BoxShape.circle),
                  child: const Icon(Icons.storefront_rounded, size: 80, color: AppTheme.accentPurple),
                ),
                const SizedBox(height: 40),
                Text('SIN NEGOCIO', style: GoogleFonts.anton(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 2), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text('Registra tu local para empezar a fidelizar a tus clientes con puntos y premios.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black38)),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateBusinessScreen()));
                      ref.read(dashboardProvider.notifier).loadData();
                    },
                    child: const Text('REGISTRAR MI LOCAL'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    String ownerDisplayName = '';
    if (state.ownerName.isNotEmpty) {
      final parts = state.ownerName.trim().split(RegExp(r'\s+'));
      ownerDisplayName = parts.length >= 2 ? '${parts[0]} ${parts[1]}' : parts[0];
    }

    return DefaultTabController(
      length: 5,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 90,
          leadingWidth: 90,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BusinessProfileScreen(business: business, ownerName: state.ownerName)),
                );
                if (result == true) {
                  ref.invalidate(dashboardProvider);
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: 'business_logo',
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      backgroundImage: business['logo_url'] != null ? NetworkImage(business['logo_url']) : null,
                      child: business['logo_url'] == null ? const Icon(Icons.store, color: Colors.black, size: 28) : null,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: GestureDetector(
                      onTap: () => _pickAndUploadLogo(business),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.accentPurple, AppTheme.accentPink], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: const Duration(seconds: 1), begin: const Offset(1, 1), end: const Offset(1.15, 1.15), curve: Curves.easeInOut).shimmer(duration: const Duration(seconds: 3), color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ownerDisplayName.isNotEmpty)
                Text('Hola, $ownerDisplayName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
              Text(business['name'].toString().toUpperCase(), style: GoogleFonts.anton(fontSize: 18, fontWeight: FontWeight.w400, letterSpacing: 0.5)),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${state.customers.length} CLIENTES ACTIVOS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black45)),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await ref.read(authStateProvider.notifier).logout();
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: Colors.black,
            unselectedLabelColor: Colors.black38,
            isScrollable: true,
            tabs: [
              const Tab(text: 'CLIENTES'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('PENDIENTES'),
                    if (state.pendingScans.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppTheme.accentPink, shape: BoxShape.circle),
                        child: Text('${state.pendingScans.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('PREMIOS'),
                    if (state.pendingRewards.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppTheme.accentPurple, shape: BoxShape.circle),
                        child: Text('${state.pendingRewards.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'MÉTRICAS'),
              const Tab(text: 'QR CODES'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              const TabCustomers(),
              const TabPendingScans(),
              RewardsManagementScreen(businessId: business['id']),
              const TabStatistics(),
              QRManagementScreen(businessId: business['id']),
            ],
          ),
        ),
      ),
    );
  }
}
