// README §19: languages (en-US default + zh-CN), light / dark / system theme, Apple-style theme,
// Accept-Language / ui_locales wiring, theme-aware chart colors.
import 'dart:io';

import 'package:client/app.dart';
import 'package:client/core/api.dart';
import 'package:client/core/auth/auth_controller.dart';
import 'package:client/core/auth/oauth_client.dart';
import 'package:client/core/auth/pkce.dart';
import 'package:client/core/auth/token_set.dart';
import 'package:client/core/i18n.dart';
import 'package:client/core/models.dart';
import 'package:client/core/prefs.dart';
import 'package:client/core/router.dart';
import 'package:client/core/settings.dart';
import 'package:client/core/theme.dart';
import 'package:client/features/auth/login_page.dart';
import 'package:client/features/shell/admin_shell.dart';
import 'package:client/render/chart/chart_format.dart';
import 'package:client/render/chart/chart_spec.dart';
import 'package:client/render/render_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

int sessionLoads = 0;

class _SignedOut extends AuthController {
  @override
  AuthState build() => const AuthState.signedOut();
}

class _SignedIn extends AuthController {
  @override
  AuthState build() => AuthState(
        status: AuthStatus.signedIn,
        tokens: TokenSet(accessToken: 'a', refreshToken: 'r', expiresAt: DateTime.now().add(const Duration(minutes: 10))),
        profile: Profile.fromJson({'id': 1, 'username': 'admin', 'nickname': 'Admin', 'is_super': true, 'permissions': ['*']}),
        menus: [MenuNode.fromJson({'id': 1, 'name': '管理员', 'type': 'menu', 'path': '/system/admins', 'icon': 'users'})],
      );

  @override
  Future<void> loadSession() async => sessionLoads++;
}

/// Captures request headers and answers 200 `{code:0,data:{}}` without network.
class _Capture extends Interceptor {
  final List<Map<String, dynamic>> headers = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    headers.add(Map.of(options.headers));
    handler.resolve(Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: {
        'code': 0,
        'data': {'schema': 1, 'type': 'table', 'version': 'v1', 'page': 'x', 'body': <String, dynamic>{}},
      },
    ));
  }
}

Future<PrefsStore> pumpAdminApp(WidgetTester tester, {required GoRouter router, required AuthController Function() auth, PrefsStore? prefs}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final p = prefs ?? PrefsStore.memory();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(p),
      routerProvider.overrideWithValue(router),
      authProvider.overrideWith(auth),
    ],
    child: const UuimsApp(),
  ));
  await tester.pumpAndSettle();
  return p;
}

Brightness brightnessOf(WidgetTester tester, Finder f) => ShadTheme.of(tester.element(f)).brightness;

GoRouter loginRouter() => GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const LoginPage())]);

GoRouter shellRouter() => GoRouter(routes: [
      ShellRoute(
        builder: (_, s, child) => UuimsShell(location: s.uri.path, child: child),
        routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink())],
      ),
    ]);

