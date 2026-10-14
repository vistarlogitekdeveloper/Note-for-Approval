import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common_widgets.dart';

/// One row of `GET /admin/audit`: who did what, to which note, and when.
class AuditEntry {
  final String id;
  final String action;
  final String? noteId;
  final String noteNumber;
  final String actorName;
  final String actorRole;
  final String details;
  final DateTime? timestamp;

  const AuditEntry({
    required this.id,
    required this.action,
    this.noteId,
    required this.noteNumber,
    required this.actorName,
    required this.actorRole,
    required this.details,
    required this.timestamp,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) {
    final actor = (j['actor'] as Map?)?.cast<String, dynamic>() ?? const {};
    final note = (j['note'] as Map?)?.cast<String, dynamic>();
    final role = actor['role'] as String? ?? '';
    return AuditEntry(
      id: j['id'] as String,
      action: j['action'] as String? ?? '',
      noteId: note?['id'] as String?,
      noteNumber: note?['note_number'] as String? ?? '—',
      actorName: actor['name'] as String? ?? 'Unknown user',
      actorRole: role.isEmpty ? '' : '${role[0].toUpperCase()}${role.substring(1)}',
      details: j['details'] as String? ?? '',
      timestamp: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal(),
    );
  }
}

class AuditPage {
  const AuditPage({required this.entries, required this.page, required this.pages, required this.total});
  final List<AuditEntry> entries;
  final int page;
  final int pages;
  final int total;
}

/// The actions the server writes, for the filter. Kept in the order an admin
/// is most likely to look for them.
const _auditActions = [
  'SUBMIT', 'APPROVE', 'REJECT', 'REASSIGN', 'CREATE', 'UPDATE', 'ATTACH',
  'PDF_GENERATED', 'LOGIN', 'LOGOUT', 'PASSWORD_CHANGE', 'USER_CREATE',
  'USER_UPDATE', 'PURPOSE_CREATE', 'PURPOSE_UPDATE', 'PURPOSE_DELETE',
  'HIERARCHY_UPDATE', 'SMTP_UPDATE', 'SMTP_TEST', 'SMTP_SEND_FAILED',
];

final auditActionFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final auditPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// The real audit trail. This used to return four hard-coded rows after a
/// fake delay and never called the server at all.
final auditLogProvider = FutureProvider.autoDispose<AuditPage>((ref) async {
  final action = ref.watch(auditActionFilterProvider);
  final page = ref.watch(auditPageProvider);
  final res = await ref.read(apiClientProvider).get(ApiEndpoints.auditLog, params: {
    'action': action,
    'page': page,
    'limit': 50,
  });
  final meta = res.meta ?? const {};
  return AuditPage(
    entries: res.asList.map(AuditEntry.fromJson).toList(),
    page: (meta['page'] as num?)?.toInt() ?? page,
    pages: (meta['pages'] as num?)?.toInt() ?? 1,
    total: (meta['total'] as num?)?.toInt() ?? 0,
  );
});

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(auditLogProvider);
    final action = ref.watch(auditActionFilterProvider);
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Audit Log',
            style: GoogleFonts.bricolageGrotesque(
              color: context.c.txt,
              fontSize: compact ? 24 : 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Every sign-in, note change, decision and setting change, newest first',
            style: TextStyle(color: context.c.txt3, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String?>(
                  initialValue: action,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    isDense: true,
                    prefixIcon: Icon(Icons.filter_list_rounded, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All actions')),
                    for (final a in _auditActions)
                      DropdownMenuItem<String?>(value: a, child: Text(_label(a))),
                  ],
                  onChanged: (v) {
                    ref.read(auditActionFilterProvider.notifier).state = v;
                    ref.read(auditPageProvider.notifier).state = 1;
                  },
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => ref.invalidate(auditLogProvider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: auditAsync.when(
              data: (page) => page.entries.isEmpty
                  ? const EmptyState(
                      message: 'No audit entries for this filter.',
                      icon: Icons.history_toggle_off_rounded,
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: compact
                              ? _AuditCards(logs: page.entries)
                              : _AuditTable(logs: page.entries),
                        ),
                        const SizedBox(height: 12),
                        _Pager(page: page),
                      ],
                    ),
              loading: () => ListView(
                children: List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerCard(height: 60),
                  ),
                ),
              ),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(auditLogProvider)),
            ),
          ),
        ],
      ),
    );
  }
}

String _label(String action) => action
    .toLowerCase()
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class _Pager extends ConsumerWidget {
  const _Pager({required this.page});
  final AuditPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(int p) => ref.read(auditPageProvider.notifier).state = p;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${page.total} ${page.total == 1 ? 'entry' : 'entries'} · page ${page.page} of ${page.pages}',
            style: TextStyle(color: context.c.txt3, fontSize: 12.5),
          ),
        ),
        IconButton(
          tooltip: 'Newer',
          onPressed: page.page > 1 ? () => go(page.page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Older',
          onPressed: page.page < page.pages ? () => go(page.page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Phones: one card per entry.
class _AuditCards extends StatelessWidget {
  const _AuditCards({required this.logs});
  final List<AuditEntry> logs;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final log = logs[i];
        return VistarCard(
          padding: const EdgeInsets.all(12),
          onTap: log.noteId == null ? null : () => context.go('/notes/${log.noteId}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _actionBadge(context, log.action),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(log.noteNumber,
                        style: TextStyle(color: context.c.txt3, fontSize: 12, fontFamily: 'monospace')),
                  ),
                  Text(log.timestamp == null ? '' : formatDateTime(log.timestamp!),
                      style: TextStyle(color: context.c.txt3, fontSize: 11.5)),
                ],
              ),
              const SizedBox(height: 6),
              Text(log.actorName,
                  style: TextStyle(color: context.c.txt, fontSize: 13.5, fontWeight: FontWeight.w600)),
              if (log.details.isNotEmpty)
                Text(log.details, style: TextStyle(color: context.c.txt2, fontSize: 13, height: 1.4)),
            ],
          ),
        );
      },
    );
  }
}

Widget _actionBadge(BuildContext context, String action) {
  final color = switch (action) {
    'SUBMIT' => context.c.info,
    'APPROVE' || 'PDF_GENERATED' => context.c.ok,
    'REJECT' || 'SMTP_SEND_FAILED' || 'SMTP_VERIFY_FAILED' || 'PURPOSE_DELETE' => context.c.bad,
    'REASSIGN' => context.c.warn,
    _ => context.c.txt2,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      _label(action),
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
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
          child: Text(log.timestamp == null ? '' : formatDateTime(log.timestamp!),
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
}
