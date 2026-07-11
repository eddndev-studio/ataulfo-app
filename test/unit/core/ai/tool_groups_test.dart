import 'package:ataulfo/core/ai/tool_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolGroup', () {
    // Los ids de wire DEBEN coincidir EXACTAMENTE (valores y orden) con
    // aitools.ValidGroups() del backend. Si cualquiera de los dos lados cambia
    // sin el otro, el drift cross-repo sale AQUÍ en CI — no en runtime con un
    // 422 al guardar o un grupo que no se pinta.
    test('los ids de wire coinciden con el contrato del backend', () {
      expect(ToolGroup.values.map((g) => g.wire).toList(), <String>[
        'mensajeria',
        'acuse',
        'etiquetas',
        'notas',
        'flujos',
        'documentos',
        'archivos',
        'alertas',
        'hora',
        'percepcion',
        'subagentes',
        'historial',
        'analisis',
        'programacion',
        'reenvio',
        'agenda',
        'catalogo',
        'stickers',
      ]);
    });

    test(
      'fromWireOrNull resuelve conocidos y devuelve null para desconocidos',
      () {
        expect(ToolGroup.fromWireOrNull('flujos'), ToolGroup.flujos);
        expect(ToolGroup.fromWireOrNull('percepcion'), ToolGroup.percepcion);
        expect(ToolGroup.fromWireOrNull('historial'), ToolGroup.historial);
        expect(ToolGroup.fromWireOrNull('analisis'), ToolGroup.analisis);
        expect(
          ToolGroup.fromWireOrNull('programacion'),
          ToolGroup.programacion,
        );
        expect(ToolGroup.fromWireOrNull('reenvio'), ToolGroup.reenvio);
        expect(ToolGroup.fromWireOrNull('agenda'), ToolGroup.agenda);
        expect(ToolGroup.fromWireOrNull('catalogo'), ToolGroup.catalogo);
        expect(ToolGroup.fromWireOrNull('stickers'), ToolGroup.stickers);
        expect(ToolGroup.fromWireOrNull('no_existe'), isNull);
      },
    );
  });
}
