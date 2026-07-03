import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../features/business/dashboard/business_dashboard_screen.dart';
import '../../features/cards/card_history_screen.dart';
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
            final payload = details.payload;
            if (payload == null || payload.isEmpty) return;
            try {
              final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
              _handleRoutingData(data);
            } catch (_) {
              // Compatibilidad: si el payload no es JSON, lo tratamos como ruta simple.
              _handleRoutingData({'route': payload});
            }
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
              // Codificamos el data completo como JSON para no perder
              // business_id, loyalty_card_id, etc. al tocar la notificación.
              payload: jsonEncode(message.data),
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
          _handleRoutingData(message.data);
        });

        // App abierta desde estado cerrado
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('App abierta desde notificacion (terminada)');
          // Esperamos un frame para que el navigator este listo
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleRoutingData(initialMessage.data);
          });
        }

        _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);
      }
    } catch (e) {
      debugPrint('Error inicializando notificaciones: ');
    }
  }

  static void _handleRoutingData(Map<String, dynamic> data) {
    // Eliminar la notificación apenas el usuario la toque
    _localNotifications.cancelAll();

    final route = data['route'] as String?;
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
    } else if (route == '/business_dashboard/pending') {
       // (Dueño) Escaneo pendiente: el dashboard raíz ya está renderizado,
       // solo le pedimos que salte a la pestaña PENDIENTES.
       BusinessDashboardScreen.goToTab(1);
    } else if (route == '/business_dashboard/rewards') {
       // (Dueño) Premio solicitado: saltamos a la pestaña PREMIOS.
       BusinessDashboardScreen.goToTab(2);
    } else if (route == '/business_dashboard') {
       // (Dueño) Notificación genérica (ej. transferencia): dejamos el dashboard
       // en su pestaña por defecto (CLIENTES). popUntil(isFirst) ya alcanza.
    } else if (route == '/my_cards') {
       // (Cliente) La raíz del cliente es MyCards, así que popUntil(isFirst)
       // ya lo deja en el lugar correcto. Lo dejamos explícito para evitar
       // que el routing dependa de un comportamiento implícito.
    } else if (route == '/points_approved') {
       // (Cliente) Le dieron/aprobaron un punto: lo llevamos al listado de
       // puntos (pestaña ESCANEOS) de esa tarjeta y disparamos las serpentinas.
       final loyaltyCardId = data['loyalty_card_id'] as String?;
       final businessId = data['business_id'] as String?;
       final businessName = data['business_name'] as String? ?? 'Tus puntos';

       if (loyaltyCardId != null && loyaltyCardId.isNotEmpty &&
           businessId != null && businessId.isNotEmpty) {
         Navigator.of(context).push(
           MaterialPageRoute(
             builder: (_) => CardHistoryScreen(
               loyaltyCardId: loyaltyCardId,
               businessId: businessId,
               businessName: businessName,
               initialTabIndex: 0, // pestaña ESCANEOS (listado de puntos)
             ),
           ),
         );
       }

       // Animación de celebración (serpentinas) al tocar la notificación.
       Future.delayed(const Duration(milliseconds: 500), () {
         if (globalNavigatorKey.currentContext != null) {
           GlobalCelebrationDialog.show(
             globalNavigatorKey.currentContext!,
             title: '¡SUMASTE UN PUNTO!',
             message: '¡Felicidades! Ya puedes ver tu listado de puntos.',
             iconType: 'reward',
           );
         }
       });
    } else if (route == '/transfer_received') {
       // (Cliente) Transferencia recibida: lo redirigimos SÍ O SÍ al historial
       // de premios de esa tarjeta, donde aparece el premio recibido.
       final loyaltyCardId = data['loyalty_card_id'] as String?;
       final businessId = data['business_id'] as String?;
       final businessName = data['business_name'] as String? ?? 'Premio recibido';

       if (loyaltyCardId != null && loyaltyCardId.isNotEmpty &&
           businessId != null && businessId.isNotEmpty) {
         Navigator.of(context).push(
           MaterialPageRoute(
             builder: (_) => CardHistoryScreen(
               loyaltyCardId: loyaltyCardId,
               businessId: businessId,
               businessName: businessName,
               initialTabIndex: 1, // pestaña PREMIOS
             ),
           ),
         );
       } else {
         // Fallback (push viejo sin IDs): al menos mostramos la celebración.
         Future.delayed(const Duration(milliseconds: 500), () {
           if (globalNavigatorKey.currentContext != null) {
             GlobalCelebrationDialog.show(
               globalNavigatorKey.currentContext!,
               title: '¡TE HAN TRANSFERIDO!',
               message: '¡Acabas de recibir un premio! Revisa tus tarjetas.',
               iconType: 'transfer',
             );
           }
         });
       }
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
