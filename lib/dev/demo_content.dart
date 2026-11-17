import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Sample pictures and documents for the demo Drive, generated in code so
/// the repository carries no binary fixtures.

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c.isOdd ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// Encodes a truecolour PNG. [pixel] returns 0xRRGGBB for each position.
Uint8List encodePng(int width, int height, int Function(int x, int y) pixel) {
  final raw = Uint8List(height * (width * 3 + 1));
  var i = 0;
  for (var y = 0; y < height; y++) {
    raw[i++] = 0; // filter: none
    for (var x = 0; x < width; x++) {
      final c = pixel(x, y);
      raw[i++] = (c >> 16) & 0xFF;
      raw[i++] = (c >> 8) & 0xFF;
      raw[i++] = c & 0xFF;
    }
  }

  final out = BytesBuilder();
  void chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    out.add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List());
    out.add(body);
    out.add((ByteData(4)..setUint32(0, _crc32(body))).buffer.asUint8List());
  }

  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  chunk(
    'IHDR',
    (ByteData(13)
          ..setUint32(0, width)
          ..setUint32(4, height)
          ..setUint8(8, 8) // bit depth
          ..setUint8(9, 2)) // colour type: RGB
        .buffer
        .asUint8List(),
  );
  chunk('IDAT', ZLibEncoder().convert(raw));
  chunk('IEND', const []);
  return out.toBytes();
}

int _mix(int a, int b, double t) {
  final u = t.clamp(0.0, 1.0);
  int channel(int shift) {
    final x = (a >> shift) & 0xFF, y = (b >> shift) & 0xFF;
    return (x + (y - x) * u).round();
  }

  return channel(16) << 16 | channel(8) << 8 | channel(0);
}

/// A simple landscape: gradient sky, optional sun, and layered hills.
Uint8List landscape({
  required int skyTop,
  required int skyBottom,
  required List<int> hills,
  int? sun,
  double sunX = 0.7,
  double sunY = 0.42,
  int width = 960,
  int height = 600,
}) => encodePng(width, height, (x, y) {
  final u = x / width, v = y / height;
  var colour = _mix(skyTop, skyBottom, v * 1.25);
  if (sun != null) {
    final d = math.sqrt(
      math.pow((u - sunX) * width / height, 2) + math.pow(v - sunY, 2),
    );
    if (d < 0.11) {
      colour = sun;
    } else if (d < 0.3) {
      colour = _mix(sun, colour, (d - 0.11) / 0.19 + 0.35);
    }
  }
  for (var layer = 0; layer < hills.length; layer++) {
    final base = 0.52 + layer * 0.13;
    final ridge =
        base +
        0.07 * math.sin(u * (5 + layer * 3) + layer * 1.7) +
        0.03 * math.sin(u * (17 + layer * 5) + layer);
    if (v > ridge) colour = hills[layer];
  }
  return colour;
});

/// Named sample pictures.
final Map<String, Uint8List> demoPictures = {
  'Sunset over the hills.png': landscape(
    skyTop: 0x4B2A7B,
    skyBottom: 0xFFA552,
    sun: 0xFFE9A8,
    hills: const [0x7A3B69, 0x4A2552, 0x241536],
  ),
  'Morning lake.png': landscape(
    skyTop: 0x6EC6F5,
    skyBottom: 0xE8F6FF,
    sun: 0xFFFBE0,
    sunX: 0.28,
    sunY: 0.3,
    hills: const [0x7FB3A6, 0x3F8F8C, 0x1E5F74],
  ),
  'Forest ridge.png': landscape(
    skyTop: 0xBFE3C0,
    skyBottom: 0xF4F9E9,
    hills: const [0x8CBF88, 0x4E9A5B, 0x2F6B3F, 0x173F27],
  ),
  'Desert dunes.png': landscape(
    skyTop: 0x2F80ED,
    skyBottom: 0xF9E7C2,
    sun: 0xFFFFFF,
    sunX: 0.8,
    sunY: 0.22,
    hills: const [0xE9B872, 0xD9954B, 0xB46A2E],
  ),
  'Northern night.png': landscape(
    skyTop: 0x06122B,
    skyBottom: 0x1F6F78,
    sun: 0xD8F3DC,
    sunX: 0.5,
    sunY: 0.3,
    hills: const [0x12343B, 0x0B2027, 0x050D12],
  ),
  'Coral coast.png': landscape(
    skyTop: 0xFF7E79,
    skyBottom: 0xFFD3B5,
    sun: 0xFFF1D0,
    sunX: 0.5,
    sunY: 0.48,
    hills: const [0x2BB3C0, 0x168AAD, 0x0B5C7A],
  ),
};

/// Builds a one-page PDF with a heading and body lines, with a correct
/// cross-reference table so strict readers accept it.
Uint8List buildPdf(String heading, List<String> lines) {
  String escape(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  final content = StringBuffer()
    ..writeln('BT /F2 26 Tf 72 720 Td (${escape(heading)}) Tj ET')
    ..writeln('0.15 0.39 0.92 rg 72 704 468 3 re f 0 g');
  var y = 670;
  for (final line in lines) {
    content.writeln('BT /F1 12 Tf 72 $y Td (${escape(line)}) Tj ET');
    y -= 20;
  }
  final stream = content.toString();

  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R '
        '/Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>',
    '<< /Length ${stream.length} >>\nstream\n${stream}endstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
  ];

  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets) {
    out.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return latin1.encode(out.toString());
}

const demoCode = '''
import 'dart:io';

/// Counts the words in every text file under a folder.
Future<void> main(List<String> args) async {
  final root = Directory(args.isEmpty ? '.' : args.first);
  final totals = <String, int>{};

  await for (final entity in root.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.txt')) continue;
    final words = (await entity.readAsString())
        .split(RegExp(r'\\s+'))
        .where((word) => word.isNotEmpty);
    totals[entity.path] = words.length;
  }

  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in sorted.take(10)) {
    print('\${entry.value.toString().padLeft(6)}  \${entry.key}');
  }
}
''';

const demoNotes = '''
# Team notes

## This week
- Finish the sync engine review
- Try the Windows and macOS builds
- Write up the release checklist

## Ideas
- Selective sync per file type
- Bandwidth limits while on battery

## Links
See the project plan in Documents for dates.
''';

const demoReportLines = [
  'Summary',
  '',
  'Storage use grew 12% this quarter, driven mostly by shared project folders.',
  'Sync reliability held at 99.9% across all three desktop platforms.',
  '',
  'Highlights',
  '',
  '  - Two-way sync now covers single files, folders, or the whole Drive.',
  '  - Conflicts keep both versions; nothing is deleted permanently.',
  '  - Built-in viewers for PDF, images, audio, video and text.',
  '',
  'Next quarter',
  '',
  '  - System tray support and resumable uploads.',
  '  - Multiple accounts.',
];
