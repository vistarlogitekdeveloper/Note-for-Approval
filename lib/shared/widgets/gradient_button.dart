import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Primary gradient button matching the Vistar ribbon design system
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.small = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool small;
  final bool fullWidth;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(begin: 1.0, end: 0.97).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.small ? 40.0 : 48.0;
    final fz = widget.small ? 13.0 : 14.0;
    final px = widget.small ? 14.0 : 20.0;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onPressed != null && !widget.loading ? widget.onPressed : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: h,
          width: widget.fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: px),
          decoration: BoxDecoration(
            gradient: widget.onPressed == null
                ? const LinearGradient(colors: [AppColors.surface3, AppColors.surface3])
                : AppColors.ribbon,
            borderRadius: BorderRadius.circular(11),
            boxShadow: widget.onPressed == null
                ? null
                : [
                    BoxShadow(
                      color: AppColors.pink.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else if (widget.icon != null) ...[
                Icon(widget.icon, size: fz + 2, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fz,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ghost (outlined) secondary button
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.small = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool small;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.bad : AppColors.txt2;
    final border = danger ? AppColors.bad.withOpacity(0.4) : AppColors.line2;
    final h = small ? 36.0 : 44.0;
    final fz = small ? 12.5 : 14.0;

    return SizedBox(
      height: h,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: fz + 1, color: color) : const SizedBox.shrink(),
        label: Text(label, style: TextStyle(color: color, fontSize: fz, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          padding: EdgeInsets.symmetric(horizontal: small ? 14 : 18),
        ),
      ),
    );
  }
}
