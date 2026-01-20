import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:appsflyer_sdk/appsflyer_sdk.dart'
    show AppsFlyerOptions, AppsflyerSdk;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, SystemUiOverlayStyle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Если эти классы есть в main.dart – оставь импорт.
import 'main.dart' show MafiaHarbor, CaptainHarbor, BillHarbor;

// ============================================================================
// RetroCar инфраструктура и паттерны
// ============================================================================

class RetroCarLogger {
  const RetroCarLogger();

  void retroCarLogInfo(Object message) =>
      debugPrint('[WheelLogger] $message');
  void retroCarLogWarn(Object message) =>
      debugPrint('[WheelLogger/WARN] $message');
  void retroCarLogError(Object message) =>
      debugPrint('[WheelLogger/ERR] $message');
}

class RetroCarVault {
  static final RetroCarVault retroCarInstance =
  RetroCarVault._retroCarInternal();
  RetroCarVault._retroCarInternal();
  factory RetroCarVault() => retroCarInstance;

  final RetroCarLogger retroCarLogger = const RetroCarLogger();
}

// ============================================================================
// Константы (статистика/кеш)
// ============================================================================

const String retroCarLoadedOnceKey = 'wheel_loaded_once';
const String retroCarStatEndpoint = 'https://getgame.portalroullete.bar/stat';
const String retroCarCachedFcmKey = 'wheel_cached_fcm';

// ============================================================================
// Утилиты: RetroCarKit
// ============================================================================

class RetroCarKit {
  static bool retroCarLooksLikeBareMail(Uri uri) {
    final String retroCarScheme = uri.scheme;
    if (retroCarScheme.isNotEmpty) return false;
    final String retroCarRaw = uri.toString();
    return retroCarRaw.contains('@') && !retroCarRaw.contains(' ');
  }

  static Uri retroCarToMailto(Uri uri) {
    final String retroCarFull = uri.toString();
    final List<String> retroCarBits = retroCarFull.split('?');
    final String retroCarWho = retroCarBits.first;
    final Map<String, String> retroCarQuery = retroCarBits.length > 1
        ? Uri.splitQueryString(retroCarBits[1])
        : <String, String>{};
    return Uri(
      scheme: 'mailto',
      path: retroCarWho,
      queryParameters: retroCarQuery.isEmpty ? null : retroCarQuery,
    );
  }

  static Uri retroCarGmailize(Uri retroCarMailUri) {
    final Map<String, String> retroCarQp = retroCarMailUri.queryParameters;
    final Map<String, String> retroCarParams = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (retroCarMailUri.path.isNotEmpty) 'to': retroCarMailUri.path,
      if ((retroCarQp['subject'] ?? '').isNotEmpty)
        'su': retroCarQp['subject']!,
      if ((retroCarQp['body'] ?? '').isNotEmpty)
        'body': retroCarQp['body']!,
      if ((retroCarQp['cc'] ?? '').isNotEmpty) 'cc': retroCarQp['cc']!,
      if ((retroCarQp['bcc'] ?? '').isNotEmpty) 'bcc': retroCarQp['bcc']!,
    };
    return Uri.https('mail.google.com', '/mail/', retroCarParams);
  }

  static String retroCarDigitsOnly(String retroCarSource) =>
      retroCarSource.replaceAll(RegExp(r'[^0-9+]'), '');
}

// ============================================================================
/* Сервис открытия ссылок: RetroCarLinker */
// ============================================================================

