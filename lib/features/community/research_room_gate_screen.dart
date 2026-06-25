import 'package:flutter/material.dart';

import 'research_room_models.dart';
import 'research_room_screen.dart';
import 'research_room_service.dart';

class ResearchRoomGateScreen extends StatefulWidget {
  final ResearchRoom room;

  const ResearchRoomGateScreen({super.key, required this.room});

  @override
  State<ResearchRoomGateScreen> createState() => _ResearchRoomGateScreenState();
}

class _ResearchRoomGateScreenState extends State<ResearchRoomGateScreen> {
  final _passwordController = TextEditingController();
  bool _isChecking = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryEnter() async {
    setState(() => _isChecking = true);
    final error = await ResearchRoomService.instance.unlockRoom(
      roomId: widget.room.id,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResearchRoomScreen(room: widget.room),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.title),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Color(0xFF00695C)),
            const SizedBox(height: 16),
            const Text(
              'غرفة محمية بكلمة مرور',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'هذه الغرفة أنشأها ${widget.room.creatorName}. '
              'أدخل كلمة المرور التي استلمتها للدخول.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _tryEnter(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isChecking ? null : _tryEnter,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00695C),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isChecking
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('دخول الغرفة'),
            ),
          ],
        ),
      ),
    );
  }
}
