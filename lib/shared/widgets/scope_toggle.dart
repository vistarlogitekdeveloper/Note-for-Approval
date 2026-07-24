import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A two-option segmented control — "My Notes" vs "All Notes" by default.
///
/// Shown to admins, who can look beyond the data they own. Used on both My
/// Notes and the Dashboard so the two stay visually and behaviourally in sync.
class ScopeToggle extends StatelessWidget {
  const ScopeToggle({
    super.key,
    required this.mineOnly,
    required this.onChanged,
    this.mineLabel = 'My Notes',
    this.allLabel = 'All Notes',
  });

  final bool mineOnly;
  final ValueChanged<bool> onChanged;
  final String mineLabel;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.c.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, mineLabel, mineOnly, () => onChanged(true)),
          _segment(context, allLabel, !mineOnly, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(
      BuildContext context, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.pink : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : context.c.txt2,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
