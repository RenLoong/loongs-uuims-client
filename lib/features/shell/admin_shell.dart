import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/settings_dialog.dart';
import '../../core/i18n.dart';

/// Map menu icon name to Lucide; null/empty/unknown → no glyph (caller keeps slot width).
IconData? menuIcon(String? name) {
  final key = name?.trim();
  if (key == null || key.isEmpty) return null;
  return switch (key) {
    'settings' => LucideIcons.settings,
    'users' => LucideIcons.users,
    'shield' => LucideIcons.shield,
    'menu' => LucideIcons.menu,
    'building' => LucideIcons.building,
    'folder' => LucideIcons.folder,
    'layout-dashboard' => LucideIcons.layoutDashboard,
    'file-text' => LucideIcons.fileText,
    'bell' => LucideIcons.bell,
    'house' => LucideIcons.house,
    _ => null,
  };
}

/// White sidebar (merchant-uuims style) and the server menu tree.
/// 「首页」is pinned to the overview dashboard; the matching menu.json row is not listed again.
/// Avatar tap opens the settings modal (account card + 通用); Windows caption also opens it.
class UuimsShell extends ConsumerWidget {
  const UuimsShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static bool _isHomePath(String? path) => path == '/' || path == '/dashboard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final theme = ShadTheme.of(context);
    final apple = AppleColors.of(context);
    final p = auth.profile;
    final homeSelected = _isHomePath(location);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Row(
        children: [
          Container(
            width: 208,
            color: apple.sidebar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                  child: Row(children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        color: apple.blue,
                      ),
                      child: const Icon(LucideIcons.layers, size: 15, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tr('LOONGS 平台'),
                          style: theme.textTheme.large.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2), overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
                _NavItem(
                  label: tr('首页'),
                  icon: LucideIcons.layoutDashboard,
                  selected: homeSelected,
                  onTap: () => context.go('/dashboard'),
                ),
                Expanded(
                  child: ListView(
                    // Keep scroll offset across route rebuilds (selected item highlight changes).
                    key: const PageStorageKey<String>('uuims-sidebar'),
                    primary: false,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final m in auth.menus)
                        if (!_isHomePath(m.path)) ..._build(context, m, 0),
                    ],
                  ),
                ),
                _AccountFooter(
                  nickname: p?.nickname ?? '…',
                  username: p?.username ?? '',
                  onOpen: () => showSettingsDialog(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: theme.colorScheme.background,
              child: p == null
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: child),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _build(BuildContext context, MenuNode m, int depth) {
    if (m.isDir) {
      final kids = [for (final c in m.children) if (!_isHomePath(c.path)) ..._build(context, c, depth + 1)];
      if (kids.isEmpty) return const [];
      final t = ShadTheme.of(context);
      return [
        Padding(
          padding: EdgeInsets.fromLTRB(18.0 + depth * 12, 16, 12, 4),
          child: Text(m.name, style: t.textTheme.muted.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        ...kids,
      ];
    }
    return [
      _NavItem(
        label: m.name,
        icon: menuIcon(m.icon),
        indent: depth * 12,
        selected: m.path != null && location == m.path,
        onTap: m.path == null ? null : () => context.go(m.path!),
      ),
    ];
  }
}

/// Avatar + name: tap opens the settings modal directly (no PopupMenu).
class _AccountFooter extends StatelessWidget {
  const _AccountFooter({
    required this.nickname,
    required this.username,
    required this.onOpen,
  });

  final String nickname;
  final String username;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final apple = AppleColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: const ValueKey('account-menu'),
          borderRadius: BorderRadius.circular(8),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: apple.blue.withValues(alpha: 0.12),
                  child: Text(
                    nickname.isNotEmpty ? nickname.characters.first : '·',
                    style: TextStyle(color: apple.blue, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nickname, style: theme.textTheme.small, overflow: TextOverflow.ellipsis),
                      Text(username, style: theme.textTheme.muted.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.selected, this.icon, this.onTap, this.indent = 0});

  final String label;
  /// Null = no glyph, but the same 16px slot is reserved so labels align.
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final double indent;

  static const double _iconSlot = 16;

  @override
  Widget build(BuildContext context) {
    final t = ShadTheme.of(context);
    final blue = AppleColors.of(context).blue;
    final fg = selected ? blue : t.colorScheme.foreground;
    final iconColor = selected ? blue : t.colorScheme.mutedForeground;
    return Padding(
      padding: EdgeInsets.fromLTRB(8 + indent, 1, 8, 1),
      child: Material(
        color: selected ? blue.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              SizedBox(
                width: _iconSlot,
                height: _iconSlot,
                child: icon == null
                    ? null
                    : Icon(icon, size: _iconSlot, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: t.textTheme.small.copyWith(color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
            ]),
          ),
        ),
      ),
    );
  }
}
