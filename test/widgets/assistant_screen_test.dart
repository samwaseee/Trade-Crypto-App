import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/View/assistant_screen.dart';
import 'package:my_crypto/theme/app_theme.dart';

void main() {
  testWidgets('AssistantScreen sends its initial prompt on first build',
      (tester) async {
    const prompt = 'Analyze my Bitcoin long position.';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AssistantScreen(initialPrompt: prompt),
      ),
    );
    await tester.pump();

    expect(find.text(prompt), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
