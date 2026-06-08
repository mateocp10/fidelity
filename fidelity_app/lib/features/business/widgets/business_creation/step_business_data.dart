import 'package:flutter/material.dart';
import '../location_picker_map.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/business_category.dart';

class StepBusinessData extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final BusinessCategory? selectedCategory;
  final List<BusinessCategory> categories;
  final ValueChanged<BusinessCategory> onCategoryChanged;

  // Location
  final double? latitude;
  final double? longitude;
  final String address;
  final Function(double, double, String) onLocationSelected;

  const StepBusinessData({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.descriptionController,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos del Negocio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '¿Cómo reconocerán los clientes a tu local?',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Nombre del negocio',
              prefixIcon: const Icon(Icons.store, color: Colors.black),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),

          Autocomplete<BusinessCategory>(
            initialValue: TextEditingValue(text: selectedCategory?.name.toUpperCase() ?? ''),
            displayStringForOption: (BusinessCategory option) => option.name.toUpperCase(),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return categories;
              }
              return categories.where((BusinessCategory option) {
                return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (BusinessCategory selection) {
              onCategoryChanged(selection);
            },
            fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Categoría (Busca o selecciona)',
                  prefixIcon: const Icon(Icons.category, color: Colors.black),
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  if (selectedCategory != null && value.toLowerCase() != selectedCategory!.name.toLowerCase()) {
                    // Reset if user types something else
                    // (Requires logic update in parent if we want to clear it, but checking in validator is enough)
                  }
                },
                validator: (String? value) {
                  if (selectedCategory == null || value == null || value.isEmpty) {
                    return 'Selecciona una categoría válida de la lista';
                  }
                  return null;
                },
              );
            },
            optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<BusinessCategory> onSelected, Iterable<BusinessCategory> options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8.0,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    // We let it size based on the parent's constraints mostly, but give it a max width
                    width: MediaQuery.of(context).size.width - 48, 
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final BusinessCategory option = options.elementAt(index);
                        return ListTile(
                          title: Text(option.name.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: descriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Descripción (Opcional)',
              prefixIcon: const Icon(
                Icons.description,
                color: Colors.black,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Ubicación Exacta *',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mueve el marcador o toca el mapa para ubicarte.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),

          LocationPickerMap(
            initialLatitude: latitude,
            initialLongitude: longitude,
            initialAddress: address,
            onLocationSelected: onLocationSelected,
          ),

          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.accentGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