void main() {
  setUp(() {
    currentLanguage = kDefaultLanguage;
    sessionLoads = 0;
  });

  group('i18n', () {
    test('tr: en-US default from the pack, zh-CN = source text, {placeholders}, missing key → source', () {
      expect(tr('保存'), 'Save');
      expect(tr('已选 {n} 条', {'n': 3}), '3 selected');
      currentLanguage = 'zh-CN';
      expect(tr('保存'), '保存');
      expect(tr('已选 {n} 条', {'n': 3}), '已选 3 条');
      currentLanguage = 'en-US';
      expect(tr('没有这个键'), '没有这个键');
      expect(tr('保存', const {}, 'zh-CN'), '保存');
    });

    test('normalizeLanguage / localeOf: en, en_GB, zh-Hans, unknown → default', () {
      expect(normalizeLanguage('en'), 'en-US');
      expect(normalizeLanguage('en_GB'), 'en-US');
      expect(normalizeLanguage('EN-us'), 'en-US');
      expect(normalizeLanguage('zh-Hans'), 'zh-CN');
      expect(normalizeLanguage('fr-FR'), 'en-US');
      expect(normalizeLanguage(null), 'en-US');
      expect(localeOf('en-US'), const Locale('en', 'US'));
      expect(supportedLocales, [const Locale('zh', 'CN'), const Locale('en', 'US')]);
    });

    test('every tr(\'…\') literal in lib/ has an en-US translation', () {
      final keys = <String>{};
      final re = RegExp(r"\btr\('((?:[^'\\]|\\.)*)'");
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        for (final m in re.allMatches(f.readAsStringSync())) {
          keys.add(m[1]!.replaceAll(r"\'", "'"));
        }
      }
      expect(keys.length, greaterThan(100));
      expect(missingTranslations(keys, 'en-US'), isEmpty);
    });

    test('compactNumber: K / M / B by default (en-US), 万 / 亿 in Chinese', () {
      expect(compactNumber(12000), '12K');
      currentLanguage = 'zh-CN';
      expect(compactNumber(12000), '1.2万');
      expect(compactNumber(120000000), '1.2亿');
      currentLanguage = 'en-US';
      expect(compactNumber(12000), '12K');
      expect(compactNumber(3500000), '3.5M');
      expect(compactNumber(1200000000), '1.2B');
      expect(compactNumber(950), '950');
    });
  });

  group('settings', () {
    test('defaults en-US + system; changes persist to the prefs store and reload', () {
      final prefs = PrefsStore.memory();
      final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      expect(c.read(settingsProvider).language, 'en-US');
      expect(c.read(settingsProvider).themeMode, ThemeMode.system);
      expect(c.read(settingsProvider).uiTheme, isNull);
      c.read(settingsProvider.notifier).setLanguage('zh');
      c.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
      expect((prefs.get(kPrefLanguage), prefs.get(kPrefTheme)), ('zh-CN', 'dark'));
      expect(currentLanguage, 'zh-CN');
      expect(c.read(settingsProvider).uiTheme, 'dark');

      final c2 = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      addTearDown(c2.dispose);
      expect((c2.read(settingsProvider).language, c2.read(settingsProvider).themeMode), ('zh-CN', ThemeMode.dark));
    });

    test('Accept-Language: API interceptor + render repository (one repository per language)', () async {
      final cap = _Capture();
      final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(PrefsStore.memory()), authProvider.overrideWith(_SignedOut.new)]);
      addTearDown(c.dispose);
      final dio = c.read(apiDioProvider)..interceptors.add(cap);
      await dio.get<dynamic>('/auth/me');
      expect(cap.headers.last['Accept-Language'], 'en-US');

      final repoEn = c.read(renderRepositoryProvider);
      await repoEn.fetch(PageRequest('uuims.system.admins'));
      expect(cap.headers.last['Accept-Language'], 'en-US');
      c.read(settingsProvider.notifier).setLanguage('zh-CN');
      final repoZh = c.read(renderRepositoryProvider);
      expect(identical(repoEn, repoZh), isFalse, reason: 'ETag cache is per language');
      await repoZh.fetch(PageRequest('uuims.system.admins'));
      expect(cap.headers.last['Accept-Language'], 'zh-CN');
      await c.read(apiDioProvider).get<dynamic>('/auth/menus');
      expect(cap.headers.last['Accept-Language'], 'zh-CN');
    });

    test('authorize URL carries ui_locales / ui_theme (omitted when unset)', () {
      final o = OAuthClient('http://api.test');
      final p = Pkce.generate();
      final u = o.authorizeUrl(redirectUri: 'http://app/callback.html', pkce: p, state: 's', uiLocales: 'en-US', uiTheme: 'dark');
      expect((u.queryParameters['ui_locales'], u.queryParameters['ui_theme']), ('en-US', 'dark'));
      final u2 = o.authorizeUrl(redirectUri: 'http://app/callback.html', pkce: p, state: 's');
      expect(u2.queryParameters.containsKey('ui_locales') || u2.queryParameters.containsKey('ui_theme'), isFalse);
    });
  });

  group('theme', () {
    test('Apple palette: systemBlue accent, grouped backgrounds, light + dark', () {
      final l = appleTheme(Brightness.light), d = appleTheme(Brightness.dark);
      expect(l.colorScheme.primary, const Color(0xFF1966FF));
      expect(d.colorScheme.primary, const Color(0xFF0A84FF));
      expect(l.colorScheme.background, const Color(0xFFF5F6FA));
      expect(d.colorScheme.background, const Color(0xFF000000));
      expect(d.colorScheme.card, const Color(0xFF1C1C1E));
      expect(l.radius, const BorderRadius.all(Radius.circular(10)));
      expect(l.switchTheme.checkedTrackColor, const Color(0xFF34C759));
      expect(l.textTheme.family, 'PingFangSC');
    });

    test('chart colors: light values unchanged, dark variants, chartN tokens, "light|dark" pairs', () {
      expect(parseColor('primary'), const Color(0xFF2563EB));
      expect(parseColor('primary', dark: true), const Color(0xFF60A5FA));
      expect(parseColor('chart1'), const Color(0xFF2563EB));
      expect(parseColor('chart2', dark: true), const Color(0xFFFBBF24));
      expect(parseColor('#111111|#eeeeee'), const Color(0xFF111111));
      expect(parseColor('#111111|#eeeeee', dark: true), const Color(0xFFEEEEEE));
      expect(parseColor('success|warning', dark: true), const Color(0xFFFBBF24));
      final block = {'chart': 'line', 'series': [{'field': 'n', 'color': 'success'}]};
      expect(ChartSpec(block).palette.first, const Color(0xFF2563EB));
      expect(ChartSpec(block, dark: true).palette.first, const Color(0xFF60A5FA));
      expect(ChartSpec(block, dark: true).series.single.color, const Color(0xFF4ADE80));
      expect(ChartSpec(block).series.single.color, const Color(0xFF16A34A));
    });
  });

  group('widgets', () {
    testWidgets('login page: language switch translates + persists; theme switch light / dark / system', (tester) async {
      final prefs = await pumpAdminApp(tester, router: loginRouter(), auth: _SignedOut.new);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.byKey(const ValueKey('language-switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('theme-switch')), findsOneWidget);
      // system mode follows the platform brightness (light in tests)
      expect(brightnessOf(tester, find.text('Sign in')), Brightness.light);

      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(find.text('登录'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(prefs.get(kPrefLanguage), 'zh-CN');
      expect(Localizations.localeOf(tester.element(find.text('登录'))), const Locale('zh', 'CN'));
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.moon));
      await tester.pumpAndSettle();
      expect(brightnessOf(tester, find.text('Sign in')), Brightness.dark);
      expect(ShadTheme.of(tester.element(find.text('Sign in'))).colorScheme.primary, const Color(0xFF0A84FF));
      expect(prefs.get(kPrefTheme), 'dark');

      await tester.tap(find.byIcon(LucideIcons.monitor));
      await tester.pumpAndSettle();
      expect(brightnessOf(tester, find.text('Sign in')), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(brightnessOf(tester, find.text('Sign in')), Brightness.dark, reason: 'system mode follows the OS');
    });

    testWidgets('restores persisted language + theme at startup', (tester) async {
      final prefs = PrefsStore({kPrefLanguage: 'en-US', kPrefTheme: 'dark'});
      await pumpAdminApp(tester, router: loginRouter(), auth: _SignedOut.new, prefs: prefs);
      expect(find.text('Sign in'), findsOneWidget);
      expect(brightnessOf(tester, find.text('Sign in')), Brightness.dark);
    });

    testWidgets('shell: switchers in the sidebar, nav translated, menus reloaded on language change', (tester) async {
      await pumpAdminApp(tester, router: shellRouter(), auth: _SignedIn.new);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Refresh permissions'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('account-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('theme-switch')), findsOneWidget);
      expect(sessionLoads, 0);

      // Account tab: former current-account fields + refresh
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Refresh permissions'), findsOneWidget);
      expect(find.text('Current account'), findsOneWidget);

      // back to General for language switch
      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-switch')), findsOneWidget);

      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(find.text('首页'), findsOneWidget);
      expect(sessionLoads, 1, reason: 'server-translated menus are reloaded');
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.moon));
      await tester.pumpAndSettle();
      expect(brightnessOf(tester, find.text('Home')), Brightness.dark);
      expect(ShadTheme.of(tester.element(find.text('Home'))).colorScheme.background, const Color(0xFF000000));
    });
  });
}
