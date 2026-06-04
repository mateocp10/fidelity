import 'package:flutter/material.dart';
import '../../../../core/validators/app_validators.dart';
import 'package:flutter/services.dart';

class StepPersonalData extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;

  const StepPersonalData({
    super.key,
    required this.formKey,
    required this.fullNameController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tus Datos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verifica o actualiza tu información de contacto.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: fullNameController,
            decoration: InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: const Icon(
                Icons.person_outline,
                color: Colors.black,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.black,
                  width: 2,
                ),
              ),
            ),
            validator: AppValidators.validateName,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: const Icon(
                Icons.phone_outlined,
                color: Colors.black,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: '10 dígitos (formato Ecuador)',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: AppValidators.validateEcuadorPhone,
          ),
        ],
      ),
    );
  }
}
