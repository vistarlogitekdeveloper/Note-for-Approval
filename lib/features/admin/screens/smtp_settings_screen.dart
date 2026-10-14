import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';

/// What `GET /admin/smtp` returns: the saved row (never the password), or
/// nothing yet plus whether a fallback server is in effect.
class SmtpConfig {
  const SmtpConfig({
    this.host = '',
    this.port = 587,
    this.username = '',
    this.senderAddress = '',
    this.enableTls = true,
    this.saved = false,
    this.fallbackAvailable = false,
  });

  final String host;
  final int port;
  final String username;
  final String senderAddress;
  final bool enableTls;

  /// A row is stored for this organisation (so the password may be left blank
  /// on save to keep it).
  final bool saved;

  /// No row, but the server has environment / platform settings it falls
  /// back to.
  final bool fallbackAvailable;
}

final smtpConfigProvider = FutureProvider.autoDispose<SmtpConfig>((ref) async {
  final res = await ref.read(apiClientProvider).get(ApiEndpoints.smtpSettings);
  final meta = res.meta ?? const {};
  if (res.data == null) {
    return SmtpConfig(
      fallbackAvailable:
          meta['env_fallback'] == true || meta['platform_settings'] == true,
    );
  }
  final j = res.asMap;
  return SmtpConfig(
    host: j['host'] as String? ?? '',
    port: (j['port'] as num?)?.toInt() ?? 587,
    username: j['username'] as String? ?? '',
    senderAddress: j['sender_address'] as String? ?? '',
    enableTls: j['enable_tls'] as bool? ?? true,
    saved: true,
  );
});

class SmtpSettingsScreen extends ConsumerWidget {
  const SmtpSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(smtpConfigProvider);
    final compact = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email (SMTP) Settings',
              style: GoogleFonts.bricolageGrotesque(
                color: context.c.txt,
                fontSize: compact ? 24 : 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
          Text('The mail server that sends approval requests and decisions',
              style: TextStyle(color: context.c.txt3, fontSize: 14)),
          const SizedBox(height: 24),
          async.when(
            data: (config) => _SmtpForm(config: config),
            loading: () => const ShimmerCard(height: 420),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(smtpConfigProvider)),
          ),
        ],
      ),
    );
  }
}

class _SmtpForm extends ConsumerStatefulWidget {
  const _SmtpForm({required this.config});
  final SmtpConfig config;

  @override
  ConsumerState<_SmtpForm> createState() => _SmtpFormState();
}

class _SmtpFormState extends ConsumerState<_SmtpForm> {
  final _formKey = GlobalKey<FormState>();
  late final _host = TextEditingController(text: widget.config.host);
  late final _port = TextEditingController(text: '${widget.config.port}');
  late final _user = TextEditingController(text: widget.config.username);
  final _pass = TextEditingController();
  late final _sender = TextEditingController(text: widget.config.senderAddress);
  late bool _tls = widget.config.enableTls;
  bool _saving = false;
  bool _testing = false;

  /// The outcome of the last test: (ok, message).
  (bool, String)? _testResult;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _sender.dispose();
    super.dispose();
  }

  String _message(Object e) =>
      e is ApiException ? (e.isNetwork ? 'Cannot reach the server.' : e.displayMessage) : '$e';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post(ApiEndpoints.smtpSettings, data: {
        'host': _host.text.trim(),
        'port': int.parse(_port.text.trim()),
        'username': _user.text.trim(),
        // Blank means "keep the stored password" on an existing row.
        if (_pass.text.isNotEmpty) 'password': _pass.text,
        'sender_address': _sender.text.trim(),
        'enable_tls': _tls,
      });
      if (!mounted) return;
      _pass.clear();
      AppFeedback.success(context, 'Email settings saved.');
      ref.invalidate(smtpConfigProvider);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.info(context, 'Not saved: ${_message(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    final me = ref.read(authProvider).user?.email ?? '';
    final ctrl = TextEditingController(text: me);
    final to = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surface,
        title: Text('Send a test email', style: TextStyle(color: context.c.txt, fontSize: 17)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Uses the SAVED settings — save your changes first.',
                  style: TextStyle(color: context.c.txt3, fontSize: 12.5)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Send to'),
                onSubmitted: (v) => Navigator.of(context).pop(v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(ctrl.text), child: const Text('Send')),
        ],
      ),
    );
    ctrl.dispose();
    if (to == null || !mounted) return;
    if (!_email.hasMatch(to.trim())) {
      setState(() => _testResult = (false, 'Enter a valid email address to send the test to.'));
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await ref.read(apiClientProvider).post(ApiEndpoints.smtpTest, data: {'to': to.trim()});
      if (mounted) setState(() => _testResult = (true, 'Test email sent to ${to.trim()}.'));
    } catch (e) {
      if (mounted) setState(() => _testResult = (false, _message(e)));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final port = TextFormField(
      controller: _port,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Port *', prefixIcon: Icon(Icons.settings_ethernet)),
      validator: (v) {
        final n = int.tryParse(v?.trim() ?? '');
        return n == null || n < 1 || n > 65535 ? 'Enter a port from 1 to 65535' : null;
      },
    );
    final host = TextFormField(
      controller: _host,
      decoration: const InputDecoration(labelText: 'SMTP host *', prefixIcon: Icon(Icons.dns_outlined)),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the mail server host' : null,
    );

    return VistarCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Server Configuration'),
            const SizedBox(height: 12),
            if (!config.saved)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  config.fallbackAvailable
                      ? 'Nothing saved yet — emails currently go through the server\'s default mailbox. Save settings here to use your own.'
                      : 'Nothing saved yet and no default mailbox is configured: no emails are being sent.',
                  style: TextStyle(
                      color: config.fallbackAvailable ? context.c.txt3 : context.c.bad, fontSize: 13),
                ),
              ),
            if (narrow) ...[host, const SizedBox(height: 16), port] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: host),
                  const SizedBox(width: 16),
                  Expanded(child: port),
                ],
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _tls,
              onChanged: (v) => setState(() => _tls = v),
              title: Text('Use TLS / STARTTLS', style: TextStyle(color: context.c.txt, fontSize: 14)),
              subtitle: Text('Recommended. Port 465 uses TLS from the start; 587 upgrades with STARTTLS.',
                  style: TextStyle(color: context.c.txt3, fontSize: 12)),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'Username *', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the mailbox username' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pass,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: config.saved ? 'Password' : 'Password *',
                helperText: config.saved ? 'Leave blank to keep the saved password' : null,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              validator: (v) =>
                  !config.saved && (v == null || v.isEmpty) ? 'A password is needed the first time' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sender,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Sender address *',
                hintText: 'notifications@yourcompany.com',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (v) => _email.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address',
            ),
            const SizedBox(height: 20),
            if (_testResult != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_testResult!.$1 ? context.c.ok : context.c.bad).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: (_testResult!.$1 ? context.c.ok : context.c.bad).withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_testResult!.$1 ? Icons.check_circle_outline : Icons.error_outline,
                        color: _testResult!.$1 ? context.c.ok : context.c.bad, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_testResult!.$2,
                          style: TextStyle(
                              color: _testResult!.$1 ? context.c.ok : context.c.bad, fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 12,
              children: [
                GhostButton(
                  label: _testing ? 'Sending…' : 'Send test email',
                  icon: Icons.outgoing_mail,
                  onPressed: _testing || _saving || !config.saved ? null : _test,
                ),
                GradientButton(
                  label: _saving ? 'Saving…' : 'Save settings',
                  icon: Icons.save_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
