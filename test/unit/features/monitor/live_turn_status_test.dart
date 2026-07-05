import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/live_turn_status.dart';
import 'package:flutter_test/flutter_test.dart';

MonitorEvent _ev(MonitorEventKind kind, {String toolName = ''}) => MonitorEvent(
  kind: kind,
  topic: '',
  at: DateTime.utc(2026, 6, 20),
  toolName: toolName,
);

void main() {
  group('liveTurnPhaseOf', () {
    test('sin eventos ⇒ reposo', () {
      expect(liveTurnPhaseOf(const <MonitorEvent>[]), LiveTurnPhase.idle);
    });

    test('último evento no-terminal (turno/tool/flujo) ⇒ turno activo', () {
      for (final kind in <MonitorEventKind>[
        MonitorEventKind.aiTurn,
        MonitorEventKind.aiTool,
        MonitorEventKind.flowStarted,
        MonitorEventKind.flowStep,
      ]) {
        expect(
          liveTurnPhaseOf(<MonitorEvent>[_ev(kind)]),
          LiveTurnPhase.active,
          reason: '$kind mantiene el turno vivo',
        );
      }
    });

    test('último evento = fallo terminal ⇒ failed', () {
      for (final kind in <MonitorEventKind>[
        MonitorEventKind.aiFailed,
        MonitorEventKind.flowFailed,
      ]) {
        expect(
          liveTurnPhaseOf(<MonitorEvent>[
            _ev(MonitorEventKind.aiTool),
            _ev(kind),
          ]),
          LiveTurnPhase.failed,
          reason: '$kind cierra el turno en fallo',
        );
      }
    });

    test('completado OK / ruido (alert, reconexión) ⇒ reposo', () {
      for (final kind in <MonitorEventKind>[
        MonitorEventKind.aiCompleted,
        MonitorEventKind.flowCompleted,
        MonitorEventKind.alert,
        MonitorEventKind.unknown,
        MonitorEventKind.reconnect,
        MonitorEventKind.connected,
      ]) {
        expect(
          liveTurnPhaseOf(<MonitorEvent>[
            _ev(MonitorEventKind.aiTool),
            _ev(kind),
          ]),
          LiveTurnPhase.idle,
          reason: '$kind no deja turno accionable',
        );
      }
    });

    test('solo cuenta el ÚLTIMO evento: un fallo viejo no persiste', () {
      expect(
        liveTurnPhaseOf(<MonitorEvent>[
          _ev(MonitorEventKind.aiFailed),
          _ev(MonitorEventKind.aiTurn),
        ]),
        LiveTurnPhase.active,
      );
    });
  });

  group('liveTurnActivityLabel', () {
    test('tool en uso con nombre ⇒ "Usando <tool>…"', () {
      expect(
        liveTurnActivityLabel(<MonitorEvent>[
          _ev(MonitorEventKind.aiTool, toolName: 'list_bots'),
        ]),
        'Usando list_bots…',
      );
    });

    test('tool sin nombre ⇒ "Trabajando…"', () {
      expect(
        liveTurnActivityLabel(<MonitorEvent>[_ev(MonitorEventKind.aiTool)]),
        'Trabajando…',
      );
    });

    test('turno de razonamiento ⇒ "Pensando…"', () {
      expect(
        liveTurnActivityLabel(<MonitorEvent>[_ev(MonitorEventKind.aiTurn)]),
        'Pensando…',
      );
    });

    test('flujo en curso ⇒ "Ejecutando un flujo…"', () {
      for (final kind in <MonitorEventKind>[
        MonitorEventKind.flowStarted,
        MonitorEventKind.flowStep,
      ]) {
        expect(
          liveTurnActivityLabel(<MonitorEvent>[_ev(kind)]),
          'Ejecutando un flujo…',
        );
      }
    });

    test('fuera de un turno activo ⇒ null (incluye fallo terminal)', () {
      expect(liveTurnActivityLabel(const <MonitorEvent>[]), isNull);
      expect(
        liveTurnActivityLabel(<MonitorEvent>[_ev(MonitorEventKind.aiFailed)]),
        isNull,
      );
      expect(
        liveTurnActivityLabel(<MonitorEvent>[
          _ev(MonitorEventKind.aiCompleted),
        ]),
        isNull,
      );
    });
  });
}
