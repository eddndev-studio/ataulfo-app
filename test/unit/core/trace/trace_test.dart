import 'package:ataulfo/core/trace/trace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('summarizeTrace', () {
    Trace traceOf(
      List<TraceNodeKind> kinds, {
      bool parcial = false,
      String? fallo,
    }) => Trace(
      nodos: kinds
          .map((k) => TraceNode(kind: k, titulo: 't', icon: Icons.bolt))
          .toList(),
      parcial: parcial,
      fallo: fallo,
    );

    test('con pensamiento: «Pensó · N pasos»', () {
      expect(
        summarizeTrace(
          traceOf([
            TraceNodeKind.thinking,
            TraceNodeKind.tool,
            TraceNodeKind.tool,
            TraceNodeKind.tool,
          ]),
        ),
        'Pensó · 3 pasos',
      );
    });

    test('sin pensamiento: «N pasos»', () {
      expect(
        summarizeTrace(
          traceOf([
            TraceNodeKind.tool,
            TraceNodeKind.tool,
            TraceNodeKind.tool,
            TraceNodeKind.tool,
          ]),
        ),
        '4 pasos',
      );
    });

    test('un solo paso se dice en singular', () {
      expect(summarizeTrace(traceOf([TraceNodeKind.tool])), '1 paso');
    });

    test('solo pensamiento: «Pensó»', () {
      expect(summarizeTrace(traceOf([TraceNodeKind.thinking])), 'Pensó');
    });

    test('parcial: «Usó herramientas», jamás inventa N', () {
      expect(
        summarizeTrace(traceOf([TraceNodeKind.tool], parcial: true)),
        'Usó herramientas',
      );
    });

    test('fallo: «Falló: <causa>»', () {
      expect(
        summarizeTrace(
          traceOf([
            TraceNodeKind.thinking,
          ], fallo: 'La corrida excedió el tiempo límite.'),
        ),
        'Falló: La corrida excedió el tiempo límite.',
      );
    });
  });

  group('capNodes', () {
    TraceNode node(int i) =>
        TraceNode(kind: TraceNodeKind.tool, titulo: 't$i', icon: Icons.bolt);

    test('8 o menos: sin cambios', () {
      final nodes = List.generate(8, node);
      expect(capNodes(nodes), hasLength(8));
      expect(capNodes(nodes).last.kind, TraceNodeKind.tool);
    });

    test('más de 8: 7 + nodo masN «+N pasos más»', () {
      final capped = capNodes(List.generate(10, node));
      expect(capped, hasLength(8));
      expect(capped.last.kind, TraceNodeKind.masN);
      expect(capped.last.titulo, '+3 pasos más');
    });
  });

  group('capNodesLive (el paso actual siempre visible)', () {
    TraceNode node(int i) =>
        TraceNode(kind: TraceNodeKind.tool, titulo: 't$i', icon: Icons.bolt);

    test('8 o menos: sin cambios', () {
      expect(capNodesLive(List.generate(8, node)), hasLength(8));
    });

    test(
      'más de 8: masN al INICIO y los 7 ÚLTIMOS visibles (el actual late)',
      () {
        final capped = capNodesLive(List.generate(12, node));
        expect(capped, hasLength(8));
        expect(capped.first.kind, TraceNodeKind.masN);
        expect(capped.first.titulo, '+5 pasos anteriores');
        expect(capped[1].titulo, 't5');
        expect(capped.last.titulo, 't11');
      },
    );

    test('el mínimo recorte (9 nodos) oculta 2', () {
      expect(
        capNodesLive(List.generate(9, node)).first.titulo,
        '+2 pasos anteriores',
      );
    });
  });

  group('runFailureCopy', () {
    test('deadline ⇒ copy es-MX', () {
      expect(
        runFailureCopy('context deadline exceeded'),
        'La corrida excedió el tiempo límite.',
      );
    });

    test('desconocido ⇒ genérico es-MX, jamás el crudo del wire', () {
      final copy = runFailureCopy('gibberish-token-qqq');
      expect(copy, isNot(contains('qqq')));
      expect(copy, 'La corrida no pudo completarse.');
    });
  });

  test('traceStoppedSummary es el copy honesto de Detener', () {
    expect(traceStoppedSummary, 'Detenido aquí — el servidor pudo continuar');
  });
}
