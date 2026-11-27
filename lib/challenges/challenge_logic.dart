import 'dart:convert';
import 'dart:math';

class HardMathProblem {
  final String prompt;
  final int answer;
  final List<int> options;
  final int correctIndex;

  const HardMathProblem({
    required this.prompt,
    required this.answer,
    required this.options,
    required this.correctIndex,
  });

  static List<int> _buildMcqOptions(int answer, Random rng) {
    const candidateOffsets = [
      -30,
      -20,
      -16,
      -12,
      -10,
      -8,
      -6,
      -4,
      4,
      6,
      8,
      10,
      12,
      16,
      20,
      30,
    ];
    final set = <int>{answer};
    // Always include at least one distractor ending with the same last digit (±10, ±20, or ±30)
    final sameLastDigitOffsets = [-30, -20, -10, 10, 20, 30];
    set.add(
      answer +
          sameLastDigitOffsets[rng.nextInt(sameLastDigitOffsets.length)],
    );
    while (set.length < 4) {
      final offset = candidateOffsets[rng.nextInt(candidateOffsets.length)];
      set.add(answer + offset);
    }
    final list = set.toList()..shuffle(rng);
    return list;
  }

  static HardMathProblem _withOptions(String prompt, int answer, Random rng) {
    final opts = _buildMcqOptions(answer, rng);
    return HardMathProblem(
      prompt: prompt,
      answer: answer,
      options: opts,
      correctIndex: opts.indexOf(answer),
    );
  }

  static HardMathProblem generate(Random rng) {
    final type = rng.nextInt(4);
    switch (type) {
      case 0:
        // Compound 3-term expression: ((A × B) + (C × D)) − E
        final a = 24 + rng.nextInt(35); // 24..58
        final b = 17 + rng.nextInt(23); // 17..39
        final c = 21 + rng.nextInt(29); // 21..49
        final d = 13 + rng.nextInt(22); // 13..34
        final e = 150 + rng.nextInt(390); // 150..539
        final ans = ((a * b) + (c * d)) - e;
        return _withOptions('(($a × $b) + ($c × $d)) − $e = ?', ans, rng);
      case 1:
        // Sum of squares minus product: (A² + B²) − (C × D)
        final a = 19 + rng.nextInt(24); // 19..42
        final b = 15 + rng.nextInt(22); // 15..36
        final c = 17 + rng.nextInt(22); // 17..38
        final d = 14 + rng.nextInt(16); // 14..29
        final ans = (a * a) + (b * b) - (c * d);
        return _withOptions('($a² + $b²) − ($c × $d) = ?', ans, rng);
      case 2:
        // Multi-step linear equation: (A × x) + (B × C) = D -> solve for x
        final a = 13 + rng.nextInt(20); // 13..32
        final x = 14 + rng.nextInt(29); // 14..42
        final b = 16 + rng.nextInt(22); // 16..37
        final c = 12 + rng.nextInt(15); // 12..26
        final d = (a * x) + (b * c);
        return _withOptions('Solve for x:\n${a}x + ($b × $c) = $d', x, rng);
      default:
        // Cubic minus product plus offset: (A³ − (B × C)) + D
        final a = 7 + rng.nextInt(9); // 7..15
        final b = 19 + rng.nextInt(28); // 19..46
        final c = 14 + rng.nextInt(20); // 14..33
        final d = 85 + rng.nextInt(255); // 85..339
        final ans = (a * a * a) - (b * c) + d;
        return _withOptions('($a³ − ($b × $c)) + $d = ?', ans, rng);
    }
  }
}

class QuizQuestion {
  final String type;
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    this.type = 'COMPREHENSION',
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) {
    return QuizQuestion(
      type: (j['type'] as String?) ?? 'COMPREHENSION',
      question: (j['question'] as String?) ?? '',
      options: ((j['options'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      correctIndex: (j['correctIndex'] as int?) ?? 0,
    );
  }
}

class EbookChallengeItem {
  final String id;
  final String title;
  final String author;
  final List<String> pages;
  final List<QuizQuestion> questions;

  const EbookChallengeItem({
    required this.id,
    required this.title,
    required this.author,
    required this.pages,
    required this.questions,
  });

  factory EbookChallengeItem.fromJson(Map<String, dynamic> j) {
    return EbookChallengeItem(
      id: (j['id'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      author: (j['author'] as String?) ?? '',
      pages: ((j['pages'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      questions: ((j['questions'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestion.fromJson)
          .toList(),
    );
  }

  static List<EbookChallengeItem> parseList(String jsonStr) {
    final raw = json.decode(jsonStr) as List<dynamic>;
    return raw
        .whereType<Map<String, dynamic>>()
        .map(EbookChallengeItem.fromJson)
        .toList();
  }
}

class IeltsChallengeItem {
  final String id;
  final String title;
  final String bandLevel;
  final String passage;
  final List<QuizQuestion> questions;

  const IeltsChallengeItem({
    required this.id,
    required this.title,
    required this.bandLevel,
    required this.passage,
    required this.questions,
  });

  factory IeltsChallengeItem.fromJson(Map<String, dynamic> j) {
    return IeltsChallengeItem(
      id: (j['id'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      bandLevel: (j['bandLevel'] as String?) ?? 'Band 8.0',
      passage: (j['passage'] as String?) ?? '',
      questions: ((j['questions'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestion.fromJson)
          .toList(),
    );
  }

  static List<IeltsChallengeItem> parseList(String jsonStr) {
    final raw = json.decode(jsonStr) as List<dynamic>;
    return raw
        .whereType<Map<String, dynamic>>()
        .map(IeltsChallengeItem.fromJson)
        .toList();
  }
}

String formatDurationCompact(int totalSec) {
  final mins = totalSec ~/ 60;
  final secs = totalSec % 60;
  if (mins >= 60) {
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }
  if (mins > 0) return '${mins}m ${secs}s';
  return '${secs}s';
}
