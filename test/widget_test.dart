import 'package:flutter_test/flutter_test.dart';
import 'package:iftatrack_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const IFTATrackApp());
    expect(find.byType(IFTATrackApp), findsOneWidget);
  });
}
