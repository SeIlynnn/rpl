import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpl/main.dart';

void main() {
  testWidgets('Encyclopedia app launches and displays navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CompanionApp(),
      ),
    );

    // Initial frame loads
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Materials'), findsWidgets);
    expect(find.text('Armors'), findsWidgets);
    expect(find.text('Monsters'), findsWidgets);
  });
}
