import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/screens/avatar_editor_screen.dart';

const _look = AvatarConfig(bodyType: 'male', hairStyle: 'undercut', topStyle: 'tshirt', bottomStyle: 'jeans');

/// A home page that opens the editor, so popping it can be observed.
Future<List<AvatarConfig>> _openEditor(WidgetTester tester) async {
  final saved = <AvatarConfig>[];
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AvatarEditorScreen(initialConfig: _look, gender: 'MAN', onSaved: saved.add),
            )),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // route transition; the preview never settles
  expect(find.text('Tu avatar'), findsOneWidget);
  return saved;
}

Future<void> _changeHair(WidgetTester tester) async {
  await tester.tap(find.text('Pelo'));
  await tester.pump();
  await tester.ensureVisible(find.text('Rapado'));
  await tester.pump();
  await tester.tap(find.text('Rapado'));
  await tester.pump();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Guardar hands the new avatar over and closes', (tester) async {
    final saved = await _openEditor(tester);
    await _changeHair(tester);
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(saved.single.hairStyle, 'buzz');
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('leaving untouched closes at once and saves nothing', (tester) async {
    final saved = await _openEditor(tester);
    await _back(tester);
    expect(find.text('¿Descartar cambios?'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('leaving with changes asks: keep editing, or discard without saving', (tester) async {
    final saved = await _openEditor(tester);
    await _changeHair(tester);

    await _back(tester);
    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tu avatar'), findsOneWidget);

    await _back(tester);
    await tester.tap(find.text('Descartar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('abrir'), findsOneWidget);
    expect(saved, isEmpty);
  });
}
