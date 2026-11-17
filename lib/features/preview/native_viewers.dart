// coverage:ignore-file
// These two viewers are thin wrappers over native libraries (PDFium and
// libmpv) that cannot load in `flutter test`. Everything testable around
// them - routing, loading, the seek bar - lives in other files.
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/ui/adaptive/app_icons.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import '../../core/util/format.dart';
import 'viewers.dart';

// ---- PDF ------------------------------------------------------------------

class PdfPane extends StatefulWidget {
  const PdfPane({super.key, required this.file});

  final File file;

  @override
  State<PdfPane> createState() => _PdfPaneState();
}

class _PdfPaneState extends State<PdfPane> {
  final _controller = PdfViewerController();

  /// Created once the viewer is ready: the searcher reads the document
  /// from the controller in its constructor.
  PdfTextSearcher? _searcher;
  final _query = TextEditingController();

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searcher
      ?..removeListener(_changed)
      ..dispose();
    _query.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (!_controller.isReady) return;
    _controller.goToPage(pageNumber: page.clamp(1, _controller.pageCount));
  }

  @override
  Widget build(BuildContext context) {
    final icons = AppIcons.of(context);
    final style = AppStyle.of(context);
    final ready = _controller.isReady;
    final page = ready ? _controller.pageNumber ?? 1 : 0;
    final pages = ready ? _controller.pageCount : 0;
    return Column(
      children: [
        Expanded(
          child: PdfViewer.file(
            widget.file.path,
            controller: _controller,
            params: PdfViewerParams(
              backgroundColor: style.isDark
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFE6E6E6),
              pagePaintCallbacks: [
                (canvas, pageRect, page) => _searcher
                    ?.pageTextMatchPaintCallback(canvas, pageRect, page),
              ],
              onViewerReady: (_, controller) {
                _searcher ??= PdfTextSearcher(controller)
                  ..addListener(_changed);
                _changed();
              },
              onPageChanged: (_) => _changed(),
            ),
          ),
        ),
        ViewerBar(
          children: [
            AppIconButton(
              icon: icons.previous,
              tooltip: 'Previous page',
              onPressed: page > 1 ? () => _goTo(page - 1) : null,
            ),
            SizedBox(
              width: 84,
              child: Text(
                ready ? 'Page $page of $pages' : '…',
                style: style.caption,
                textAlign: TextAlign.center,
              ),
            ),
            AppIconButton(
              icon: icons.next,
              tooltip: 'Next page',
              onPressed: page < pages ? () => _goTo(page + 1) : null,
            ),
            const SizedBox(width: 12),
            AppIconButton(
              icon: icons.zoomOut,
              tooltip: 'Zoom out',
              onPressed: ready ? _controller.zoomDown : null,
            ),
            AppIconButton(
              icon: icons.zoomIn,
              tooltip: 'Zoom in',
              onPressed: ready ? _controller.zoomUp : null,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: AppTextField(
                controller: _query,
                placeholder: 'Find in document',
                prefixIcon: icons.search,
                onSubmitted: (text) => text.isEmpty
                    ? _searcher?.resetTextSearch()
                    : _searcher?.startTextSearch(text, caseInsensitive: true),
              ),
            ),
            if (_searcher case final searcher? when searcher.hasMatches) ...[
              const SizedBox(width: 6),
              Text(
                '${(searcher.currentIndex ?? 0) + 1}/${searcher.matches.length}',
                style: style.caption,
              ),
              AppIconButton(
                icon: icons.up,
                tooltip: 'Previous match',
                onPressed: searcher.goToPrevMatch,
              ),
              AppIconButton(
                icon: icons.chevron,
                tooltip: 'Next match',
                onPressed: searcher.goToNextMatch,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ---- audio and video ------------------------------------------------------

class MediaPane extends StatefulWidget {
  const MediaPane({super.key, required this.source, required this.video});

  final MediaSource source;
  final bool video;

  @override
  State<MediaPane> createState() => _MediaPaneState();
}

class _MediaPaneState extends State<MediaPane> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  final List<StreamSubscription<Object?>> _subs = [];
  static const _rates = [0.5, 1.0, 1.25, 1.5, 2.0];
  bool _fullscreen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    void rebuild(Object? _) {
      if (mounted) setState(() {});
    }

    _subs.addAll([
      _player.stream.position.listen(rebuild),
      _player.stream.duration.listen(rebuild),
      _player.stream.playing.listen(rebuild),
      _player.stream.volume.listen(rebuild),
      _player.stream.rate.listen(rebuild),
      _player.stream.error.listen((e) {
        if (mounted) setState(() => _error = e);
      }),
    ]);
    _player.open(Media(widget.source.uri, httpHeaders: widget.source.headers));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    if (_fullscreen) windowManager.setFullScreen(false);
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    await windowManager.setFullScreen(_fullscreen);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final icons = AppIcons.of(context);
    final style = AppStyle.of(context);
    final state = _player.state;
    final rate = state.rate;
    return Column(
      children: [
        Expanded(
          child: _error != null
              ? Center(
                  child: Text('Playback failed: $_error', style: style.caption),
                )
              : widget.video
              ? ColoredBox(
                  color: const Color(0xFF000000),
                  child: Video(controller: _video, controls: NoVideoControls),
                )
              : Center(
                  child: Icon(
                    icons.audio,
                    size: 96,
                    color: style.muted.withValues(alpha: 0.4),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SeekBar(
            position: state.position,
            duration: state.duration,
            onSeek: _player.seek,
          ),
        ),
        ViewerBar(
          children: [
            Text(
              '${formatDuration(state.position)} / '
              '${formatDuration(state.duration)}',
              style: style.caption,
            ),
            const SizedBox(width: 12),
            AppIconButton(
              icon: state.playing ? icons.pause : icons.play,
              tooltip: state.playing ? 'Pause' : 'Play',
              onPressed: _player.playOrPause,
            ),
            const SizedBox(width: 12),
            Icon(icons.volume, size: 14, color: style.muted),
            const SizedBox(width: 6),
            SizedBox(
              width: 90,
              child: SeekBar(
                position: Duration(milliseconds: state.volume.round()),
                duration: const Duration(milliseconds: 100),
                onSeek: (d) => _player.setVolume(d.inMilliseconds.toDouble()),
              ),
            ),
            const SizedBox(width: 12),
            AppButton(
              label: '${rate == rate.roundToDouble() ? rate.toInt() : rate}×',
              onPressed: () => _player.setRate(
                _rates[(_rates.indexOf(rate) + 1) % _rates.length],
              ),
            ),
            if (widget.video) ...[
              const SizedBox(width: 6),
              AppIconButton(
                icon: icons.fullscreen,
                tooltip: _fullscreen ? 'Exit full screen' : 'Full screen',
                onPressed: _toggleFullscreen,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
