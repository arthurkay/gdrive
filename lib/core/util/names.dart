import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

final _illegal = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
const _reserved = {
  'CON',
  'PRN',
  'AUX',
  'NUL',
  'COM1',
  'COM2',
  'COM3',
  'COM4',
  'COM5',
  'COM6',
  'COM7',
  'COM8',
  'COM9',
  'LPT1',
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
};

/// Turns a Drive name into one that is legal on Windows, macOS and Linux.
String sanitizeName(String name) {
  var out = name.replaceAll(_illegal, '_').trim();
  // Windows rejects trailing dots and spaces.
  out = out.replaceAll(RegExp(r'[. ]+$'), '');
  if (out.isEmpty || out == '.' || out == '..') return '_';
  if (_reserved.contains(p.basenameWithoutExtension(out).toUpperCase())) {
    out = '_$out';
  }
  return out;
}

/// `report.pdf` + 2 -> `report (2).pdf`.
String numberedName(String name, int n) {
  final ext = p.extension(name);
  return '${p.basenameWithoutExtension(name)} ($n)$ext';
}

/// `report.pdf` -> `report (conflicted copy 2026-11-17).pdf`.
String conflictName(String name, DateTime now) {
  final ext = p.extension(name);
  final date = DateFormat('yyyy-MM-dd').format(now);
  return '${p.basenameWithoutExtension(name)} (conflicted copy $date)$ext';
}

/// Files the sync engine never uploads: partial downloads and OS/editor noise.
bool isIgnoredLocalName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.part') ||
      lower.endsWith('.tmp') ||
      lower.endsWith('.swp') ||
      lower.startsWith('~\$') ||
      lower.startsWith('.~lock') ||
      lower == '.ds_store' ||
      lower == 'thumbs.db' ||
      lower == 'desktop.ini';
}

/// Sync paths are stored with forward slashes on every platform.
String toRelPath(String root, String absolute) =>
    p.split(p.relative(absolute, from: root)).join('/');

String toAbsPath(String root, String rel) =>
    p.joinAll([root, ...rel.split('/')]);

String relParent(String rel) {
  final i = rel.lastIndexOf('/');
  return i < 0 ? '' : rel.substring(0, i);
}

String relName(String rel) => rel.substring(rel.lastIndexOf('/') + 1);

String relJoin(String parent, String name) =>
    parent.isEmpty ? name : '$parent/$name';
