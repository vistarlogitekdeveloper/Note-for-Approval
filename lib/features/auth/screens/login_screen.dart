import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
    } catch (e) {
      setState(() {
        _error = 'Invalid email or password. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 800;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Ambient background ──────────────────────────────────────────
          Positioned.fill(child: _AmbientBg()),

          // ── Content ────────────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: isMobile ? _mobileLayout() : _desktopLayout(),
          ),
        ],
      ),
    );
  }

  Widget _desktopLayout() {
    return Row(
      children: [
        // Left hero panel
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0E0C22), Color(0xFF130F28)],
              ),
            ),
            child: Stack(
              children: [
                // Faint S-watermark placeholder
                Positioned(
                  right: -60,
                  top: 80,
                  child: Opacity(
                    opacity: 0.06,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [AppColors.violet, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo area
                      Row(
                        children: [
                          _LogoMark(size: 36),
                          const SizedBox(width: 10),
                          Text(
                            AppStrings.company,
                            style: GoogleFonts.bricolageGrotesque(
                              color: AppColors.txt,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ShaderMask(
                        shaderCallback: (b) => AppColors.ribbon.createShader(b),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          'Streamlined',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                      ),
                      Text(
                        'Approvals',
                        style: GoogleFonts.bricolageGrotesque(
                          color: AppColors.txt,
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Replace paper-based note approvals with a\ndigital, multi-level workflow — tracked,\naudit-ready, and PDF-archived.',
                        style: const TextStyle(
                          color: AppColors.txt3,
                          fontSize: 15.5,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          _StatFigure(value: '8+', label: 'Approval Levels'),
                          const SizedBox(width: 32),
                          _StatFigure(value: '100%', label: 'Audit Trail'),
                          const SizedBox(width: 32),
                          _StatFigure(value: 'PDF', label: 'Auto Generated'),
                        ],
                      ),
                      const SizedBox(height: 56),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right form panel
        SizedBox(
          width: 480,
          child: Container(
            color: AppColors.bg2,
            child: Center(child: _FormContent(
              formKey: _formKey,
              emailCtrl: _emailCtrl,
              passCtrl: _passCtrl,
              obscure: _obscure,
              loading: _loading,
              error: _error,
              onObscureToggle: () => setState(() => _obscure = !_obscure),
              onSubmit: _submit,
            )),
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LogoMark(size: 32),
                const SizedBox(width: 10),
                Text(
                  AppStrings.company,
                  style: GoogleFonts.bricolageGrotesque(
                    color: AppColors.txt,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _FormContent(
              formKey: _formKey,
              emailCtrl: _emailCtrl,
              passCtrl: _passCtrl,
              obscure: _obscure,
              loading: _loading,
              error: _error,
              onObscureToggle: () => setState(() => _obscure = !_obscure),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _AmbientBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -0.6),
          radius: 1.4,
          colors: [Color(0xFF1A0F30), AppColors.bg],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.ribbon,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(
          'V',
          style: GoogleFonts.bricolageGrotesque(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatFigure extends StatelessWidget {
  const _StatFigure({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (b) => AppColors.ribbon.createShader(b),
          blendMode: BlendMode.srcIn,
          child: Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(label,
            style: const TextStyle(color: AppColors.txt3, fontSize: 12.5)),
      ],
    );
  }
}

class _FormContent extends StatelessWidget {
  const _FormContent({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onObscureToggle,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onObscureToggle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sign in',
              style: GoogleFonts.bricolageGrotesque(
                color: AppColors.txt,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Note for Approval Portal — ${AppStrings.company}',
              style: const TextStyle(color: AppColors.txt3, fontSize: 13.5),
            ),
            const SizedBox(height: 32),

            // Email field
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: AppColors.txt, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password field
            TextFormField(
              controller: passCtrl,
              obscureText: obscure,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(color: AppColors.txt, fontSize: 14),
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: onObscureToggle,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),

            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bad.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bad.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.bad, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.bad, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            GradientButton(
              label: 'Sign in',
              icon: Icons.arrow_forward_rounded,
              onPressed: onSubmit,
              loading: loading,
              fullWidth: true,
            ),

            const SizedBox(height: 32),
            const Divider(color: AppColors.line),
            const SizedBox(height: 16),
            Text(
              'Contact your administrator if you have trouble signing in.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.txt3, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
