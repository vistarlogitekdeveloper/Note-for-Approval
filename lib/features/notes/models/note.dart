/// Wire values are `draft` | `pendingApproval` | `approved` | `rejected` |
/// `returned` — the enum names map directly (camelCase values included).
///
/// `rejected` is terminal. `returned` is a note an approver sent back for
/// revision (reassign): it belongs to its creator again, is editable, and
/// resubmits to RESUME at the level it was sent back from — see [Note].
enum NoteStatus {
  draft,
  pendingApproval,
  approved,
  rejected,
  returned;

  String get label => switch (this) {
        NoteStatus.draft => 'Draft',
        NoteStatus.pendingApproval => 'Pending',
        NoteStatus.approved => 'Approved',
        NoteStatus.rejected => 'Rejected',
        NoteStatus.returned => 'Returned',
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

/// One level of a note's own approval chain.
///
/// A note either carries a chain of these — level 1..N, one named person each,
/// chosen by the initiator — or it has none and follows the global hierarchy
/// that every note used before per-note chains existed. An empty list means
/// the latter, not "no approvers".
class NoteApprover {
  final String id;
  final int level;
  final String userId;

  /// The label this level carried when the note was raised. Stored per note,
  /// so renaming a hierarchy role later doesn't rewrite a note in flight.
  final String roleName;

  final String userName;
  final String userEmail;

  const NoteApprover({
    required this.id,
    required this.level,
    required this.userId,
    required this.roleName,
    required this.userName,
    required this.userEmail,
  });

  factory NoteApprover.fromJson(Map<String, dynamic> j) {
    final user = (j['user'] as Map?)?.cast<String, dynamic>();
    return NoteApprover(
      id: j['id'] as String,
      level: (j['level'] as num?)?.toInt() ?? 0,
      userId: j['user_id'] as String? ?? '',
      roleName: j['role_name'] as String? ?? '',
      userName: user?['name'] as String? ?? 'Unknown',
      userEmail: user?['email'] as String? ?? '',
    );
  }
}

class ApprovalAction {
  final String id;
  final int level;

  /// Which attempt this decision belongs to. A note that was rejected and
  /// resubmitted carries decisions from several rounds, and level alone would
  /// make round 2's "L1 approved" indistinguishable from round 1's.
  final int revision;

  final String roleName;
  final String approverId;
  final String approverName;
  final String action; // 'approved' | 'rejected' | 'reassigned'
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
    this.revision = 1,
    this.actedAt,
  });

  bool get isApproved => action == 'approved';
  bool get isRejected => action == 'rejected';

  /// An approver sent the note back to its creator to revise the hierarchy —
  /// not an approval, not a rejection.
  bool get isReassigned => action == 'reassigned';

  factory ApprovalAction.fromJson(Map<String, dynamic> j) {
    final approver = (j['approver'] as Map?)?.cast<String, dynamic>();
    return ApprovalAction(
      id: j['id'] as String,
      level: (j['level'] as num?)?.toInt() ?? 0,
      // Defaults to 1 so a note recorded before rounds existed still reads as
      // a single first attempt.
      revision: (j['revision'] as num?)?.toInt() ?? 1,
      roleName: j['role_name'] as String? ?? '',
      approverId: j['approver_id'] as String? ?? '',
      approverName: approver?['name'] as String? ?? 'Unknown',
      action: j['action'] as String? ?? '',
      remark: j['remark'] as String? ?? '',
      actedAt: DateTime.tryParse(j['acted_at'] as String? ?? ''),
    );
  }
}

/// One decision this user made, with just enough of the note attached to
/// identify it. Comes from `GET /approvals/my-decisions`.
///
/// Distinct from a status count: this is a record of an ACT. A note you
/// rejected that was later revised and approved still appears here as your
/// rejection, which is the whole point — it is your history, not the note's
/// current state.
class MyDecision {
  const MyDecision({
    required this.id,
    required this.level,
    required this.revision,
    required this.roleName,
    required this.action,
    required this.remark,
    required this.noteId,
    required this.noteNumber,
    required this.noteObjective,
    required this.noteStatus,
    this.actedAt,
  });

  final String id;
  final int level;
  final int revision;
  final String roleName;
  final String action; // 'approved' | 'rejected'
  final String remark;
  final DateTime? actedAt;

  final String noteId;
  final String noteNumber;
  final String noteObjective;

  /// Where the note stands NOW, which may differ from what this decision was.
  final NoteStatus noteStatus;

  bool get isApproved => action == 'approved';

  /// True when the note moved on after this decision — you rejected it and it
  /// was revised, or you approved it and a later level rejected it.
  bool get outcomeDiffers =>
      (isApproved && noteStatus == NoteStatus.rejected) ||
      (!isApproved && noteStatus != NoteStatus.rejected);

