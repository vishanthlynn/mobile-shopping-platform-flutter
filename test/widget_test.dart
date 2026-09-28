import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_market/data/catalog_seed.dart';
import 'package:lumen_market/data/stores.dart';
import 'package:lumen_market/ui/auth_screens.dart';
import 'package:lumen_market/ui/widgets.dart';

void main() {
  testWidgets('product card shows name and price', (tester) async {
    final product = seedProducts.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            width: 180,
            child: ProductCard(product: product, onTap: () {}),
          ),
        ),
      ),
    );
    expect(find.text(product.name), findsOneWidget);
    expect(find.text('\$78.00'), findsOneWidget);
  });

  testWidgets('login screen offers the demo account', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    expect(find.text(demoEmail), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });
}
