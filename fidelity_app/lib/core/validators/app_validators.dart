// lib/core/validators/app_validators.dart
class AppValidators {
  // Validar nombre: solo letras y espacios
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu nombre completo';
    }

    // Regex: solo letras (incluyendo tildes) y espacios
    final nameRegex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!nameRegex.hasMatch(value)) {
      return 'El nombre no debe contener números ni caracteres especiales';
    }

    if (value.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }

    return null;
  }

  // Validar teléfono Ecuador: exactamente 10 dígitos (Obligatorio)
  static String? validateEcuadorPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu número de teléfono';
    }

    // Regex: exactamente 10 dígitos
    final phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'El teléfono debe tener exactamente 10 dígitos (formato Ecuador)';
    }

    return null;
  }

  // Validar email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu email';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }

    return null;
  }

  // Validar contraseña
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }

    if (value.length < 6) {
      return 'Mínimo 6 caracteres';
    }

    return null;
  }

  // Validar confirmación de contraseña
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }

    if (value != password) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }
}
