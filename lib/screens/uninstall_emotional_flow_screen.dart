import 'package:flutter/material.dart';
import '../challenges/challenge_logic.dart';
import '../engine_bridge.dart';
import '../theme/app_theme.dart';
import 'emergency_challenge_screen.dart';

/// Multi-stage emotional reality-check journey shown when the user attempts
/// to turn off Strict Uninstall Lock or uninstall No-Reels:
///
/// Stage 0: Overview of how much time & life the user has saved by using No-Reels.
/// Stage 1: "What is your reason to uninstall?" (funny yet concerning options).
/// Stage 2: "Why are Reels more important than your life?" (similar reflective questions).
/// Stage 3: Final reflection with the "Let me destroy my valuable times" button
///          that opens the Unlock Protection challenge screen.
class UninstallEmotionalFlowScreen extends StatefulWidget {
  final EngineState state;

  const UninstallEmotionalFlowScreen({
    super.key,
    required this.state,
  });

  @override
  State<UninstallEmotionalFlowScreen> createState() =>
      _UninstallEmotionalFlowScreenState();
}

class _UninstallEmotionalFlowScreenState
    extends State<UninstallEmotionalFlowScreen> {
  int _stage = 0; // 0, 1, 2, 3
  int? _selectedReasonIndex;
  int? _selectedWhyReelsIndex;

  static const List<(String, String)> _uninstallReasons = [
    (
      'I want to destroy my time',
      'I miss scrolling for 3 hours at 2 AM for zero reason.',
    ),
    (
      'I hate my life & focus',
      'Peace of mind is boring, give me cheap 15-second dopamine.',
    ),
    (
      'My life, My rules',
      'Even if my rule is letting an algorithm control my thumb.',
    ),
    (
      'My thumb feels lonely',
      'It forgot how to swipe up 500 times every night.',
    ),
    (
      'I want brain rot back',
      'My attention span was starting to heal and it scared me.',
    ),
  ];

  static const List<(String, String)> _whyReelsImportantOptions = [
    (
      'Strangers dancing > My real life',
      'Watching random people lip-sync is more urgent than my goals.',
    ),
    (
      'I prefer a 10-second memory span',
      'Who needs deep focus when I can forget a video in 3 seconds?',
    ),
    (
      'My dreams and sleep can wait',
      'Billion-dollar algorithms need my ad revenue tonight.',
    ),
    (
      'I love that 3 AM regret',
      'Nothing hits quite like staring at the ceiling after 200 Reels.',
    ),
    (
      'I surrender to the feed',
      'Take my valuable hours, I do not want to protect them anymore.',
    ),
  ];

  void _previousStage() {
    AppHaptics.light();
    if (_stage > 0) {
      setState(() => _stage--);
    } else {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _proceedToUnlockChallenge() async {
    AppHaptics.heavy();
    final unlocked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmergencyChallengeScreen(
          walkTargetSteps: widget.state.walkTargetSteps,
          forUninstallUnlock: true,
          isLight: !AppUiController.instance.palette.isDark,
        ),
      ),
    );
    if (!mounted) return;
    if (unlocked == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppUiController.instance.palette;
    final textMain = palette.textPrimary;
    final textSub = palette.textSecondary;

    return PopScope(
      canPop: _stage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stage > 0) {
          _previousStage();
        }
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 18, color: textMain),
            ),
            onPressed: _previousStage,
          ),
          title: Text(
            'Step ${_stage + 1} of 4',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textSub,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 4-step progress bar
                Row(
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= _stage
                                ? palette.primary
                                : palette.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: switch (_stage) {
                    0 => _buildStage0TimeSavedOverview(palette),
                    1 => _buildStage1ReasonQuestion(palette),
                    2 => _buildStage2WhyReelsQuestion(palette),
                    _ => _buildStage3FinalConfirmation(palette),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── STAGE 0: How Much Life & Time You Saved (Lifetime Totals) ───────────
  Widget _buildStage0TimeSavedOverview(AppThemePalette palette) {
    final savedSecTotal = widget.state.lifetimeSavedSec;
    final dodgedReels = widget.state.lifetimeBlockedCount;
    final lifetimeWatchedReels = widget.state.lifetimeReelsCount;
    final lifetimeWastedSec = widget.state.lifetimeReelsSec;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border, width: 1.1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'YOUR LIFE RECLAIMED (LIFETIME)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Look how much life you saved with No-Reels',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.25,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Here is your complete lifetime protection record across all days since installing No-Reels:',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Accurate Lifetime Saved & Dodged Stats
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatDurationCompact(savedSecTotal),
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: palette.textPrimary,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Valuable Life Saved',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.textSecondary,
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
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$dodgedReels',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: palette.textPrimary,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Reels Dodged',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(height: 1, color: palette.border),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lifetime Watched: $lifetimeWatchedReels reels',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textSecondary,
                                ),
                              ),
                              Text(
                                'Wasted: ${formatDurationCompact(lifetimeWastedSec)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Text(
                      '"Every single reel you dodged was time you kept for your real life instead of handing it to a feed."',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Keep My Protection ON',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            AppHaptics.selection();
            setState(() => _stage = 1);
          },
          child: Text(
            'I still want to turn off Uninstall Lock →',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ── STAGE 1: What is the reason for you to uninstall? ────────────────────
  Widget _buildStage1ReasonQuestion(AppThemePalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What is your reason to uninstall?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick the honest reason why you want to disable your protection:',
          style: TextStyle(
            fontSize: 13.5,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: _uninstallReasons.length,
            itemBuilder: (ctx, idx) {
              final item = _uninstallReasons[idx];
              final selected = _selectedReasonIndex == idx;
              return _buildEmotionalOptionCard(
                palette: palette,
                title: item.$1,
                subtitle: item.$2,
                selected: selected,
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _selectedReasonIndex = idx);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textPrimary,
                    side: BorderSide(color: palette.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Stay Protected',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: _selectedReasonIndex == null
                      ? null
                      : () {
                          AppHaptics.selection();
                          setState(() => _stage = 2);
                        },
                  child: const Text(
                    'Continue →',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── STAGE 2: Why are Reels so important than life? ───────────────────────
  Widget _buildStage2WhyReelsQuestion(AppThemePalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Why are Reels more important than your life?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tell us why short videos deserve your best hours today:',
          style: TextStyle(
            fontSize: 13.5,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: _whyReelsImportantOptions.length,
            itemBuilder: (ctx, idx) {
              final item = _whyReelsImportantOptions[idx];
              final selected = _selectedWhyReelsIndex == idx;
              return _buildEmotionalOptionCard(
                palette: palette,
                title: item.$1,
                subtitle: item.$2,
                selected: selected,
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _selectedWhyReelsIndex = idx);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textPrimary,
                    side: BorderSide(color: palette.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Keep Lock ON',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: _selectedWhyReelsIndex == null
                      ? null
                      : () {
                          AppHaptics.selection();
                          setState(() => _stage = 3);
                        },
                  child: const Text(
                    'Final Step →',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _buildSavageRoast(int rIdx, int wIdx) {
    final firstHalf = switch (rIdx) {
      0 =>
        'So your grand life plan today is literally "I want to destroy my time." Respect the honesty—most people at least pretend they have self-control before throwing their hours in the trash.',
      1 =>
        'You really looked at peace of mind and actual focus and said "nah, I hate my life, feed me 15-second brain rot." That is generational self-sabotage.',
      2 =>
        '"My life, my rules" is hilarious coming from someone about to let a billion-dollar recommendation algorithm babysit their thumb for the next 3 hours.',
      3 =>
        'Your thumb "feels lonely"? Your thumb is the only part of you getting any exercise while your real-world goals sit on the bench collecting dust.',
      _ =>
        'Your attention span finally started recovering from terminal brain rot and you panicked because having a working brain felt too unfamiliar.',
    };

    final secondHalf = switch (wIdx) {
      0 =>
        'And on top of that, you decided strangers lip-syncing in their bedrooms are more important than your actual future. They are cashing checks while you pay with your youth—clock in for your unpaid scrolling shift, champ.',
      1 =>
        'Trading your memory for clips you cannot even recall 4 seconds after swiping is wild. Actual goldfish are looking at your attention span with secondhand embarrassment right now.',
      2 =>
        'Putting your own sleep, health, and ambition on hold just to generate fractions of a cent in ad revenue for a tech conglomerate? At least clowns get paid to perform—you are doing it for free.',
      3 =>
        'Actively craving that 3 AM ceiling-staring regret after 200 meaningless swipes is crazy work. Tomorrow morning\'s version of you is already shaking their head in disappointment.',
      _ =>
        'Waving the white flag to an infinite feed of 15-second noise without even putting up a fight. Go ahead—trade your potential for a cheap dopamine crumb.',
    };

    return '$firstHalf\n\n$secondHalf';
  }

  // ── STAGE 3: Final Reality Check & "Let me destroy my valuable times" ────
  Widget _buildStage3FinalConfirmation(AppThemePalette palette) {
    final rIdx = _selectedReasonIndex ?? 0;
    final wIdx = _selectedWhyReelsIndex ?? 0;
    final reason1 = _uninstallReasons[rIdx].$1;
    final reason2 = _whyReelsImportantOptions[wIdx].$1;
    final savageRoast = _buildSavageRoast(rIdx, wIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border, width: 1.1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'FINAL REALITY CHECK',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Look at what you just admitted:',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1. "$reason1"',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '2. "$reason2"',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        savageRoast,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.48,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'No, Protect My Valuable Time',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(
                color: AppColors.error.withValues(alpha: 0.6),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _proceedToUnlockChallenge,
            child: const Text(
              'Let me destroy my valuable times',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionalOptionCard({
    required AppThemePalette palette,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? palette.surface2 : palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.6 : 1.1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? palette.primary : palette.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
