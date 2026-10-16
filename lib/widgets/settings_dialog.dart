import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/auth/auth_controller.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'ui_settings.dart';

Future<void> showSettingsDialog(BuildContext context, {String section = 'general'}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x73000000),
    builder: (context) => SettingsDialog(initialSection: section),
  );
}

/// Settings modal: left nav 通用 / 账户.
/// 账户 panel holds former「当前账号」fields + refresh + logout (no separate page).
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key, this.initialSection = 'general'});

  final String initialSection;

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late String _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection == 'account' ? 'account' : 'general';
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
    final title = _section == 'account' ? tr('账户') : tr('通用');

    return Dialog(
      key: const ValueKey('open-settings'),
      backgroundColor: dark ? c.elevated : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
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
                  onTap: () => setState(() => _section = 'account'),
                ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Text(title, style: t.textTheme.h4.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Expanded(
                    child: _section == 'account' ? _AccountPanel(onLogout: _logout) : const _GeneralPanel(),
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

class _GeneralPanel extends StatelessWidget {
  const _GeneralPanel();

  @override
  Widget build(BuildContext context) {
    final t = ShadTheme.of(context);
    final c = AppleColors.of(context);
    final dark = t.brightness == Brightness.dark;
    return ListView(
      children: [
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
    );
  }
}

class _AccountPanel extends ConsumerWidget {
  const _AccountPanel({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ShadTheme.of(context);
    final c = AppleColors.of(context);
    final dark = t.brightness == Brightness.dark;
    final p = ref.watch(authProvider).profile;
    if (p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final nickname = p.nickname;
    final username = p.username;

    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 88, child: Text(k, style: t.textTheme.muted)),
            Expanded(child: Text(v, style: t.textTheme.small)),
          ]),
        );

    return ListView(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.separator.withValues(alpha: dark ? 0.6 : 1)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
                    Text(username, style: t.textTheme.muted.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: onLogout,
                child: Text(tr('退出登录')),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Text(tr('当前账号'), style: t.textTheme.small.copyWith(color: c.secondaryLabel, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.separator.withValues(alpha: dark ? 0.6 : 1)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              kv(tr('用户名'), p.username),
              kv(tr('部门'), p.deptName ?? '—'),
              kv(tr('角色'), p.isSuper ? tr('超级管理员') : (p.roles.isEmpty ? '—' : p.roles.join('、'))),
              kv(tr('数据范围'), p.isSuper ? tr('全部数据') : (p.dataScope ?? '—')),
              kv(tr('权限码'), p.isSuper ? tr('*（全部）') : (p.permissions.isEmpty ? '—' : (p.permissions.toList()..sort()).join('\n'))),
              if (p.fields.isNotEmpty) kv(tr('字段权限'), p.fields.entries.map((e) => '${e.key}: ${e.value}').join('\n')),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            leading: const Icon(LucideIcons.refreshCw, size: 16),
            onPressed: () => ref.read(authProvider.notifier).loadSession(),
            child: Text(tr('刷新权限')),
          ),
        ),
      ],
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
