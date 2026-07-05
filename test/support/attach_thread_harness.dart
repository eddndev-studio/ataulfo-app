import 'package:ataulfo/features/messages/presentation/widgets/attach_panel.dart';
import 'package:ataulfo/features/messages/presentation/widgets/message_composer.dart';
import 'package:flutter/material.dart';

/// Compone el composer + el panel de adjuntar inline para tests que ejercen el
/// flujo end-to-end (tocar el clip abre el panel; tocar un destino corre el
/// flujo del composer). Requiere que `AttachPanelCubit` esté provisto por
/// encima.
///
/// Consume el MISMO [AttachPanelScaffold] que usa `MessageThreadPage`, con un
/// espaciador en lugar de la lista: así los tests de invariantes validan el
/// layout REAL del panel (reserva, superposición, back), no una copia. Una
/// deriva del contenedor rompe estos tests.
class AttachThreadHarness extends StatelessWidget {
  const AttachThreadHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return const AttachPanelScaffold(
      children: <Widget>[
        Expanded(child: SizedBox()),
        MessageComposer(),
      ],
    );
  }
}
