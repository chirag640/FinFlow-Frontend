import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../features/expenses/domain/entities/expense.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/cloud_auth_provider.dart';
import '../../../budgets/domain/entities/budget.dart';
import '../../../budgets/presentation/providers/budget_provider.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? error;

  const SyncState({this.isSyncing = false, this.lastSyncTime, this.error});

  SyncState copyWith(
          {bool? isSyncing, DateTime? lastSyncTime, String? error}) =>
      SyncState(
        isSyncing: isSyncing ?? this.isSyncing,
        lastSyncTime: lastSyncTime ?? this.lastSyncTime,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  // Must use the same Android options as auth_interceptor.dart and
  // cloud_auth_provider.dart — all three must read/write the same
  // encryptedSharedPreferences bucket; mismatched options = different
  // buckets = token always reads null = sync permanently skipped on Android.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  SyncNotifier(this._ref) : super(const SyncState()) {
    // Listen for login / session-restore events and sync immediately.
    // This covers: login, register+verify, cold-start session restore.
    _ref.listen<CloudAuthState>(cloudAuthProvider, (prev, next) {
      final wasConnected = prev?.isConnected ?? false;
      if (!wasConnected && next.isConnected) {
        debugPrint('[FinFlow Sync] 🔑 Connected — triggering sync');
        sync();
      }
    });

    // Auto-sync when device comes back online after being offline.
    // Combined with the cloudAuth listener above, this covers all reconnect paths.
    _ref.listen<bool>(connectivityProvider, (prev, next) {
      final wasOffline = !(prev ?? true);
      if (wasOffline && next) {
        debugPrint('[FinFlow Sync] 📶 Network restored — triggering sync');
        sync();
      }
    });

    _autoSyncOnStartup();
  }

  /// On startup: fire sync once after a short delay to let the widget tree
  /// and token storage settle. sync() already gates on the token directly,
  /// so no polling is needed.
  Future<void> _autoSyncOnStartup() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await sync();
  }

  Future<void> sync() async {
    // Gate on the JWT token directly — same source of truth as AuthInterceptor.
    // This is more reliable than the in-memory isConnected flag which can be
    // stale after hot-reload or a race with _restoreSession().
    final token = await _storage.read(key: TokenKeys.accessToken);
    if (token == null) {
      debugPrint('[FinFlow Sync] ⏭ Skipped — no access token in storage');
      return;
    }

    // Prevent concurrent syncs
    if (state.isSyncing) {
      debugPrint('[FinFlow Sync] ⏭ Skipped — sync already in progress');
      return;
    }

    state = state.copyWith(isSyncing: true);
    debugPrint('[FinFlow Sync] 🔄 Starting sync...');
    try {
      final dio = _ref.read(dioProvider);

      // ── Push local expenses ──────────────────────────────────────────────
      final expState = _ref.read(expenseProvider);
      final expDs = _ref.read(expenseDatasourceProvider);
      final now = DateTime.now().toIso8601String();
      final expenses = expState.expenses
          .map((e) => {
                'id': e.id,
                'amount': e.amount,
                'description': e.description,
                'category': e.category.name,
                'date': e.date.toIso8601String(),
                'notes': e.note,
                'isIncome': e.isIncome,
                'isRecurring': e.isRecurring,
                'recurringRule': e.recurringFrequency?.name,
                'updatedAt': now,
                'deleted': false,
              })
          .toList();

      // ── Include any offline-deleted expenses so the server removes them ──
      // These are expenses that were deleted locally but the DELETE /expenses/:id
      // call failed (offline or transient error). Including them here as
      // { deleted: true } ensures the server soft-deletes them and prevents
      // the pull phase from resurrecting them.
      final pendingDelIds = expDs.getPendingDeletions();
      for (final id in pendingDelIds) {
        // Only add if not already in the living expenses list
        final alreadyPresent = expenses.any((e) => e['id'] == id);
        if (!alreadyPresent) {
          expenses.add({
            'id': id,
            'amount': 0,
            'description': '',
            'category': 'other',
            'date': now,
            'isIncome': false,
            'isRecurring': false,
            'updatedAt': now,
            'deleted': true,
          });
        }
      }

      // ── Push local budgets ───────────────────────────────────────────────
      final budgetDs = _ref.read(budgetDatasourceProvider);
      final allBudgets = budgetDs.getAll();
      final budgets = allBudgets
          .map((b) => {
                'id': b.id,
                'categoryKey': b.categoryKey,
                'allocatedAmount': b.allocatedAmount,
                'month': b.month,
                'year': b.year,
                'carryForward': b.carryForward,
                'updatedAt': now,
                'deleted': false,
              })
          .toList();

      debugPrint(
          '[FinFlow Sync] 📤 Pushing ${expenses.length} expenses (${pendingDelIds.length} pending deletes), ${budgets.length} budgets');
      await dio.post(
        '/sync/push',
        data: {
          if (expenses.isNotEmpty) 'expenses': expenses,
          if (budgets.isNotEmpty) 'budgets': budgets,
        },
      );
      debugPrint('[FinFlow Sync] ✅ Push successful');

      // Server confirmed receipt of pending deletions — safe to clear queue
      if (pendingDelIds.isNotEmpty) {
        await expDs.clearAllPendingDeletions();
        debugPrint(
            '[FinFlow Sync] 🗑 Cleared ${pendingDelIds.length} pending deletions');
      }

      // ── Pull server changes ──────────────────────────────────────────────
      // toUtc() ensures the ISO string has a 'Z' suffix so the Node.js server
      // parses it as UTC rather than its local timezone, preventing the
      // subsequent pull from silently skipping server-side changes that
      // occurred within the UTC-offset window.
      final since = state.lastSyncTime?.toUtc().toIso8601String() ?? '';
      final pullRes = await dio.get(
        '/sync/pull',
        queryParameters: since.isNotEmpty ? {'since': since} : {},
      );

      final pullData = pullRes.data['data'];
      final serverExpenses = (pullData?['expenses'] as List?) ?? [];
      final expNotifier = _ref.read(expenseProvider.notifier);

      // ── Sync user profile (name, monthlyBudget, currency) from cloud ────
      final serverUser = pullData?['user'];
      if (serverUser != null) {
        final cloudUser = _ref.read(cloudAuthProvider).user;
        final currency =
            (serverUser['currency'] as String?) ?? cloudUser?.currency ?? 'INR';
        await _ref.read(authStateProvider.notifier).syncFromCloud(
              name: (serverUser['name'] as String?) ?? cloudUser?.name ?? '',
              email: (serverUser['email'] as String?) ?? cloudUser?.email ?? '',
              currency: currency,
              monthlyBudget:
                  ((serverUser['monthlyBudget'] as num?) ?? 0).toDouble(),
              pinHash: serverUser['pinHash'] as String?,
            );
        // Keep the settings store in sync so export/display uses the correct currency.
        await _ref.read(settingsProvider.notifier).setCurrency(currency);
      }

      // ── Collect bulk lists first — single state= per batch, not per item ──
      final toUpsert = <Expense>[];
      final toDelete = <String>[];

      for (final raw in serverExpenses) {
        final se = raw as Map<String, dynamic>;
        final expId = se['id'] as String?;
        if (expId == null) continue;

        if (se['deleted'] == true) {
          // Local storage delete is fine here (no state= yet).
          await expDs.delete(expId);
          toDelete.add(expId);
        } else {
          // Guard against resurrection: expense is pending deletion locally.
          final isPendingDelete = expDs.getPendingDeletions().contains(expId);
          if (isPendingDelete) continue;

          // Map server field names → local entity field names.
          final mapped = <String, dynamic>{
            'id': expId,
            'amount': se['amount'],
            'description': se['description'],
            'category': se['category'],
            'date': se['date'] is String
                ? se['date']
                : (se['date'] as DateTime).toIso8601String(),
            'note': se['notes'], // server: notes → local: note
            'isIncome': se['isIncome'] ?? false,
            'isRecurring': se['isRecurring'] ?? false,
            'recurringFrequency': se['recurringRule'], // server name
          };
          try {
            toUpsert.add(Expense.fromJson(mapped));
          } catch (_) {} // skip malformed records
        }
      }

      // Single state= per operation — see bulkUpsertFromSync / bulkDeleteFromSync
      // for the Future.delayed(Duration.zero) deferral that prevents the
      // defunct-element assertion when widgets are mid-disposal.
      await expNotifier.bulkDeleteFromSync(toDelete);
      await expNotifier.bulkUpsertFromSync(toUpsert);

      // ── Sync budgets from cloud ──────────────────────────────────────────
      final serverBudgets = (pullData?['budgets'] as List?) ?? [];
      if (serverBudgets.isNotEmpty) {
        final budgetDs = _ref.read(budgetDatasourceProvider);
        for (final raw in serverBudgets) {
          final sb = raw as Map<String, dynamic>;
          final month = (sb['month'] as num?)?.toInt();
          final year = (sb['year'] as num?)?.toInt();
          if (month == null || year == null) continue;
          if (sb['deleted'] == true) {
            await budgetDs.deleteBudget(sb['id'] as String, month, year);
          } else {
            try {
              final b = Budget(
                id: sb['id'] as String,
                categoryKey: sb['categoryKey'] as String,
                allocatedAmount: (sb['allocatedAmount'] as num).toDouble(),
                month: month,
                year: year,
                carryForward: (sb['carryForward'] as bool?) ?? false,
              );
              await budgetDs.saveBudget(b);
            } catch (_) {}
          }
        }
        _ref.read(budgetProvider.notifier).refresh();
        debugPrint('[FinFlow Sync] 💰 Synced ${serverBudgets.length} budgets');
      }

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime:
            DateTime.now().toUtc(), // store as UTC — see since comment above
      );
      debugPrint('[FinFlow Sync] 🎉 Sync complete at ${DateTime.now()}');
    } on DioException catch (e, st) {
      debugPrint('[FinFlow Sync] ❌ Sync error: $e');
      if (kDebugMode) debugPrint(st.toString());
      state = state.copyWith(isSyncing: false, error: formatDioError(e));
    } catch (e, st) {
      debugPrint('[FinFlow Sync] ❌ Sync error: $e');
      if (kDebugMode) debugPrint(st.toString());
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(ref),
);
