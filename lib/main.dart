import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/locale/locale_service.dart';
import 'core/theme/acadegate_theme.dart';
import 'core/video/register_video_player_desktop.dart';
import 'core/widgets/beta_shell.dart';
import 'core/notifications/push_notification_bootstrap.dart';
import 'firebase_options.dart';
import 'features/bugs/bug_report_service.dart';
import 'features/auth/auth_web_deep_link.dart';
import 'features/auth/email_auth_gate.dart';
import 'features/auth/email_verification_screen.dart';
import 'features/auth/language_selection_screen.dart';
import 'features/auth/portal_gateway.dart';
import 'features/auth/welcome_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerVideoPlayerDesktop();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationBootstrap.init();
  await LocaleService.instance.init();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // ignore: unawaited_futures
    BugReportService.instance.logAutoError(
      source: BugReportService.sourceAutoFlutter,
      message: details.exceptionAsString(),
      stack: details.stack?.toString(),
      severity: 'critical',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: unawaited_futures
    BugReportService.instance.logAutoError(
      source: BugReportService.sourceAutoPlatform,
      message: '$error',
      stack: stack.toString(),
      severity: 'critical',
    );
    return true;
  };

  runApp(const AcadeGateApp());
}

class AcadeGateApp extends StatelessWidget {
  const AcadeGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, _) {
        final locale = LocaleService.instance.locale ?? const Locale('ar');
        final textDirection = LocaleService.instance.textDirection;
        // On web, `home` is only applied to the initial route. Crossing
        // language-pick → ready must remount MaterialApp or the language
        // screen stays until a full page refresh.
        final appPhase =
            LocaleService.instance.hasChosenLocale ? 'ready' : 'pick-locale';

        return MaterialApp(
          key: ValueKey(appPhase),
          debugShowCheckedModeBanner: false,
          title: 'AcadeGate',
          locale: locale,
          supportedLocales: LocaleService.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: acadegateTheme(),
          builder: (context, child) {
            return Directionality(
              textDirection: textDirection,
              child: BetaShell(child: child!),
            );
          },
          home: const _AppRoot(),
        );
      },
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, _) {
        if (!LocaleService.instance.hasChosenLocale) {
          return const LanguageSelectionScreen();
        }

        // userChanges rebuilds after emailVerified flips (reload).
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
            if (user == null) {
              return WelcomeScreen(
                initialAuthAction: AuthWebDeepLink.actionFromUri(),
              );
            }
            if (EmailAuthGate.requiresVerification(user)) {
              return const EmailVerificationScreen();
            }
            return const PortalGateway();
          },
        );
      },
    );
  }
}

