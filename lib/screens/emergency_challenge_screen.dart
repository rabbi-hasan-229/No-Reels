import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../challenges/challenge_logic.dart';
import '../engine_bridge.dart';
import '../theme/app_theme.dart';

enum ChallengeMode { walk, ebook, math }

/// Emergency Bypass Screen:
/// First asks the user to choose their unlock method (Walk, Read Book, or Hard Math),
/// then launches the chosen challenge to grant a 5-minute pass.
class EmergencyChallengeScreen extends StatefulWidget {
  final int walkTargetSteps;
  final bool forUninstallUnlock;
  final bool isLight;

  const EmergencyChallengeScreen({
    super.key,
    required this.walkTargetSteps,
    this.forUninstallUnlock = false,
    this.isLight = false,
  });

  @override
  State<EmergencyChallengeScreen> createState() =>
      _EmergencyChallengeScreenState();
}

class _EmergencyChallengeScreenState extends State<EmergencyChallengeScreen> {
  ChallengeMode? _selectedMode;
  final Random _rng = Random();

  // 1. Walk state
  int _currentSteps = 0;
  bool _sensorActive = false;

  // 2. E-Book state
  List<EbookChallengeItem> _ebooks = const [];
  int _selectedBookIdx = 0;
  int _pageIndex = 0;
  int _pageSecondsLeft = 15;
  Timer? _pageTimer;
  bool _inEbookQuiz = false;
  final Map<int, int> _ebookAnswers = {};
  String? _ebookFeedback;

  // 3. Hard Math state
  late HardMathProblem _mathProblem;
  int _mathStreak = 0;
  static const int _requiredMathStreak = 5;
  String? _mathFeedback;
  bool _mathIsError = false;

  @override
  void initState() {
    super.initState();
    _mathProblem = HardMathProblem.generate(_rng);
    _loadAssets();
    EngineBridge.setListeners(
      onWalkStep: (steps) {
        if (!mounted) return;
        setState(() => _currentSteps = steps);
        if (steps >= widget.walkTargetSteps) {
          _completeChallenge();
        }
      },
    );
  }

  Future<void> _loadAssets() async {
    try {
      final ebRaw =
          await rootBundle.loadString('assets/challenges/ebooks.json');
      if (!mounted) return;
      setState(() {
        _ebooks = EbookChallengeItem.parseList(ebRaw);
      });
    } catch (_) {}
  }

  void _selectMode(ChallengeMode? next) {
    if (_selectedMode == ChallengeMode.walk && next != ChallengeMode.walk) {
      EngineBridge.stopWalkSensor();
      _sensorActive = false;
    }
    _pageTimer?.cancel();
    setState(() => _selectedMode = next);
    if (next == ChallengeMode.walk) {
      _startWalk();
    } else if (next == ChallengeMode.ebook) {
      _startPageTimer();
    } else if (next == ChallengeMode.math) {
      setState(() {
        _mathProblem = HardMathProblem.generate(_rng);
        _mathFeedback = null;
      });
    }
  }

  Future<void> _startWalk() async {
    final ok = await EngineBridge.startWalkSensor();
    if (!mounted) return;
    setState(() {
      _sensorActive = ok;
      _currentSteps = 0;
    });
  }

