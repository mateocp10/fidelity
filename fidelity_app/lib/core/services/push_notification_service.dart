import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../features/business/dashboard/business_dashboard_screen.dart';
import '../../features/cards/my_cards_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/admin/admin_businesses_screen.dart';
import '../../features/admin/admin_activity_screen.dart';
import '../../features/admin/admin_rewards_screen.dart';
import '../widgets/global_celebration_dialog.dart';

class PushNotificationService {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificaciones de Fidelity',
    description: 'Este canal se usa para notificaciones importantes.',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> initialize() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Permiso de notificaciones concedido.');
        
        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);

        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        );

        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (details) {
            _handleRouting(details.payload);
          },
        );

        final fcmToken = await _firebaseMessaging.getToken();
        
        if (fcmToken != null) {
          debugPrint('FCM Token obtenido: ');
          await _saveTokenToDatabase(fcmToken);
        }

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          RemoteNotification? notification = message.notification;
          AndroidNotification? android = message.notification?.android;

          if (notification != null && android != null) {
            _localNotifications.show(
              notification.hashCode,
              notification.title,
              notification.body,
              payload: message.data['route'],
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _channel.id,
                  _channel.name,
                  channelDescription: _channel.description,
                  importance: _channel.importance,
                  priority: Priority.high,
                  icon: android.smallIcon,
                  playSound: true,
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
            );
          }
        });

        // App abierta desde background
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('App abierta desde notificacion (background)');
          _handleRouting(message.data['route']);
        });

        // App abierta desde estado cerrado
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('App abierta desde notificacion (terminada)');
          // Esperamos un frame para que el navigator este listo
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleRouting(initialMessage.data['route']);
          });
        }

        _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);
      }
    } catch (e) {
      debugPrint('Error inicializando notificaciones: ');
    }
  }

  static void _handleRouting(String? route) {
    // Eliminar la notificación apenas el usuario la toque
    _localNotifications.cancelAll();

    if (route == null) return;
    
    final context = globalNavigatorKey.currentContext;
    if (context == null) return;

    // Práctica de grado empresarial: NUNCA destruir el AuthWrapper raíz con pushAndRemoveUntil.
    // Esto rompía el árbol de widgets y trababa la app cuando cambiaba el estado de autenticación
    // o al encadenar navegaciones múltiples muy rápidas.
    // Siempre limpiamos la pila de navegación de forma segura hasta llegar al Root.
    Navigator.of(context).popUntil((r) => r.isFirst);

    // Dependiendo de la ruta, pusheamos la pantalla deseada sobre el Dashboard/Root actual.
    // Las rutas raíz como /my_cards, /admin_dashboard, o /business_dashboard ya están renderizadas
    // por defecto en el AuthWrapper según el rol, por lo que popUntil(isFirst) es suficiente.
    if (route == '/admin_users') {
       Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
    } else if (route == '/admin_businesses') {
       Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminBusinessesScreen()));
    } else if (route == '/admin_activity') {
       Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminActivityScreen()));
    } else if (route == '/admin_rewards') {
       Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRewardsScreen()));
    } else if (route == '/transfer_received') {
       // La ruta raíz es MyCards para el cliente, así que popUntil(isFirst) ya lo deja ahí.
       // Esperamos a que la navegación termine y lanzamos la animación.
       Future.delayed(const Duration(milliseconds: 500), () {
         if (globalNavigatorKey.currentContext != null) {
           GlobalCelebrationDialog.show(
             globalNavigatorKey.currentContext!,
             title: '¡TE HAN TRANSFERIDO!',
             message: '¡Acabas de recibir un premio de un amigo! Revisa tus tarjetas.',
             iconType: 'transfer',
           );
         }
       });
    }
    // Nota: Para /business_dashboard y /my_cards el AuthWrapper ya hace el trabajo por nosotros.
  }

  static Future<void> _saveTokenToDatabase(String token) async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', user.id);
        debugPrint('Token guardado en Supabase exitosamente.');
      } catch (e) {
        debugPrint('Error guardando token en BD: ');
      }
    }
  }

  static Future<void> removeTokenFromDatabase() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'fcm_token': null})
            .eq('id', user.id);
        await _firebaseMessaging.deleteToken();
        debugPrint('Token eliminado de Supabase exitosamente al cerrar sesion.');
      } catch (e) {
        debugPrint('Error eliminando token: $e');
      }
    }
  }
}
