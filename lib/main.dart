import 'package:flutter/material.dart';
import 'package:livuka/Audio/waveform_cache.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:livuka/l10n/app_locale.dart';
import 'package:livuka/l10n/app_translations.dart';
import 'package:livuka/services/name_language.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/media_session.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/services/auto_send.dart';
import 'package:livuka/services/sign_out.dart';
import 'package:livuka/services/user_store.dart';
import 'package:livuka/splash.dart';

import 'dart:async';
import 'dart:io';

class DebugHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return false; // keep rejecting - this is just to see what's happening
      };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Where the waveforms read on earlier days are kept, found before the
  // first recording is drawn.
  unawaited(WaveformCache.prepare());
  HttpOverrides.global = DebugHttpOverrides();
  await SessionService.init();
  UserStore.init();
  await NameLanguage.init();
  await AppLocale.init();
  await MediaSession.restore();
  // The closed-app send, every quarter hour where the phone allows.
  await AutoSend.registerBackgroundJob();
  MainApp.roles = SessionService.roles;
  // Counts time on each stage from here on; nothing is counted until a
  // stage screen says where the person is.
  TimeTracker.instance.start();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  /// The API. Every request the app makes goes through here or through one
  /// of the two builders below - there is no LAN shortcut any more, because
  /// one resolved only on the machine it was written on and failed silently
  /// everywhere else.
  /// What this build calls itself, sent with the activity log. Kept by
  /// hand beside pubspec's `version`.
  static const String appVersion = '0.1.6';

  static Uri buildmainUri(String file) =>
      Uri.https('obt.calnicsolutions.in', "/api/$file");

  /// The web app itself, which holds the source material and the sign-in
  /// form that guards it.
  static Uri buildWebUri(String path) => Uri.https(
    'obt.calnicsolutions.in',
    "/${path.replaceFirst(RegExp(r'^/+'), '')}",
  );

  /// The web app's media root.
  ///
  /// Source material is stored as a path relative to it
  /// (`/source-content/SourceAudio/<uuid>.mp3`), never as a full URL, so the
  /// host belongs here rather than repeated in every row - and these files
  /// live with the web app, not beside the API.
  static Uri buildMediaUri(String path) => Uri.https(
    'obt.calnicsolutions.in',
    "/media/${path.replaceFirst(RegExp(r'^/+'), '').replaceFirst(RegExp(r'^media/', caseSensitive: false), '')}",
  );
  /// The LIVUKA palette (livuka-logo-kit/tokens/colors.css), as the
  /// website's `--livuka-*` variables hold it: navy for text and dark
  /// surfaces, the smile's orange, and the eyes' blue.
  static const Color brandNavy = Color(0xFF040134);
  static const Color brandOrange = Color(0xFFCD572D);
  static const Color brandBlue = Color(0xFF5DA0D3);

  /// The warm off-white the website's pages sit on (`--ob-page`).
  static Color pageBackground = const Color(0xFFF9F8F6);

  // Shadows are navy-tinted, as the website's are, so they sit with the
  // navy text rather than looking cold grey beside it.
  static const Color cardShadowColor = Color(0x24040134);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x14040134), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0D040134), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// The brand colour for primary actions: the smile's orange, the
  /// website's `--ob-brand` (#CD572D since the LIVUKA rebrand). The two
  /// products are one product to the people using them, and a shade that
  /// is nearly but not quite the same reads as a mistake in whichever one
  /// they opened second. The name is older than both the purple and the
  /// orange; it is kept so the fifty places that use it stay as they are.
  static const Color primaryGreen = brandOrange;

  /// The brand orange for orange text on white: plain #CD572D is a little
  /// light for small type (`--ob-brand-dark`).
  static const Color brandDark = Color(0xFFA9441F);

  /// The pale orange behind chips and selected tiles (`--ob-brand-bg`).
  static const Color brandTint = Color(0xFFFBEBE4);

  /// The caret in a text field and the tint behind selected text. The kit
  /// has no lighter orange, so this is the brand orange itself, as the
  /// website's focused field is.
  static const Color lightGreen = brandOrange;

  /// Sending work back. Dark red wherever it appears, so a button that
  /// returns a Set to somebody never looks like one that moves it on.
  /// `--ob-danger` on the website, which is what its own send-back button
  /// is painted with.
  static const Color sendBackRed = Color.fromARGB(255, 198, 40, 40);
  /// The website's field fill (`--ob-surface-2`).
  static const Color fieldFill = Color(0xFFF5F4F1);

  /// Secondary text: the kit's slate (`--ob-text-muted`).
  static const Color mutedText = Color(0xFF4B4870);

  /// Headings and body text: the brand navy (`--ob-text`).
  static const Color titleColor = brandNavy;
  static List<String> roles = [];

  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LIVUKA',
      // English is the key as well as the fallback: a sentence nobody has
      // translated yet shows in English rather than as a blank or a code.
      translations: AppTranslations(),
      locale: AppLocale.current,
      fallbackLocale: AppLocale.english,
      supportedLocales: AppLocale.supported,
      // Material's own words - "Cancel", the back button's label, the
      // direction a drawer slides in from - follow the language too. This is
      // also what turns the whole layout right to left for Urdu.
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // The layout stays left to right in every language. Choosing Urdu
      // changes the words, not where things are: the back arrow, the cog, the
      // avatar and the buttons stay where a user learnt to find them, and a
      // name or an email address in Latin letters is not thrown to the far
      // side of the screen. The Urdu itself still reads right to left - that
      // comes from the letters, inside each piece of text, not from the
      // page - so only the arrangement of the screen is held still.
      builder: (context, child) => Listener(
        // Every touch, anywhere: what the time tracker takes as "still
        // here". It watches and lets the touch through.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          TimeTracker.instance.touched();
          IdleLogout.instance.touched();
        },
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      theme: ThemeData(
        // Montserrat, the brand face the website is set in. It has Latin
        // letters only, so Hindi and Urdu fall through to the platform's
        // own font for those scripts.
        fontFamily: 'Montserrat',
        // No Arabic-script font is named here on purpose. Left alone, the
        // platform picks the one it uses everywhere else on the phone, which
        // is what a text file opened in any other app is drawn with - and
        // what matched the website. Naming Nastaliq made this app the only
        // place the passage was drawn in a different hand.
        useMaterial3: true,

        // Switches, checkboxes, radio buttons and filled buttons that are
        // not given a colour take the scheme's primary. Left to Material it
        // is its own default purple, which on this app reads as the old
        // brand; seeded here they are the brand orange.
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandOrange,
          primary: brandOrange,
          onSurface: brandNavy,
        ),
        scaffoldBackgroundColor: pageBackground,

        // Every card-like surface is plain white. Material 3 otherwise gives
        // dialogs, sheets and menus its own faint grey-purple surface
        // colours, and tints anything raised by its elevation — so panels
        // that are written as white come out slightly off it, and differently
        // off it depending on how high they sit.
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        // Every spinner in the app is the brand orange. Set here rather than
        // passed at each of the two dozen call sites: Material would
        // otherwise give them the scheme's primary, and one indicator added
        // later without a colour would be the odd one out.
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: primaryGreen,
        ),

        // The caret, the drag handles and the highlight behind selected
        // text. Set here so they stay the brand orange whatever the
        // scheme's primary becomes.
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: lightGreen,
          selectionHandleColor: lightGreen,
          selectionColor: lightGreen.withValues(alpha: 0.28),
        ),

        // One AppBar look for the whole app: white, flat, navy text, and
        // titles hard left. centerTitle is false here because it is platform
        // dependent by default - centred on iOS, leading on Android - which
        // would have the same screen laid out differently per device.
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          foregroundColor: brandNavy,
          elevation: 0,
          centerTitle: false,
          // Material leaves 16 between the back arrow and the title, on top
          // of the arrow's own padding - a gap wide enough that the two read
          // as separate things rather than as one heading with a way back.
          titleSpacing: 4,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
