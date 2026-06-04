// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fidelity_app/main.dart';
import 'package:fidelity_app/core/config/supabase_config.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  });

  testWidgets('App initializes successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const FidelityApp());

    // Because AuthWrapper starts with a CircularProgressIndicator instead of LoginScreen
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
