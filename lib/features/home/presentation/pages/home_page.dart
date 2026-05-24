import 'package:flutter/material.dart';

/// Placeholder post-login.
///
/// Existe sólo para que el router tenga un destino al que llegar tras
/// `LoginSucceeded` y la UI no quede colgada. El home real aterriza con
/// el slice de listado de bots.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agentic')),
      body: Center(
        child: Text(
          'Sesión iniciada',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
