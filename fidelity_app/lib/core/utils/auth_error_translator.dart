import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Traductor centralizado de errores de autenticación de Supabase a español.
///
/// Supabase devuelve los mensajes de [AuthException] en inglés. En lugar de
/// mostrar esos mensajes crudos al usuario, esta utilidad los mapea a textos
/// claros en español. Es la ÚNICA fuente de verdad para estos mensajes:
/// usala en login, registro, recuperación de contraseña, etc.
class AuthErrorTranslator {
  AuthErrorTranslator._();

  /// Traduce cualquier error de auth (o de red) a un mensaje en español.
  ///
  /// Acepta el objeto de error tal cual viene del `catch`. Maneja
  /// [AuthException], errores de red ([SocketException]) y cualquier otro caso
  /// con un fallback genérico.
  static String translate(Object error) {
    if (error is AuthException) {
      return _fromMessage(error.message);
    }
    if (error is SocketException) {
      return 'No hay conexión a internet. Revisá tu red e intentá de nuevo.';
    }
    return _fromMessage(error.toString());
  }

  static String _fromMessage(String rawMessage) {
    final msg = rawMessage.toLowerCase();

    // Credenciales inválidas (el caso más común al loguearse).
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Correo o contraseña incorrectos.';
    }

    // Email no confirmado.
    if (msg.contains('email not confirmed') ||
        msg.contains('email not verified')) {
      return 'Tenés que confirmar tu correo antes de iniciar sesión.';
    }

    // Usuario ya registrado.
    if (msg.contains('user already registered') ||
        msg.contains('already been registered') ||
        msg.contains('already registered')) {
      return 'Este correo ya está registrado. Probá iniciar sesión.';
    }

    // Usuario inexistente.
    if (msg.contains('user not found')) {
      return 'No existe una cuenta con este correo.';
    }

    // Contraseña demasiado corta.
    if (msg.contains('password should be at least') ||
        msg.contains('password is too short')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    // Nueva contraseña igual a la anterior.
    if (msg.contains('new password should be different')) {
      return 'La nueva contraseña debe ser distinta a la anterior.';
    }

    // Formato de email inválido.
    if (msg.contains('unable to validate email address') ||
        msg.contains('invalid email') ||
        msg.contains('invalid format')) {
      return 'El formato del correo no es válido.';
    }

    // Límite de intentos / rate limit.
    if (msg.contains('rate limit') ||
        msg.contains('too many requests') ||
        msg.contains('for security purposes')) {
      return 'Demasiados intentos. Esperá unos segundos e intentá de nuevo.';
    }

    // Token expirado o inválido (links de recuperación/verificación).
    if (msg.contains('token has expired') ||
        msg.contains('invalid token') ||
        msg.contains('otp expired')) {
      return 'El enlace expiró o no es válido. Solicitá uno nuevo.';
    }

    // Registros deshabilitados.
    if (msg.contains('signups not allowed') ||
        msg.contains('signup is disabled')) {
      return 'El registro de cuentas está deshabilitado por el momento.';
    }

    // Errores de red genéricos.
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      return 'No hay conexión a internet. Revisá tu red e intentá de nuevo.';
    }

    // Fallback: no exponemos el mensaje crudo en inglés.
    return 'Ocurrió un error. Intentá de nuevo en unos momentos.';
  }
}
