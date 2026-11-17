import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/platform/system.dart';
import '../../core/platform/ui_kit.dart';
import '../../core/ui/adaptive/app_icons.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import '../../core/ui/adaptive/dialogs.dart';
import '../../core/ui/notice.dart';
import '../../core/util/file_kind.dart';
import '../../core/util/format.dart';
import '../auth/auth_controller.dart';
import '../sync/sync_controller.dart';
import 'preview_service.dart';
import 'viewers.dart';

/// Full-window viewer for one file, with previous/next through the files of
/// the folder it was opened from.
class PreviewPage extends ConsumerStatefulWidget {
  const PreviewPage({super.key, required this.item, required this.siblings});

  final DriveItem item;
  final List<DriveItem> siblings;

  /// Route that carries the active kit across the navigator boundary.
  static Route<void> route(
    BuildContext context, {
    required DriveItem item,
    required List<DriveItem> siblings,
  }) {
    final kit = Kit.of(context);
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 120),
      reverseTransitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (_, _, _) => Kit(
        kit: kit,
        child: PreviewPage(item: item, siblings: siblings),
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  ConsumerState<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends ConsumerState<PreviewPage> {
  late int _index = widget.siblings
      .indexWhere((e) => e.id == widget.item.id)
      .clamp(0, widget.siblings.isEmpty ? 0 : widget.siblings.length - 1);
  final _focus = FocusNode(debugLabel: 'preview');

  /// Edited text waiting to be saved, or null when there is nothing to save.
  String? _draft;
  bool _saving = false;
  PreviewSource? _textSource;

  DriveItem get _item =>
      widget.siblings.isEmpty ? widget.item : widget.siblings[_index];

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (_draft == null) return true;
    return showConfirm(
      context,
      title: 'Discard changes?',
      message: 'Your edits to "${_item.name}" have not been saved.',
      confirmLabel: 'Discard',
    );
  }

  Future<void> _step(int delta) async {
    final next = _index + delta;
    if (next < 0 || next >= widget.siblings.length) return;
    if (!await _confirmDiscard()) return;
    setState(() {
      _index = next;
      _draft = null;
      _textSource = null;
    });
  }

  Future<void> _close() async {
    if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final draft = _draft;
    final source = _textSource;
    if (draft == null || source == null || _saving) return;
    setState(() => _saving = true);
    final notice = ref.read(noticeProvider.notifier);
    try {
      final uploaded = await ref
          .read(previewServiceProvider)
          .saveText(_item, source, draft);
      if (!uploaded) ref.read(syncProvider.notifier).syncNow();
      if (mounted) setState(() => _draft = null);
      notice.show(uploaded ? 'Saved to Drive' : 'Saved; syncing to Drive');
    } catch (e) {
      notice.show('Could not save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openWithSystem() async {
    final notice = ref.read(noticeProvider.notifier);
    try {
      final source = await ref.read(previewServiceProvider).open(_item);
      await ref.read(launcherProvider)(Uri.file(source.file.path));
    } catch (e) {
      notice.show('Could not open: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);
    final isText = item.kind == FileKind.text;
    final many = widget.siblings.length > 1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        if (!isText) ...{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
        },
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: NoticeHost(
          child: AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: style.surface,
                    border: Border(bottom: BorderSide(color: style.border)),
                  ),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: icons.back,
                        tooltip: 'Back to files',
                        onPressed: _close,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        icons.forKind(item.kind),
                        size: 16,
                        color: style.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _draft == null ? item.name : '${item.name} •',
                          style: style.strong,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isText && _draft != null) ...[
                        AppButton(
                          label: _saving ? 'Saving…' : 'Save',
                          icon: icons.save,
                          primary: true,
                          onPressed: _saving ? null : _save,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (many) ...[
                        AppIconButton(
                          icon: icons.previous,
                          tooltip: 'Previous file',
                          onPressed: _index > 0 ? () => _step(-1) : null,
                        ),
                        Text(
                          '${_index + 1} / ${widget.siblings.length}',
                          style: style.caption,
                        ),
                        AppIconButton(
                          icon: icons.next,
                          tooltip: 'Next file',
                          onPressed: _index < widget.siblings.length - 1
                              ? () => _step(1)
                              : null,
                        ),
                      ],
                      AppIconButton(
                        icon: icons.openExternal,
                        tooltip: 'Open with default app',
                        onPressed: item.isUnsyncable ? null : _openWithSystem,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(item.id),
                    child: _PreviewBody(
                      item: item,
                      onTextLoaded: (source) => _textSource = source,
                      onTextChanged: (text, original) => setState(
                        () => _draft = text == original ? null : text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A file on disk for the viewers, keyed by item id and version.
final _sourceProvider = FutureProvider.autoDispose
    .family<PreviewSource, DriveItem>(
      (ref, item) => ref.watch(previewServiceProvider).open(item),
    );

/// Media plays from the synced copy when there is one, streams from Drive
/// when signed in, and otherwise falls back to a cached download.
final _mediaProvider = FutureProvider.autoDispose
    .family<MediaSource, DriveItem>((ref, item) async {
      final service = ref.watch(previewServiceProvider);
      final local = await service.syncedCopy(item);
      if (local != null) return MediaSource.file(local.path);
      if (ref.read(sessionProvider) == null) {
        return MediaSource.file((await service.open(item)).file.path);
      }
      final stream = await ref.watch(mediaStreamProvider(item.id).future);
      return MediaSource.network(stream.url, stream.headers);
    });

final _textProvider = FutureProvider.autoDispose
    .family<({PreviewSource source, String text}), DriveItem>((
      ref,
      item,
    ) async {
      final source = await ref.watch(_sourceProvider(item).future);
      return (source: source, text: await _readText(source.file));
    });

Future<String> _readText(File file) async {
  final bytes = await file.readAsBytes();
  try {
    return const Utf8Codec().decode(bytes);
  } on FormatException {
    return const Latin1Codec().decode(bytes);
  }
}

class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({
    required this.item,
    required this.onTextLoaded,
    required this.onTextChanged,
  });

  final DriveItem item;
  final ValueChanged<PreviewSource> onTextLoaded;
  final void Function(String text, String original) onTextChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewers = ref.watch(viewerFactoryProvider);
    final style = AppStyle.of(context);

    Widget pending<T>(AsyncValue<T> value, Widget Function(T) ready) =>
        value.when(
          skipLoadingOnReload: true,
          data: ready,
          loading: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppSpinner(size: 26),
                const SizedBox(height: 12),
                Text('Loading ${item.name}…', style: style.caption),
              ],
            ),
          ),
          error: (e, _) => _Unavailable(
            item: item,
            message: 'This file could not be loaded.\n$e',
          ),
        );

    switch (item.kind) {
      case FileKind.image:
        return pending(
          ref.watch(_sourceProvider(item)),
          (source) => viewers.image(source.file),
        );
      case FileKind.pdf || FileKind.googleDoc:
        return pending(
          ref.watch(_sourceProvider(item)),
          (source) => viewers.pdf(source.file),
        );
      case FileKind.audio || FileKind.video:
        return pending(
          ref.watch(_mediaProvider(item)),
          (source) => viewers.media(source, video: item.kind == FileKind.video),
        );
      case FileKind.text:
        return pending(ref.watch(_textProvider(item)), (loaded) {
          onTextLoaded(loaded.source);
          final readOnly = item.trashed || (item.size ?? 0) > maxEditableBytes;
          return viewers.text(
            content: loaded.text,
            language: highlightLanguageOf(item.name),
            readOnly: readOnly,
            onChanged: (text) => onTextChanged(text, loaded.text),
          );
        });
      case FileKind.folder || FileKind.other:
        return _Unavailable(
          item: item,
          message: 'No built-in preview for this type of file.',
        );
    }
  }
}

class _Unavailable extends ConsumerWidget {
  const _Unavailable({required this.item, required this.message});

  final DriveItem item;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icons.forKind(item.kind),
              size: 52,
              color: style.muted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(item.name, style: style.strong, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              '${item.mimeType} · ${formatBytes(item.size)}',
              style: style.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(message, style: style.body, textAlign: TextAlign.center),
            if (item.webViewLink != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'Open in browser',
                icon: icons.openExternal,
                onPressed: () =>
                    ref.read(launcherProvider)(Uri.parse(item.webViewLink!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
