import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart';
import '../business/dashboard/business_dashboard_screen.dart';
import '../business/create_business_screen.dart';
import '../cards/my_cards_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/widgets/global_celebration_dialog.dart';
import '../../core/providers/supabase_provider.dart';
import 'dart:async';
import 'providers/auth_provider.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  StreamSubscription<void>? _transferSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Re-verificamos la autenticación por si acaso, aunque el Provider se inicializa solo
      ref.read(authStateProvider.notifier).checkAuth();
    });

    _transferSub = RealtimeSyncService().onRewardTransfersChanged.listen((payload) {
      if (!mounted || payload == null) return;
      final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (payload['to_user_id'] == currentUserId && currentUserId != null) {
        GlobalCelebrationDialog.show(
          context,
          title: '¡TE HAN TRANSFERIDO!',
          message: '¡Acabas de recibir un premio de un amigo! Revisa tus tarjetas.',
          iconType: 'transfer',
        );
      }
    });
  }

  @override
  void dispose() {
    _transferSub?.cancel();
    super.dispose();
  }

  void _showInactiveAccountDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'CUENTA INACTIVA',
          style: GoogleFonts.anton(
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tu negocio se encuentra inactivo.\n\nPor favor, comunícate con nosotros para procesar el pago o la activación de tu cuenta:',
              textAlign: TextAlign.center,
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
                onPressed: () => launchUrl(Uri.parse('https://wa.me/593995371895')),
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
              child: const Text('CERRAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Escuchar cambios de estado para mostrar dialogos (side-effects)
    ref.listen<AuthStateStatus>(authStateProvider, (previous, next) {
      if (next is AuthBusinessInactive && previous is! AuthBusinessInactive) {
        _showInactiveAccountDialog();
      }
      
      // Manejar inicialización de push notification cuando hay usuario validado
      if (next is AuthAdmin || next is AuthBusinessActive || next is AuthClient) {
        PushNotificationService.initialize();
        // Recién acá (ya autenticado) suscribimos el realtime, para que el canal
        // lleve el JWT del usuario y RLS le entregue sus cambios en vivo.
        RealtimeSyncService().initialize();
      } else if (next is AuthUnauthenticated) {
        // Al cerrar sesión, soltamos el canal para que el próximo login abra uno limpio,
        // y reseteamos los flags de sesión (bienvenida / recordatorio de premio) para
        // que el próximo usuario los vea correctamente.
        RealtimeSyncService().reset();
        MyCardsScreen.resetSessionFlags();
      }
    });

    if (authState is AuthInitial) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
          ),
        ),
      );
    }

    if (authState is AuthUnauthenticated) {
      return const LoginScreen();
    }

    if (authState is AuthAdmin) {
      return const AdminDashboardScreen();
    }

    if (authState is AuthBusinessPendingCreate) {
      return const CreateBusinessScreen();
    }

    if (authState is AuthBusinessActive) {
      return const BusinessDashboardScreen();
    }

    if (authState is AuthClient) {
      return const MyCardsScreen();
    }

    // Estado por defecto mientras procesa inactividad
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
        ),
      ),
    );
  }
}
