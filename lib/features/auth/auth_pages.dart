import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/adaptive/app_icons.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import '../../core/ui/app_logo.dart';
import 'auth_controller.dart';

class _Centered extends StatelessWidget {
  const _Centered({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    return AppSurface(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 84),
                const SizedBox(height: 16),
                Text('GDrive', style: style.title),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the app was built without an OAuth client.
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    return _Centered(
      children: [
        Text(
          'Google sign-in is not set up yet',
          style: style.strong,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          '1. In Google Cloud Console, enable the Google Drive API and create '
          'an OAuth client of type "Desktop app".\n'
          '2. Copy config/oauth.example.json to config/oauth.json and paste in '
          'the client ID and secret.\n'
          '3. Run the app with --dart-define-from-file=config/oauth.json',
          style: style.body.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key, this.error, this.busy = false});

  final String? error;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppStyle.of(context);
    return _Centered(
      children: [
        Text(
          'Browse, preview and sync your Google Drive on this computer.',
          style: style.body.copyWith(color: style.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (busy) ...[
          const AppSpinner(size: 24),
          const SizedBox(height: 12),
          Text('Finish signing in from your browser…', style: style.caption),
        ] else
          AppButton(
            label: 'Sign in with Google',
            primary: true,
            icon: AppIcons.of(context).account,
            onPressed: () => ref.read(authProvider.notifier).signIn(),
          ),
        if (error != null && !busy) ...[
          const SizedBox(height: 20),
          AppBanner(message: error!, kind: BannerKind.error),
        ],
      ],
    );
  }
}
