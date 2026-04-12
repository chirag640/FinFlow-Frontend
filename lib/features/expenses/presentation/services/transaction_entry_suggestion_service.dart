import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';

class TransactionEntrySuggestion {
  final String description;
  final ExpenseCategory category;
  final double amount;
  final bool isIncome;
  final int frequency;
  final DateTime lastUsedAt;
  final int confidence;
  final String reason;

  const TransactionEntrySuggestion({
    required this.description,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.frequency,
    required this.lastUsedAt,
    required this.confidence,
    required this.reason,
  });
}

class TransactionEntrySuggestionService {
  static List<TransactionEntrySuggestion> suggest({
    required List<Expense> history,
    required bool isIncome,
    required String descriptionInput,
    String? amountInput,
    int limit = 4,
  }) {
    final scopedHistory = history.where((e) => e.isIncome == isIncome).toList();
    if (scopedHistory.isEmpty) return const [];

    final query = _normalize(descriptionInput);
    final hasQuery = query.length >= 2;
    final typedAmount = _parseAmount(amountInput);

    final aggregates = _aggregateByDescription(scopedHistory);
    if (aggregates.isEmpty) return const [];

    final maxFrequency = aggregates.fold<int>(
      1,
      (maxCount, item) => item.frequency > maxCount ? item.frequency : maxCount,
    );

    final now = DateTime.now();
    final scored = <_ScoredSuggestion>[];

    for (final aggregate in aggregates) {
      final normalizedDescription = _normalize(aggregate.latestDescription);
      final matchScore = hasQuery
          ? _descriptionMatchScore(query, normalizedDescription)
          : 0.65;
      if (hasQuery && matchScore <= 0) continue;

      final ageDays = now.difference(aggregate.lastUsedAt).inDays;
      final recencyScore = 1 / (1 + (ageDays / 21));
      final frequencyScore = aggregate.frequency / maxFrequency;
      final amountScore = typedAmount == null
          ? 0.5
          : _amountSimilarity(typedAmount, aggregate.latestAmount);

        final descriptionWeight = isIncome ? 0.4 : 0.45;
        final recencyWeight = isIncome ? 0.35 : 0.25;
        final frequencyWeight = isIncome ? 0.1 : 0.2;
        final amountWeight = isIncome ? 0.15 : 0.1;

        final score = (matchScore * descriptionWeight) +
          (recencyScore * recencyWeight) +
          (frequencyScore * frequencyWeight) +
          (amountScore * amountWeight);

      final confidence = (score * 100).clamp(0, 99).round();
      scored.add(
        _ScoredSuggestion(
          score: score,
          suggestion: TransactionEntrySuggestion(
            description: aggregate.latestDescription,
            category: aggregate.topCategory,
            amount: aggregate.latestAmount,
            isIncome: isIncome,
            frequency: aggregate.frequency,
            lastUsedAt: aggregate.lastUsedAt,
            confidence: confidence,
            reason: _buildReason(
              hasQuery: hasQuery,
              matchScore: matchScore,
              frequency: aggregate.frequency,
              recencyScore: recencyScore,
              amountScore: amountScore,
              typedAmount: typedAmount,
            ),
          ),
        ),
      );
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      final freqCompare =
          b.suggestion.frequency.compareTo(a.suggestion.frequency);
      if (freqCompare != 0) return freqCompare;
      return b.suggestion.lastUsedAt.compareTo(a.suggestion.lastUsedAt);
    });

    return scored.take(limit).map((entry) => entry.suggestion).toList();
  }

  static ExpenseCategory? inferCategoryFromHistory({
    required List<Expense> history,
    required bool isIncome,
    required String descriptionInput,
  }) {
    final top = suggest(
      history: history,
      isIncome: isIncome,
      descriptionInput: descriptionInput,
      limit: 1,
    );
    if (top.isEmpty) return null;
    return top.first.confidence >= 55 ? top.first.category : null;
  }

  static List<_EntryAggregate> _aggregateByDescription(List<Expense> history) {
    final map = <String, _EntryAggregate>{};

    for (final entry in history) {
      final key = _normalize(entry.description);
      if (key.isEmpty) continue;

      final existing = map[key];
      if (existing == null) {
        map[key] = _EntryAggregate.fromExpense(entry);
        continue;
      }
      existing.add(entry);
    }

    return map.values.toList();
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static double? _parseAmount(String? amountInput) {
    if (amountInput == null) return null;
    final cleaned = amountInput.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static double _descriptionMatchScore(String query, String candidate) {
    if (query == candidate) return 1;
    if (candidate.startsWith(query)) return 0.9;
    if (candidate.contains(query)) return 0.7;

    final queryWords = query.split(' ');
    final candidateWords = candidate.split(' ');
    final overlap = queryWords.where(candidateWords.contains).length;
    if (overlap == 0) return 0;

    return (overlap / queryWords.length).clamp(0.35, 0.65);
  }

  static double _amountSimilarity(double typedAmount, double candidateAmount) {
    final maxValue =
        typedAmount > candidateAmount ? typedAmount : candidateAmount;
    if (maxValue <= 0) return 0;
    final normalizedDifference =
        (typedAmount - candidateAmount).abs() / maxValue;
    return (1 - normalizedDifference).clamp(0, 1);
  }

  static String _buildReason({
    required bool hasQuery,
    required double matchScore,
    required int frequency,
    required double recencyScore,
    required double amountScore,
    required double? typedAmount,
  }) {
    if (hasQuery && matchScore >= 0.95) return 'Exact match';
    if (frequency >= 3) return 'Frequent entry';
    if (recencyScore >= 0.8) return 'Recent entry';
    if (typedAmount != null && amountScore >= 0.9) return 'Amount match';
    return 'Similar to previous';
  }
}

class _ScoredSuggestion {
  final double score;
  final TransactionEntrySuggestion suggestion;

  const _ScoredSuggestion({required this.score, required this.suggestion});
}

class _EntryAggregate {
  String latestDescription;
  double latestAmount;
  DateTime lastUsedAt;
  int frequency;
  final Map<ExpenseCategory, int> _categoryFrequency;

  _EntryAggregate({
    required this.latestDescription,
    required this.latestAmount,
    required this.lastUsedAt,
    required this.frequency,
    required Map<ExpenseCategory, int> categoryFrequency,
  }) : _categoryFrequency = categoryFrequency;

  factory _EntryAggregate.fromExpense(Expense expense) {
    return _EntryAggregate(
      latestDescription: expense.description.trim(),
      latestAmount: expense.amount,
      lastUsedAt: expense.date,
      frequency: 1,
      categoryFrequency: {expense.category: 1},
    );
  }

  void add(Expense expense) {
    frequency += 1;
    _categoryFrequency[expense.category] =
        (_categoryFrequency[expense.category] ?? 0) + 1;

    if (expense.date.isAfter(lastUsedAt)) {
      lastUsedAt = expense.date;
      latestDescription = expense.description.trim();
      latestAmount = expense.amount;
    }
  }

  ExpenseCategory get topCategory {
    ExpenseCategory bestCategory = ExpenseCategory.other;
    int bestCount = 0;

    _categoryFrequency.forEach((category, count) {
      if (count > bestCount) {
        bestCount = count;
        bestCategory = category;
      }
    });

    return bestCategory;
  }
}
