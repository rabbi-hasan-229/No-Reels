import 'dart:async';
import 'package:flutter/material.dart';
import '../challenges/challenge_logic.dart';
import '../engine_bridge.dart';
import '../theme/app_theme.dart';
import '../widgets/connected_pill_item.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  EngineState _state = const EngineState();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final s = await EngineBridge.getState();
    if (!mounted) return;
    setState(() => _state = s);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppUiController.instance,
      builder: (context, _) {
        final palette = AppUiController.instance.palette;
        final textPrimary = palette.textPrimary;
        final textSecondary = palette.textSecondary;

        final avgSec = _state.avg7DaySec;
        final avgReels = _state.avg7DayReels;
        final isBelowOrEqualAvg = _state.todayReelsSec <= avgSec;

        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Bar ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          AppHaptics.light();
                          Navigator.of(context).maybePop();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.surface2,
                            border: Border.all(
                              color: palette.border,
                              width: 1.1,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 17,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Performance',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                    children: [
                      // ── 1. TODAY'S PERFORMANCE HERO CARD ────────────────
                      Container(
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
                                Text(
                                  "TODAY'S PERFORMANCE",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: palette.textMuted,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isBelowOrEqualAvg
                                                ? AppColors.success
                                                : AppColors.warning)
                                            .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isBelowOrEqualAvg
                                        ? 'On Track vs 7d Avg'
                                        : 'Above 7d Avg',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isBelowOrEqualAvg
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_state.todayReelsCount}',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Reels Today',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: palette.border,
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatDurationCompact(
                                          _state.todayReelsSec,
                                        ),
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Wasted Today',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
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

                      const SizedBox(height: 14),

                      // ── 2. LAST 7-DAY AVERAGE & TOTALS ──────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _MetricBentoBox(
                              palette: palette,
                              label: '7-DAY AVG REELS',
                              value: '${avgReels.toStringAsFixed(1)} / day',
                              sub: '${_state.total7DayReels} total in 7d',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricBentoBox(
                              palette: palette,
                              label: '7-DAY AVG TIME',
                              value: '${formatDurationCompact(avgSec)} / day',
                              sub:
                                  '${formatDurationCompact(_state.total7DaySec)} total in 7d',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── 2.5. MINIMAL LIFETIME CARD ──────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: palette.border, width: 1.1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'LIFETIME',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: palette.textMuted,
                                  ),
                                ),
                                Text(
                                  '${_state.lifetimeBlockedCount} dodged • ${formatDurationCompact(_state.lifetimeSavedSec)} saved',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_state.lifetimeReelsCount}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Total Reels',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: palette.border,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatDurationCompact(
                                          _state.lifetimeReelsSec,
                                        ),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Total Wasted',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
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

                      const SizedBox(height: 14),

                      // ── 3. LAST 7 DAYS BAR CHART ────────────────────────
                      _build7DayChartCard(palette),

                      const SizedBox(height: 20),

                      // ── 4. TODAY'S PLATFORM BREAKDOWN ───────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          "TODAY'S PLATFORM USAGE",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final rule in _state.rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildPlatformUsageRow(palette, rule),
                        ),

                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _build7DayChartCard(AppThemePalette palette) {
    final days = _state.dailyHistory;
    final maxSec = days.fold<int>(
      60,
      (prev, e) => e.reelsSec > prev ? e.reelsSec : prev,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 7 DAYS TREND',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final isToday = d.dayLabel == 'Today';
                        final ratio = maxSec > 0
                            ? (d.reelsSec / maxSec).clamp(0.0, 1.0)
                            : 0.0;
                        final barHeight = 10.0 + (ratio * 76.0);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${d.reelsCount}r',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isToday
                                    ? palette.textPrimary
                                    : palette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 24,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? palette.primary
                                    : palette.surface2,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isToday
                                      ? palette.primary
                                      : palette.border,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              d.dayLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isToday
                                    ? palette.textPrimary
                                    : palette.textSecondary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformUsageRow(AppThemePalette palette, AppRuleModel rule) {
    final limitSec = rule.dailyReelLimitSec;
    final usedSec = rule.usedReelSec;
    final progress = limitSec > 0
        ? (usedSec / limitSec).clamp(0.0, 1.0)
        : (usedSec > 0 ? 1.0 : 0.0);

    final limitText = limitSec > 0
        ? '${limitSec ~/ 60}m limit'
        : '0m (Blocked)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border, width: 1.1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PlatformBrandLogo(appId: rule.appId, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      '${rule.usedReelCount} videos • App open ${formatDurationCompact(rule.usedAppSec)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${formatDurationCompact(usedSec)} / $limitText',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: palette.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBentoBox extends StatelessWidget {
  const _MetricBentoBox({
    required this.palette,
    required this.label,
    required this.value,
    required this.sub,
  });

  final AppThemePalette palette;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
