import 'package:flutter_test/flutter_test.dart';
import 'package:appmobilesos/main.dart';

void main() {
  testWidgets('App loads main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AppMobileSOS());
    await tester.pumpAndSettle();

    expect(find.text('SOS - Trang chính'), findsOneWidget);
  });
}
