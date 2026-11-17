import 'package:fluent_ui/fluent_ui.dart' as f;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as md;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart' as m;
import 'package:yaru/yaru.dart' as y;

import '../core/platform/ui_kit.dart';
import '../core/ui/adaptive/app_icons.dart';
import '../core/ui/app_logo.dart';
import '../features/drive/browser_controller.dart';
import '../features/sync/sync_controller.dart';
import 'destinations.dart';

/// The signed-in window: a sidebar in the active kit's idiom around the
/// shared pages.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (Kit.of(context)) {
        UiKit.fluent => const FluentShell(),
        UiKit.macos => const MacosShell(),
        UiKit.yaru => const YaruShell(),
      };
}

Widget _badge(int count) => Text('$count');

/// Logo and name at the top of each sidebar.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      AppLogo(size: 22),
      SizedBox(width: 10),
      Text('GDrive', style: TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}

class FluentShell extends ConsumerWidget {
  const FluentShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(navProvider);
    final active = ref.watch(activeTransfersProvider);
    final icons = AppIcons.of(context);

    f.PaneItem item(Destination d) => f.PaneItem(
      icon: Icon(d.icon(icons)),
      title: Text(d.label),
      body: const SizedBox.shrink(),
      infoBadge: d == Destination.transfers && active > 0
          ? f.InfoBadge(source: _badge(active))
          : null,
    );

    return f.NavigationView(
      pane: f.NavigationPane(
        selected: current.index,
        onChanged: (i) =>
            ref.read(navProvider.notifier).go(Destination.values[i]),
        displayMode: f.PaneDisplayMode.auto,
        header: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: _Brand(),
        ),
        items: [
          for (final d in Destination.values)
            if (!d.isFooter) item(d),
        ],
        footerItems: [
          for (final d in Destination.values)
            if (d.isFooter) item(d),
        ],
      ),
      paneBodyBuilder: (_, _) => DestinationBody(current),
    );
  }
}

class MacosShell extends ConsumerWidget {
  const MacosShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(navProvider);
    final active = ref.watch(activeTransfersProvider);
    final icons = AppIcons.of(context);
    final nav = ref.read(navProvider.notifier);

    // Off macOS (only reachable with the UI_KIT override) there is no native
    // vibrancy behind the sidebar, so it gets a solid colour instead.
    final onMac = defaultTargetPlatform == TargetPlatform.macOS;
    final dark = m.MacosTheme.brightnessOf(context) == Brightness.dark;
    final window = m.MacosWindow(
      sidebar: m.Sidebar(
        decoration: onMac
            ? null
            : BoxDecoration(
                color: dark ? const Color(0xFF2A2A2C) : const Color(0xFFE8E8ED),
              ),
        minWidth: 210,
        top: const Padding(
          padding: EdgeInsets.only(left: 6, bottom: 6),
          child: _Brand(),
        ),
        builder: (context, scrollController) => m.SidebarItems(
          scrollController: scrollController,
          currentIndex: current.index,
          onChanged: (i) => nav.go(Destination.values[i]),
          items: [
            for (final d in Destination.values)
              m.SidebarItem(
                leading: m.MacosIcon(d.icon(icons)),
                label: Text(d.label),
                trailing: d == Destination.transfers && active > 0
                    ? _badge(active)
                    : null,
              ),
          ],
        ),
      ),
      child: DestinationBody(current),
    );

    if (!onMac) return window;
    final browser = ref.read(browserProvider.notifier);
    final sync = ref.read(syncProvider.notifier);
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'GDrive',
          menus: [
            PlatformMenuItem(
              label: 'Settings…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ),
              onSelected: () => nav.go(Destination.settings),
            ),
            if (PlatformProvidedMenuItem.hasMenu(
              PlatformProvidedMenuItemType.quit,
            ))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.quit,
              ),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: 'Refresh',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyR,
                meta: true,
              ),
              onSelected: browser.refresh,
            ),
            for (final d in Destination.values)
              PlatformMenuItem(label: d.label, onSelected: () => nav.go(d)),
          ],
        ),
        PlatformMenu(
          label: 'Sync',
          menus: [
            PlatformMenuItem(label: 'Sync Now', onSelected: sync.syncNow),
            PlatformMenuItem(
              label: 'Pause Syncing',
              onSelected: () => sync.setPaused(true),
            ),
            PlatformMenuItem(
              label: 'Resume Syncing',
              onSelected: () => sync.setPaused(false),
            ),
          ],
        ),
      ],
      child: window,
    );
  }
}

class YaruShell extends ConsumerWidget {
  const YaruShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(navProvider);
    final active = ref.watch(activeTransfersProvider);
    final icons = AppIcons.of(context);
    final nav = ref.read(navProvider.notifier);
    final theme = md.Theme.of(context);

    Widget tile(Destination d) => y.YaruMasterTile(
      selected: d == current,
      leading: Icon(d.icon(icons)),
      title: Text(d.label),
      trailing: d == Destination.transfers && active > 0
          ? _badge(active)
          : null,
      onTap: () => nav.go(d),
    );

    return md.Scaffold(
      body: Row(
        children: [
          Container(
            width: 232,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(right: BorderSide(color: theme.dividerColor)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: _Brand(),
                ),
                for (final d in Destination.values)
                  if (!d.isFooter) tile(d),
                const Spacer(),
                const md.Divider(height: 12),
                for (final d in Destination.values)
                  if (d.isFooter) tile(d),
              ],
            ),
          ),
          Expanded(child: DestinationBody(current)),
        ],
      ),
    );
  }
}
