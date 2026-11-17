import 'package:flutter/widgets.dart';

/// The GDrive mark. Regenerate the image with `python3 tool/make_logo.py`.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 24});

  static const asset = 'assets/logo_256.png';

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'GDrive',
  );
}
