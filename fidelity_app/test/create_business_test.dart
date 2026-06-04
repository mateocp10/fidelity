// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelity_app/features/business/create_business_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fidelity_app/core/config/supabase_config.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase if not already initialized
    // Note: In a real test environment with full mocks, we'd mock the client.
    // Here we just ensure initialization for the widgets to mount.
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (_) {
      // Already initialized
    }
  });

  testWidgets('Navigation to CreateBusinessScreen smoke test', (
    WidgetTester tester,
  ) async {
    // We cannot fully test the Supabase interaction without deep mocking,
    // but we can test that CreateBusinessScreen builds correctly.

    await tester.pumpWidget(const MaterialApp(home: CreateBusinessScreen()));

    // Verify key elements of the Create Business Screen
    expect(find.text('Registrar Negocio'), findsOneWidget);
    expect(find.text('Nombre del negocio'), findsOneWidget);
    expect(find.text('Categoría'), findsOneWidget);
    expect(find.text('Ubicación'), findsOneWidget);

    // Verify the button exists
    expect(
      find.widgetWithText(ElevatedButton, 'Guardar Negocio'),
      findsOneWidget,
    );
  });
}
