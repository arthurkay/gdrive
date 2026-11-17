import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/material.dart' as md;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart' as m;

import '../../platform/ui_kit.dart';
import 'app_icons.dart';
import 'app_style.dart';
import 'controls.dart';

/// Shows a two-button dialog in the active kit's style. Resolves to true
/// when the confirm button is chosen, false otherwise.
Future<bool> showAppDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  String confirmLabel = 'OK',
  String? cancelLabel = 'Cancel',
  bool Function()? canConfirm,
}) async {
  void close(BuildContext dialog, bool value) {
    if (value && canConfirm != null && !canConfirm()) return;
    Navigator.of(dialog).pop(value);
  }

  final style = AppStyle.of(context);
  final body = DefaultTextStyle(style: style.body, child: content);

  final appIcon = AppIcons.of(context).myDrive;
  final Future<bool?> pending = switch (Kit.of(context)) {
    UiKit.fluent => f.showDialog<bool>(
      context: context,
      builder: (dialog) => f.ContentDialog(
        title: Text(title),
        content: body,
        actions: [
          if (cancelLabel != null)
            f.Button(
              onPressed: () => close(dialog, false),
              child: Text(cancelLabel),
            ),
          f.FilledButton(
            onPressed: () => close(dialog, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
    // macos_ui's alert is a fixed narrow column made for one-line messages;
    // forms and pickers need room, so the panel is laid out here with the
    // kit's own buttons.
    UiKit.macos => showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x55000000),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialog, _, _) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: style.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: style.border),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 30),
            ],
          ),
          child: DefaultTextStyle(
            style: style.body,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(appIcon, size: 22, color: style.accent),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, style: style.strong)),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(child: body),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cancelLabel != null) ...[
                      m.PushButton(
                        controlSize: m.ControlSize.large,
                        secondary: true,
                        onPressed: () => close(dialog, false),
                        child: Text(cancelLabel),
                      ),
                      const SizedBox(width: 10),
                    ],
                    m.PushButton(
                      controlSize: m.ControlSize.large,
                      onPressed: () => close(dialog, true),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    UiKit.yaru => md.showDialog<bool>(
      context: context,
      builder: (dialog) => md.AlertDialog(
        title: Text(title),
        content: SizedBox(width: 380, child: body),
        actions: [
          if (cancelLabel != null)
            md.OutlinedButton(
              onPressed: () => close(dialog, false),
              child: Text(cancelLabel),
            ),
          md.ElevatedButton(
            onPressed: () => close(dialog, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  };
  return await pending ?? false;
}

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'OK',
}) => showAppDialog(
  context,
  title: title,
  content: Text(message),
  confirmLabel: confirmLabel,
);

Future<void> showMessage(
  BuildContext context, {
  required String title,
  required String message,
}) => showAppDialog(
  context,
  title: title,
  content: Text(message),
  cancelLabel: null,
);

/// Asks for one line of text. Returns null when cancelled or left empty.
Future<String?> showPrompt(
  BuildContext context, {
  required String title,
  String initial = '',
  String placeholder = '',
  String confirmLabel = 'OK',
}) async {
  var text = initial;
  final confirmed = await showAppDialog(
    context,
    title: title,
    confirmLabel: confirmLabel,
    canConfirm: () => text.trim().isNotEmpty,
    content: _PromptField(
      initial: initial,
      placeholder: placeholder,
      onChanged: (value) => text = value,
    ),
  );
  return confirmed && text.trim().isNotEmpty ? text.trim() : null;
}

/// Owns the prompt's text controller for as long as the dialog (including
/// its closing animation) is on screen.
class _PromptField extends StatefulWidget {
  const _PromptField({
    required this.initial,
    required this.placeholder,
    required this.onChanged,
  });

  final String initial;
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  State<_PromptField> createState() => _PromptFieldState();
}

class _PromptFieldState extends State<_PromptField> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: _controller,
    placeholder: widget.placeholder,
    autofocus: true,
    onChanged: widget.onChanged,
    onSubmitted: (value) {
      widget.onChanged(value);
      if (value.trim().isNotEmpty) Navigator.of(context).pop(true);
    },
  );
}
