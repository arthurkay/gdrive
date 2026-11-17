import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/adaptive/controls.dart';
import 'sync_controller.dart';

/// Appears when sync needs the user: a large deletion to approve, or an
/// error that stopped the last pass.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncProvider);
    final sync = ref.read(syncProvider.notifier);
    final banner = switch (status.phase) {
      SyncPhase.needsConfirmation => AppBanner(
        kind: BannerKind.warning,
        message:
            'Sync is about to remove ${status.pendingDeletes} files that were '
            'deleted on the other side. Nothing has been removed yet.',
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Pause sync',
              onPressed: () => sync.setPaused(true),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'Remove them',
              primary: true,
              onPressed: sync.confirmDeletes,
            ),
          ],
        ),
      ),
      SyncPhase.error => AppBanner(
        kind: BannerKind.error,
        message: 'Sync stopped: ${status.message}',
        action: AppButton(label: 'Try again', onPressed: sync.syncNow),
      ),
      _ => null,
    };
    if (banner == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: banner,
    );
  }
}
