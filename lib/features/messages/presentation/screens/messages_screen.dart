import 'package:flutter/material.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.black26),
            SizedBox(height: 16),
            Text(
              'No tenés mensajes aún',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Cuando contactes a un profesional\naparecerá acá.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
