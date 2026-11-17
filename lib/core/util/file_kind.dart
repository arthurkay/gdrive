import 'package:path/path.dart' as p;

import '../db/database.dart';

/// How the app treats a file: which icon it gets and which viewer opens it.
enum FileKind { folder, image, video, audio, pdf, text, googleDoc, other }

const _googleAppsPrefix = 'application/vnd.google-apps.';

/// Google-native types and the Office format each is exported to on disk.
const nativeExports = <String, ({String mimeType, String extension})>{
  'application/vnd.google-apps.document': (
    mimeType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    extension: '.docx',
  ),
  'application/vnd.google-apps.spreadsheet': (
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    extension: '.xlsx',
  ),
  'application/vnd.google-apps.presentation': (
    mimeType:
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    extension: '.pptx',
  ),
  'application/vnd.google-apps.drawing': (
    mimeType: 'application/pdf',
    extension: '.pdf',
  ),
};

const _textExtensions = {
  '.txt',
  '.md',
  '.markdown',
  '.json',
  '.yaml',
  '.yml',
  '.xml',
  '.html',
  '.htm',
  '.css',
  '.js',
  '.ts',
  '.dart',
  '.py',
  '.java',
  '.kt',
  '.c',
  '.h',
  '.cpp',
  '.hpp',
  '.cs',
  '.go',
  '.rs',
  '.rb',
  '.php',
  '.sh',
  '.bash',
  '.zsh',
  '.sql',
  '.csv',
  '.tsv',
  '.log',
  '.ini',
  '.conf',
  '.cfg',
  '.toml',
  '.env',
  '.gradle',
  '.properties',
  '.tex',
  '.swift',
  '.lua',
  '.r',
  '.bat',
  '.ps1',
};

const _textMimeTypes = {
  'application/json',
  'application/xml',
  'application/javascript',
  'application/x-sh',
  'application/x-yaml',
  'application/sql',
};

extension DriveItemKind on DriveItem {
  bool get isFolder => mimeType == folderMimeType;

  /// Docs, Sheets, Slides and Drawings: no bytes on Drive, exported on demand.
  bool get isNative => nativeExports.containsKey(mimeType);

  /// Google-apps types with no export (Forms, Sites, shortcuts, Maps).
  bool get isUnsyncable =>
      mimeType.startsWith(_googleAppsPrefix) && !isFolder && !isNative;

  FileKind get kind => fileKindOf(mimeType, name);
}

FileKind fileKindOf(String mimeType, String name) {
  if (mimeType == folderMimeType) return FileKind.folder;
  if (mimeType.startsWith(_googleAppsPrefix)) {
    return nativeExports.containsKey(mimeType)
        ? FileKind.googleDoc
        : FileKind.other;
  }
  final ext = p.extension(name).toLowerCase();
  if (mimeType == 'application/pdf' || ext == '.pdf') return FileKind.pdf;
  if (mimeType.startsWith('image/')) return FileKind.image;
  if (mimeType.startsWith('video/')) return FileKind.video;
  if (mimeType.startsWith('audio/')) return FileKind.audio;
  if (mimeType.startsWith('text/') ||
      _textMimeTypes.contains(mimeType) ||
      _textExtensions.contains(ext)) {
    return FileKind.text;
  }
  return FileKind.other;
}

/// Language id understood by the code viewer, or null for plain text.
String? highlightLanguageOf(String name) => const {
  '.json': 'json',
  '.yaml': 'yaml',
  '.yml': 'yaml',
  '.xml': 'xml',
  '.html': 'xml',
  '.htm': 'xml',
  '.css': 'css',
  '.js': 'javascript',
  '.ts': 'typescript',
  '.dart': 'dart',
  '.py': 'python',
  '.java': 'java',
  '.kt': 'kotlin',
  '.c': 'c',
  '.h': 'c',
  '.cpp': 'cpp',
  '.hpp': 'cpp',
  '.cs': 'csharp',
  '.go': 'go',
  '.rs': 'rust',
  '.rb': 'ruby',
  '.php': 'php',
  '.sh': 'bash',
  '.bash': 'bash',
  '.zsh': 'bash',
  '.sql': 'sql',
  '.md': 'markdown',
  '.markdown': 'markdown',
  '.swift': 'swift',
  '.lua': 'lua',
  '.ini': 'ini',
  '.toml': 'ini',
}[p.extension(name).toLowerCase()];