  factory MyDecision.fromJson(Map<String, dynamic> j) {
    final note = (j['note'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MyDecision(
      id: j['id'] as String,
      level: (j['level'] as num?)?.toInt() ?? 0,
      revision: (j['revision'] as num?)?.toInt() ?? 1,
      roleName: j['role_name'] as String? ?? '',
      action: j['action'] as String? ?? '',
      remark: j['remark'] as String? ?? '',
      actedAt: DateTime.tryParse(j['acted_at'] as String? ?? ''),
      noteId: note['id'] as String? ?? '',
      noteNumber: note['note_number'] as String? ?? '—',
      noteObjective: note['objective_in_detail'] as String? ?? '',
      noteStatus: NoteStatus.fromString(note['status'] as String? ?? 'draft'),
    );
  }
}

/// A page of decisions plus the lifetime tallies. The tallies cover the whole
/// history, not the page, so they do not shift as you scroll.
class MyDecisionPage {
  const MyDecisionPage({
    required this.decisions,
    required this.approved,
    required this.rejected,
    required this.total,
  });

  final List<MyDecision> decisions;
  final int approved;
  final int rejected;
  final int total;

  factory MyDecisionPage.fromResult(
    List<MyDecision> decisions,
    Map<String, dynamic>? meta,
  ) =>
      MyDecisionPage(
        decisions: decisions,
        approved: (meta?['approved'] as num?)?.toInt() ?? 0,
        rejected: (meta?['rejected'] as num?)?.toInt() ?? 0,
        total: (meta?['total'] as num?)?.toInt() ?? decisions.length,
      );
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

  /// Which attempt the note is on. A reassign returns it to the creator;
  /// resubmitting bumps this and RESUMES at the level it was sent back from —
  /// the already-approved levels below stay approved.
  final int revision;

  final String initiatorId;
  final String initiatorName;
  final String initiatorEmail;

  /// Populated on `GET /notes/:id` only — always empty in list responses.
  final List<NoteAttachment> attachments;

  /// Populated on `GET /notes/:id` only — always empty in list responses.
  final List<ApprovalAction> approvalTrail;

  /// This note's own approval chain, ordered by level. Empty means the note
  /// follows the global hierarchy instead — the default, and what every note
  /// did before per-note chains existed.
  final List<NoteApprover> approverChain;

  bool get hasCustomChain => approverChain.isNotEmpty;

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
    this.revision = 1,
    required this.initiatorId,
    required this.initiatorName,
    required this.initiatorEmail,
    required this.attachments,
    required this.approvalTrail,
    this.approverChain = const [],
    this.pdfUrl,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft => status == NoteStatus.draft;
  bool get hasPdf => status == NoteStatus.approved;

  /// A returned note was sent back by an approver (reassign) to its creator to
  /// revise the hierarchy and resubmit. Distinct from [isRejected], which is
  /// terminal. Only the creator can act on a returned note.
  bool get isReturned => status == NoteStatus.returned;
  bool get isRejected => status == NoteStatus.rejected;

  /// How many leading approvers are already approved and therefore LOCKED on a
  /// returned note. A note only reaches level L once levels 1..L-1 have all
  /// approved, and it is sent back AT [currentLevel] — so that many levels
  /// below it are locked. 0 for anything not mid-resume (a fresh draft, or a
  /// note sent back before its first approval).
  int get lockedApproverCount =>
      isReturned ? (currentLevel - 1).clamp(0, approverChain.length) : 0;

  /// Whether [userId] may edit and resubmit this note right now. Mirrors the
  /// server's EDITABLE_STATUSES + initiator-only rule: a draft, or a note
  /// returned for revision. A rejected note is terminal and NOT editable.
  bool editableBy(String? userId) =>
      userId != null &&
      initiatorId == userId &&
      (status == NoteStatus.draft || status == NoteStatus.returned);

  /// Decisions grouped into rounds, oldest round first, each round's entries
  /// in level order. A note that was never rejected has a single round.
  List<MapEntry<int, List<ApprovalAction>>> get trailByRound {
    final byRound = <int, List<ApprovalAction>>{};
    for (final a in approvalTrail) {
      byRound.putIfAbsent(a.revision, () => []).add(a);
    }
    final rounds = byRound.keys.toList()..sort();
    return [
      for (final r in rounds)
        MapEntry(r, byRound[r]!..sort((a, b) => a.level.compareTo(b.level)))
    ];
  }

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
      revision: (j['revision'] as num?)?.toInt() ?? 1,
      initiatorId: j['initiator_id'] as String? ?? '',
      initiatorName: initiator?['name'] as String? ?? 'Unknown',
      initiatorEmail: initiator?['email'] as String? ?? '',
      attachments: ((j['attachments'] as List?) ?? const [])
          .map((e) => NoteAttachment.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      approvalTrail: ((j['approvalTrail'] as List?) ?? const [])
          .map((e) => ApprovalAction.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      // The server's include carries no ORDER BY, so level order is whatever
      // Postgres felt like returning. Sort here — the chain is a sequence and
      // rendering it out of order would misstate the route.
      approverChain: ((j['approverChain'] as List?) ?? const [])
          .map((e) => NoteApprover.fromJson((e as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.level.compareTo(b.level)),
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
