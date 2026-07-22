import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common_widgets.dart';

class AuditEntry {
  final String id;
  final String action;
  final String noteNumber;
  final String actorName;
  final String actorRole;
  final String details;
  final DateTime timestamp;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.noteNumber,
    required this.actorName,
    required this.actorRole,
    required this.details,
    required this.timestamp,
  });
}

final auditLogProvider = FutureProvider<List<AuditEntry>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    AuditEntry(
      id: '1',
      action: 'SUBMIT',
      noteNumber: 'NFA-2026-0004',
      actorName: 'Arjun Sharma',
      actorRole: 'Initiator',
      details: 'Objective: Capital Expenditure for new IT infrastructure',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    AuditEntry(
      id: '2',
      action: 'APPROVE',
      noteNumber: 'NFA-2026-0003',
      actorName: 'Priya Mehta',
      actorRole: 'Level 1: Dept Head',
      details: 'Remark: Verified and approved for next level',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AuditEntry(
      id: '3',
      action: 'REJECT',
      noteNumber: 'NFA-2026-0002',
      actorName: 'Rohit Verma',
      actorRole: 'Level 2: GM',
      details: 'Remark: Budget exceeded. Revise and resubmit.',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    AuditEntry(
      id: '4',
      action: 'SAVE_DRAFT',
      noteNumber: 'NFA-2026-0005',
      actorName: 'Arjun Sharma',
      actorRole: 'Initiator',
      details: 'Saved draft version',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
});

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(auditLogProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Audit Log',
            style: GoogleFonts.bricolageGrotesque(
              color: context.c.txt,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Immutable, sequential log of all note submissions, approvals, rejections, and configurations',
            style: TextStyle(color: context.c.txt3, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: auditAsync.when(
              data: (logs) => _AuditTable(logs: logs),
              loading: () => Column(
                children: List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerCard(height: 60),
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e', style: TextStyle(color: context.c.bad)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditTable extends StatelessWidget {
  const _AuditTable({required this.logs});
  final List<AuditEntry> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.c.line),
        borderRadius: BorderRadius.circular(16),
        color: context.c.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Table(
            // Timestamp, action pill and actor size to their content; the two
            // free-text columns take the remaining width.
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: IntrinsicColumnWidth(),
              2: IntrinsicColumnWidth(),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(3),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: context.c.surface2),
                children: ['Timestamp', 'Action', 'Note #', 'Actor', 'Details']
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          child: Text(
                            h.toUpperCase(),
                            style: TextStyle(
                              color: context.c.txt3,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              ...logs.map((log) => _buildRow(context, log)),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _buildRow(BuildContext context, AuditEntry log) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.c.line)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(formatDateTime(log.timestamp),
              style: TextStyle(color: context.c.txt2, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: _actionBadge(context, log.action),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(log.noteNumber,
              style: TextStyle(
                color: context.c.txt,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              )),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.actorName,
                  style: TextStyle(
                      color: context.c.txt, fontSize: 13.5, fontWeight: FontWeight.w600)),
              Text(log.actorRole, style: TextStyle(color: context.c.txt3, fontSize: 11)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(log.details,
              style: TextStyle(color: context.c.txt2, fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }

  Widget _actionBadge(BuildContext context, String action) {
    final (color, bg) = switch (action) {
      'SUBMIT' => (context.c.info, const Color(0x225BA8FF)),
      'APPROVE' => (context.c.ok, const Color(0x2234D399)),
      'REJECT' => (context.c.bad, const Color(0x22FB6F84)),
      'SAVE_DRAFT' => (context.c.txt3, context.c.surface3),
      _ => (context.c.txt2, context.c.surface2),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        action,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
