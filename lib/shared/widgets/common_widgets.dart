import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Section title with left ribbon accent bar
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppColors.ribbon,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: context.c.txt,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Simple Vistar-style card wrapper
class VistarCard extends StatelessWidget {
  const VistarCard({super.key, required this.child, this.padding, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.c.surface2, context.c.surface],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.c.line),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// KPI stat card used on the dashboard
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Every KPI stands for a filtered slice of the notes list, so tapping one
  /// takes you to exactly that slice rather than leaving you to re-derive it
  /// by hand.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const Spacer(),
              // Flexible, not a fixed 120: on a narrow tile a rigid bar was
              // the thing that pushed the row over its width.
              Flexible(
                child: Container(
                  height: 5,
                  constraints: const BoxConstraints(maxWidth: 84),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 15, color: context.c.txt3.withValues(alpha: 0.7)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Flexible + scaleDown so a cramped tile shrinks the number instead
          // of overflowing. The grid gives these cards a fixed height, but
          // font metrics vary by platform and a KPI card must never be the
          // thing that throws a layout error.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ShaderMask(
                shaderCallback: (b) => AppColors.ribbon.createShader(b),
                blendMode: BlendMode.srcIn,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'BricolageGrotesque',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.c.txt3,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading card
class ShimmerCard extends StatefulWidget {
  const ShimmerCard({super.key, this.height = 80});
  final double height;

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: context.c.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.c.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      (_ctrl.value * 2 - 0.5) * MediaQuery.sizeOf(context).width,
                      0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.pink.withValues(alpha: 0.10),
                            AppColors.orange.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon, this.action});
  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.inbox_outlined, size: 56, color: context.c.txt3),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.c.txt3, fontSize: 15),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
