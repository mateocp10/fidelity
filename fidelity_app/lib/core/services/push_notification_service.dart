import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../features/business/dashboard/business_dashboard_screen.dart';
import '../../features/cards/my_cards_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';

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
    if (route == null) return;
    
    final context = globalNavigatorKey.currentContext;
    if (context == null) return;

    if (route == '/business_dashboard' || route == 'pending_scans') {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => const BusinessDashboardScreen(initialIndex: 1)),
         (r) => false,
       );
    } else if (route == '/business_dashboard/rewards') {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => const BusinessDashboardScreen(initialIndex: 2)),
         (r) => false,
       );
    } else if (route == '/my_cards') {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => const MyCardsScreen()),
         (r) => false,
       );
    } else if (route == '/admin_dashboard') {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
         (r) => false,
       );
    }
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
