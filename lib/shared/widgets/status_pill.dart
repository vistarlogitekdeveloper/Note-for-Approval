import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../features/notes/models/note.dart';

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final NoteStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status) {
      NoteStatus.draft => (context.c.txt3, context.c.surface3, 'Draft'),
      NoteStatus.pendingApproval => (context.c.info, const Color(0x225BA8FF), 'Pending'),
      NoteStatus.approved => (context.c.ok, const Color(0x2234D399), 'Approved'),
      NoteStatus.rejected => (context.c.bad, const Color(0x22FB6F84), 'Rejected'),
      NoteStatus.returned => (context.c.warn, const Color(0x22F5A623), 'Returned'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple text-based level indicator pill
class LevelPill extends StatelessWidget {
  const LevelPill({super.key, required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.c.surface3,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.c.line),
      ),
      child: Text(
        'Level $current / $total',
        style: TextStyle(
          color: context.c.txt2,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
