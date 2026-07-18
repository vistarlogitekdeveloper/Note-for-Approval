/// Paths are relative to the module mount, `/api/v1/note-for-approval`,
/// which the Dio base URL already carries.
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ────────────────────────────────────────────────────────────────
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const refreshToken = '/auth/refresh';
  static const me = '/auth/me';
  static const changePassword = '/auth/change-password';

  // ── Notes ────────────────────────────────────────────────────────────────
  static const notes = '/notes';
  static String noteById(String id) => '/notes/$id';
  static String submitNote(String id) => '/notes/$id/submit';
  static String notePdf(String id) => '/notes/$id/pdf';
  static String noteAttachments(String id) => '/notes/$id/attachments';
  static String noteAttachmentFile(String noteId, String attachId) =>
      '/notes/$noteId/attachments/$attachId';

  // ── Approval ─────────────────────────────────────────────────────────────
  //
  // approve/reject live on the notes router, not under /approvals. There is no
  // per-note audit-trail endpoint — the trail arrives inline as `approvalTrail`
  // on GET /notes/:id.
  static const pendingApprovals = '/approvals/pending';

  /// The caller's own approve/reject history. Returns only their own rows, so
  /// it needs no role — an approver who raises no notes has no other record of
  /// their work (`/admin/audit` is admin-only, My Notes is initiator-only).
  static const myDecisions = '/approvals/my-decisions';
  static String approveNote(String id) => '/notes/$id/approve';
  static String rejectNote(String id) => '/notes/$id/reject';

  // ── Masters ──────────────────────────────────────────────────────────────
  static const purposes = '/masters/purposes';
  static String purposeById(String id) => '/masters/purposes/$id';

  /// The people who may be put on a note's own approval chain. Open to any
  /// authenticated user, because an initiator has to pick from it while
  /// raising a note — `/admin/users` is admin-only and cannot serve this.
  static const approvers = '/masters/approvers';

  // ── Hierarchy ────────────────────────────────────────────────────────────
  //
  // Read and update only. Levels cannot be created, deleted, or reordered
  // through the API, and `level` is stripped from the update body server-side.
  static const hierarchy = '/admin/hierarchy';
  static String hierarchyById(String id) => '/admin/hierarchy/$id';

  // ── Users ─────────────────────────────────────────────────────────────────
  //
  // Deactivation is a PATCH with `is_active: false`; there is no toggle route.
  static const users = '/admin/users';
  static String userById(String id) => '/admin/users/$id';

  // ── Audit ──────────────────────────────────────────────────────────────
  static const auditLog = '/admin/audit';

  // ── SMTP Settings ────────────────────────────────────────────────────────
  static const smtpSettings = '/admin/smtp';
  static const smtpTest = '/admin/smtp/test';

  // ── Dashboard ────────────────────────────────────────────────────────────
  static const dashboardStats = '/dashboard/stats';
}
