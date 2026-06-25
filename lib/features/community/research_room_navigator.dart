import 'package:flutter/material.dart';

import 'research_room_gate_screen.dart';
import 'research_room_models.dart';
import 'research_room_screen.dart';
import 'research_room_service.dart';

Future<void> openResearchRoom(BuildContext context, ResearchRoom room) async {
  final hasAccess = await ResearchRoomService.instance.hasRoomAccess(room.id);
  if (!context.mounted) return;

  if (room.isPasswordProtected && !hasAccess) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResearchRoomGateScreen(room: room),
      ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ResearchRoomScreen(room: room),
    ),
  );
}
