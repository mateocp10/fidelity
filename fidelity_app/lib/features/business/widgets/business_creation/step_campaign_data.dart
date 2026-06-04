import 'package:flutter/material.dart';

class StepCampaignData extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController rewardController;
  final TextEditingController pointsController;

  const StepCampaignData({
    super.key,
    required this.formKey,
    required this.rewardController,
    required this.pointsController,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tu Primer Sistema de Puntos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '¿Qué ganan tus clientes y cuántos puntos necesitan?',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: rewardController,
            decoration: InputDecoration(
              labelText: 'Premio (ej: Café Gratis, 10% de Descuento)',
              prefixIcon: const Icon(
                Icons.card_giftcard,
                color: Colors.black,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: pointsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Escaneos / Puntos necesarios',
              prefixIcon: const Icon(Icons.star, color: Colors.black),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: 'Recomendamos entre 5 y 10 puntos.',
            ),
            validator: (v) =>
                (int.tryParse(v ?? '') ?? 0) < 1 ? 'Mínimo 1 punto' : null,
          ),
        ],
      ),
    );
  }
}
