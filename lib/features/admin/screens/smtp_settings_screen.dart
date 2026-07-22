import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';

class SmtpSettingsScreen extends ConsumerStatefulWidget {
  const SmtpSettingsScreen({super.key});

  @override
  ConsumerState<SmtpSettingsScreen> createState() => _SmtpSettingsScreenState();
}

class _SmtpSettingsScreenState extends ConsumerState<SmtpSettingsScreen> {
  final _hostCtrl = TextEditingController(text: 'smtp.vistar.com');
  final _portCtrl = TextEditingController(text: '587');
  final _userCtrl = TextEditingController(text: 'notifications@vistar.com');
  final _passCtrl = TextEditingController();
  final _senderCtrl = TextEditingController(text: 'Vistar NFA <notifications@vistar.com>');
  bool _tls = true;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SMTP Settings',
              style: GoogleFonts.bricolageGrotesque(
                color: context.c.txt,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
          Text('Configure the email server for approval notifications',
              style: TextStyle(color: context.c.txt3, fontSize: 14)),
          const SizedBox(height: 24),

          VistarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Server Configuration'),
                const SizedBox(height: 20),

                // Host + Port
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _hostCtrl,
                        style: TextStyle(color: context.c.txt),
                        decoration: const InputDecoration(
                          labelText: 'SMTP Host *',
                          prefixIcon: Icon(Icons.dns_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _portCtrl,
                        style: TextStyle(color: context.c.txt),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Port *',
                          prefixIcon: Icon(Icons.settings_ethernet),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // TLS toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.c.surface2,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: context.c.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: context.c.txt3, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enable TLS/STARTTLS',
                                style: TextStyle(color: context.c.txt, fontSize: 14)),
                            Text('Recommended for production',
                                style: TextStyle(color: context.c.txt3, fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _tls,
                        onChanged: (v) => setState(() => _tls = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Auth
                TextField(
                  controller: _userCtrl,
                  style: TextStyle(color: context.c.txt),
                  decoration: const InputDecoration(
                    labelText: 'Username / Email *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  style: TextStyle(color: context.c.txt),
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),

                // Sender identity
                TextField(
                  controller: _senderCtrl,
                  style: TextStyle(color: context.c.txt),
                  decoration: const InputDecoration(
                    labelText: 'Sender Identity',
                    hintText: 'Display Name <address@example.com>',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // Test result
                if (_testResult != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _testResult!.startsWith('✓')
                          ? context.c.ok.withValues(alpha: 0.1)
                          : context.c.bad.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _testResult!.startsWith('✓')
                            ? context.c.ok.withValues(alpha: 0.3)
                            : context.c.bad.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testResult!.startsWith('✓')
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: _testResult!.startsWith('✓')
                              ? context.c.ok
                              : context.c.bad,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(_testResult!,
                            style: TextStyle(
                              color: _testResult!.startsWith('✓')
                                  ? context.c.ok
                                  : context.c.bad,
                              fontSize: 13.5,
                            )),
                      ],
                    ),
                  ),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GhostButton(
                      label: _testing ? 'Testing…' : 'Send Test Email',
                      icon: Icons.science_outlined,
                      onPressed: _testing
                          ? null
                          : () async {
                              setState(() {
                                _testing = true;
                                _testResult = null;
                              });
                              await Future.delayed(const Duration(seconds: 2));
                              if (mounted) {
                                setState(() {
                                  _testing = false;
                                  _testResult = '✓ Test email sent successfully';
                                });
                              }
                            },
                    ),
                    const SizedBox(width: 12),
                    GradientButton(
                      label: _saving ? 'Saving…' : 'Save Settings',
                      icon: Icons.save_rounded,
                      loading: _saving,
                      onPressed: () async {
                        setState(() => _saving = true);
                        await Future.delayed(const Duration(seconds: 1));
                        if (mounted) setState(() => _saving = false);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
