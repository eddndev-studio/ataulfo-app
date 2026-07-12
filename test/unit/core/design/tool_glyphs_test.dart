import 'package:ataulfo/core/design/tool_glyphs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toolTitleFor', () {
    test('nombra las lecturas del asistente en es-MX', () {
      expect(toolTitleFor('list_bots'), 'Consultó los bots');
      expect(toolTitleFor('get_flow'), 'Consultó un flujo');
    });

    test('nombra las escrituras del asistente en es-MX', () {
      expect(toolTitleFor('create_flow'), 'Creó un flujo');
      expect(toolTitleFor('set_bot_paused'), 'Pausó o reanudó un bot');
      expect(toolTitleFor('update_step'), 'Actualizó un paso');
    });

    test('spawn_agent es "Delegó a un subagente"', () {
      expect(toolTitleFor('spawn_agent'), 'Delegó a un subagente');
    });

    test('una tool desconocida cae a «Usó <tool>»', () {
      expect(toolTitleFor('tool_del_futuro'), 'Usó tool_del_futuro');
    });

    test('un nombre vacío cae a un genérico sin crudo del wire', () {
      expect(toolTitleFor(''), 'Usó una herramienta');
    });
  });

  group('toolIconFor', () {
    test('la familia de bots comparte ícono', () {
      expect(toolIconFor('list_bots'), toolIconFor('set_bot_paused'));
    });

    test('spawn_agent tiene su propio ícono, distinto del genérico', () {
      expect(toolIconFor('spawn_agent'), isNot(toolIconFor('tool_del_futuro')));
    });

    test('una tool desconocida cae al ícono genérico (bolt)', () {
      expect(toolIconFor('tool_del_futuro'), Icons.bolt);
    });
  });
}
