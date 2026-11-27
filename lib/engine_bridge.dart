import 'package:flutter/services.dart';

class AppRuleModel {
  final String appId;
  final String name;
  final bool blockReels;
  final int dailyReelLimitSec;
  final int dailyReelCountLimit;
  final bool blockWholeApp;
  final int dailyAppLimitSec;
  final int usedAppSec;
  final int usedReelSec;
  final int usedReelCount;

  const AppRuleModel({
    required this.appId,
    required this.name,
    required this.blockReels,
    required this.dailyReelLimitSec,
    required this.dailyReelCountLimit,
    required this.blockWholeApp,
    required this.dailyAppLimitSec,
    required this.usedAppSec,
    this.usedReelSec = 0,
    this.usedReelCount = 0,
  });

  factory AppRuleModel.fromMap(Map<dynamic, dynamic> m) {
    return AppRuleModel(
      appId: (m['appId'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      blockReels: (m['blockReels'] as bool?) ?? true,
      dailyReelLimitSec: (m['dailyReelLimitSec'] as int?) ?? 0,
      dailyReelCountLimit: (m['dailyReelCountLimit'] as int?) ?? 0,
      blockWholeApp: (m['blockWholeApp'] as bool?) ?? false,
      dailyAppLimitSec: (m['dailyAppLimitSec'] as int?) ?? 1800,
      usedAppSec: (m['usedAppSec'] as int?) ?? 0,
      usedReelSec: (m['usedReelSec'] as int?) ?? 0,
      usedReelCount: (m['usedReelCount'] as int?) ?? 0,
    );
  }
}

class DailyStatModel {
  final String date;
  final String dayLabel;
  final int reelsCount;
  final int reelsSec;

  const DailyStatModel({
    required this.date,
    required this.dayLabel,
    required this.reelsCount,
    required this.reelsSec,
  });

  factory DailyStatModel.fromMap(Map<dynamic, dynamic> m) {
    return DailyStatModel(
      date: (m['date'] as String?) ?? '',
      dayLabel: (m['dayLabel'] as String?) ?? '',
      reelsCount: (m['reelsCount'] as int?) ?? 0,
      reelsSec: (m['reelsSec'] as int?) ?? 0,
    );
  }
}

class EngineState {
  final int todayReelsCount;
  final int todayReelsSec;
  final int lifetimeReelsCount;
  final int lifetimeReelsSec;
  final int lifetimeBlockedCount;
  final int lifetimeSavedSec;
  final String compactStatus;
  final bool allowDmReels;
  final String statusBarMode; // PERMANENT, FEED_ONLY, OFF
  final bool statusBarNotification;
  final bool strictUninstallLock;
  final int emergencyUnlockUntilMs;
  final bool isEmergencyUnlockActive;
  final int walkTargetSteps;
  final bool lightMode;
  final String themeId;
  final String fontFamily;
  final double cardTitleSize;
  final double cardBodySize;
  final double uiTextScale;
  final bool isGridView;
  final bool isAccessibilityEnabled;
  final bool isDeviceAdminEnabled;
  final bool isBatteryUnrestricted;
  final bool openEmergencyChallenge;
  final bool forUninstallUnlock;
  final List<AppRuleModel> rules;
  final List<DailyStatModel> dailyHistory;

  int get total7DayReels =>
      dailyHistory.isEmpty
          ? todayReelsCount
          : dailyHistory.fold(0, (sum, d) => sum + d.reelsCount);

  int get total7DaySec =>
      dailyHistory.isEmpty
          ? todayReelsSec
          : dailyHistory.fold(0, (sum, d) => sum + d.reelsSec);

  double get avg7DayReels =>
      dailyHistory.isEmpty
          ? todayReelsCount.toDouble()
          : total7DayReels / dailyHistory.length;

  int get avg7DaySec =>
      dailyHistory.isEmpty
          ? todayReelsSec
          : (total7DaySec / dailyHistory.length).round();

  const EngineState({
    this.todayReelsCount = 0,
    this.todayReelsSec = 0,
    this.lifetimeReelsCount = 0,
    this.lifetimeReelsSec = 0,
    this.lifetimeBlockedCount = 0,
    this.lifetimeSavedSec = 0,
    this.compactStatus = '0r · 0s',
    this.allowDmReels = true,
    this.statusBarMode = 'PERMANENT',
    this.statusBarNotification = true,
    this.strictUninstallLock = false,
    this.emergencyUnlockUntilMs = 0,
    this.isEmergencyUnlockActive = false,
    this.walkTargetSteps = 200,
    this.lightMode = true,
    this.themeId = 'pure_light',
    this.fontFamily = 'plus_jakarta_sans',
    this.cardTitleSize = 20.0,
    this.cardBodySize = 14.0,
    this.uiTextScale = 1.0,
    this.isGridView = false,
    this.isAccessibilityEnabled = false,
    this.isDeviceAdminEnabled = false,
    this.isBatteryUnrestricted = true,
    this.openEmergencyChallenge = false,
    this.forUninstallUnlock = false,
    this.dailyHistory = const [
      DailyStatModel(date: '2026-11-21', dayLabel: 'Sat', reelsCount: 0, reelsSec: 0),
      DailyStatModel(date: '2026-11-22', dayLabel: 'Sun', reelsCount: 0, reelsSec: 0),
      DailyStatModel(date: '2026-11-23', dayLabel: 'Mon', reelsCount: 0, reelsSec: 0),
      DailyStatModel(date: '2026-11-24', dayLabel: 'Tue', reelsCount: 0, reelsSec: 0),
      DailyStatModel(date: '2026-11-25', dayLabel: 'Wed', reelsCount: 0, reelsSec: 0),
      DailyStatModel(date: '2026-11-26', dayLabel: 'Thu', reelsCount: 0, reelsSec: 0),
      DailyStatModel(date: '2026-11-27', dayLabel: 'Today', reelsCount: 0, reelsSec: 0),
    ],
    this.rules = const [
      AppRuleModel(
        appId: 'youtube',
        name: 'YouTube',
        blockReels: true,
        dailyReelLimitSec: 0,
        dailyReelCountLimit: 0,
        blockWholeApp: false,
        dailyAppLimitSec: 1800,
        usedAppSec: 0,
      ),
      AppRuleModel(
        appId: 'instagram',
        name: 'Instagram',
        blockReels: true,
        dailyReelLimitSec: 0,
        dailyReelCountLimit: 0,
        blockWholeApp: false,
        dailyAppLimitSec: 1800,
        usedAppSec: 0,
      ),
      AppRuleModel(
        appId: 'facebook',
        name: 'Facebook',
        blockReels: true,
        dailyReelLimitSec: 0,
        dailyReelCountLimit: 0,
        blockWholeApp: false,
        dailyAppLimitSec: 1800,
        usedAppSec: 0,
      ),
      AppRuleModel(
        appId: 'tiktok',
        name: 'TikTok',
        blockReels: true,
        dailyReelLimitSec: 0,
        dailyReelCountLimit: 0,
        blockWholeApp: false,
        dailyAppLimitSec: 1800,
        usedAppSec: 0,
      ),
    ],
  });

  factory EngineState.fromMap(Map<dynamic, dynamic> m) {
    final rawRules = (m['rules'] as List<dynamic>?) ?? const [];
    final parsedRules = rawRules
        .whereType<Map<dynamic, dynamic>>()
        .map(AppRuleModel.fromMap)
        .toList();
    final rawHistory = (m['dailyHistory'] as List<dynamic>?) ?? const [];
    final parsedHistory = rawHistory
        .whereType<Map<dynamic, dynamic>>()
        .map(DailyStatModel.fromMap)
        .toList();
    return EngineState(
      todayReelsCount: (m['todayReelsCount'] as int?) ?? 0,
      todayReelsSec: (m['todayReelsSec'] as int?) ?? 0,
      lifetimeReelsCount: (m['lifetimeReelsCount'] as int?) ?? 0,
      lifetimeReelsSec: (m['lifetimeReelsSec'] as int?) ?? 0,
      lifetimeBlockedCount: (m['lifetimeBlockedCount'] as int?) ?? 0,
      lifetimeSavedSec: (m['lifetimeSavedSec'] as int?) ?? 0,
      compactStatus: (m['compactStatus'] as String?) ?? '0r · 0s',
      allowDmReels: (m['allowDmReels'] as bool?) ?? true,
      statusBarMode: (m['statusBarMode'] as String?) ?? 'PERMANENT',
      statusBarNotification: (m['statusBarNotification'] as bool?) ?? true,
      strictUninstallLock: (m['strictUninstallLock'] as bool?) ?? false,
      emergencyUnlockUntilMs: (m['emergencyUnlockUntilMs'] as int?) ?? 0,
      isEmergencyUnlockActive: (m['isEmergencyUnlockActive'] as bool?) ?? false,
      walkTargetSteps: (m['walkTargetSteps'] as int?) ?? 200,
      lightMode: (m['lightMode'] as bool?) ?? true,
      themeId: (m['themeId'] as String?) ?? 'pure_light',
      fontFamily: (m['fontFamily'] as String?) ?? 'plus_jakarta_sans',
      cardTitleSize: ((m['cardTitleSize'] as num?) ?? 20.0).toDouble(),
      cardBodySize: ((m['cardBodySize'] as num?) ?? 14.0).toDouble(),
      uiTextScale: ((m['uiTextScale'] as num?) ?? 1.0).toDouble(),
      isGridView: (m['isGridView'] as bool?) ?? false,
      isAccessibilityEnabled: (m['isAccessibilityEnabled'] as bool?) ?? false,
      isDeviceAdminEnabled: (m['isDeviceAdminEnabled'] as bool?) ?? false,
      isBatteryUnrestricted: (m['isBatteryUnrestricted'] as bool?) ?? true,
      openEmergencyChallenge: (m['openEmergencyChallenge'] as bool?) ?? false,
      forUninstallUnlock: (m['forUninstallUnlock'] as bool?) ?? false,
      rules: parsedRules.isNotEmpty ? parsedRules : const EngineState().rules,
      dailyHistory: parsedHistory.isNotEmpty
          ? parsedHistory
          : const EngineState().dailyHistory,
    );
  }
}

class EngineBridge {
  static const MethodChannel _ch = MethodChannel('com.nodoom/engine');

  static void setListeners({
    void Function(int steps)? onWalkStep,
    void Function(bool forUninstall)? onOpenEmergencyChallenge,
  }) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onWalkStep') {
        final steps = (call.arguments as int?) ?? 0;
        onWalkStep?.call(steps);
      } else if (call.method == 'onOpenEmergencyChallenge') {
        final forUninstall = (call.arguments as bool?) ?? false;
        onOpenEmergencyChallenge?.call(forUninstall);
      }
    });
  }

  static Future<EngineState> getState() async {
    try {
      final res = await _ch.invokeMapMethod<dynamic, dynamic>('getState');
      if (res != null) return EngineState.fromMap(res);
    } catch (_) {}
    return const EngineState();
  }

  static Future<EngineState> updateRule({
    required String appId,
    bool? blockReels,
    int? dailyReelLimitSec,
    int? dailyReelCountLimit,
    bool? blockWholeApp,
    int? dailyAppLimitSec,
  }) async {
    try {
      final res = await _ch.invokeMapMethod<dynamic, dynamic>('updateRule', {
        'appId': appId,
        'blockReels': ?blockReels,
        'dailyReelLimitSec': ?dailyReelLimitSec,
        'dailyReelCountLimit': ?dailyReelCountLimit,
        'blockWholeApp': ?blockWholeApp,
        'dailyAppLimitSec': ?dailyAppLimitSec,
      });
      if (res != null) return EngineState.fromMap(res);
    } catch (_) {}
    return getState();
  }

  static Future<EngineState> updateSettings({
    bool? allowDmReels,
    String? statusBarMode,
    bool? statusBarNotification,
    bool? strictUninstallLock,
    int? walkTargetSteps,
    bool? lightMode,
    String? themeId,
    String? fontFamily,
    double? cardTitleSize,
    double? cardBodySize,
    double? uiTextScale,
    bool? isGridView,
  }) async {
    try {
      final res = await _ch.invokeMapMethod<dynamic, dynamic>('updateSettings', {
        'allowDmReels': ?allowDmReels,
        'statusBarMode': ?statusBarMode,
        'statusBarNotification': ?statusBarNotification,
        'strictUninstallLock': ?strictUninstallLock,
        'walkTargetSteps': ?walkTargetSteps,
        'lightMode': ?lightMode,
        'themeId': ?themeId,
        'fontFamily': ?fontFamily,
        'cardTitleSize': ?cardTitleSize,
        'cardBodySize': ?cardBodySize,
        'uiTextScale': ?uiTextScale,
        'isGridView': ?isGridView,
      });
      if (res != null) return EngineState.fromMap(res);
    } catch (_) {}
    return getState();
  }

  static Future<EngineState> grantEmergencyUnlock({
    int minutes = 5,
    bool deactivateAdmin = false,
  }) async {
    try {
      final res = await _ch.invokeMapMethod<dynamic, dynamic>(
        'grantEmergencyUnlock',
        {
          'minutes': minutes,
          'deactivateAdmin': deactivateAdmin,
        },
      );
      if (res != null) return EngineState.fromMap(res);
    } catch (_) {}
    return getState();
  }

  static Future<EngineState> lockNow() async {
    try {
      final res = await _ch.invokeMapMethod<dynamic, dynamic>('lockNow');
      if (res != null) return EngineState.fromMap(res);
    } catch (_) {}
    return getState();
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _ch.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  static Future<void> requestDeviceAdmin() async {
    try {
      await _ch.invokeMethod('requestDeviceAdmin');
    } catch (_) {}
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _ch.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  static Future<bool> startWalkSensor() async {
    try {
      final ok = await _ch.invokeMethod<bool>('startWalkSensor');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopWalkSensor() async {
    try {
      await _ch.invokeMethod('stopWalkSensor');
    } catch (_) {}
  }
}
