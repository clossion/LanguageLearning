// lib/widgets/icon_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 桌面统一 48×48 图标按钮，带悬停 / 点击动画
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  /// icon 可传 IconData 或 SVG 路径 ('assets/icons/xxx.svg')
  final dynamic icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _hovering = false;
  bool _pressed  = false;

  void _enter(PointerEnterEvent _) => setState(() => _hovering = true);
  void _exit (PointerExitEvent  _) => setState(() => _hovering = false);
  void _down (TapDownDetails    _) => setState(() => _pressed  = true);
  void _up   (TapUpDetails      _) => setState(() => _pressed  = false);
  void _cancel()                   => setState(() => _pressed  = false);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 背景颜色计算
    Color bg = Colors.transparent;
    if (widget.active) bg = cs.primary.withOpacity(.10);
    if (_hovering)     bg = cs.primaryContainer.withOpacity(.25);
    if (_pressed)      bg = cs.primaryContainer.withOpacity(.40);

    // 图标颜色
    final Color fg = widget.active ? cs.primary : cs.onSurfaceVariant;

    // Icon or SVG
    final Widget iconWidget = switch (widget.icon) {
      IconData data          => Icon(data, size: 24, color: fg),
      String   path when path.endsWith('.svg')
                          => SvgPicture.asset(path, width: 24, height: 24, color: fg),
      _                    => const SizedBox.shrink(),
    };

    return Tooltip(
      waitDuration: const Duration(milliseconds: 200),
      message     : widget.tooltip ?? '',
      child: MouseRegion(
        cursor : SystemMouseCursors.click,
        onEnter: _enter,
        onExit : _exit,
        child  : GestureDetector(
          behavior   : HitTestBehavior.opaque,
          onTapDown  : _down,
          onTapUp    : _up,
          onTap      : widget.onPressed,
          onTapCancel: _cancel,
          child: AnimatedContainer(
            duration   : const Duration(milliseconds: 120),
            curve      : Curves.easeOut,
            width      : 48,
            height     : 48,
            decoration : BoxDecoration(
              color       : bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: iconWidget),
          ),
        ),
      ),
    );
  }
}
