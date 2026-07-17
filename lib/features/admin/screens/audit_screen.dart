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
              color: AppColors.txt,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Text(
            'Immutable, sequential log of all note submissions, approvals, rejections, and configurations',
            style: TextStyle(color: AppColors.txt3, fontSize: 14),
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
                child: Text('Error: $e', style: const TextStyle(color: AppColors.bad)),
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
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(160),
              1: FixedColumnWidth(110),
              2: FixedColumnWidth(140),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(3),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppColors.surface2),
                children: ['Timestamp', 'Action', 'Note #', 'Actor', 'Details']
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          child: Text(
                            h.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.txt3,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              ...logs.map((log) => _buildRow(log)),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _buildRow(AuditEntry log) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(formatDateTime(log.timestamp),
              style: const TextStyle(color: AppColors.txt2, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: _actionBadge(log.action),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(log.noteNumber,
              style: const TextStyle(
                color: AppColors.txt,
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
                  style: const TextStyle(
                      color: AppColors.txt, fontSize: 13.5, fontWeight: FontWeight.w600)),
              Text(log.actorRole, style: const TextStyle(color: AppColors.txt3, fontSize: 11)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(log.details,
              style: const TextStyle(color: AppColors.txt2, fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }

  Widget _actionBadge(String action) {
    final (color, bg) = switch (action) {
      'SUBMIT' => (AppColors.info, const Color(0x225BA8FF)),
      'APPROVE' => (AppColors.ok, const Color(0x2234D399)),
      'REJECT' => (AppColors.bad, const Color(0x22FB6F84)),
      'SAVE_DRAFT' => (AppColors.txt3, AppColors.surface3),
      _ => (AppColors.txt2, AppColors.surface2),
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
