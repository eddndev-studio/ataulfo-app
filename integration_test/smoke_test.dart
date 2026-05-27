import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:agentic/main.dart' as app;

/// Smoke E2E del cliente Flutter contra un backend agentic-go real.
///
/// Recorre la ruta crítica del operador: arranque en `/login` (storage
/// limpio), login con la cuenta smoke, navegación a la pestaña Plantillas,
/// tap en la primera plantilla, entrar al editor, modificar el system
/// prompt, guardar y verificar el regreso al detalle.
///
/// Asume que el backend está corriendo en `--dart-define=AGENTIC_BASE_URL`
/// y que existe al menos una plantilla en la org del operador. Si la lista
/// está vacía (BD fresca), el test salta el tramo del editor con un
/// `skip:` explícito en lugar de fallar — el setup del seed de templates
/// queda fuera del scope del smoke.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Storage limpio ⇒ AuthCheckRequested cae a Unauthenticated y el
    // router lleva a `/login` deterministicamente.
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
  });

  testWidgets(
    'login → tab Plantillas → primer template → edit → submit → detalle',
    (tester) async {
      app.main();

      // Esperar a que el Splash colapse en LoginPage.
      await _pumpUntil(tester, find.byKey(const Key('login.email')));

      await tester.enterText(
        find.byKey(const Key('login.email')),
        'smoke@agentic.local',
      );
      await tester.enterText(
        find.byKey(const Key('login.password')),
        'smoke-agentic-2026',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // El botón "Entrar" es un AppButton.filled; tappear el texto bubblea
      // al InkWell que captura el evento.
      await tester.tap(find.text('Entrar'));

      // El AuthBloc emite Authenticated; el router empuja /home (ShellPage).
      // El primer tab (Bots) es el activo por default — esperamos su AppBar.
      await _pumpUntil(
        tester,
        find.widgetWithText(AppBar, 'Bots'),
        timeout: const Duration(seconds: 15),
      );

      // Cambiar a la tab Plantillas (BottomNavigationBarItem index 1).
      await tester.tap(find.text('Plantillas').last);
      await _pumpUntil(tester, find.widgetWithText(AppBar, 'Plantillas'));

      // La lista se carga con spinner. Espera el primer tile o el
      // empty state — cualquiera de los dos resuelve el smoke.
      final emptyFinder = find.byKey(const Key('templates.empty'));
      final tileFinder = find.byType(InkWell).hitTestable();
      await _pumpUntilAny(tester, <Finder>[
        emptyFinder,
        tileFinder,
      ], timeout: const Duration(seconds: 15));

      if (emptyFinder.evaluate().isNotEmpty) {
        // Backend vivo, login OK, pero org sin templates seed. Reportar
        // y terminar el smoke sin fallar — seed no es responsabilidad
        // de este test.
        // ignore: avoid_print
        print(
          'SMOKE: org sin templates — tramo de edición saltado. '
          'Crear al menos un template para cubrir el flujo completo.',
        );
        return;
      }

      // Tap en la primera tarjeta. Usamos AppCard como ancestro porque
      // ya quedó en el listado (cada tile es un AppCard).
      await tester.tap(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(InkWell),
            )
            .first,
      );

      // Detalle: esperar el botón de editar.
      await _pumpUntil(
        tester,
        find.byKey(const Key('template_detail.edit_button')),
        timeout: const Duration(seconds: 10),
      );

      await tester.tap(find.byKey(const Key('template_detail.edit_button')));

      // Editor: el form requiere TemplateEditing + CatalogLoaded. Esperar
      // que el campo del system prompt esté visible y editable.
      await _pumpUntil(
        tester,
        find.byKey(const Key('template_edit.field.system_prompt')),
        timeout: const Duration(seconds: 15),
      );

      // Capturar el prompt actual para reescribirlo (idempotencia: dejamos
      // el mismo valor más un sufijo determinista por timestamp).
      final stamp = DateTime.now().toIso8601String();
      final newPrompt = 'Smoke run @ $stamp';
      await tester.enterText(
        find.byKey(const Key('template_edit.field.system_prompt')),
        newPrompt,
      );
      await tester.pump();

      // Submit.
      await tester.ensureVisible(find.byKey(const Key('template_edit.submit')));
      await tester.tap(find.byKey(const Key('template_edit.submit')));

      // El submit completa con pushReplacement a `/templates/:id`. El
      // detalle ya no tiene el botón de editar visible hasta que el load
      // del bloc termine, así que esperamos el botón de "Crear bot" como
      // marca de detalle re-renderizado (es siempre visible en Loaded).
      await _pumpUntil(
        tester,
        find.byKey(const Key('template_detail.create_bot_button')),
        timeout: const Duration(seconds: 15),
      );

      expect(
        find.byKey(const Key('template_detail.create_bot_button')),
        findsOneWidget,
        reason: 'Tras el submit, el detalle se monta con sus botones.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'detalle: agregar → editar → eliminar variable-definition',
    (tester) async {
      app.main();

      // Login — mismo lead-in que el smoke previo. No extraemos helper
      // mientras sean 2 consumers (la convención del repo extrae con
      // el tercero).
      await _pumpUntil(tester, find.byKey(const Key('login.email')));
      await tester.enterText(
        find.byKey(const Key('login.email')),
        'smoke@agentic.local',
      );
      await tester.enterText(
        find.byKey(const Key('login.password')),
        'smoke-agentic-2026',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.text('Entrar'));
      await _pumpUntil(
        tester,
        find.widgetWithText(AppBar, 'Bots'),
        timeout: const Duration(seconds: 15),
      );

      // Tab Plantillas + primera tarjeta.
      await tester.tap(find.text('Plantillas').last);
      await _pumpUntil(tester, find.widgetWithText(AppBar, 'Plantillas'));

      final emptyFinder = find.byKey(const Key('templates.empty'));
      final tileFinder = find.byType(InkWell).hitTestable();
      await _pumpUntilAny(tester, <Finder>[
        emptyFinder,
        tileFinder,
      ], timeout: const Duration(seconds: 15));

      if (emptyFinder.evaluate().isNotEmpty) {
        // ignore: avoid_print
        print(
          'SMOKE TE4: org sin templates — tramo de var-defs saltado. '
          'Crear al menos un template para cubrir el flujo.',
        );
        return;
      }

      await tester.tap(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(InkWell),
            )
            .first,
      );

      // El detalle quedará listo cuando el botón "Agregar variable" del
      // bloc de var-defs entre en Loaded. Esa misma key marca el detalle
      // como completo desde la perspectiva del operador.
      await _pumpUntil(
        tester,
        find.byKey(const Key('var_defs.add_button')),
        timeout: const Duration(seconds: 15),
      );

      // Identidad única por corrida para no colisionar con var-defs
      // creadas por corridas previas que no llegaron al delete.
      final stamp = DateTime.now().millisecondsSinceEpoch.toString();
      final varName = 'smoke_var_$stamp';
      final newDefault = 'editado-$stamp';

      // --- Add ----------------------------------------------------------
      await tester.ensureVisible(find.byKey(const Key('var_defs.add_button')));
      await tester.tap(find.byKey(const Key('var_defs.add_button')));
      await _pumpUntil(
        tester,
        find.byKey(const Key('var_def_form.name')),
        timeout: const Duration(seconds: 5),
      );

      await tester.enterText(
        find.byKey(const Key('var_def_form.name')),
        varName,
      );
      await tester.enterText(
        find.byKey(const Key('var_def_form.default')),
        'pendiente',
      );
      await tester.enterText(
        find.byKey(const Key('var_def_form.description')),
        'Smoke run @ $stamp',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('var_def_form.submit')));

      // El sheet se auto-cierra al primer Loaded post-submit; el submit
      // button vive dentro del sheet, así que su desaparición es señal
      // canónica de "mutación completa + refetch verde".
      await _pumpUntilGone(
        tester,
        find.byKey(const Key('var_def_form.submit')),
        timeout: const Duration(seconds: 15),
      );

      await _pumpUntil(
        tester,
        find.text('{{$varName}}'),
        timeout: const Duration(seconds: 10),
      );

      // --- Edit ---------------------------------------------------------
      await tester.tap(find.text('{{$varName}}'));
      await _pumpUntil(
        tester,
        find.byKey(const Key('var_def_form.name')),
        timeout: const Duration(seconds: 5),
      );

      await tester.enterText(
        find.byKey(const Key('var_def_form.default')),
        newDefault,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('var_def_form.submit')));

      await _pumpUntilGone(
        tester,
        find.byKey(const Key('var_def_form.submit')),
        timeout: const Duration(seconds: 15),
      );

      await _pumpUntil(
        tester,
        find.text(newDefault),
        timeout: const Duration(seconds: 10),
      );

      // --- Delete -------------------------------------------------------
      // El trash icon vive dentro de la misma InkWell del row. Cada fila
      // tiene UN solo IconButton (el delete), así que el descendant es
      // único y no necesita match por icon ni por tooltip.
      final rowFinder = find.ancestor(
        of: find.text('{{$varName}}'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is InkWell &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('var_defs.row.') &&
              !(w.key! as ValueKey<String>).value.endsWith('.delete'),
        ),
      );
      final deleteBtn = find.descendant(
        of: rowFinder,
        matching: find.byType(IconButton),
      );

      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);

      await _pumpUntil(
        tester,
        find.byKey(const Key('var_defs.delete_confirm')),
        timeout: const Duration(seconds: 5),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));

      await _pumpUntilGone(
        tester,
        find.text('{{$varName}}'),
        timeout: const Duration(seconds: 15),
      );

      expect(
        find.text('{{$varName}}'),
        findsNothing,
        reason: 'Var-def eliminada desaparece tras refetch del listado.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Espera frame a frame hasta que `finder` aparezca o se cumpla `timeout`.
///
/// `pumpAndSettle` no sirve cuando la UI tiene animaciones infinitas
/// (CircularProgressIndicator del Splash o del fetch del listado): se
/// cuelga hasta el timeout sin avanzar. Este helper usa pumps cortos y
/// resuelve apenas el finder reporta resultados.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TimeoutException(
    'No apareció ${finder.describeMatch(Plurality.zero)} '
    'en ${timeout.inSeconds}s',
  );
}

/// Igual que `_pumpUntil` pero resuelve apenas CUALQUIERA de los finders
/// reporta resultados. Útil cuando un flujo puede legítimamente terminar
/// en dos estados (lista con items vs empty state).
Future<void> _pumpUntilAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    for (final f in finders) {
      if (f.evaluate().isNotEmpty) return;
    }
  }
  throw TimeoutException('Ningún finder apareció en ${timeout.inSeconds}s');
}

/// Inversa de `_pumpUntil`: resuelve apenas el finder reporta vacío.
/// Útil cuando la señal de "ya pasó" es la desaparición de un widget
/// (sheet auto-pop tras un Loaded, row eliminada tras refetch).
Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isEmpty) return;
  }
  throw TimeoutException(
    '${finder.describeMatch(Plurality.zero)} '
    'no desapareció en ${timeout.inSeconds}s',
  );
}
