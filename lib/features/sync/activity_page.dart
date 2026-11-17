import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/ui/adaptive/app_icons.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import '../transfers/transfers_page.dart';
import 'sync_banner.dart';
import 'sync_controller.dart';

/// What sync has done, newest first, with the controls to run or pause it.
class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);
    final status = ref.watch(syncProvider);
    final events = ref.watch(activityProvider).value ?? const <ActivityEvent>[];
    final sync = ref.read(syncProvider.notifier);
    final paused = status.phase == SyncPhase.paused;

    return PageFrame(
      title: 'Sync activity',
      actions: [
        AppButton(
          label: paused ? 'Resume sync' : 'Pause sync',
          icon: paused ? icons.play : icons.pause,
          onPressed: () => sync.setPaused(!paused),
        ),
        AppButton(
          label: 'Sync now',
          icon: icons.sync,
          primary: true,
          onPressed: paused || status.phase == SyncPhase.syncing
              ? null
              : sync.syncNow,
        ),
        AppButton(
          label: 'Clear',
          onPressed: events.isEmpty
              ? null
              : () => ref.read(databaseProvider).clearActivity(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
            child: Text(syncSummary(status), style: style.caption),
          ),
          const SyncBanner(),
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Text(
                      'Choose "Sync to this computer" on a file or folder '
                      'to start',
                      style: style.caption,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
                    itemCount: events.length,
                    itemBuilder: (context, i) {
                      final e = events[i];
                      final (icon, color) = switch (e.kind) {
                        'download' => (icons.download, style.muted),
                        'upload' => (icons.upload, style.muted),
                        'delete' => (icons.trash, style.muted),
                        'conflict' => (icons.warning, style.warning),
                        'error' => (icons.error, style.danger),
                        _ => (icons.info, style.muted),
                      };
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 14, color: color),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e.message, style: style.body)),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('d MMM HH:mm').format(e.at.toLocal()),
                              style: style.caption,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// One-line description of where sync stands.
String syncSummary(SyncStatus status) {
  final last = status.lastSync == null
      ? ''
      : ' · last synced ${DateFormat.Hm().format(status.lastSync!.toLocal())}';
  return switch (status.phase) {
    SyncPhase.syncing => 'Syncing…',
    SyncPhase.paused => 'Sync is paused',
    SyncPhase.needsConfirmation => 'Waiting for your confirmation',
    SyncPhase.error => 'Sync stopped with an error',
    SyncPhase.idle => '${status.message ?? 'Ready'}$last',
  };
}