class RetroCarLinker {
  static Future<bool> retroCarOpen(Uri retroCarUri) async {
    try {
      if (await launchUrl(
        retroCarUri,
        mode: LaunchMode.inAppBrowserView,
      )) {
        return true;
      }
      return await launchUrl(
        retroCarUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (retroCarError) {
      debugPrint('WheelLinker error: $retroCarError; url=$retroCarUri');
      try {
        return await launchUrl(
          retroCarUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }
}

// ============================================================================
// FCM Background Handler
// ============================================================================

@pragma('vm:entry-point')
Future<void> retroCarFcmBackgroundHandler(
    RemoteMessage retroCarMessage) async {
  debugPrint("Spin ID: ${retroCarMessage.messageId}");
  debugPrint("Spin Data: ${retroCarMessage.data}");
}

// ============================================================================
// RetroCarDeviceProfile: информация об устройстве
// ============================================================================

class RetroCarDeviceProfile {
  String? retroCarDeviceId;
  String? retroCarSessionId = 'wheel-one-off';
  String? retroCarPlatformKind;
  String? retroCarOsBuild;
  String? retroCarAppVersion;
  String? retroCarLocaleCode;
  String? retroCarTimezoneName;
  bool retroCarPushEnabled = true;

  Future<void> retroCarInitialize() async {
    final DeviceInfoPlugin retroCarInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo retroCarAndroidInfo =
      await retroCarInfoPlugin.androidInfo;
      retroCarDeviceId = retroCarAndroidInfo.id;
      retroCarPlatformKind = 'android';
      retroCarOsBuild = retroCarAndroidInfo.version.release;
    } else if (Platform.isIOS) {
      final IosDeviceInfo retroCarIosInfo =
      await retroCarInfoPlugin.iosInfo;
      retroCarDeviceId = retroCarIosInfo.identifierForVendor;
      retroCarPlatformKind = 'ios';
      retroCarOsBuild = retroCarIosInfo.systemVersion;
    }

    final PackageInfo retroCarPackageInfo =
    await PackageInfo.fromPlatform();
    retroCarAppVersion = retroCarPackageInfo.version;
    retroCarLocaleCode = Platform.localeName.split('_').first;
    retroCarTimezoneName = timezone.local.name;
    retroCarSessionId =
    'wheel-${DateTime.now().millisecondsSinceEpoch}';

    // Реальное состояние пушей
    try {
      final FirebaseMessaging retroCarFm = FirebaseMessaging.instance;
      final NotificationSettings retroCarSettings =
      await retroCarFm.getNotificationSettings();
      retroCarPushEnabled =
          retroCarSettings.authorizationStatus == AuthorizationStatus.authorized ||
              retroCarSettings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      retroCarPushEnabled = false;
    }
  }

  Map<String, dynamic> retroCarAsMap({String? fcmToken}) => {
    'fcm_token': fcmToken ?? 'missing_token',
    'device_id': retroCarDeviceId ?? 'missing_id',
    'app_name': 'joiler',
    'instance_id': retroCarSessionId ?? 'missing_session',
    'platform': retroCarPlatformKind ?? 'missing_system',
    'os_version': retroCarOsBuild ?? 'missing_build',
    'app_version': retroCarAppVersion ?? 'missing_app',
    'language': retroCarLocaleCode ?? 'en',
    'timezone': retroCarTimezoneName ?? 'UTC',
    'push_enabled': retroCarPushEnabled,
  };
}

// ============================================================================
// AppsFlyer шпион: RetroCarSpy
// ============================================================================

class RetroCarSpy {
  AppsFlyerOptions? retroCarOptions;
  AppsflyerSdk? retroCarSdk;

  String retroCarAppsFlyerUid = '';
  String retroCarAppsFlyerData = '';

  void retroCarStart({VoidCallback? onUpdate}) {
    final AppsFlyerOptions retroCarOpts = AppsFlyerOptions(
      afDevKey: 'qsBLmy7dAXDQhowM8V3ca4',
      appId: '6756072063',
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );

    retroCarOptions = retroCarOpts;
    retroCarSdk = AppsflyerSdk(retroCarOpts);

    retroCarSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    retroCarSdk?.startSDK(
      onSuccess: () => RetroCarVault()
          .retroCarLogger
          .retroCarLogInfo('WheelSpy started'),
      onError: (retroCarCode, retroCarMsg) => RetroCarVault()
          .retroCarLogger
          .retroCarLogError(
          'WheelSpy error $retroCarCode: $retroCarMsg'),
    );

    retroCarSdk?.onInstallConversionData((retroCarValue) {
      retroCarAppsFlyerData = retroCarValue.toString();
      onUpdate?.call();
    });

    retroCarSdk?.getAppsFlyerUID().then((retroCarValue) {
      retroCarAppsFlyerUid = retroCarValue.toString();
      onUpdate?.call();
    });
  }
}

// ============================================================================
// Мост для FCM токена: RetroCarFcmBridge
// ============================================================================

class RetroCarFcmBridge {
  final RetroCarLogger retroCarLog = const RetroCarLogger();
  String? retroCarToken;
  final List<void Function(String)> retroCarWaiters =
  <void Function(String)>[];

  String? get retroCarFcmToken => retroCarToken;

  RetroCarFcmBridge() {
    const MethodChannel('com.example.fcm/token')
        .setMethodCallHandler((MethodCall retroCarCall) async {
      if (retroCarCall.method == 'setToken') {
        final String retroCarTokenString =
        retroCarCall.arguments as String;
        if (retroCarTokenString.isNotEmpty) {
          retroCarSetToken(retroCarTokenString);
        }
      }
    });

    retroCarRestoreToken();
  }

  Future<void> retroCarRestoreToken() async {
    try {
      final SharedPreferences retroCarPrefs =
      await SharedPreferences.getInstance();
      final String? retroCarCached =
      retroCarPrefs.getString(retroCarCachedFcmKey);
      if (retroCarCached != null && retroCarCached.isNotEmpty) {
        retroCarSetToken(retroCarCached, notify: false);
      }
    } catch (_) {}
  }

  Future<void> retroCarPersistToken(String retroCarNewToken) async {
    try {
      final SharedPreferences retroCarPrefs =
      await SharedPreferences.getInstance();
      await retroCarPrefs.setString(
          retroCarCachedFcmKey, retroCarNewToken);
    } catch (_) {}
  }

  void retroCarSetToken(
      String retroCarNewToken, {
        bool notify = true,
      }) {
    retroCarToken = retroCarNewToken;
    retroCarPersistToken(retroCarNewToken);
    if (notify) {
      for (final void Function(String) retroCarCallback
      in List<void Function(String)>.from(retroCarWaiters)) {
        try {
          retroCarCallback(retroCarNewToken);
        } catch (retroCarErr) {
          retroCarLog
              .retroCarLogWarn('fcm waiter error: $retroCarErr');
        }
      }
      retroCarWaiters.clear();
    }
  }

  Future<void> retroCarWaitForToken(
      Function(String retroCarTokenValue) retroCarOnToken,
      ) async {
    try {
      final FirebaseMessaging retroCarFm = FirebaseMessaging.instance;

      // Запрашиваем реальные разрешения
      final NotificationSettings retroCarSettings =
      await retroCarFm.getNotificationSettings();
      if (retroCarSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined ||
          retroCarSettings.authorizationStatus ==
              AuthorizationStatus.denied) {
        await retroCarFm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      if ((retroCarToken ?? '').isNotEmpty) {
        retroCarOnToken(retroCarToken!);
        return;
      }

      retroCarWaiters.add(retroCarOnToken);
    } catch (retroCarErr) {
      retroCarLog
          .retroCarLogError('wheelWaitToken error: $retroCarErr');
    }
  }
}

// ============================================================================
// Неоновый Loader Retro / cars
// ============================================================================

class RetroCarNeonLoader extends StatefulWidget {
  const RetroCarNeonLoader({Key? key}) : super(key: key);

  @override
  State<RetroCarNeonLoader> createState() => _RetroCarNeonLoaderState();
}

class _RetroCarNeonLoaderState extends State<RetroCarNeonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController retroCarAnimationController;
  late Animation<double> retroCarPositionAnimation;
  late Animation<double> retroCarGlowAnimation;

  @override
  void initState() {
    super.initState();

    retroCarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    retroCarPositionAnimation = CurvedAnimation(
      parent: retroCarAnimationController,
      curve: Curves.easeInOut,
    );

    retroCarGlowAnimation = CurvedAnimation(
      parent: retroCarAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    retroCarAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size retroCarSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: retroCarAnimationController,
        builder: (BuildContext retroCarCtx, Widget? retroCarChild) {
          final double retroCarT = retroCarPositionAnimation.value;
          final double retroCarGlow =
              0.4 + 0.6 * retroCarGlowAnimation.value;

          final double retroCarCenterY = retroCarSize.height / 2;

          // Верхнее слово "RETRO" — едет вниз
          final double retroCarTopStartY = retroCarCenterY - 140;
          final double retroCarTopEndY = retroCarCenterY - 40;
          final double retroCarTopY = retroCarTopStartY +
              (retroCarTopEndY - retroCarTopStartY) * retroCarT;

          // Нижнее слово "cars" — едет вверх
          final double retroCarBottomStartY = retroCarCenterY + 140;
          final double retroCarBottomEndY = retroCarCenterY + 40;
          final double retroCarBottomY = retroCarBottomStartY +
              (retroCarBottomEndY - retroCarBottomStartY) * retroCarT;

          return CustomPaint(
            size: retroCarSize,
            painter: RetroCarNeonPainter(
              retroCarTopY: retroCarTopY,
              retroCarBottomY: retroCarBottomY,
              retroCarGlowStrength: retroCarGlow,
            ),
          );
        },
      ),
    );
  }
}

class RetroCarNeonPainter extends CustomPainter {
  final double retroCarTopY;
  final double retroCarBottomY;
  final double retroCarGlowStrength;

  RetroCarNeonPainter({
    required this.retroCarTopY,
    required this.retroCarBottomY,
    required this.retroCarGlowStrength,
  });

  @override
  void paint(Canvas retroCarCanvas, Size retroCarSize) {
    retroCarCanvas.drawRect(
      Offset.zero & retroCarSize,
      Paint()..color = Colors.black,
    );

    final double retroCarCenterX = retroCarSize.width / 2;

    final Paint retroCarBackgroundGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.cyanAccent.withOpacity(0.05 * retroCarGlowStrength),
          Colors.deepPurple.withOpacity(0.35 * retroCarGlowStrength),
          Colors.black,
        ],
        stops: const <double>[0.0, 0.4, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(retroCarCenterX, retroCarSize.height / 2),
          radius: retroCarSize.width * 0.8,
        ),
      );

    retroCarCanvas.drawCircle(
      Offset(retroCarCenterX, retroCarSize.height / 2),
      retroCarSize.width * 0.8,
      retroCarBackgroundGlow,
    );

    final TextStyle retroCarBaseStyle = TextStyle(
      fontSize: 50,
      fontWeight: FontWeight.w900,
      letterSpacing: 8,
      color: Colors.white,
      shadows: <Shadow>[
        Shadow(
          color: Colors.cyanAccent.withOpacity(0.9 * retroCarGlowStrength),
          blurRadius: 24 * retroCarGlowStrength,
          offset: const Offset(0, 0),
        ),
        Shadow(
          color: Colors.white.withOpacity(0.7 * retroCarGlowStrength),
          blurRadius: 10 * retroCarGlowStrength,
          offset: const Offset(0, 0),
        ),
      ],
    );

    // Верхнее слово "RETRO"
    final TextPainter retroCarTopTextPainter = TextPainter(
      text: TextSpan(
        text: 'RETRO',
        style: retroCarBaseStyle.copyWith(
          fontSize: 56,
          foreground: Paint()
            ..shader = LinearGradient(
              colors: <Color>[
                Colors.pinkAccent,
                Colors.white,
                Colors.cyanAccent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(const Rect.fromLTWH(0, 0, 260, 60)),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    retroCarTopTextPainter.paint(
      retroCarCanvas,
      Offset(
        (retroCarSize.width - retroCarTopTextPainter.width) / 2,
        retroCarTopY,
      ),
    );

    // Нижнее слово "cars"
    final TextPainter retroCarBottomTextPainter = TextPainter(
      text: TextSpan(
        text: 'cars',
        style: retroCarBaseStyle.copyWith(
          fontSize: 48,
          letterSpacing: 6,
          foreground: Paint()
            ..shader = LinearGradient(
              colors: <Color>[
                Colors.white,
                Colors.cyanAccent,
                Colors.pinkAccent,
              ],
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
            ).createShader(const Rect.fromLTWH(0, 0, 220, 60)),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    retroCarBottomTextPainter.paint(
      retroCarCanvas,
      Offset(
        (retroCarSize.width - retroCarBottomTextPainter.width) / 2,
        retroCarBottomY,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant RetroCarNeonPainter oldDelegate) =>
      oldDelegate.retroCarTopY != retroCarTopY ||
          oldDelegate.retroCarBottomY != retroCarBottomY ||
          oldDelegate.retroCarGlowStrength != retroCarGlowStrength;
}

// ============================================================================
// Статистика
// ============================================================================

Future<String> retroCarFinalUrl(
    String retroCarStartUrl, {
      int maxHops = 10,
    }) async {
  final HttpClient retroCarClient = HttpClient();

  try {
    Uri retroCarCurrentUri = Uri.parse(retroCarStartUrl);

    for (int retroCarI = 0; retroCarI < maxHops; retroCarI++) {
      final HttpClientRequest retroCarRequest =
      await retroCarClient.getUrl(retroCarCurrentUri);
      retroCarRequest.followRedirects = false;
      final HttpClientResponse retroCarResponse =
      await retroCarRequest.close();

      if (retroCarResponse.isRedirect) {
        final String? retroCarLoc =
        retroCarResponse.headers.value(HttpHeaders.locationHeader);
        if (retroCarLoc == null || retroCarLoc.isEmpty) break;

        final Uri retroCarNextUri = Uri.parse(retroCarLoc);
        retroCarCurrentUri = retroCarNextUri.hasScheme
            ? retroCarNextUri
            : retroCarCurrentUri.resolveUri(retroCarNextUri);
        continue;
      }

      return retroCarCurrentUri.toString();
    }

    return retroCarCurrentUri.toString();
  } catch (retroCarError) {
    debugPrint('wheelFinalUrl error: $retroCarError');
    return retroCarStartUrl;
  } finally {
    retroCarClient.close(force: true);
  }
}

Future<void> retroCarPostStat({
  required String event,
  required int timeStart,
  required String url,
  required int timeFinish,
  required String appSid,
  int? firstPageTs,
}) async {
  try {
    final String retroCarResolvedUrl = await retroCarFinalUrl(url);
    final Map<String, dynamic> retroCarPayload = <String, dynamic>{
      'event': event,
      'timestart': timeStart,
      'timefinsh': timeFinish,
      'url': retroCarResolvedUrl,
      'appleID': '6755681349',
      'open_count': '$appSid/$timeStart',
    };

    debugPrint('wheelStat $retroCarPayload');

    final http.Response retroCarResp = await http.post(
      Uri.parse('$retroCarStatEndpoint/$appSid'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(retroCarPayload),
    );

    debugPrint(
        'wheelStat resp=${retroCarResp.statusCode} body=${retroCarResp.body}');
  } catch (retroCarError) {
    debugPrint('wheelPostStat error: $retroCarError');
  }
}

// ============================================================================
// WebView-экран: RetroCarTableView
// ============================================================================

class RetroCarTableView extends StatefulWidget with WidgetsBindingObserver {
  String retroCarStartingUrl;
  RetroCarTableView(this.retroCarStartingUrl, {super.key});

  @override
  State<RetroCarTableView> createState() =>
      _RetroCarTableViewState(retroCarStartingUrl);
}

class _RetroCarTableViewState extends State<RetroCarTableView>
    with WidgetsBindingObserver {
  _RetroCarTableViewState(this.retroCarCurrentUrl);

  final RetroCarVault retroCarVault = RetroCarVault();

  late InAppWebViewController retroCarWebViewController;
  String? retroCarPushToken;
  final RetroCarDeviceProfile retroCarDeviceProfile =
  RetroCarDeviceProfile();
  final RetroCarSpy retroCarSpy = RetroCarSpy();

  bool retroCarOverlayBusy = false;
  String retroCarCurrentUrl;
  DateTime? retroCarLastPausedAt;

  bool retroCarLoadedOnceSent = false;
  int? retroCarFirstPageTimestamp;
  int retroCarStartLoadTimestamp = 0;

  final Set<String> retroCarExternalHosts = <String>{
    't.me',
    'telegram.me',
    'telegram.dog',
    'wa.me',
    'api.whatsapp.com',
    'chat.whatsapp.com',
    'bnl.com',
    'www.bnl.com',
    'facebook.com',
    'www.facebook.com',
    'm.facebook.com',
    'instagram.com',
    'www.instagram.com',
    'twitter.com',
    'www.twitter.com',
    'x.com',
    'www.x.com',
  };

  final Set<String> retroCarExternalSchemes = <String>{
    'tg',
    'telegram',
    'whatsapp',
    'bnl',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    FirebaseMessaging.onBackgroundMessage(retroCarFcmBackgroundHandler);

    retroCarFirstPageTimestamp =
        DateTime.now().millisecondsSinceEpoch;

    retroCarInitPushAndGetToken();
    retroCarDeviceProfile.retroCarInitialize();
    retroCarWireForegroundPushHandlers();
    retroCarBindPlatformNotificationTap();
    retroCarSpy.retroCarStart(onUpdate: () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState retroCarState) {
    if (retroCarState == AppLifecycleState.paused) {
      retroCarLastPausedAt = DateTime.now();
    }
    if (retroCarState == AppLifecycleState.resumed) {
      if (Platform.isIOS && retroCarLastPausedAt != null) {
        final DateTime retroCarNow = DateTime.now();
        final Duration retroCarDrift =
        retroCarNow.difference(retroCarLastPausedAt!);
        if (retroCarDrift > const Duration(minutes: 25)) {
          retroCarForceReloadToLobby();
        }
      }
      retroCarLastPausedAt = null;
    }
  }

  void retroCarForceReloadToLobby() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      // Здесь можно вернуть в лобби (MafiaHarbor / CaptainHarbor / BillHarbor),
      // если нужно.
    });
  }

  // --------------------------------------------------------------------------
  // Push / FCM
  // --------------------------------------------------------------------------

  void retroCarWireForegroundPushHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage retroCarMsg) {
      if (retroCarMsg.data['uri'] != null) {
        retroCarNavigateTo(retroCarMsg.data['uri'].toString());
      } else {
        retroCarReturnToCurrentUrl();
      }
    });

    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage retroCarMsg) {
      if (retroCarMsg.data['uri'] != null) {
        retroCarNavigateTo(retroCarMsg.data['uri'].toString());
      } else {
        retroCarReturnToCurrentUrl();
      }
    });
  }

  void retroCarNavigateTo(String retroCarNewUrl) async {
    await retroCarWebViewController.loadUrl(
      urlRequest: URLRequest(url: WebUri(retroCarNewUrl)),
    );
  }

  void retroCarReturnToCurrentUrl() async {
    Future<void>.delayed(const Duration(seconds: 3), () {
      retroCarWebViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(retroCarCurrentUrl)),
      );
    });
  }

  Future<void> retroCarInitPushAndGetToken() async {
    final FirebaseMessaging retroCarFm = FirebaseMessaging.instance;

    // Реальный запрос разрешений
    final NotificationSettings retroCarSettings =
    await retroCarFm.getNotificationSettings();
    if (retroCarSettings.authorizationStatus ==
        AuthorizationStatus.notDetermined ||
        retroCarSettings.authorizationStatus ==
            AuthorizationStatus.denied) {
      await retroCarFm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    retroCarPushToken = await retroCarFm.getToken();

    // Обновляем состояние пушей в профиле устройства
    try {
      final NotificationSettings updatedSettings =
      await retroCarFm.getNotificationSettings();
      retroCarDeviceProfile.retroCarPushEnabled =
          updatedSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
              updatedSettings.authorizationStatus ==
                  AuthorizationStatus.provisional;
    } catch (_) {
      retroCarDeviceProfile.retroCarPushEnabled = false;
    }
  }

  // --------------------------------------------------------------------------
  // Привязка канала: тап по уведомлению из native
  // --------------------------------------------------------------------------

  void retroCarBindPlatformNotificationTap() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((MethodCall retroCarCall) async {
      if (retroCarCall.method == "onNotificationTap") {
        final Map<String, dynamic> retroCarPayload =
        Map<String, dynamic>.from(retroCarCall.arguments);
        debugPrint("URI from platform tap: ${retroCarPayload['uri']}");
        final String? retroCarUriString =
        retroCarPayload["uri"]?.toString();
        if (retroCarUriString != null &&
            !retroCarUriString.contains("Нет URI")) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder: (BuildContext retroCarContext) =>
                  RetroCarTableView(retroCarUriString),
            ),
                (Route<dynamic> retroCarRoute) => false,
          );
        }
      }
    });
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    retroCarBindPlatformNotificationTap();

    final bool retroCarIsDark =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: retroCarIsDark
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                disableDefaultErrorPage: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: true,
                useOnDownloadStart: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: true,
              ),
              initialUrlRequest: URLRequest(
                url: WebUri(retroCarCurrentUrl),
              ),
              onWebViewCreated:
                  (InAppWebViewController retroCarController) {
                retroCarWebViewController = retroCarController;

                retroCarWebViewController.addJavaScriptHandler(
                  handlerName: 'onServerResponse',
                  callback: (List<dynamic> retroCarArgs) {
                    retroCarVault.retroCarLogger.retroCarLogInfo(
                        "JS Args: $retroCarArgs");
                    try {
                      return retroCarArgs.reduce(
                            (dynamic retroCarV, dynamic retroCarE) =>
                        retroCarV + retroCarE,
                      );
                    } catch (_) {
                      return retroCarArgs.toString();
                    }
                  },
                );
              },
              onLoadStart: (
                  InAppWebViewController retroCarController,
                  Uri? retroCarUri,
                  ) async {
                retroCarStartLoadTimestamp =
                    DateTime.now().millisecondsSinceEpoch;

                if (retroCarUri != null) {
                  if (RetroCarKit.retroCarLooksLikeBareMail(
                      retroCarUri)) {
                    try {
                      await retroCarController.stopLoading();
                    } catch (_) {}
                    final Uri retroCarMailto =
                    RetroCarKit.retroCarToMailto(retroCarUri);
                    await RetroCarLinker.retroCarOpen(
                      RetroCarKit.retroCarGmailize(retroCarMailto),
                    );
                    return;
                  }

                  final String retroCarScheme =
                  retroCarUri.scheme.toLowerCase();
                  if (retroCarScheme != 'http' &&
                      retroCarScheme != 'https') {
                    try {
                      await retroCarController.stopLoading();
                    } catch (_) {}
                  }
                }
              },
              onLoadStop: (
                  InAppWebViewController retroCarController,
                  Uri? retroCarUri,
                  ) async {
                await retroCarController.evaluateJavascript(
                  source: "console.log('Hello from Roulette JS!');",
                );

                setState(() {
                  retroCarCurrentUrl =
                      retroCarUri?.toString() ?? retroCarCurrentUrl;
                });

                Future<void>.delayed(const Duration(seconds: 20), () {
                  retroCarSendLoadedOnce();
                });
              },
              shouldOverrideUrlLoading: (
                  InAppWebViewController retroCarController,
                  NavigationAction retroCarNav,
                  ) async {
                final Uri? retroCarUri = retroCarNav.request.url;
                if (retroCarUri == null) {
                  return NavigationActionPolicy.ALLOW;
                }

                if (RetroCarKit.retroCarLooksLikeBareMail(retroCarUri)) {
                  final Uri retroCarMailto =
                  RetroCarKit.retroCarToMailto(retroCarUri);
                  await RetroCarLinker.retroCarOpen(
                    RetroCarKit.retroCarGmailize(retroCarMailto),
                  );
                  return NavigationActionPolicy.CANCEL;
                }

                final String retroCarScheme =
                retroCarUri.scheme.toLowerCase();

                if (retroCarScheme == 'mailto') {
                  await RetroCarLinker.retroCarOpen(
                    RetroCarKit.retroCarGmailize(retroCarUri),
                  );
                  return NavigationActionPolicy.CANCEL;
                }

                if (retroCarScheme == 'tel') {
                  await launchUrl(
                    retroCarUri,
                    mode: LaunchMode.externalApplication,
                  );
                  return NavigationActionPolicy.CANCEL;
                }

                final String retroCarHost =
                retroCarUri.host.toLowerCase();
                final bool retroCarIsSocial =
                    retroCarHost.endsWith('facebook.com') ||
                        retroCarHost.endsWith('instagram.com') ||
                        retroCarHost.endsWith('twitter.com') ||
                        retroCarHost.endsWith('x.com');

                if (retroCarIsSocial) {
                  await RetroCarLinker.retroCarOpen(retroCarUri);
                  return NavigationActionPolicy.CANCEL;
                }

                if (retroCarIsExternalDestination(retroCarUri)) {
                  final Uri retroCarMapped =
                  retroCarMapExternalToHttp(retroCarUri);
                  await RetroCarLinker.retroCarOpen(retroCarMapped);
                  return NavigationActionPolicy.CANCEL;
                }

                if (retroCarScheme != 'http' &&
                    retroCarScheme != 'https') {
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (
                  InAppWebViewController retroCarController,
                  CreateWindowAction retroCarReq,
                  ) async {
                final Uri? retroCarUrl = retroCarReq.request.url;
                if (retroCarUrl == null) return false;

                if (RetroCarKit.retroCarLooksLikeBareMail(retroCarUrl)) {
                  final Uri retroCarMail =
                  RetroCarKit.retroCarToMailto(retroCarUrl);
                  await RetroCarLinker.retroCarOpen(
                    RetroCarKit.retroCarGmailize(retroCarMail),
                  );
                  return false;
                }

                final String retroCarScheme =
                retroCarUrl.scheme.toLowerCase();

                if (retroCarScheme == 'mailto') {
                  await RetroCarLinker.retroCarOpen(
                    RetroCarKit.retroCarGmailize(retroCarUrl),
                  );
                  return false;
                }

                if (retroCarScheme == 'tel') {
                  await launchUrl(
                    retroCarUrl,
                    mode: LaunchMode.externalApplication,
                  );
                  return false;
                }

                final String retroCarHost =
                retroCarUrl.host.toLowerCase();
                final bool retroCarIsSocial =
                    retroCarHost.endsWith('facebook.com') ||
                        retroCarHost.endsWith('instagram.com') ||
                        retroCarHost.endsWith('twitter.com') ||
                        retroCarHost.endsWith('x.com');

                if (retroCarIsSocial) {
                  await RetroCarLinker.retroCarOpen(retroCarUrl);
                  return false;
                }

                if (retroCarIsExternalDestination(retroCarUrl)) {
                  final Uri retroCarMapped =
                  retroCarMapExternalToHttp(retroCarUrl);
                  await RetroCarLinker.retroCarOpen(retroCarMapped);
                  return false;
                }

                if (retroCarScheme == 'http' ||
                    retroCarScheme == 'https') {
                  retroCarController.loadUrl(
                    urlRequest:
                    URLRequest(url: WebUri(retroCarUrl.toString())),
                  );
                }

                return false;
              },
            ),
            if (retroCarOverlayBusy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black87,
                  child: Center(
                    child: RetroCarNeonLoader(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // Внешние “столы” (протоколы/мессенджеры/соцсети)
  // ========================================================================

  bool retroCarIsExternalDestination(Uri retroCarUri) {
    final String retroCarScheme =
    retroCarUri.scheme.toLowerCase();
    if (retroCarExternalSchemes.contains(retroCarScheme)) {
      return true;
    }

    if (retroCarScheme == 'http' || retroCarScheme == 'https') {
      final String retroCarHost =
      retroCarUri.host.toLowerCase();
      if (retroCarExternalHosts.contains(retroCarHost)) {
        return true;
      }
      if (retroCarHost.endsWith('t.me')) return true;
      if (retroCarHost.endsWith('wa.me')) return true;
      if (retroCarHost.endsWith('m.me')) return true;
      if (retroCarHost.endsWith('signal.me')) return true;
      if (retroCarHost.endsWith('facebook.com')) return true;
      if (retroCarHost.endsWith('instagram.com')) return true;
      if (retroCarHost.endsWith('twitter.com')) return true;
      if (retroCarHost.endsWith('x.com')) return true;
    }

    return false;
  }

  Uri retroCarMapExternalToHttp(Uri retroCarUri) {
    final String retroCarScheme =
    retroCarUri.scheme.toLowerCase();

    if (retroCarScheme == 'tg' || retroCarScheme == 'telegram') {
      final Map<String, String> retroCarQp =
          retroCarUri.queryParameters;
      final String? retroCarDomain = retroCarQp['domain'];
      if (retroCarDomain != null && retroCarDomain.isNotEmpty) {
        return Uri.https(
          't.me',
          '/$retroCarDomain',
          <String, String>{
            if (retroCarQp['start'] != null)
              'start': retroCarQp['start']!,
          },
        );
      }
      final String retroCarPath =
      retroCarUri.path.isNotEmpty ? retroCarUri.path : '';
      return Uri.https(
        't.me',
        '/$retroCarPath',
        retroCarUri.queryParameters.isEmpty
            ? null
            : retroCarUri.queryParameters,
      );
    }

    if (retroCarScheme == 'whatsapp') {
      final Map<String, String> retroCarQp =
          retroCarUri.queryParameters;
      final String? retroCarPhone = retroCarQp['phone'];
      final String? retroCarText = retroCarQp['text'];
      if (retroCarPhone != null && retroCarPhone.isNotEmpty) {
        return Uri.https(
          'wa.me',
          '/${RetroCarKit.retroCarDigitsOnly(retroCarPhone)}',
          <String, String>{
            if (retroCarText != null && retroCarText.isNotEmpty)
              'text': retroCarText,
          },
        );
      }
      return Uri.https(
        'wa.me',
        '/',
        <String, String>{
          if (retroCarText != null && retroCarText.isNotEmpty)
            'text': retroCarText,
        },
      );
    }

    if (retroCarScheme == 'bnl') {
      final String retroCarNewPath =
      retroCarUri.path.isNotEmpty ? retroCarUri.path : '';
      return Uri.https(
        'bnl.com',
        '/$retroCarNewPath',
        retroCarUri.queryParameters.isEmpty
            ? null
            : retroCarUri.queryParameters,
      );
    }

    return retroCarUri;
  }

  Future<void> retroCarSendLoadedOnce() async {
    if (retroCarLoadedOnceSent) {
      debugPrint('Wheel Loaded already sent, skip');
      return;
    }

    final int retroCarNow = DateTime.now().millisecondsSinceEpoch;

    await retroCarPostStat(
      event: 'Loaded',
      timeStart: retroCarStartLoadTimestamp,
      timeFinish: retroCarNow,
      url: retroCarCurrentUrl,
      appSid: retroCarSpy.retroCarAppsFlyerUid,
      firstPageTs: retroCarFirstPageTimestamp,
    );

    retroCarLoadedOnceSent = true;
  }
}