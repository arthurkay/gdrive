import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/ui/adaptive/app_icons.dart';
import '../../core/ui/adaptive/app_style.dart';
import '../../core/ui/adaptive/controls.dart';
import '../../core/util/format.dart';
import 'transfer_manager.dart';

/// Shared page frame: a title row with actions, then content.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: style.title.copyWith(fontSize: 17)),
                ),
                for (final action in actions) ...[
                  const SizedBox(width: 8),
                  action,
                ],
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class TransfersPage extends ConsumerWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppStyle.of(context);
    final transfers = ref.watch(transfersProvider).value ?? const <Transfer>[];
    final hasFinished = transfers.any(
      (t) => t.state != 'queued' && t.state != 'running',
    );
    return PageFrame(
      title: 'Transfers',
      actions: [
        AppButton(
          label: 'Clear finished',
          onPressed: hasFinished
              ? () => ref.read(databaseProvider).clearFinishedTransfers()
              : null,
        ),
      ],
      child: transfers.isEmpty
          ? Center(
              child: Text(
                'Uploads and downloads will appear here',
                style: style.caption,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              itemCount: transfers.length,
              itemBuilder: (context, i) => _TransferRow(transfers[i]),
            ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  const _TransferRow(this.transfer);

  final Transfer transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppStyle.of(context);
    final icons = AppIcons.of(context);
    final t = transfer;
    final active = t.state == 'queued' || t.state == 'running';
    final upload = t.direction == 'upload';
    final status = switch (t.state) {
      'queued' => 'Waiting',
      'running' =>
        '${formatBytes(t.doneBytes)} of ${formatBytes(t.totalBytes)}',
      'done' =>
        '${upload ? 'Uploaded' : 'Downloaded'} · '
            '${formatBytes(t.totalBytes)}',
      'cancelled' => 'Cancelled',
      _ => 'Failed: ${t.error ?? 'unknown error'}',
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: style.border)),
      ),
      child: Row(
        children: [
          Icon(
            upload ? icons.upload : icons.download,
            size: 16,
            color: style.muted,
            semanticLabel: upload ? 'Upload' : 'Download',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        t.name,
                        style: style.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (t.fromSync)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('sync', style: style.caption),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                if (t.state == 'running') ...[
                  AppProgressBar(
                    value: t.totalBytes > 0 ? t.doneBytes / t.totalBytes : null,
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  status,
                  style: style.caption.copyWith(
                    color: t.state == 'failed' ? style.danger : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (active)
            AppIconButton(
              icon: icons.close,
              tooltip: 'Cancel',
              onPressed: () => ref.read(transferManagerProvider).cancel(t.id),
            )
          else if (t.state == 'done')
            Icon(icons.synced, size: 15, color: style.success)
          else if (t.state == 'failed')
            Icon(icons.error, size: 15, color: style.danger),
        ],
      ),
    );
  }
}
