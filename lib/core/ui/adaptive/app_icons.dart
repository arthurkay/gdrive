import 'package:fluent_ui/fluent_ui.dart' show FluentIcons;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:yaru/yaru.dart' show YaruIcons;

import '../../platform/ui_kit.dart';
import '../../util/file_kind.dart';

/// Icons by meaning, drawn from each kit's own icon set.
class AppIcons {
  const AppIcons._(this._kit);

  factory AppIcons.of(BuildContext context) => AppIcons._(Kit.of(context));

  final UiKit _kit;

  IconData _pick(IconData fluent, IconData macos, IconData yaru) =>
      switch (_kit) {
        UiKit.fluent => fluent,
        UiKit.macos => macos,
        UiKit.yaru => yaru,
      };

  IconData get folder => _pick(
    FluentIcons.fabric_folder_fill,
    CupertinoIcons.folder_fill,
    YaruIcons.folder_filled,
  );
  IconData get file =>
      _pick(FluentIcons.page, CupertinoIcons.doc, YaruIcons.document);
  IconData get image =>
      _pick(FluentIcons.photo2, CupertinoIcons.photo, YaruIcons.image);
  IconData get video =>
      _pick(FluentIcons.video, CupertinoIcons.film, YaruIcons.video);
  IconData get audio => _pick(
    FluentIcons.music_note,
    CupertinoIcons.music_note,
    YaruIcons.music_note,
  );
  IconData get pdf => _pick(
    FluentIcons.pdf,
    CupertinoIcons.doc_richtext,
    YaruIcons.document_template,
  );
  IconData get text => _pick(
    FluentIcons.text_document,
    CupertinoIcons.doc_text,
    YaruIcons.text_editor,
  );
  IconData get googleDoc => _pick(
    FluentIcons.document,
    CupertinoIcons.doc_text_fill,
    YaruIcons.office,
  );

  IconData get myDrive =>
      _pick(FluentIcons.cloud, CupertinoIcons.cloud, YaruIcons.cloud);
  IconData get shared =>
      _pick(FluentIcons.people, CupertinoIcons.person_2, YaruIcons.users);
  IconData get recent =>
      _pick(FluentIcons.recent, CupertinoIcons.clock, YaruIcons.clock);
  IconData get starred => _pick(
    FluentIcons.favorite_star_fill,
    CupertinoIcons.star_fill,
    YaruIcons.star_filled,
  );
  IconData get star =>
      _pick(FluentIcons.favorite_star, CupertinoIcons.star, YaruIcons.star);
  IconData get trash =>
      _pick(FluentIcons.delete, CupertinoIcons.trash, YaruIcons.trash);
  IconData get transfers => _pick(
    FluentIcons.cloud_upload,
    CupertinoIcons.arrow_up_arrow_down,
    YaruIcons.send_receive,
  );
  IconData get activity =>
      _pick(FluentIcons.history, CupertinoIcons.list_bullet, YaruIcons.history);
  IconData get settings =>
      _pick(FluentIcons.settings, CupertinoIcons.gear, YaruIcons.gear);

