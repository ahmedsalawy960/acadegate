import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/locale/locale_service.dart';
import 'core/widgets/beta_shell.dart';
import 'core/notifications/push_notification_bootstrap.dart';
import 'firebase_options.dart';
import 'features/auth/language_selection_screen.dart';
import 'features/auth/portal_gateway.dart';
import 'features/auth/welcome_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationBootstrap.init();
  await LocaleService.instance.init();
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

        return MaterialApp(
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
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          ),
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
    if (!LocaleService.instance.hasChosenLocale) {
      return const LanguageSelectionScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1A237E)),
            ),
          );
        }
        if (snapshot.hasData) {
          return const PortalGateway();
        }
        return const WelcomeScreen();
      },
    );
  }
}
