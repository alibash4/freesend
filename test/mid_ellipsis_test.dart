import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:free_send/ui/widgets/common.dart';

void main() {
  testWidgets('middle ellipsis keeps the extension', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: MiddleEllipsisText('file-name-that-is-too-long.zip'),
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, contains('…'));
    expect(text.data, endsWith('.zip'));
  });

  testWidgets('middle ellipsis leaves fitting names alone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: MiddleEllipsisText('short.zip'),
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.byType(Text)).data, 'short.zip');
  });
}
