import 'dart:async';
import 'package:flutter/material.dart';
import '../challenges/challenge_logic.dart';
import '../engine_bridge.dart';
import '../theme/app_theme.dart';
import '../widgets/connected_pill_item.dart';
import 'emergency_challenge_screen.dart';
import 'performance_screen.dart';
import 'settings_screen.dart';
import 'uninstall_emotional_flow_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  EngineState _state = const EngineState();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EngineBridge.setListeners(
      onOpenEmergencyChallenge: (forUninstall) =>
          _openEmergencyChallenge(forUninstall: forUninstall),
    );
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final s = await EngineBridge.getState();
    if (!mounted) return;
    AppUiController.instance.syncFromEngineState(s);
    setState(() => _state = s);
    if (s.openEmergencyChallenge) {
      _openEmergencyChallenge(forUninstall: s.forUninstallUnlock);
    }
  }

  bool get _isLockedByStrictMode =>
      _state.strictUninstallLock && !_state.isEmergencyUnlockActive;

  Future<bool> _requireChallengeIfLocked({bool forUninstall = false}) async {
    if (!_isLockedByStrictMode && !forUninstall) return true;
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmergencyChallengeScreen(
          walkTargetSteps: _state.walkTargetSteps,
          forUninstallUnlock: forUninstall,
          isLight: !AppUiController.instance.palette.isDark,
        ),
      ),
    );
    await _refresh();
    return passed == true;
  }

  Future<void> _openEmergencyChallenge({bool forUninstall = false}) async {
    if (forUninstall) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => UninstallEmotionalFlowScreen(state: _state),
        ),
      );
      await _refresh();
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmergencyChallengeScreen(
          walkTargetSteps: _state.walkTargetSteps,
          forUninstallUnlock: false,
          isLight: !AppUiController.instance.palette.isDark,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _openPerformanceScreen() async {
    AppHaptics.light();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PerformanceScreen()));
    await _refresh();
  }

  Future<bool> _confirmLimitEntireApp(
    AppThemePalette palette,
    String appName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.border),
        ),
        title: Text(
          'Limit Entire $appName App?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to block the entire $appName app once its daily time limit is reached?',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: palette.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Yes, Limit App',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppUiController.instance,
      builder: (context, _) {
        final ui = AppUiController.instance;
        final palette = ui.palette;
        final fontSettings = ui.fontSettings;
        final allPermissionsReady =
            _state.isAccessibilityEnabled && _state.isDeviceAdminEnabled;

        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header ───────────────────────────────────────────
                _buildHomeHeader(palette),

                // ── Main Content ScrollView ──────────────────────────────
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 115),
                    children: [
                      // 1. Daily Exposure Hero Card (Tap to open Performance Screen)
                      _buildDailyExposureHeroCard(palette, fontSettings),

                      if (!allPermissionsReady) ...[
                        const SizedBox(height: 14),
                        _buildHardwareSetupBanner(palette),
                      ],

                      const SizedBox(height: 22),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'PLATFORMS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2. Clean Platform List Cards with Original Brand Logos
                      for (int i = 0; i < _state.rules.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildPlatformCard(
                            palette: palette,
                            rule: _state.rules[i],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _buildFloatingBottomDock(palette),
        );
      },
    );
  }

  // ── Top Header ───────────────────────────────────────────────────────────
  Widget _buildHomeHeader(AppThemePalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp20,
        vertical: AppTheme.sp12,
      ),
      child: Row(
        children: [
          AppLogo(isDark: palette.isDark, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No-Reels',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: palette.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: _openPerformanceScreen,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.border, width: 1.1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 16,
                    color: palette.textPrimary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Performance',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Daily Exposure Summary Card ─────────────────────────────────────
  Widget _buildDailyExposureHeroCard(
    AppThemePalette palette,
    FontSettings fontSettings,
  ) {
    final textColor = palette.textPrimary;
    final subColor = palette.textSecondary;

    final unlockRemainingSec =
        ((_state.emergencyUnlockUntilMs -
                    DateTime.now().millisecondsSinceEpoch) ~/
                1000)
            .clamp(0, 86400);

    return GestureDetector(
      onTap: _openPerformanceScreen,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.border, width: 1.1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _state.isEmergencyUnlockActive
                              ? AppColors.warning
                              : (_state.strictUninstallLock
                                    ? AppColors.success
                                    : palette.primary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _state.isEmergencyUnlockActive
                            ? 'Unlocked • ${formatDurationCompact(unlockRemainingSec)} left'
                            : (_state.strictUninstallLock
                                  ? 'Strict Lock Active'
                                  : 'Guard Active'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_state.isEmergencyUnlockActive)
                  GestureDetector(
                    onTap: () async {
                      AppHaptics.medium();
                      final next = await EngineBridge.lockNow();
                      if (mounted) setState(() => _state = next);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Relock',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '7d Avg: ${formatDurationCompact(_state.avg7DaySec)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: subColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: subColor,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_state.todayReelsCount}',
                        style: fontSettings.fontFamily.getTextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          height: 1.1,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reels Watched Today',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: palette.border,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDurationCompact(_state.todayReelsSec),
                        style: fontSettings.fontFamily.getTextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          height: 1.15,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time Wasted Today',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareSetupBanner(AppThemePalette palette) {
    return GestureDetector(
      onTap: () async {
        AppHaptics.light();
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        await _refresh();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.6),
            width: 1.1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 19,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable Protection Permissions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Turn on Accessibility & Device Admin in Settings',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── Clean Minimal Platform Card with Original Brand Logo & Progress Bar ──
  Widget _buildPlatformCard({
    required AppThemePalette palette,
    required AppRuleModel rule,
  }) {
    final reelMin = rule.dailyReelLimitSec ~/ 60;
    final appMin = rule.dailyAppLimitSec ~/ 60;

    final String shortTarget = switch (rule.appId) {
      'youtube' => 'Shorts',
      'tiktok' => 'Videos',
      _ => 'Reels',
    };

    final parts = <String>[];
    if (!rule.blockReels) {
      parts.add('$shortTarget allowed');
    } else if (reelMin == 0 && rule.dailyReelCountLimit == 0) {
      parts.add('$shortTarget blocked');
    } else {
      if (reelMin > 0) {
        parts.add(
          '${formatDurationCompact(rule.usedReelSec)} / ${reelMin}m',
        );
      }
      if (rule.dailyReelCountLimit > 0) {
        parts.add('${rule.usedReelCount}/${rule.dailyReelCountLimit} videos');
      }
    }
    if (rule.blockWholeApp) {
      parts.add('App limit ${appMin}m');
    }
    final statusSummary = parts.join(' • ');

    final double reelProgress = rule.dailyReelLimitSec > 0
        ? (rule.usedReelSec / rule.dailyReelLimitSec).clamp(0.0, 1.0)
        : (rule.blockReels ? 1.0 : 0.0);

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        _showPlatformConfigSheet(palette, rule);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.border, width: 1.1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                PlatformBrandLogo(appId: rule.appId, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: rule.blockReels,
                  activeTrackColor: palette.primary,
                  onChanged: (v) async {
                    AppHaptics.selection();
                    if (!v && !await _requireChallengeIfLocked()) {
                      return;
                    }
                    final next = await EngineBridge.updateRule(
                      appId: rule.appId,
                      blockReels: v,
                    );
                    if (mounted) setState(() => _state = next);
                  },
                ),
              ],
            ),
            if (rule.dailyReelLimitSec > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: reelProgress,
                  minHeight: 4,
                  backgroundColor: palette.surface2,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Clean, Minimal Platform Setup Bottom Sheet ───────────────────────────
  Future<void> _showPlatformConfigSheet(
    AppThemePalette palette,
    AppRuleModel initialRule,
  ) async {
    const reelMinutes = [0, 5, 15, 30, 60];
    const countCaps = [0, 15, 30, 50, 100];
    const appLimits = [15, 30, 60, 120];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final rule = _state.rules.firstWhere(
              (r) => r.appId == initialRule.appId,
              orElse: () => initialRule,
            );
            final currentReelMin = rule.dailyReelLimitSec ~/ 60;
            final currentAppMin = rule.dailyAppLimitSec ~/ 60;
            final shortTarget = switch (rule.appId) {
              'youtube' => 'Shorts',
              'tiktok' => 'Videos',
              _ => 'Reels',
            };

            final progress = rule.dailyReelLimitSec > 0
                ? (rule.usedReelSec / rule.dailyReelLimitSec).clamp(0.0, 1.0)
                : (rule.blockReels ? 1.0 : 0.0);

            final progressLabel = currentReelMin > 0
                ? '${formatDurationCompact(rule.usedReelSec)} / ${currentReelMin}m finished'
                : (rule.blockReels
                      ? '${formatDurationCompact(rule.usedReelSec)} used • 0m (Instant Block)'
                      : '${formatDurationCompact(rule.usedReelSec)} used • Unrestricted');

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header Row: Original Brand Logo + App Name + Toggle
                    Row(
                      children: [
                        PlatformBrandLogo(appId: rule.appId, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rule.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: palette.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Block $shortTarget',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: rule.blockReels,
                          activeTrackColor: palette.primary,
                          onChanged: (v) async {
                            AppHaptics.selection();
                            if (!v && !await _requireChallengeIfLocked()) {
                              return;
                            }
                            final next = await EngineBridge.updateRule(
                              appId: rule.appId,
                              blockReels: v,
                            );
                            if (mounted) {
                              setState(() => _state = next);
                              setSheetState(() {});
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Minimal Daily Reels Time Progress Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daily $shortTarget Usage',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textSecondary,
                                ),
                              ),
                              Text(
                                progressLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: palette.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                palette.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 1. Daily Time Allowance
                    Text(
                      'Daily $shortTarget Time',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (int i = 0; i < reelMinutes.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _OptionPill(
                              palette: palette,
                              label: reelMinutes[i] == 0
                                  ? 'Block'
                                  : '${reelMinutes[i]}m',
                              selected: currentReelMin == reelMinutes[i],
                              onTap: () async {
                                AppHaptics.selection();
                                final m = reelMinutes[i];
                                if (m > currentReelMin &&
                                    !await _requireChallengeIfLocked()) {
                                  return;
                                }
                                final next = await EngineBridge.updateRule(
                                  appId: rule.appId,
                                  dailyReelLimitSec: m * 60,
                                );
                                if (mounted) {
                                  setState(() => _state = next);
                                  setSheetState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 2. Daily Video Count Limit
                    Text(
                      'Daily Video Limit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (int i = 0; i < countCaps.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _OptionPill(
                              palette: palette,
                              label: countCaps[i] == 0
                                  ? 'None'
                                  : '${countCaps[i]}',
                              selected:
                                  rule.dailyReelCountLimit == countCaps[i],
                              onTap: () async {
                                AppHaptics.selection();
                                final cap = countCaps[i];
                                if ((cap == 0 ||
                                        cap > rule.dailyReelCountLimit) &&
                                    rule.dailyReelCountLimit > 0 &&
                                    !await _requireChallengeIfLocked()) {
                                  return;
                                }
                                final next = await EngineBridge.updateRule(
                                  appId: rule.appId,
                                  dailyReelCountLimit: cap,
                                );
                                if (mounted) {
                                  setState(() => _state = next);
                                  setSheetState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 18),
                    Divider(color: palette.border, height: 1),
                    const SizedBox(height: 14),

                    // 3. Full App Daily Limit (With "Are You Sure?" Confirmation Popup)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Limit Entire App',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        Switch.adaptive(
                          value: rule.blockWholeApp,
                          activeTrackColor: palette.primary,
                          onChanged: (v) async {
                            AppHaptics.selection();
                            if (v) {
                              final sure = await _confirmLimitEntireApp(
                                palette,
                                rule.name,
                              );
                              if (!sure) return;
                            } else {
                              if (!await _requireChallengeIfLocked()) {
                                return;
                              }
                            }
                            final next = await EngineBridge.updateRule(
                              appId: rule.appId,
                              blockWholeApp: v,
                            );
                            if (mounted) {
                              setState(() => _state = next);
                              setSheetState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    if (rule.blockWholeApp) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (int i = 0; i < appLimits.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _OptionPill(
                                palette: palette,
                                label: '${appLimits[i]}m',
                                selected: currentAppMin == appLimits[i],
                                onTap: () async {
                                  AppHaptics.selection();
                                  final m = appLimits[i];
                                  if (m > currentAppMin &&
                                      !await _requireChallengeIfLocked()) {
                                    return;
                                  }
                                  final next = await EngineBridge.updateRule(
                                    appId: rule.appId,
                                    dailyAppLimitSec: m * 60,
                                  );
                                  if (mounted) {
                                    setState(() => _state = next);
                                    setSheetState(() {});
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Full-Width Bottom Bar (Same Horizontal Width as Platform Cards) ──────
  Widget _buildFloatingBottomDock(AppThemePalette palette) {
    final isDark = palette.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: palette.border, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Unlock Button (Expanded to half of card width)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  _openEmergencyChallenge(forUninstall: false);
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_open_rounded,
                        color: palette.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Unlock',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 26,
              width: 1,
              color: palette.border,
            ),
            // Right: Settings Button (Expanded to half of card width)
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  AppHaptics.medium();
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  await _refresh();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: palette.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppThemePalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? palette.onPrimary : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}
