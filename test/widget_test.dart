import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:escrow_app/app.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const EscrowApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
