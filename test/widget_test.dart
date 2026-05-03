import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appmobilesos/main.dart';

void main() {
  testWidgets('App loads main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AppMobileSOS());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
