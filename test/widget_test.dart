import 'package:flutter_test/flutter_test.dart';
import 'package:pulltube/main.dart';

void main() {
  testWidgets('renders PullTube shell', (tester) async {
    await tester.pumpWidget(const PullTubeApp());

    expect(find.text('PullTube'), findsOneWidget);
    expect(find.text('Paste & Fetch'), findsOneWidget);
  });
}