  void _startPageTimer() {
    _pageTimer?.cancel();
    setState(() => _pageSecondsLeft = 15);
    _pageTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_pageSecondsLeft <= 1) {
        t.cancel();
        setState(() => _pageSecondsLeft = 0);
      } else {
        setState(() => _pageSecondsLeft--);
      }
    });
  }

  Future<void> _completeChallenge() async {
    _pageTimer?.cancel();
    await EngineBridge.stopWalkSensor();
    await EngineBridge.grantEmergencyUnlock(
      minutes: 5,
      deactivateAdmin: widget.forUninstallUnlock,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _pageTimer?.cancel();
    EngineBridge.stopWalkSensor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = AppUiController.instance;
    final palette = ui.palette;
    final bg = palette.background;
    final cardBg = palette.surface;
    final borderCol = palette.border;
    final textMain = palette.textPrimary;
    final textSub = palette.textSecondary;
    final primaryCol = palette.primary;
    final onPrimary = palette.onPrimary;

    return PopScope(
      canPop: _selectedMode == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedMode != null) {
          _selectMode(null);
        }
      },
      child: Scaffold(
        backgroundColor: bg,
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
                border: Border.all(color: borderCol),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 18, color: textMain),
            ),
            onPressed: () {
              if (_selectedMode != null) {
                _selectMode(null);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            widget.forUninstallUnlock
                ? 'Unlock Protection'
                : 'Emergency Unlock',
            style: TextStyle(
              fontFamily: ui.fontSettings.fontFamily.familyName,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: textMain,
            ),
          ),
          actions: [
            if (_selectedMode != null)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: TextButton(
                  onPressed: () => _selectMode(null),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textSub,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: _selectedMode == null
                ? _buildMethodPicker(palette)
                : Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderCol, width: 1.2),
                    ),
                    child: switch (_selectedMode!) {
                      ChallengeMode.walk => _buildWalkView(
                          textMain,
                          textSub,
                          borderCol,
                          primaryCol,
                        ),
                      ChallengeMode.ebook => _buildEbookView(
                          textMain,
                          textSub,
                          borderCol,
                          primaryCol,
                          onPrimary,
                        ),
                      ChallengeMode.math => _buildMathView(
                          textMain,
                          textSub,
                          borderCol,
                          primaryCol,
                          onPrimary,
                          palette.surface2,
                        ),
                    },
                  ),
          ),
        ),
      ),
    );
  }

  // ---------------- 0. Initial Method Chooser (Clean Bento Cards) ----------------

  Widget _buildMethodPicker(AppThemePalette palette) {
    final options = [
      (
        ChallengeMode.walk,
        'Make a Walk',
        '${widget.walkTargetSteps} Steps',
        'Walk with your phone in hand to complete the step target.',
        Icons.directions_walk_rounded,
      ),
      (
        ChallengeMode.ebook,
        'Read Book',
        '3 Pages + Quiz',
        'Read a short philosophical passage and answer 3 questions.',
        Icons.menu_book_rounded,
      ),
      (
        ChallengeMode.math,
        'Hard Math',
        '5 Equations',
        'Solve 5 multi-step multiple-choice math problems in a row.',
        Icons.calculate_rounded,
      ),
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 4),
        // Header Summary Card
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.forUninstallUnlock
                      ? 'DISABLE STRICT LOCK'
                      : '5-MINUTE BYPASS PASS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose how to unlock',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.forUninstallUnlock
                    ? 'Complete any one challenge below to turn off Strict Uninstall Lock and allow uninstallation.'
                    : 'Complete any one challenge below to unlock all short-form feeds for 5 minutes.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: palette.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3 Clean Challenge Bento Cards
        for (final opt in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                AppHaptics.selection();
                _selectMode(opt.$1);
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: palette.border, width: 1.1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border),
                      ),
                      child: Icon(
                        opt.$5,
                        size: 23,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                opt.$2,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: palette.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surface2,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  opt.$3,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            opt.$4,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------- 1. Hard Math View (MCQ Options) ----------------

  Widget _buildMathView(
    Color textMain,
    Color textSub,
    Color borderCol,
    Color primaryCol,
    Color onPrimary,
    Color surface2,
  ) {
    final options = _mathProblem.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hard Math Challenge',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textMain,
              ),
            ),
            Text(
              '$_mathStreak / $_requiredMathStreak solved',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textSub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _mathStreak / _requiredMathStreak,
            minHeight: 8,
            backgroundColor: borderCol,
            valueColor: AlwaysStoppedAnimation<Color>(primaryCol),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol),
          ),
          child: Text(
            _mathProblem.prompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.35,
              color: textMain,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Select the correct answer',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textSub,
          ),
        ),
        const SizedBox(height: 14),
        // 2x2 Grid of MCQ Answer Buttons
        Row(
          children: [
            Expanded(
              child: _buildMcqAnswerButton(
                value: options[0],
                textMain: textMain,
                surface2: surface2,
                borderCol: borderCol,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMcqAnswerButton(
                value: options[1],
                textMain: textMain,
                surface2: surface2,
                borderCol: borderCol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMcqAnswerButton(
                value: options[2],
                textMain: textMain,
                surface2: surface2,
                borderCol: borderCol,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMcqAnswerButton(
                value: options[3],
                textMain: textMain,
                surface2: surface2,
                borderCol: borderCol,
              ),
            ),
          ],
        ),
        if (_mathFeedback != null) ...[
          const SizedBox(height: 18),
          Text(
            _mathFeedback!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _mathIsError
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981),
            ),
          ),
        ],
        const Spacer(),
      ],
    );
  }

  Widget _buildMcqAnswerButton({
    required int value,
    required Color textMain,
    required Color surface2,
    required Color borderCol,
  }) {
    return GestureDetector(
      onTap: () => _verifyMathMcq(value),
      child: Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderCol, width: 1.2),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textMain,
          ),
        ),
      ),
    );
  }

  void _verifyMathMcq(int chosenValue) {
    AppHaptics.selection();
    if (chosenValue == _mathProblem.answer) {
      final nextStreak = _mathStreak + 1;
      if (nextStreak >= _requiredMathStreak) {
        _completeChallenge();
        return;
      }
      setState(() {
        _mathStreak = nextStreak;
        _mathProblem = HardMathProblem.generate(_rng);
        _mathIsError = false;
        _mathFeedback =
            'Correct! ${_requiredMathStreak - nextStreak} more to unlock.';
      });
    } else {
      setState(() {
        _mathStreak = 0;
        _mathProblem = HardMathProblem.generate(_rng);
        _mathIsError = true;
        _mathFeedback = 'Incorrect choice. Streak reset to 0.';
      });
    }
  }

  // ---------------- 2. Walk View ----------------

  Widget _buildWalkView(
    Color textMain,
    Color textSub,
    Color borderCol,
    Color primaryCol,
  ) {
    final target = widget.walkTargetSteps;
    final progress =
        (target > 0) ? (_currentSteps / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Physical Walk Challenge',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textMain,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _sensorActive
              ? 'Walk with your phone to reach the target step count.'
              : 'Initializing step sensor...',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: textSub),
        ),
        const SizedBox(height: 32),
        Text(
          '$_currentSteps / $target',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: textMain,
          ),
        ),
        Text(
          'Steps',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: textSub),
        ),
        const SizedBox(height: 28),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: borderCol,
            valueColor: AlwaysStoppedAnimation<Color>(primaryCol),
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: _startWalk,
            style: OutlinedButton.styleFrom(
              foregroundColor: textMain,
              side: BorderSide(color: borderCol),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Reset Step Counter'),
          ),
        ),
      ],
    );
  }

  // ---------------- 3. E-Book View ----------------

  Widget _buildEbookView(
    Color textMain,
    Color textSub,
    Color borderCol,
    Color primaryCol,
    Color onPrimary,
  ) {
    if (_ebooks.isEmpty) {
      return Center(
        child: Text('Loading books...', style: TextStyle(color: textSub)),
      );
    }
    final book = _ebooks[_selectedBookIdx % _ebooks.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < _ebooks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_ebooks[i].author.split('(').first.trim()),
                    selected: _selectedBookIdx == i,
                    onSelected: (_) {
                      setState(() {
                        _selectedBookIdx = i;
                        _pageIndex = 0;
                        _inEbookQuiz = false;
                        _ebookAnswers.clear();
                        _ebookFeedback = null;
                      });
                      _startPageTimer();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          book.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textMain,
          ),
        ),
        const SizedBox(height: 10),
        Divider(color: borderCol, height: 1),
        const SizedBox(height: 12),
        if (!_inEbookQuiz) ...[
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                book.pages[_pageIndex],
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: textMain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${_pageIndex + 1} of ${book.pages.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textSub,
                ),
              ),
              FilledButton(
                onPressed: _pageSecondsLeft > 0
                    ? null
                    : () {
                        if (_pageIndex + 1 < book.pages.length) {
                          setState(() => _pageIndex++);
                          _startPageTimer();
                        } else {
                          setState(() => _inEbookQuiz = true);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: primaryCol,
                  foregroundColor: onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  _pageSecondsLeft > 0
                      ? 'Keep Reading (${_pageSecondsLeft}s)'
                      : (_pageIndex + 1 < book.pages.length
                          ? 'Next Page'
                          : 'Take Quiz'),
                ),
              ),
            ],
          ),
        ] else ...[
          Expanded(
            child: ListView.builder(
              itemCount: book.questions.length,
              itemBuilder: (ctx, qIdx) {
                final q = book.questions[qIdx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${qIdx + 1}. ${q.question}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (int oIdx = 0; oIdx < q.options.length; oIdx++)
                        _buildNormalOptionTile(
                          text: q.options[oIdx],
                          selected: _ebookAnswers[qIdx] == oIdx,
                          textMain: textMain,
                          borderCol: borderCol,
                          primaryCol: primaryCol,
                          onTap: () =>
                              setState(() => _ebookAnswers[qIdx] = oIdx),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_ebookFeedback != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _ebookFeedback!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
              ),
            ),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () {
                int correct = 0;
                for (int i = 0; i < book.questions.length; i++) {
                  if (_ebookAnswers[i] == book.questions[i].correctIndex) {
                    correct++;
                  }
                }
                if (correct == book.questions.length) {
                  _completeChallenge();
                } else {
                  setState(() {
                    _ebookFeedback =
                        'Scored $correct/${book.questions.length} (3/3 needed). Please review the pages.';
                    _inEbookQuiz = false;
                    _pageIndex = 0;
                    _ebookAnswers.clear();
                  });
                  _startPageTimer();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: primaryCol,
                foregroundColor: onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Submit Quiz (3/3 Required)'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNormalOptionTile({
    required String text,
    required bool selected,
    required Color textMain,
    required Color borderCol,
    required Color primaryCol,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected ? primaryCol.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? primaryCol : borderCol,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? primaryCol : textMain.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13.5,
                  color: textMain,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
