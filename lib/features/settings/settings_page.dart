import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/system.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import '../../core/ui/adaptive/dialogs.dart';
import '../../core/ui/notice.dart';
import '../../core/util/format.dart';
import '../auth/auth_controller.dart';
import '../preview/preview_service.dart';
import '../sync/sync_controller.dart';
import '../transfers/transfers_page.dart';
import 'settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppStyle.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final account = ref.watch(accountProvider);
    final notice = ref.read(noticeProvider.notifier);

    Widget section(String title, List<Widget> rows) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: style.strong),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );

    Widget row(String label, String detail, Widget control) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style.body),
                if (detail.isNotEmpty) Text(detail, style: style.caption),
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );

    Widget choices<T>(
      List<T> values,
      T current,
      String Function(T) label,
      ValueChanged<T> onChanged,
    ) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: AppButton(
              label: label(value),
              primary: value == current,
              onPressed: () => onChanged(value),
            ),
          ),
      ],
    );

    final usage = account.limitBytes == null
        ? '${formatBytes(account.usageBytes)} used'
        : '${formatBytes(account.usageBytes)} of '
              '${formatBytes(account.limitBytes)} used';

    return PageFrame(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        children: [
          section('Account', [
            row(
              account.displayName.isEmpty ? account.email : account.displayName,
              '${account.email} · $usage',
              AppButton(
                label: 'Sign out',
                onPressed: () async {
                  final confirmed = await showConfirm(
                    context,
                    title: 'Sign out?',
                    message:
                        'Syncing stops and this computer forgets the account. '
                        'Files already in your sync folder stay where they '
                        'are.',
                    confirmLabel: 'Sign out',
                  );
                  if (confirmed) {
                    await ref.read(authProvider.notifier).signOut();
                  }
                },
              ),
            ),
          ]),
          section('Sync', [
            row(
              'Sync folder',
              settings.syncRoot,
              AppButton(
                label: 'Change…',
                onPressed: () async {
                  final path = await ref
                      .read(filePickerProvider)
                      .pickDirectory();
                  if (path == null || path == settings.syncRoot) return;
                  await controller.setSyncRoot(path);
                  notice.show(
                    'Sync folder changed. Existing files were not moved.',
                  );
                },
              ),
            ),
            row(
              'Pause syncing',
              'Nothing is uploaded or downloaded while paused',
              AppSwitch(
                value: settings.paused,
                onChanged: ref.read(syncProvider.notifier).setPaused,
              ),
            ),
            row(
              'Check Drive for changes',
              'How often to ask Google Drive what changed',
              choices<int>(
                const [15, 30, 60, 300],
                settings.pollSeconds,
                (s) => s < 60 ? '${s}s' : '${s ~/ 60} min',
                controller.setPollSeconds,
              ),
            ),
            row(
              'Simultaneous transfers',
              'More is faster on a good connection',
              choices<int>(
                const [1, 3, 5, 8],
                settings.concurrency,
                (n) => '$n',
                controller.setConcurrency,
              ),
            ),
          ]),
          section('Appearance', [
            row(
              'Theme',
              '',
              choices<ThemePreference>(
                ThemePreference.values,
                settings.theme,
                (t) => switch (t) {
                  ThemePreference.system => 'System',
                  ThemePreference.light => 'Light',
                  ThemePreference.dark => 'Dark',
                },
                controller.setTheme,
              ),
            ),
          ]),
          section('Storage', [
            row(
              'Preview cache',
              'Files downloaded only to preview them',
              AppButton(
                label: 'Clear',
                onPressed: () async {
                  await ref.read(previewServiceProvider).clearCache();
                  notice.show('Preview cache cleared');
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
