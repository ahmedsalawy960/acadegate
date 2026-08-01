import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'research_room_gate_screen.dart';
import 'research_room_models.dart';
import 'research_room_screen.dart';
import 'research_room_service.dart';

Future<void> openResearchRoom(BuildContext context, ResearchRoom room) async {
  try {
    final hasAccess = await ResearchRoomService.instance.hasRoomAccess(room.id);
    if (!context.mounted) return;

    if (room.isPasswordProtected && !hasAccess) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResearchRoomGateScreen(room: room),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResearchRoomScreen(room: room),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'تعذر فتح الغرفة البحثية. حاول مرة أخرى.',
            'Could not open the research room. Please try again.',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
