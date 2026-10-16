import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/auth/auth_controller.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'ui_settings.dart';

Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x73000000),
    builder: (context) => const SettingsDialog(),
  );
}

/// Settings modal: left nav + account card + 通用 (theme / language).
/// Avatar click opens this directly — no PopupMenu.
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  /// Left nav: `general` | `account` (account jumps to /account).
  String _section = 'general';

  void _goAccount() {
    Navigator.of(context).pop();
    context.go('/account');
  }

  Future<void> _logout() async {
    Navigator.of(context).pop();
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final t = ShadTheme.of(context);
    final c = AppleColors.of(context);
    final dark = t.brightness == Brightness.dark;
    final p = ref.watch(authProvider).profile;
    final nickname = p?.nickname ?? '…';
    final username = p?.username ?? '';

    return Dialog(
      key: const ValueKey('open-settings'),
      backgroundColor: dark ? c.elevated : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 180,
              color: dark ? const Color(0xFF161618) : const Color(0xFFF5F5F7),
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _NavItem(
                  label: tr('通用'),
                  icon: LucideIcons.settings,
                  selected: _section == 'general',
                  onTap: () => setState(() => _section = 'general'),
                ),
                const SizedBox(height: 4),
                _NavItem(
                  label: tr('账户'),
                  icon: LucideIcons.user,
                  selected: _section == 'account',
                  onTap: _goAccount,
                ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Text(tr('通用'), style: t.textTheme.h4.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView(
                      children: [
                        Text(tr('账户'), style: t.textTheme.small.copyWith(color: c.secondaryLabel, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.separator.withValues(alpha: dark ? 0.6 : 1)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                            child: Row(children: [
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: _goAccount,
                                    child: Row(children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: c.blue.withValues(alpha: 0.12),
                                        child: Text(
                                          nickname.isNotEmpty ? nickname.characters.first : '·',
                                          style: TextStyle(color: c.blue, fontWeight: FontWeight.w600, fontSize: 16),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(nickname, style: t.textTheme.small.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            // Username only — no copy icon (user request).
                                            Text(username, style: t.textTheme.muted.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ShadButton.outline(
                                size: ShadButtonSize.sm,
                                onPressed: _logout,
                                child: Text(tr('退出登录')),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(tr('外观'), style: t.textTheme.small.copyWith(color: c.secondaryLabel, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.separator.withValues(alpha: dark ? 0.6 : 1)),
                          ),
                          child: Column(children: [
                            _Row(label: tr('主题'), child: const ThemeModeSwitch()),
                            Divider(height: 1, thickness: 0.5, color: c.separator.withValues(alpha: 0.7)),
                            _Row(label: tr('语言'), child: const LanguageSwitch()),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ShadTheme.of(context);
    final c = AppleColors.of(context);
    final dark = t.brightness == Brightness.dark;
    return Material(
      color: selected ? (dark ? const Color(0xFF2C2C2E) : Colors.white) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            Icon(icon, size: 15, color: selected ? c.label : c.secondaryLabel),
            const SizedBox(width: 8),
            Text(label, style: t.textTheme.small.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Text(label, style: t.textTheme.small),
        const Spacer(),
        child,
      ]),
    );
  }
}
