import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/adaptive/app_icons.dart';
import '../core/ui/adaptive/app_style.dart';
import '../core/ui/notice.dart';
import '../features/auth/auth_controller.dart';
import '../features/drive/browser_controller.dart';
import '../features/drive/browser_page.dart';
import '../features/settings/settings_page.dart';
import '../features/sync/activity_page.dart';
import '../features/sync/sync_controller.dart';
import '../features/transfers/transfer_manager.dart';
import '../features/transfers/transfers_page.dart';

/// Everything reachable from the sidebar, in order. The first five are the
/// Drive sections; the rest are app pages.
enum Destination {
  myDrive('My Drive'),
  shared('Shared with me'),
  recent('Recent'),
  starred('Starred'),
  trash('Trash'),
  transfers('Transfers'),
  activity('Sync activity'),
  settings('Settings');

  const Destination(this.label);
  final String label;

  DriveSection? get section =>
      index < DriveSection.values.length ? DriveSection.values[index] : null;

  /// App pages sit apart from the Drive sections in each sidebar.
  bool get isFooter => section == null;

  IconData icon(AppIcons icons) => switch (this) {
    Destination.myDrive => icons.myDrive,
    Destination.shared => icons.shared,
    Destination.recent => icons.recent,
    Destination.starred => icons.starred,
    Destination.trash => icons.trash,
    Destination.transfers => icons.transfers,
    Destination.activity => icons.activity,
    Destination.settings => icons.settings,
  };
}

class NavController extends Notifier<Destination> {
  @override
  Destination build() => Destination.myDrive;

  void go(Destination destination) {
    final section = destination.section;
    if (section != null) {
      ref.read(browserProvider.notifier).openSection(section);
    }
    state = destination;
  }
}

final navProvider = NotifierProvider<NavController, Destination>(
  NavController.new,
);

/// Count of uploads and downloads in flight, for the sidebar badge.
final activeTransfersProvider = Provider<int>(
  (ref) => (ref.watch(transfersProvider).value ?? const [])
      .where((t) => t.state == 'queued' || t.state == 'running')
      .length,
);

/// The page for [destination], with the status bar and notices that every
/// shell shares.
class DestinationBody extends StatelessWidget {
  const DestinationBody(this.destination, {super.key});

  final Destination destination;

  @override
  Widget build(BuildContext context) => NoticeHost(
    child: Column(
      children: [
        Expanded(
          child: switch (destination) {
            Destination.transfers => const TransfersPage(),
            Destination.activity => const ActivityPage(),
            Destination.settings => const SettingsPage(),
            _ => const BrowserPage(),
          },
        ),
        const StatusBar(),
      ],
    ),
  );
}

/// Bottom strip: sync state on the left, signed-in account on the right.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);
    final status = ref.watch(syncProvider);
    final active = ref.watch(activeTransfersProvider);
    final account = ref.watch(accountProvider);
    final (icon, color) = switch (status.phase) {
      SyncPhase.syncing => (icons.sync, style.accent),
      SyncPhase.paused => (icons.pause, style.muted),
      SyncPhase.needsConfirmation => (icons.warning, style.warning),
      SyncPhase.error => (icons.error, style.danger),
      SyncPhase.idle => (icons.synced, style.success),
    };
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: style.surface,
        border: Border(top: BorderSide(color: style.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              active > 0
                  ? '${syncSummary(status)} · $active '
                        '${active == 1 ? 'transfer' : 'transfers'} in progress'
                  : syncSummary(status),
              style: style.caption.copyWith(decoration: TextDecoration.none),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            account.email,
            style: style.caption.copyWith(decoration: TextDecoration.none),
          ),
        ],
      ),
    );
  }
}
