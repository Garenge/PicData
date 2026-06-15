import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pic_data/pages/main_tab/main_tab_page.dart';

void main() {
  testWidgets('app starts on the main tab shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainTabPage()));

    expect(find.text('导航'), findsWidgets);
    expect(find.text('文件'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
