import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodoom/challenges/challenge_logic.dart';
import 'package:nodoom/engine_bridge.dart';
import 'package:nodoom/main.dart';
import 'package:nodoom/screens/emergency_challenge_screen.dart';
import 'package:nodoom/screens/performance_screen.dart';
import 'package:nodoom/screens/uninstall_emotional_flow_screen.dart';
import 'package:nodoom/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HardMathProblem generator produces valid compound MCQ problems', () {
    final rng = Random(42);
    for (int i = 0; i < 40; i++) {
      final p = HardMathProblem.generate(rng);
      expect(p.prompt.isNotEmpty, isTrue);
      expect(p.answer.abs() < 1000000, isTrue);
      expect(p.options.length, equals(4));
      expect(p.options[p.correctIndex], equals(p.answer));
    }
  });

  test('Offline E-Book JSON asset parses cleanly', () async {
    final ebooksJson = await rootBundle.loadString(
      'assets/challenges/ebooks.json',
    );
    final ebooks = EbookChallengeItem.parseList(ebooksJson);
    expect(ebooks.length, greaterThanOrEqualTo(3));
    expect(ebooks.first.pages.length, greaterThanOrEqualTo(3));
    expect(ebooks.first.questions.length, equals(3));
  });

  test('Only White Mode and Dark Mode themes exist and build cleanly', () {
    expect(AppThemeId.values.length, equals(2));
    expect(AppThemePalettes.all.length, equals(2));
    for (final palette in AppThemePalettes.all) {
      final theme = palette.buildThemeData();
      expect(theme.scaffoldBackgroundColor, equals(palette.background));
    }
  });

  testWidgets(
    'No-Reels dashboard renders clean header, cards, and Unlock dock',
    (WidgetTester tester) async {
      await tester.pumpWidget(const NoDoomApp());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('No-Reels'), findsWidgets);
      expect(find.text('Reels Watched Today'), findsOneWidget);
      expect(find.text('PLATFORMS'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    },
  );

  testWidgets(
    'Emergency Unlock shows Walk, Read Book, and Hard Math picker first',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: EmergencyChallengeScreen(walkTargetSteps: 200)),
      );
      await tester.pump();

      expect(find.text('Choose how to unlock'), findsOneWidget);
      expect(find.text('Make a Walk'), findsOneWidget);
      expect(find.text('Read Book'), findsOneWidget);
      expect(find.text('Hard Math'), findsOneWidget);
      expect(find.text('IELTS'), findsNothing);
    },
  );

  testWidgets(
    'PerformanceScreen renders Today, 7-Day Average, and Daily History',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: PerformanceScreen()));
      await tester.pump();

      expect(find.text('Performance'), findsOneWidget);
      expect(find.text("TODAY'S PERFORMANCE"), findsOneWidget);
      expect(find.text('7-DAY AVG REELS'), findsOneWidget);
      expect(find.text('7-DAY AVG TIME'), findsOneWidget);
      expect(find.text('LIFETIME'), findsOneWidget);
      expect(find.text('LAST 7 DAYS TREND'), findsOneWidget);
    },
  );

  testWidgets('UninstallEmotionalFlowScreen walks through 4 emotional stages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UninstallEmotionalFlowScreen(state: EngineState()),
      ),
    );
    await tester.pump();

    // Stage 1: Time saved overview
    expect(
      find.text('Look how much life you saved with No-Reels'),
      findsOneWidget,
    );
    await tester.tap(find.text('I still want to turn off Uninstall Lock →'));
    await tester.pumpAndSettle();

    // Stage 2: Reason to uninstall
    expect(find.text('What is your reason to uninstall?'), findsOneWidget);
    expect(find.text('I want to destroy my time'), findsOneWidget);
    expect(find.text('I hate my life & focus'), findsOneWidget);
    expect(find.text('My life, My rules'), findsOneWidget);

    await tester.tap(find.text('I want to destroy my time'));
    await tester.pump();
    await tester.tap(find.text('Continue →'));
    await tester.pumpAndSettle();

    // Stage 3: Why are Reels more important than your life?
    expect(
      find.text('Why are Reels more important than your life?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Strangers dancing > My real life'));
    await tester.pump();
    await tester.tap(find.text('Final Step →'));
    await tester.pumpAndSettle();

    // Stage 4: Final reality check & tailored roast
    expect(find.text('Look at what you just admitted:'), findsOneWidget);
    expect(find.textContaining('unpaid scrolling shift, champ'), findsOneWidget);
    expect(find.text('Let me destroy my valuable times'), findsOneWidget);
  });
}
