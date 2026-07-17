/// Wire values are `draft` | `pendingApproval` | `approved` | `rejected` —
/// `pendingApproval` is camelCase as a value, so the enum names map directly.
enum NoteStatus {
  draft,
  pendingApproval,
  approved,
  rejected;

  String get label => switch (this) {
        NoteStatus.draft => 'Draft',
        NoteStatus.pendingApproval => 'Pending',
        NoteStatus.approved => 'Approved',
        NoteStatus.rejected => 'Rejected',
      };

  /// The value the API expects for `?status=`.
  String get wireValue => name;

  factory NoteStatus.fromString(String s) => NoteStatus.values.firstWhere(
        (v) => v.name == s,
        orElse: () => NoteStatus.draft,
      );
}

class NoteAttachment {
  final String id;
  final String noteId;
  final String fileName;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime? createdAt;

  const NoteAttachment({
    required this.id,
    required this.noteId,
    required this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.createdAt,
  });

  factory NoteAttachment.fromJson(Map<String, dynamic> j) => NoteAttachment(
        id: j['id'] as String,
        noteId: j['note_id'] as String? ?? '',
        fileName: j['file_name'] as String? ?? 'Untitled',
        mimeType: j['mime_type'] as String?,
        sizeBytes: (j['size_bytes'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );
}

class ApprovalAction {
  final String id;
  final int level;
  final String roleName;
  final String approverId;
  final String approverName;
  final String action; // 'approved' | 'rejected'
  final String remark;
  final DateTime? actedAt;

  const ApprovalAction({
    required this.id,
    required this.level,
    required this.roleName,
    required this.approverId,
    required this.approverName,
    required this.action,
    required this.remark,
    this.actedAt,
  });

  bool get isApproved => action == 'approved';

  factory ApprovalAction.fromJson(Map<String, dynamic> j) {
    final approver = (j['approver'] as Map?)?.cast<String, dynamic>();
    return ApprovalAction(
      id: j['id'] as String,
      level: (j['level'] as num?)?.toInt() ?? 0,
      roleName: j['role_name'] as String? ?? '',
      approverId: j['approver_id'] as String? ?? '',
      approverName: approver?['name'] as String? ?? 'Unknown',
      action: j['action'] as String? ?? '',
      remark: j['remark'] as String? ?? '',
      actedAt: DateTime.tryParse(j['acted_at'] as String? ?? ''),
    );
  }
}

class Note {
  final String id;
  final String noteNumber;
  final String purposeId;
  final String purposeLabel;
  final String objectiveInDetail;
  final String briefNote;
  final String benefit;
  final String costImpact;
  final NoteStatus status;
  final int currentLevel; // 0 = not yet submitted, 1..N = at which level
  final int totalLevels; // frozen at submit time
  final String initiatorId;
  final String initiatorName;
  final String initiatorEmail;

  /// Populated on `GET /notes/:id` only — always empty in list responses.
  final List<NoteAttachment> attachments;

  /// Populated on `GET /notes/:id` only — always empty in list responses.
  final List<ApprovalAction> approvalTrail;

  /// A storage key, not a fetchable URL. Use `GET /notes/:id/pdf` instead.
  final String? pdfUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Note({
    required this.id,
    required this.noteNumber,
    required this.purposeId,
    required this.purposeLabel,
    required this.objectiveInDetail,
    required this.briefNote,
    required this.benefit,
    required this.costImpact,
    required this.status,
    required this.currentLevel,
    required this.totalLevels,
    required this.initiatorId,
    required this.initiatorName,
    required this.initiatorEmail,
    required this.attachments,
    required this.approvalTrail,
    this.pdfUrl,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft => status == NoteStatus.draft;
  bool get hasPdf => status == NoteStatus.approved;

  factory Note.fromJson(Map<String, dynamic> j) {
    final initiator = (j['initiator'] as Map?)?.cast<String, dynamic>();
    final purpose = (j['purpose'] as Map?)?.cast<String, dynamic>();

    return Note(
      id: j['id'] as String,
      noteNumber: j['note_number'] as String? ?? '',
      purposeId: j['purpose_id'] as String? ?? '',
      purposeLabel: purpose?['name'] as String? ?? '—',
      objectiveInDetail: j['objective_in_detail'] as String? ?? '',
      briefNote: j['brief_note'] as String? ?? '',
      benefit: j['benefit'] as String? ?? '',
      costImpact: j['cost_impact'] as String? ?? '',
      status: NoteStatus.fromString(j['status'] as String? ?? 'draft'),
      currentLevel: (j['current_level'] as num?)?.toInt() ?? 0,
      totalLevels: (j['total_levels'] as num?)?.toInt() ?? 3,
      initiatorId: j['initiator_id'] as String? ?? '',
      initiatorName: initiator?['name'] as String? ?? 'Unknown',
      initiatorEmail: initiator?['email'] as String? ?? '',
      attachments: ((j['attachments'] as List?) ?? const [])
          .map((e) => NoteAttachment.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      approvalTrail: ((j['approvalTrail'] as List?) ?? const [])
          .map((e) => ApprovalAction.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      pdfUrl: j['pdf_url'] as String?,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? ''),
    );
  }
}

class HierarchyRole {
  final String id;
  final int level;
  final String name;
  final String? description;
  final bool isActive;

  /// Injected by the admin controller, not a stored column.
  final int approverCount;

  const HierarchyRole({
    required this.id,
    required this.level,
    required this.name,
    this.description,
    this.isActive = true,
    this.approverCount = 0,
  });

  factory HierarchyRole.fromJson(Map<String, dynamic> j) => HierarchyRole(
        id: j['id'] as String,
        level: (j['level'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        approverCount: (j['approver_count'] as num?)?.toInt() ?? 0,
      );
}

class PurposeMaster {
  final String id;
  final String name;
  final bool isActive;

  const PurposeMaster({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  factory PurposeMaster.fromJson(Map<String, dynamic> j) => PurposeMaster(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        isActive: j['is_active'] as bool? ?? true,
      );
}

class DashboardStats {
  final int totalNotes;
  final int pendingNotes;
  final int approvedNotes;
  final int rejectedNotes;
  final int draftNotes;
  final int pendingMyAction; // approvers: awaiting my level
  final int raisedByMe;

  /// `all` for admins, otherwise `visible-to-me` — the counts are scoped to
  /// match what `GET /notes` would return for this caller.
  final String scope;

  const DashboardStats({
    required this.totalNotes,
    required this.pendingNotes,
    required this.approvedNotes,
    required this.rejectedNotes,
    required this.draftNotes,
    required this.pendingMyAction,
    this.raisedByMe = 0,
    this.scope = 'visible-to-me',
  });

  bool get isGlobalScope => scope == 'all';

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalNotes: (j['total'] as num?)?.toInt() ?? 0,
        pendingNotes: (j['pendingApproval'] as num?)?.toInt() ?? 0,
        approvedNotes: (j['approved'] as num?)?.toInt() ?? 0,
        rejectedNotes: (j['rejected'] as num?)?.toInt() ?? 0,
        draftNotes: (j['draft'] as num?)?.toInt() ?? 0,
        pendingMyAction: (j['myPendingApprovals'] as num?)?.toInt() ?? 0,
        raisedByMe: (j['raisedByMe'] as num?)?.toInt() ?? 0,
        scope: j['scope'] as String? ?? 'visible-to-me',
      );
}

/// A page of notes plus the server's pagination counters.
class NotePage {
  const NotePage({
    required this.notes,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  final List<Note> notes;
  final int page;
  final int limit;
  final int total;
  final int pages;

  bool get hasMore => page < pages;

  factory NotePage.fromResult(List<Note> notes, Map<String, dynamic>? meta) =>
      NotePage(
        notes: notes,
        page: (meta?['page'] as num?)?.toInt() ?? 1,
        limit: (meta?['limit'] as num?)?.toInt() ?? notes.length,
        total: (meta?['total'] as num?)?.toInt() ?? notes.length,
        pages: (meta?['pages'] as num?)?.toInt() ?? 1,
      );
}
