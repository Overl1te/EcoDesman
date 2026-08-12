import "package:eco_nizhny/app/app.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  testWidgets("app routes guest to login flow", (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: EcoNizhnyApp()));

    await tester.pumpAndSettle();

    expect(find.text("Вход"), findsAtLeastNWidgets(1));
    expect(find.text("Продолжить как гость"), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });
}
