import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../../core/ui/adaptive/app_icons.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import 'native_viewers.dart';

/// Where a media player reads from: a local file, or a URL with headers.
class MediaSource {
  const MediaSource.file(String path) : uri = path, headers = const {};
  const MediaSource.network(this.uri, this.headers);

  final String uri;
  final Map<String, String> headers;
}

/// Builds the built-in viewers. A provider so widget tests can substitute
/// plain widgets for the ones backed by native libraries.
class ViewerFactory {
  const ViewerFactory();

  Widget image(File file) => ImageViewer(file: file);

  Widget pdf(File file) => PdfPane(file: file);

  Widget media(MediaSource source, {required bool video}) =>
      MediaPane(source: source, video: video);

  Widget text({
    required String content,
    required String? language,
    required bool readOnly,
    required ValueChanged<String> onChanged,
  }) => TextPane(
    content: content,
    language: language,
    readOnly: readOnly,
    onChanged: onChanged,
  );
}

final viewerFactoryProvider = Provider<ViewerFactory>(
  (ref) => const ViewerFactory(),
);

class ViewerBar extends StatelessWidget {
  const ViewerBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.surface,
        border: Border(top: BorderSide(color: style.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

// ---- images ---------------------------------------------------------------

class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key, required this.file});

  final File file;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  final _transform = TransformationController();
  int _quarterTurns = 0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final size = context.size ?? Size.zero;
    final centre = Offset(size.width / 2, size.height / 2);
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      0.25,
      8.0,
    );
    final scene = _transform.toScene(centre);
    _transform.value = Matrix4.identity()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final icons = AppIcons.of(context);
    final style = AppStyle.of(context);
    return Column(
      children: [
        Expanded(
          child: ClipRect(
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 0.25,
              maxScale: 8,
              // Fill the window, so small pictures are scaled up to fit and
              // large ones scaled down.
              child: SizedBox.expand(
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Image.file(
                    widget.file,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => Text(
                      'This image could not be displayed',
                      style: style.caption,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ViewerBar(
          children: [
            AppIconButton(
              icon: icons.zoomOut,
              tooltip: 'Zoom out',
              onPressed: () => _zoom(1 / 1.25),
            ),
            AppIconButton(
              icon: icons.zoomIn,
              tooltip: 'Zoom in',
              onPressed: () => _zoom(1.25),
            ),
            AppIconButton(
              icon: icons.fullscreen,
              tooltip: 'Fit to window',
              onPressed: () => _transform.value = Matrix4.identity(),
            ),
            AppIconButton(
              icon: icons.rotate,
              tooltip: 'Rotate',
              onPressed: () =>
                  setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
            ),
          ],
        ),
      ],
    );
  }
}

/// Click-or-drag progress bar.
class SeekBar extends StatelessWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final total = duration.inMilliseconds;
    final fraction = total <= 0
        ? 0.0
        : (position.inMilliseconds / total).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(double dx) {
          if (total <= 0) return;
          final f = (dx / constraints.maxWidth).clamp(0.0, 1.0);
          onSeek(Duration(milliseconds: (total * f).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
          child: SizedBox(
            height: 16,
            child: Center(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: style.border,
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    decoration: BoxDecoration(
                      color: style.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fixed-width fonts to try, covering what each desktop ships with. The
/// generic "monospace" name is not resolved on every platform.
const monospaceFonts = [
  'JetBrains Mono',
  'Ubuntu Mono',
  'DejaVu Sans Mono',
  'Cascadia Mono',
  'Consolas',
  'Menlo',
  'SF Mono',
  'Courier New',
  'monospace',
];

// ---- text -----------------------------------------------------------------

class TextPane extends StatefulWidget {
  const TextPane({
    super.key,
    required this.content,
    required this.language,
    required this.readOnly,
    required this.onChanged,
  });

  final String content;
  final String? language;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  @override
  State<TextPane> createState() => _TextPaneState();
}

class _TextPaneState extends State<TextPane> {
  late final _controller = CodeLineEditingController.fromText(widget.content);
  late final _find = CodeFindController(_controller);

  @override
  void dispose() {
    _find.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final mode = builtinAllLanguages[widget.language];
    return CodeEditor(
      controller: _controller,
      findController: _find,
      readOnly: widget.readOnly,
      wordWrap: widget.language == null || widget.language == 'markdown',
      autofocus: true,
      onChanged: (_) => widget.onChanged(_controller.text),
      style: CodeEditorStyle(
        fontSize: 14,
        fontFamily: monospaceFonts.first,
        fontFamilyFallback: monospaceFonts,
        fontHeight: 1.45,
        textColor: style.text,
        backgroundColor: style.background,
        selectionColor: style.selected,
        cursorColor: style.accent,
        cursorLineColor: style.hover,
        codeTheme: mode == null
            ? null
            : CodeHighlightTheme(
                languages: {
                  widget.language!: CodeHighlightThemeMode(mode: mode),
                },
                theme: style.isDark ? atomOneDarkTheme : atomOneLightTheme,
              ),
      ),
      indicatorBuilder: (context, editing, chunks, notifier) =>
          DefaultCodeLineNumber(
            controller: editing,
            notifier: notifier,
            textStyle: style.caption.copyWith(
              fontFamily: monospaceFonts.first,
              fontFamilyFallback: monospaceFonts,
            ),
          ),
      findBuilder: (context, controller, readOnly) =>
          _FindPanel(controller: controller),
    );
  }
}

class _FindPanel extends StatelessWidget implements PreferredSizeWidget {
  const _FindPanel({required this.controller});

  final CodeFindController controller;

  @override
  Size get preferredSize => Size.fromHeight(controller.value == null ? 0 : 44);

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (value == null) return const SizedBox.shrink();
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);
    final result = value.result;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: style.surface,
        border: Border(bottom: BorderSide(color: style.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            child: AppTextField(
              controller: controller.findInputController,
              focusNode: controller.findInputFocusNode,
              placeholder: 'Find',
              prefixIcon: icons.search,
              onSubmitted: (_) => controller.nextMatch(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            result == null || result.matches.isEmpty
                ? 'No matches'
                : '${result.index + 1} of ${result.matches.length}',
            style: style.caption,
          ),
          AppIconButton(
            icon: icons.up,
            tooltip: 'Previous match',
            onPressed: controller.previousMatch,
          ),
          AppIconButton(
            icon: icons.chevron,
            tooltip: 'Next match',
            onPressed: controller.nextMatch,
          ),
          const Spacer(),
          AppIconButton(
            icon: icons.close,
            tooltip: 'Close find',
            onPressed: controller.close,
          ),
        ],
      ),
    );
  }
}
