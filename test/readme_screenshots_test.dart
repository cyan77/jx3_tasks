import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jx3_tasks/app.dart';
import 'package:jx3_tasks/data/local_store.dart';

Future<LocalStore> demoStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = LocalStore();
  await store.load();
  store.tasks = [
    for (var index = 0; index < store.tasks.length; index++)
      store.tasks[index].copyWith(
        tags: index % 3 == 0
            ? const ['日常', '组队']
            : index % 3 == 1
                ? const ['周常']
                : const ['休闲'],
      ),
  ];
  return store;
}

Future<void> loadScreenshotFont() async {
  final bytes = await File(
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  ).readAsBytes();
  await (FontLoader('Arial')
        ..addFont(Future.value(ByteData.sublistView(bytes))))
      .load();
}

void main() {
  testWidgets('README mobile home screenshot', (tester) async {
    await loadScreenshotFont();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(Jx3TasksApp(store: await demoStore()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/readme-home-mobile.png'),
    );
  });

  testWidgets('README desktop task screenshot', (tester) async {
    await loadScreenshotFont();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(Jx3TasksApp(store: await demoStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-tag-filter-button')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/readme-tasks-desktop.png'),
    );
  });
}
