import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/material.dart' as md;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart' as m;
import 'package:yaru/yaru.dart' as y;

import '../../platform/ui_kit.dart';
import 'app_style.dart';

/// Push button in the active kit's style.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 6)],
        Text(label),
      ],
    );
    return switch (Kit.of(context)) {
      UiKit.fluent =>
        primary
            ? f.FilledButton(onPressed: onPressed, child: child)
            : f.Button(onPressed: onPressed, child: child),
      UiKit.macos => m.PushButton(
        controlSize: m.ControlSize.large,
        secondary: !primary,
        onPressed: onPressed,
        child: child,
      ),
      UiKit.yaru =>
        primary
            ? md.ElevatedButton(onPressed: onPressed, child: child)
            : md.OutlinedButton(onPressed: onPressed, child: child),
    };
  }
}

/// Icon-only button with a tooltip.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final tint = onPressed == null
        ? style.muted.withValues(alpha: 0.4)
        : color ?? style.text;
    final glyph = Icon(icon, size: 16, color: tint, semanticLabel: tooltip);
    return switch (Kit.of(context)) {
      UiKit.fluent => f.Tooltip(
        message: tooltip,
        child: f.IconButton(icon: glyph, onPressed: onPressed),
      ),
      UiKit.macos => m.MacosTooltip(
        message: tooltip,
        child: m.MacosIconButton(
          icon: glyph,
          onPressed: onPressed,
          boxConstraints: const BoxConstraints(
            minHeight: 28,
            minWidth: 28,
            maxHeight: 32,
            maxWidth: 32,
          ),
        ),
      ),
      UiKit.yaru => md.IconButton(
        icon: glyph,
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: md.VisualDensity.compact,
      ),
    };
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.prefixIcon,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final IconData? prefixIcon;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final prefix = prefixIcon == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 8, right: 2),
            child: Icon(
              prefixIcon,
              size: 14,
              color: AppStyle.of(context).muted,
            ),
          );
    return switch (Kit.of(context)) {
      UiKit.fluent => f.TextBox(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        prefix: prefix,
      ),
      UiKit.macos => m.MacosTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        prefix: prefix,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
      UiKit.yaru => md.TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        decoration: md.InputDecoration(
          hintText: placeholder,
          prefixIcon: prefix,
          prefixIconConstraints: const BoxConstraints(minHeight: 0),
          isDense: true,
        ),
      ),
    };
  }
}

class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => switch (Kit.of(context)) {
    UiKit.fluent => f.ToggleSwitch(checked: value, onChanged: onChanged),
    UiKit.macos => m.MacosSwitch(value: value, onChanged: onChanged),
    UiKit.yaru => y.YaruSwitch(value: value, onChanged: onChanged),
  };
}

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => switch (Kit.of(context)) {
    UiKit.fluent => f.Checkbox(
      checked: value,
      onChanged: (v) => onChanged(v ?? false),
    ),
    UiKit.macos => m.MacosCheckbox(value: value, onChanged: onChanged),
    UiKit.yaru => y.YaruCheckbox(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
    ),
  };
}

/// Progress from 0 to 1, or indeterminate when [value] is null.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final clamped = value?.clamp(0.0, 1.0);
    return switch (Kit.of(context)) {
      UiKit.fluent => f.ProgressBar(
        value: clamped == null ? null : clamped * 100,
      ),
      UiKit.macos =>
        clamped == null
            ? const Align(
                alignment: Alignment.centerLeft,
                child: m.ProgressCircle(radius: 7),
              )
            : m.ProgressBar(value: clamped * 100),
      UiKit.yaru => y.YaruLinearProgressIndicator(value: clamped),
    };
  }
}

class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: switch (Kit.of(context)) {
      UiKit.fluent => const f.ProgressRing(strokeWidth: 3),
      UiKit.macos => m.ProgressCircle(radius: size / 2),
      UiKit.yaru => const y.YaruCircularProgressIndicator(strokeWidth: 3),
    },
  );
}

enum BannerKind { info, warning, error }

/// Inline message strip with an optional action.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.kind = BannerKind.info,
    this.action,
  });

  final String message;
  final BannerKind kind;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    if (Kit.of(context) == UiKit.fluent) {
      return f.InfoBar(
        title: Text(message),
        isLong: false,
        severity: switch (kind) {
          BannerKind.info => f.InfoBarSeverity.info,
          BannerKind.warning => f.InfoBarSeverity.warning,
          BannerKind.error => f.InfoBarSeverity.error,
        },
        action: action,
      );
    }
    final style = AppStyle.of(context);
    final tint = switch (kind) {
      BannerKind.info => style.accent,
      BannerKind.warning => style.warning,
      BannerKind.error => style.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: style.body)),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

/// Rebuilds with whether the pointer is over it.
class Hoverable extends StatefulWidget {
  const Hoverable({super.key, required this.builder});

  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: widget.builder(context, _hovered),
  );
}