  IconData get upload =>
      _pick(FluentIcons.upload, CupertinoIcons.cloud_upload, YaruIcons.share);
  IconData get download => _pick(
    FluentIcons.download,
    CupertinoIcons.cloud_download,
    YaruIcons.download,
  );
  IconData get newFolder => _pick(
    FluentIcons.new_folder,
    CupertinoIcons.folder_badge_plus,
    YaruIcons.folder_new,
  );
  IconData get refresh =>
      _pick(FluentIcons.refresh, CupertinoIcons.refresh, YaruIcons.refresh);
  IconData get search =>
      _pick(FluentIcons.search, CupertinoIcons.search, YaruIcons.search);
  IconData get grid => _pick(
    FluentIcons.grid_view_medium,
    CupertinoIcons.square_grid_2x2,
    YaruIcons.app_grid,
  );
  IconData get list => _pick(
    FluentIcons.list,
    CupertinoIcons.list_bullet,
    YaruIcons.unordered_list,
  );
  IconData get back => _pick(
    FluentIcons.back,
    CupertinoIcons.chevron_back,
    YaruIcons.go_previous,
  );
  IconData get chevron => _pick(
    FluentIcons.chevron_right,
    CupertinoIcons.chevron_forward,
    YaruIcons.go_next,
  );
  IconData get up =>
      _pick(FluentIcons.up, CupertinoIcons.arrow_up, YaruIcons.go_up);
  IconData get more =>
      _pick(FluentIcons.more, CupertinoIcons.ellipsis, YaruIcons.view_more);
  IconData get sync => _pick(
    FluentIcons.sync,
    CupertinoIcons.arrow_2_circlepath,
    YaruIcons.sync,
  );
  IconData get synced => _pick(
    FluentIcons.completed_solid,
    CupertinoIcons.checkmark_circle_fill,
    YaruIcons.ok_filled,
  );
  IconData get warning => _pick(
    FluentIcons.warning,
    CupertinoIcons.exclamationmark_triangle,
    YaruIcons.warning,
  );
  IconData get error =>
      _pick(FluentIcons.error, CupertinoIcons.xmark_circle, YaruIcons.error);
  IconData get pause =>
      _pick(FluentIcons.pause, CupertinoIcons.pause, YaruIcons.media_pause);
  IconData get play =>
      _pick(FluentIcons.play, CupertinoIcons.play, YaruIcons.media_play);
  IconData get close =>
      _pick(FluentIcons.clear, CupertinoIcons.xmark, YaruIcons.window_close);
  IconData get rename =>
      _pick(FluentIcons.rename, CupertinoIcons.pencil, YaruIcons.pen);
  IconData get move => _pick(
    FluentIcons.move_to_folder,
    CupertinoIcons.folder,
    YaruIcons.folder_open,
  );
  IconData get copy =>
      _pick(FluentIcons.copy, CupertinoIcons.doc_on_doc, YaruIcons.copy);
  IconData get restore =>
      _pick(FluentIcons.undo, CupertinoIcons.arrow_uturn_left, YaruIcons.undo);
  IconData get openExternal => _pick(
    FluentIcons.open_in_new_window,
    CupertinoIcons.arrow_up_right_square,
    YaruIcons.external_link,
  );
  IconData get info =>
      _pick(FluentIcons.info, CupertinoIcons.info, YaruIcons.information);
  IconData get zoomIn =>
      _pick(FluentIcons.add, CupertinoIcons.zoom_in, YaruIcons.zoom_in);
  IconData get zoomOut =>
      _pick(FluentIcons.remove, CupertinoIcons.zoom_out, YaruIcons.zoom_out);
  IconData get rotate => _pick(
    FluentIcons.rotate,
    CupertinoIcons.rotate_right,
    YaruIcons.rotate_right,
  );
  IconData get save =>
      _pick(FluentIcons.save, CupertinoIcons.floppy_disk, YaruIcons.save);
  IconData get account => _pick(
    FluentIcons.contact,
    CupertinoIcons.person_crop_circle,
    YaruIcons.user,
  );
  IconData get volume => _pick(
    FluentIcons.volume3,
    CupertinoIcons.volume_up,
    YaruIcons.speaker_high,
  );
  IconData get fullscreen => _pick(
    FluentIcons.full_screen,
    CupertinoIcons.fullscreen,
    YaruIcons.fullscreen,
  );
  IconData get next => _pick(
    FluentIcons.next,
    CupertinoIcons.forward_end,
    YaruIcons.skip_forward,
  );
  IconData get previous => _pick(
    FluentIcons.previous,
    CupertinoIcons.backward_end,
    YaruIcons.skip_backward,
  );

  IconData forKind(FileKind kind) => switch (kind) {
    FileKind.folder => folder,
    FileKind.image => image,
    FileKind.video => video,
    FileKind.audio => audio,
    FileKind.pdf => pdf,
    FileKind.text => text,
    FileKind.googleDoc => googleDoc,
    FileKind.other => file,
  };
}
