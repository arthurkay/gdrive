import 'package:flutter/widgets.dart';

import 'app_style.dart';
import 'controls.dart';

class AppMenuItem {
  const AppMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
    this.enabled = true,
  }) : divider = false;

  const AppMenuItem.divider()
    : label = '',
      onSelected = null,
      icon = null,
      destructive = false,
      enabled = false,
      divider = true;

  final String label;
  final VoidCallback? onSelected;
  final IconData? icon;
  final bool destructive;
  final bool enabled;
  final bool divider;
}

/// Opens a context menu at [position] (global coordinates). One
/// implementation for all kits, coloured from the active theme.
Future<void> showAppMenu(
  BuildContext context, {
  required Offset position,
  required List<AppMenuItem> items,
}) {
  final style = AppStyle.of(context);
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(_MenuRoute(position: position, items: items, style: style));
}

class _MenuRoute extends PopupRoute<void> {
  _MenuRoute({
    required this.position,
    required this.items,
    required this.style,
  });

  final Offset position;
  final List<AppMenuItem> items;
  final AppStyle style;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 90);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => FadeTransition(
    opacity: animation,
    child: CustomSingleChildLayout(
      delegate: _MenuLayout(position),
      child: _MenuPanel(items: items, style: style),
    ),
  );
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(this.position);

  final Offset position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    position.dx.clamp(4, (size.width - childSize.width - 4).clamp(4, 1e6)),
    position.dy.clamp(4, (size.height - childSize.height - 4).clamp(4, 1e6)),
  );

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      oldDelegate.position != position;
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.items, required this.style});

  final List<AppMenuItem> items;
  final AppStyle style;

  @override
  Widget build(BuildContext context) => Container(
    width: 232,
    padding: const EdgeInsets.symmetric(vertical: 5),
    decoration: BoxDecoration(
      color: style.isDark ? const Color(0xFF2B2B2B) : const Color(0xFFFCFCFC),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: style.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            if (item.divider)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: style.border,
              )
            else
              _MenuRow(item: item, style: style),
        ],
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.style});

  final AppMenuItem item;
  final AppStyle style;

  @override
  Widget build(BuildContext context) {
    final color = !item.enabled
        ? style.muted.withValues(alpha: 0.45)
        : item.destructive
        ? style.danger
        : style.text;
    return Hoverable(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !item.enabled
            ? null
            : () {
                Navigator.of(context).pop();
                item.onSelected?.call();
              },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: hovered && item.enabled ? style.hover : null,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: item.icon == null
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(item.icon, size: 15, color: color),
                      ),
              ),
              Expanded(
                child: Text(
                  item.label,
                  style: style.body.copyWith(
                    color: color,
                    decoration: TextDecoration.none,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
