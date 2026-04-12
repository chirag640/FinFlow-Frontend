import '../../features/expenses/domain/entities/expense.dart';
import '../../features/expenses/presentation/providers/expense_provider.dart';
import '../storage/hive_service.dart';
import 'notification_service.dart';

/// Runs on app startup to auto-generate expense instances for any recurring
/// templates that are due today or overdue.
///
/// Idempotency: a Hive settings key `ff_rec_{templateId}` records the last
/// date on which the engine generated an instance from that template.
/// If `lastGenerated` already equals today the engine skips the template,
/// preventing double-posting on multiple cold-starts in the same day.
abstract class RecurringEngineService {
  static const String _prefix = 'ff_rec_';

  // ── Public entry point ─────────────────────────────────────────────────────

  /// Call after expenses are loaded in [ExpenseNotifier].
  /// [templates] must already be filtered to `isRecurring && !isIncome`.
  static Future<void> run(
    ExpenseNotifier notifier,
    List<Expense> templates,
  ) async {
    final today = _dateOnly(DateTime.now());
    int generated = 0;

    for (final t in templates) {
      final freq = t.recurringFrequency;
      if (freq == null) continue;

      final last = _lastGenerated(t.id) ?? _dateOnly(t.date);
      // If we already ran today for this template, skip
      if (last.isAtSameMomentAs(today)) continue;

      final next = _nextDue(
        last,
        freq,
        monthlyDueDay: t.recurringDueDay,
      );
      // Not due yet
      if (next.isAfter(today)) continue;

      // Generate the instance as a regular (non-recurring) expense dated today
      await notifier.addExpense(
        amount: t.amount,
        description: t.description,
        category: t.category,
        date: today,
        note: t.note,
        isIncome: false,
        isRecurring: false, // generated instances are not templates
      );

      // Stamp today so we don't double-generate
      await HiveService.settings.put(
        '$_prefix${t.id}',
        today.toIso8601String(),
      );

      generated++;

      // Fire individual notification only for the first one; batch below
      if (generated == 1) {
        await NotificationService.showRecurringDue(t.description, t.amount);
      }
    }

    // Replace the individual notification with a batch summary if > 1 generated
    if (generated > 1) {
      await NotificationService.showRecurringBatch(generated);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the date on which the engine last ran for [templateId],
  /// or `null` if it has never run.
  static DateTime? _lastGenerated(String templateId) {
    final raw = HiveService.settings.get('$_prefix$templateId') as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Computes the next theoretical due date after [last] based on [freq].
  static DateTime _nextDue(
    DateTime last,
    RecurringFrequency freq, {
    int? monthlyDueDay,
  }) =>
      switch (freq) {
        RecurringFrequency.daily => last.add(const Duration(days: 1)),
        RecurringFrequency.weekly => last.add(const Duration(days: 7)),
        RecurringFrequency.monthly =>
          _nextMonthlyDue(last, monthlyDueDay ?? last.day),
        RecurringFrequency.yearly =>
          DateTime(last.year + 1, last.month, last.day),
      };

  static DateTime _nextMonthlyDue(DateTime last, int dueDay) {
    final monthStart = DateTime(last.year, last.month + 1, 1);
    final maxDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final clampedDay = dueDay.clamp(1, maxDay);
    return DateTime(monthStart.year, monthStart.month, clampedDay);
  }

  /// Strips the time component so comparisons are purely date-based.
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // ── Public helper (used by RecurringManagerPage) ───────────────────────────

  /// Returns the next due date for a template.
  /// Reads `lastGenerated` from settings, falls back to `template.date`.
  static DateTime nextDueFor(Expense template) {
    final freq = template.recurringFrequency;
    if (freq == null) return template.date;
    final last = _lastGenerated(template.id) ?? _dateOnly(template.date);
    return _nextDue(last, freq, monthlyDueDay: template.recurringDueDay);
  }

  /// `true` when the template's next due date is today or in the past.
  static bool isDue(Expense template) {
    final today = _dateOnly(DateTime.now());
    final next = _dateOnly(nextDueFor(template));
    return !next.isAfter(today);
  }
}
