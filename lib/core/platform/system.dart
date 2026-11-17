// coverage:ignore-file
// One-line wrappers over the file_selector and url_launcher plugins, which
// need a real desktop. Tests replace both providers with fakes.
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Native open/save dialogs. Faked in widget tests.
class FilePicker {
  const FilePicker();

  Future<List<String>> pickFiles() async =>
      (await fs.openFiles()).map((f) => f.path).toList();

  Future<String?> pickDirectory({String? title}) =>
      fs.getDirectoryPath(confirmButtonText: title);
}

final filePickerProvider = Provider<FilePicker>((ref) => const FilePicker());

/// Opens a web page or a local file with the system's default app.
final launcherProvider = Provider<Future<void> Function(Uri uri)>(
  (ref) => (uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  },
);
