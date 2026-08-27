import 'package:flutter/material.dart';

/// 关闭显示叉号，开启显示对号，带滑动与图标缩放动画
class MorphSwitch extends StatelessWidget {
  const MorphSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onChanged != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: value ? cs.primary : cs.surfaceContainerHighest,
            border: Border.all(
              color: value ? cs.primary : cs.outline,
              width: 1.5,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? cs.onPrimary : cs.outline,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                child: Icon(
                  value ? Icons.check_rounded : Icons.close_rounded,
                  key: ValueKey(value),
                  size: 16,
                  color: value ? cs.primary : cs.surfaceContainerHighest,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
