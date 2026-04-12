import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../features/expenses/domain/entities/expense.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/cloud_auth_provider.dart';
import '../../../budgets/data/datasources/budget_local_datasource.dart';
import '../../../budgets/domain/entities/budget.dart';
import '../../../budgets/presentation/providers/budget_provider.dart';
import '../../../expenses/data/datasources/expense_local_datasource.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../../goals/data/datasources/goal_local_datasource.dart';
import '../../../goals/domain/entities/savings_goal.dart';
import '../../../goals/presentation/providers/goals_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class SyncMetrics {
  final int queueDepth;
  final int pushLatencyP95Ms;
  final int pullLatencyP95Ms;
  final int pullStalenessMs;
  final int errorCount;
  final int retryCount;

  const SyncMetrics({
    this.queueDepth = 0,
    this.pushLatencyP95Ms = 0,
    this.pullLatencyP95Ms = 0,
    this.pullStalenessMs = 0,
    this.errorCount = 0,
    this.retryCount = 0,
  });

  SyncMetrics copyWith({
    int? queueDepth,
    int? pushLatencyP95Ms,
    int? pullLatencyP95Ms,
    int? pullStalenessMs,
    int? errorCount,
    int? retryCount,
  }) {
    return SyncMetrics(
      queueDepth: queueDepth ?? this.queueDepth,
      pushLatencyP95Ms: pushLatencyP95Ms ?? this.pushLatencyP95Ms,
      pullLatencyP95Ms: pullLatencyP95Ms ?? this.pullLatencyP95Ms,
      pullStalenessMs: pullStalenessMs ?? this.pullStalenessMs,
      errorCount: errorCount ?? this.errorCount,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

class SyncConflictSummary {
  final List<String> expensePendingUpserts;
  final List<String> expensePendingDeletions;
  final List<String> budgetPendingUpserts;
  final List<String> budgetPendingDeletions;
  final List<String> goalPendingUpserts;
  final List<String> goalPendingDeletions;

  const SyncConflictSummary({
    this.expensePendingUpserts = const [],
    this.expensePendingDeletions = const [],
    this.budgetPendingUpserts = const [],
    this.budgetPendingDeletions = const [],
    this.goalPendingUpserts = const [],
    this.goalPendingDeletions = const [],
  });

  int get total =>
      expensePendingUpserts.length +
      expensePendingDeletions.length +
      budgetPendingUpserts.length +
      budgetPendingDeletions.length +
      goalPendingUpserts.length +
      goalPendingDeletions.length;

  bool get hasConflicts => total > 0;
}

enum SyncConflictEntityType { expense, budget, goal }

enum SyncConflictActionType { upsert, deletion }

class SyncConflictRecord {
  final String id;
  final SyncConflictEntityType entityType;
  final SyncConflictActionType actionType;
  final Map<String, dynamic>? localData;
  final Map<String, dynamic>? cloudData;
  final DateTime? localUpdatedAt;
  final DateTime? cloudUpdatedAt;
  final bool cloudSnapshotAvailable;
  final List<String> changedFields;

  const SyncConflictRecord({
    required this.id,
    required this.entityType,
    required this.actionType,
    required this.localData,
    required this.cloudData,
    required this.localUpdatedAt,
    required this.cloudUpdatedAt,
    required this.cloudSnapshotAvailable,
    required this.changedFields,
  });
}

class SuggestionInteractionEvent {
  final String flow;
  final String eventType;
  final bool isIncome;
  final String? suggestionDescription;
  final String? suggestionCategory;
  final double? suggestionAmount;
  final int? confidence;
  final String? reason;
  final String? inputDescription;
  final DateTime createdAt;

  const SuggestionInteractionEvent({
    required this.flow,
    required this.eventType,
    required this.isIncome,
    this.suggestionDescription,
    this.suggestionCategory,
    this.suggestionAmount,
    this.confidence,
    this.reason,
    this.inputDescription,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'flow': flow,
        'eventType': eventType,
        'isIncome': isIncome,
        if (suggestionDescription != null)
          'suggestionDescription': suggestionDescription,
        if (suggestionCategory != null)
          'suggestionCategory': suggestionCategory,
        if (suggestionAmount != null) 'suggestionAmount': suggestionAmount,
        if (confidence != null) 'confidence': confidence,
        if (reason != null) 'reason': reason,
        if (inputDescription != null) 'inputDescription': inputDescription,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

class SyncCircuitStatus {
  final int consecutiveFullFailures;
  final int consecutivePullFailures;
  final int fullFailureThreshold;
  final int pullFailureThreshold;
  final DateTime? fullOpenUntil;
  final DateTime? pullOpenUntil;

  const SyncCircuitStatus({
    this.consecutiveFullFailures = 0,
    this.consecutivePullFailures = 0,
    this.fullFailureThreshold = 3,
    this.pullFailureThreshold = 5,
    this.fullOpenUntil,
    this.pullOpenUntil,
  });

  bool get isFullOpen =>
      fullOpenUntil != null && DateTime.now().isBefore(fullOpenUntil!);

  bool get isPullOpen =>
      pullOpenUntil != null && DateTime.now().isBefore(pullOpenUntil!);

  bool get hasOpenCircuit => isFullOpen || isPullOpen;

  Duration? get fullOpenRemaining {
    if (!isFullOpen || fullOpenUntil == null) return null;
    return fullOpenUntil!.difference(DateTime.now());
  }

  Duration? get pullOpenRemaining {
    if (!isPullOpen || pullOpenUntil == null) return null;
    return pullOpenUntil!.difference(DateTime.now());
  }
}

class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? error;
  final SyncMetrics metrics;
  final SyncCircuitStatus circuitStatus;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.error,
    this.metrics = const SyncMetrics(),
    this.circuitStatus = const SyncCircuitStatus(),
  });

  SyncState copyWith(
          {bool? isSyncing,
          DateTime? lastSyncTime,
          String? error,
          SyncMetrics? metrics,
          SyncCircuitStatus? circuitStatus}) =>
      SyncState(
        isSyncing: isSyncing ?? this.isSyncing,
        lastSyncTime: lastSyncTime ?? this.lastSyncTime,
        error: error,
        metrics: metrics ?? this.metrics,
        circuitStatus: circuitStatus ?? this.circuitStatus,
      );
}

class _ConflictCloudSnapshot {
  final bool available;
  final Map<String, Map<String, dynamic>> expenses;
  final Map<String, Map<String, dynamic>> budgets;
  final Map<String, Map<String, dynamic>> goals;

  const _ConflictCloudSnapshot({
    required this.available,
    this.expenses = const {},
    this.budgets = const {},
    this.goals = const {},
  });
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class SyncNotifier extends StateNotifier<SyncState> {
  static const int _syncVersion = 1;

  final Ref _ref;
  final Random _random = Random();
  late final Future<void> _restoreSyncTimeFuture;
  Timer? _debounceTimer;
  Timer? _pullDebounceTimer;
  Timer? _intervalTimer;
  Timer? _foregroundPullTimer;
  bool _queuedWhileSyncing = false;
  bool _pullOnlyInProgress = false;
  bool _isForeground = true;
  DateTime? _lastRouteTriggerAt;
  DateTime? _lastPullAttemptAt;
  DateTime? _serverSuggestedDelayExpiresAt;
  DateTime? _fastPullUntil;
  int _consecutiveEmptyPulls = 0;
  Duration? _serverSuggestedForegroundPullDelay;
  late final Duration _interval;
  late final Duration _baseForegroundPullInterval;
  static const _routeTriggerCooldown = Duration(seconds: 90);
  static const _fastPullWindow = Duration(minutes: 2);
  static const _intervalFreshnessThreshold = Duration(seconds: 90);
  static const _startupFreshSyncSkipWindow = Duration(minutes: 2);
  static const _minPullGap = Duration(seconds: 30);
  static const _foregroundPullJitterRatio = 0.20;
  static const _lastSyncStorageKey = 'ff_last_sync_time_utc';
  static const _sampleWindow = 100;
  static const _fullFailureThreshold = 3;
  static const _pullFailureThreshold = 5;
  static const _fullCircuitDuration = Duration(seconds: 45);
  static const _pullCircuitDuration = Duration(seconds: 30);
  static const _maxSuggestionInteractions = 300;

  int _consecutiveFullFailures = 0;
  int _consecutivePullFailures = 0;
  DateTime? _fullCircuitOpenUntil;
  DateTime? _pullCircuitOpenUntil;
  final List<int> _pushLatencySamples = [];
  final List<int> _pullLatencySamples = [];
  final List<int> _pullStalenessSamples = [];
  final List<SuggestionInteractionEvent> _pendingSuggestionInteractions = [];

  // Must use the same Android options as auth_interceptor.dart and
  // cloud_auth_provider.dart — all three must read/write the same
  // encryptedSharedPreferences bucket; mismatched options = different
  // buckets = token always reads null = sync permanently skipped on Android.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  SyncNotifier(this._ref) : super(const SyncState()) {
    _interval = _resolveFullSyncInterval();
    _baseForegroundPullInterval = _resolveForegroundPullInterval();
    _restoreSyncTimeFuture = _restoreLastSyncTime();

    // Listen for login / session-restore events and sync immediately.
    // This covers: login, register+verify, cold-start session restore.
    _ref.listen<CloudAuthState>(cloudAuthProvider, (prev, next) {
      final wasConnected = prev?.isConnected ?? false;
      if (!wasConnected && next.isConnected) {
        debugPrint('[FinFlow Sync] 🔑 Connected — scheduling sync');
        scheduleSync(
          reason: 'auth-connected',
          delay: const Duration(seconds: 1),
        );
      }
    });

    // Auto-sync when device comes back online after being offline.
    // Combined with the cloudAuth listener above, this covers all reconnect paths.
    _ref.listen<bool>(connectivityProvider, (prev, next) {
      final wasOffline = !(prev ?? true);
      if (wasOffline && next) {
        debugPrint('[FinFlow Sync] 📶 Network restored — scheduling sync');
        scheduleSync(
          reason: 'network-restored',
          delay: const Duration(seconds: 1),
        );
      }
    });

    // Interval safety net: keeps cross-device data eventually consistent
    // without forcing sync on every single write action.
    _intervalTimer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      unawaited(_runIntervalTick());
    });

    // Foreground pull-only polling keeps cross-device updates fresh while
    // avoiding full push+pull on every short interval tick.
    _scheduleNextForegroundPull();

    _autoSyncOnStartup();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pullDebounceTimer?.cancel();
    _intervalTimer?.cancel();
    _foregroundPullTimer?.cancel();
    super.dispose();
  }

  void scheduleSync({
    String reason = 'scheduled',
    Duration delay = const Duration(seconds: 4),
  }) {
    if (_isCircuitOpen(pullOnly: false)) {
      debugPrint('[FinFlow Sync] ⛔ Full-sync circuit open, skipping ($reason)');
      return;
    }
    if (_isMutationReason(reason)) {
      _markFastPullWindow();
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (!mounted) return;
      debugPrint('[FinFlow Sync] ⏱ Running scheduled sync ($reason)');
      sync();
    });
  }

  void schedulePull({
    String reason = 'scheduled-pull',
    Duration delay = const Duration(seconds: 1),
  }) {
    if (_isCircuitOpen(pullOnly: true)) {
      debugPrint('[FinFlow Sync] ⛔ Pull circuit open, skipping ($reason)');
      return;
    }
    final now = DateTime.now();
    final lastPullAttemptAt = _lastPullAttemptAt;
    final skipForGap = lastPullAttemptAt != null &&
        now.difference(lastPullAttemptAt) < _minPullGap &&
        !_isMutationReason(reason) &&
        !reason.startsWith('retry-');
    if (skipForGap) {
      return;
    }

    _lastPullAttemptAt = now;
    _pullDebounceTimer?.cancel();
    _pullDebounceTimer = Timer(delay, () {
      if (!mounted) return;
      debugPrint('[FinFlow Sync] 👀 Running light pull ($reason)');
      sync(pushChanges: false, showSyncingState: false);
    });
  }

  void onRouteVisible(String routeName) {
    final now = DateTime.now();
    final last = _lastRouteTriggerAt;
    if (last != null && now.difference(last) < _routeTriggerCooldown) {
      return;
    }
    _lastRouteTriggerAt = now;
    schedulePull(reason: 'route-$routeName', delay: Duration.zero);
  }

  void onAppForegroundChanged(bool isForeground) {
    _isForeground = isForeground;
    if (!isForeground) {
      _foregroundPullTimer?.cancel();
      return;
    }
    if (isForeground) {
      schedulePull(reason: 'app-foreground', delay: Duration.zero);
      _scheduleNextForegroundPull();
    }
  }

  void onAppResumed() {
    onAppForegroundChanged(true);
    scheduleSync(
      reason: 'app-resumed',
      delay: const Duration(seconds: 1),
    );
  }

  Future<void> _runIntervalTick() async {
    if (!mounted || state.isSyncing || _pullOnlyInProgress) return;

    final hasPending = _hasPendingLocalQueue();
    final lastSync = state.lastSyncTime;
    final isStale = lastSync == null ||
        DateTime.now().toUtc().difference(lastSync.toUtc()) >
            _intervalFreshnessThreshold;

    if (hasPending || isStale) {
      scheduleSync(reason: 'interval-120s', delay: Duration.zero);
    } else {
      debugPrint('[FinFlow Sync] ⏭ Skipped interval sync — data still fresh');
    }
  }

  bool _hasPendingLocalQueue() {
    final expDs = _ref.read(expenseDatasourceProvider);
    final budgetDs = _ref.read(budgetDatasourceProvider);
    final goalDs = _ref.read(goalDatasourceProvider);

    return expDs.getPendingDeletions().isNotEmpty ||
        expDs.getPendingUpserts().isNotEmpty ||
        budgetDs.getPendingUpserts().isNotEmpty ||
        budgetDs.getPendingDeletions().isNotEmpty ||
        goalDs.getPendingUpserts().isNotEmpty ||
        goalDs.getPendingDeletions().isNotEmpty ||
        _pendingSuggestionInteractions.isNotEmpty;
  }

  int _currentQueueDepth() {
    final expDs = _ref.read(expenseDatasourceProvider);
    final budgetDs = _ref.read(budgetDatasourceProvider);
    final goalDs = _ref.read(goalDatasourceProvider);

    return expDs.getPendingDeletions().length +
        expDs.getPendingUpserts().length +
        budgetDs.getPendingUpserts().length +
        budgetDs.getPendingDeletions().length +
        goalDs.getPendingUpserts().length +
        goalDs.getPendingDeletions().length +
        _pendingSuggestionInteractions.length;
  }

  void trackSuggestionInteraction({
    required String flow,
    required String eventType,
    required bool isIncome,
    String? suggestionDescription,
    String? suggestionCategory,
    double? suggestionAmount,
    int? confidence,
    String? reason,
    String? inputDescription,
  }) {
    final normalizedEventType = eventType == 'ignored' ? 'ignored' : 'accepted';
    final normalizedFlow = flow.trim();
    if (normalizedFlow.isEmpty) return;

    final event = SuggestionInteractionEvent(
      flow: normalizedFlow.length > 48
          ? normalizedFlow.substring(0, 48)
          : normalizedFlow,
      eventType: normalizedEventType,
      isIncome: isIncome,
      suggestionDescription: _trimNullable(suggestionDescription, 120),
      suggestionCategory: _trimNullable(suggestionCategory, 64),
      suggestionAmount: suggestionAmount,
      confidence: confidence?.clamp(0, 100),
      reason: _trimNullable(reason, 64),
      inputDescription: _trimNullable(inputDescription, 120),
      createdAt: DateTime.now().toUtc(),
    );

    _pendingSuggestionInteractions.add(event);
    if (_pendingSuggestionInteractions.length > _maxSuggestionInteractions) {
      _pendingSuggestionInteractions.removeRange(
        0,
        _pendingSuggestionInteractions.length - _maxSuggestionInteractions,
      );
    }

    _updateMetrics(queueDepth: _currentQueueDepth());
    scheduleSync(
        reason: 'suggestion-feedback', delay: const Duration(seconds: 2));
  }

  String? _trimNullable(String? value, int maxLength) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= maxLength) return trimmed;
    return trimmed.substring(0, maxLength);
  }

  SyncConflictSummary getLocalConflictSummary() {
    final expDs = _ref.read(expenseDatasourceProvider);
    final budgetDs = _ref.read(budgetDatasourceProvider);
    final goalDs = _ref.read(goalDatasourceProvider);

    return SyncConflictSummary(
      expensePendingUpserts: expDs.getPendingUpserts(),
      expensePendingDeletions: expDs.getPendingDeletions(),
      budgetPendingUpserts: budgetDs.getPendingUpserts(),
      budgetPendingDeletions: budgetDs.getPendingDeletions(),
      goalPendingUpserts: goalDs.getPendingUpserts(),
      goalPendingDeletions: goalDs.getPendingDeletions(),
    );
  }

  Future<void> discardPendingLocalChanges() async {
    final expDs = _ref.read(expenseDatasourceProvider);
    final budgetDs = _ref.read(budgetDatasourceProvider);
    final goalDs = _ref.read(goalDatasourceProvider);

    await Future.wait([
      expDs.clearAllPendingUpserts(),
      expDs.clearAllPendingDeletions(),
      budgetDs.clearAllPendingUpserts(),
      budgetDs.clearAllPendingDeletions(),
      goalDs.clearAllPendingUpserts(),
      goalDs.clearAllPendingDeletions(),
    ]);
    _pendingSuggestionInteractions.clear();

    _updateMetrics(queueDepth: 0);
    state = state.copyWith(error: null);
    schedulePull(reason: 'conflict-discard-local', delay: Duration.zero);
  }

  Future<List<SyncConflictRecord>> buildConflictRecords() async {
    final summary = getLocalConflictSummary();
    final expDs = _ref.read(expenseDatasourceProvider);
    final budgetDs = _ref.read(budgetDatasourceProvider);
    final goalDs = _ref.read(goalDatasourceProvider);

    final localExpenses = {
      for (final expense in expDs.getAll()) expense.id: expense.toJson(),
    };
    final localBudgets = {
      for (final budget in budgetDs.getAll()) budget.id: budget.toJson(),
    };
    final localGoals = {
      for (final goal in goalDs.getAll()) goal.id: goal.toJson(),
    };

    final cloudSnapshot = await _fetchConflictCloudSnapshot();
    final records = <SyncConflictRecord>[];

    for (final id in summary.expensePendingUpserts.toSet()) {
      records.add(
        _buildConflictRecord(
          id: id,
          entityType: SyncConflictEntityType.expense,
          actionType: SyncConflictActionType.upsert,
          localData: localExpenses[id],
          cloudData:
              cloudSnapshot.available ? cloudSnapshot.expenses[id] : null,
          cloudSnapshotAvailable: cloudSnapshot.available,
        ),
      );
    }
    for (final id in summary.expensePendingDeletions.toSet()) {
      records.add(
        _buildConflictRecord(
          id: id,
          entityType: SyncConflictEntityType.expense,
          actionType: SyncConflictActionType.deletion,
          localData: localExpenses[id],
          cloudData:
              cloudSnapshot.available ? cloudSnapshot.expenses[id] : null,
          cloudSnapshotAvailable: cloudSnapshot.available,
        ),
      );
    }

    for (final id in summary.budgetPendingUpserts.toSet()) {
      records.add(
        _buildConflictRecord(
          id: id,
          entityType: SyncConflictEntityType.budget,
          actionType: SyncConflictActionType.upsert,
          localData: localBudgets[id],
          cloudData: cloudSnapshot.available ? cloudSnapshot.budgets[id] : null,
          cloudSnapshotAvailable: cloudSnapshot.available,
        ),
      );
    }
    for (final id in summary.budgetPendingDeletions.toSet()) {
      records.add(
        _buildConflictRecord(
          id: id,
          entityType: SyncConflictEntityType.budget,
          actionType: SyncConflictActionType.deletion,
          localData: localBudgets[id],
          cloudData: cloudSnapshot.available ? cloudSnapshot.budgets[id] : null,
          cloudSnapshotAvailable: cloudSnapshot.available,
        ),
      );
    }

    for (final id in summary.goalPendingUpserts.toSet()) {
      records.add(
        _buildConflictRecord(
          id: id,
          entityType: SyncConflictEntityType.goal,
          actionType: SyncConflictActionType.upsert,
          localData: localGoals[id],
          cloudData: cloudSnapshot.available ? cloudSnapshot.goals[id] : null,
          cloudSnapshotAvailable: cloudSnapshot.available,
        ),
      );
    }
    for (final id in summary.goalPendingDeletions.toSet()) {
      records.add(
        _buildConflictRecord(
          id: id,
          entityType: SyncConflictEntityType.goal,
          actionType: SyncConflictActionType.deletion,
          localData: localGoals[id],
          cloudData: cloudSnapshot.available ? cloudSnapshot.goals[id] : null,
          cloudSnapshotAvailable: cloudSnapshot.available,
        ),
      );
    }

    records.sort((a, b) {
      final typeCompare = _entitySortOrder(a.entityType)
          .compareTo(_entitySortOrder(b.entityType));
      if (typeCompare != 0) return typeCompare;
      final actionCompare = a.actionType.index.compareTo(b.actionType.index);
      if (actionCompare != 0) return actionCompare;
      return a.id.compareTo(b.id);
    });
    return records;
  }

  Future<void> preferCloudForConflict(SyncConflictRecord record) async {
    final cloudSnapshot = await _fetchConflictCloudSnapshot();
    if (!cloudSnapshot.available) {
      state = state.copyWith(
        error:
            'Unable to load cloud snapshot. Reconnect and try conflict merge again.',
      );
      return;
    }

    final cloudData = switch (record.entityType) {
      SyncConflictEntityType.expense => cloudSnapshot.expenses[record.id],
      SyncConflictEntityType.budget => cloudSnapshot.budgets[record.id],
      SyncConflictEntityType.goal => cloudSnapshot.goals[record.id],
    };

    await _clearPendingForRecord(record.entityType, record.id);
    await _applyCloudSnapshotForRecord(record.entityType, record.id, cloudData);

    _updateMetrics(queueDepth: _currentQueueDepth());
    state = state.copyWith(error: null);
    schedulePull(reason: 'conflict-prefer-cloud', delay: Duration.zero);
  }

  Future<void> retryNow({bool pullOnly = false}) async {
    _consecutiveFullFailures = 0;
    _consecutivePullFailures = 0;
    _fullCircuitOpenUntil = null;
    _pullCircuitOpenUntil = null;
    _publishCircuitStatus();

    if (pullOnly) {
      await sync(pushChanges: false, showSyncingState: false);
      return;
    }
    await sync();
  }

  SyncConflictRecord _buildConflictRecord({
    required String id,
    required SyncConflictEntityType entityType,
    required SyncConflictActionType actionType,
    required Map<String, dynamic>? localData,
    required Map<String, dynamic>? cloudData,
    required bool cloudSnapshotAvailable,
  }) {
    return SyncConflictRecord(
      id: id,
      entityType: entityType,
      actionType: actionType,
      localData: localData,
      cloudData: cloudData,
      localUpdatedAt: _parseDateTime(localData?['updatedAt']),
      cloudUpdatedAt: _parseDateTime(cloudData?['updatedAt']),
      cloudSnapshotAvailable: cloudSnapshotAvailable,
      changedFields: _diffFields(localData, cloudData),
    );
  }

  Future<_ConflictCloudSnapshot> _fetchConflictCloudSnapshot() async {
    final token = await _storage.read(key: TokenKeys.accessToken);
    final isOnline = _ref.read(connectivityProvider);
    if (token == null || !isOnline) {
      return const _ConflictCloudSnapshot(available: false);
    }

    try {
      final dio = _ref.read(dioProvider);
      final pullRes = await dio.get(
        ApiEndpoints.syncPull,
        queryParameters: {'syncVersion': _syncVersion},
      );
      final pullData = pullRes.data is Map<String, dynamic>
          ? pullRes.data['data'] as Map<String, dynamic>?
          : null;

      final expenseMap = <String, Map<String, dynamic>>{};
      final budgetMap = <String, Map<String, dynamic>>{};
      final goalMap = <String, Map<String, dynamic>>{};

      for (final raw in (pullData?['expenses'] as List?) ?? const []) {
        if (raw is! Map) continue;
        final normalized =
            _normalizeServerExpenseRecord(raw.cast<String, dynamic>());
        if (normalized == null) continue;
        expenseMap[normalized['id'] as String] = normalized;
      }

      for (final raw in (pullData?['budgets'] as List?) ?? const []) {
        if (raw is! Map) continue;
        final normalized =
            _normalizeServerBudgetRecord(raw.cast<String, dynamic>());
        if (normalized == null) continue;
        budgetMap[normalized['id'] as String] = normalized;
      }

      for (final raw in (pullData?['goals'] as List?) ?? const []) {
        if (raw is! Map) continue;
        final normalized =
            _normalizeServerGoalRecord(raw.cast<String, dynamic>());
        if (normalized == null) continue;
        goalMap[normalized['id'] as String] = normalized;
      }

      return _ConflictCloudSnapshot(
        available: true,
        expenses: expenseMap,
        budgets: budgetMap,
        goals: goalMap,
      );
    } catch (_) {
      return const _ConflictCloudSnapshot(available: false);
    }
  }

  Map<String, dynamic>? _normalizeServerExpenseRecord(
    Map<String, dynamic> raw,
  ) {
    final id = raw['id'] as String?;
    if (id == null) return null;

    if (raw['deleted'] == true) {
      return {
        'id': id,
        'deleted': true,
        'updatedAt': _toIsoString(raw['updatedAt']),
      };
    }

    return {
      'id': id,
      'amount': (raw['amount'] as num?)?.toDouble() ?? 0,
      'description': raw['description'] as String? ?? '',
      'category': raw['category'] as String? ?? 'other',
      'date': _toIsoString(raw['date']),
      'note': raw['notes'],
      'receiptImageBase64': raw['receiptImageBase64'],
      'receiptImageMimeType': raw['receiptImageMimeType'],
      'receiptImageUrl': raw['receiptImageUrl'],
      'receiptStorageKey': raw['receiptStorageKey'],
      'receiptOcrText': raw['receiptOcrText'],
      'isIncome': raw['isIncome'] == true,
      'isRecurring': raw['isRecurring'] == true,
      'recurringFrequency': raw['recurringRule'],
      'recurringDueDay': (raw['recurringDueDay'] as num?)?.toInt(),
      'updatedAt': _toIsoString(raw['updatedAt']),
    };
  }

  Map<String, dynamic>? _normalizeServerBudgetRecord(
    Map<String, dynamic> raw,
  ) {
    final id = raw['id'] as String?;
    if (id == null) return null;

    if (raw['deleted'] == true) {
      return {
        'id': id,
        'deleted': true,
        'updatedAt': _toIsoString(raw['updatedAt']),
      };
    }

    return {
      'id': id,
      'categoryKey': raw['categoryKey'] as String? ?? '',
      'allocatedAmount': (raw['allocatedAmount'] as num?)?.toDouble() ?? 0,
      'month': (raw['month'] as num?)?.toInt() ?? 1,
      'year': (raw['year'] as num?)?.toInt() ?? DateTime.now().year,
      'carryForward': raw['carryForward'] == true,
      'updatedAt': _toIsoString(raw['updatedAt']),
    };
  }

  Map<String, dynamic>? _normalizeServerGoalRecord(
    Map<String, dynamic> raw,
  ) {
    final id = raw['id'] as String?;
    if (id == null) return null;

    if (raw['deleted'] == true) {
      return {
        'id': id,
        'deleted': true,
        'updatedAt': _toIsoString(raw['updatedAt']),
      };
    }

    final deadline = raw['deadline'];
    return {
      'id': id,
      'title': raw['title'] as String? ?? '',
      'emoji': raw['emoji'] as String? ?? '🎯',
      'targetAmount': (raw['targetAmount'] as num?)?.toDouble() ?? 0,
      'currentAmount': (raw['currentAmount'] as num?)?.toDouble() ?? 0,
      'deadline': deadline == null ? null : _toIsoString(deadline),
      'colorIndex': (raw['colorIndex'] as num?)?.toInt() ?? 0,
      'updatedAt': _toIsoString(raw['updatedAt']),
    };
  }

  List<String> _diffFields(
    Map<String, dynamic>? localData,
    Map<String, dynamic>? cloudData,
  ) {
    if (localData == null || cloudData == null) return const [];
    if (cloudData['deleted'] == true) return const ['deleted'];

    final keys = <String>{...localData.keys, ...cloudData.keys}
      ..remove('id')
      ..remove('updatedAt');

    final diffs = <String>[];
    for (final key in keys) {
      final localValue = _normalizeDiffValue(localData[key]);
      final cloudValue = _normalizeDiffValue(cloudData[key]);
      if (localValue != cloudValue) {
        diffs.add(key);
      }
    }
    diffs.sort();
    return diffs;
  }

  Object? _normalizeDiffValue(dynamic value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is num) return value.toDouble();
    return value;
  }

  int _entitySortOrder(SyncConflictEntityType type) {
    return switch (type) {
      SyncConflictEntityType.expense => 0,
      SyncConflictEntityType.budget => 1,
      SyncConflictEntityType.goal => 2,
    };
  }

  Future<void> _clearPendingForRecord(
    SyncConflictEntityType entityType,
    String id,
  ) async {
    switch (entityType) {
      case SyncConflictEntityType.expense:
        final expDs = _ref.read(expenseDatasourceProvider);
        await expDs.clearPendingUpsert(id);
        await expDs.clearPendingDeletion(id);
        return;
      case SyncConflictEntityType.budget:
        final budgetDs = _ref.read(budgetDatasourceProvider);
        await budgetDs.clearPendingUpsert(id);
        await budgetDs.clearPendingDeletion(id);
        return;
      case SyncConflictEntityType.goal:
        final goalDs = _ref.read(goalDatasourceProvider);
        await goalDs.clearPendingUpsert(id);
        await goalDs.clearPendingDeletion(id);
        return;
    }
  }

  Future<void> _applyCloudSnapshotForRecord(
    SyncConflictEntityType entityType,
    String id,
    Map<String, dynamic>? cloudData,
  ) async {
    switch (entityType) {
      case SyncConflictEntityType.expense:
        final expNotifier = _ref.read(expenseProvider.notifier);
        if (cloudData == null || cloudData['deleted'] == true) {
          await expNotifier.bulkDeleteFromSync([id]);
          return;
        }
        try {
          final expense = Expense.fromJson(cloudData);
          await expNotifier.bulkUpsertFromSync([expense]);
        } catch (_) {
          await expNotifier.bulkDeleteFromSync([id]);
        }
        return;
      case SyncConflictEntityType.budget:
        final budgetDs = _ref.read(budgetDatasourceProvider);
        if (cloudData == null || cloudData['deleted'] == true) {
          Budget? localBudget;
          for (final budget in budgetDs.getAll()) {
            if (budget.id == id) {
              localBudget = budget;
              break;
            }
          }
          if (localBudget != null) {
            await budgetDs.deleteBudget(
              id,
              localBudget.month,
              localBudget.year,
              trackPending: false,
            );
          }
        } else {
          try {
            final budget = Budget.fromJson(cloudData);
            await budgetDs.saveBudget(budget, trackPending: false);
          } catch (_) {}
        }
        _ref.read(budgetProvider.notifier).refresh();
        return;
      case SyncConflictEntityType.goal:
        final goalDs = _ref.read(goalDatasourceProvider);
        if (cloudData == null || cloudData['deleted'] == true) {
          await goalDs.delete(id, trackPending: false);
        } else {
          try {
            final goal = SavingsGoal.fromJson(cloudData);
            await goalDs.save(goal, trackPendingUpsert: false);
          } catch (_) {}
        }
        _ref.read(goalsProvider.notifier).refresh();
        return;
    }
  }

  bool _isMutationReason(String reason) {
    const hints = <String>[
      'created',
      'updated',
      'deleted',
      'quick-add',
      'post-login',
      'auth-connected',
      'network-restored',
      'app-resumed',
      'queued-follow-up',
    ];
    final normalized = reason.toLowerCase();
    return hints.any(normalized.contains);
  }

  void _markFastPullWindow() {
    _fastPullUntil = DateTime.now().add(_fastPullWindow);
    _consecutiveEmptyPulls = 0;
    if (_isForeground) {
      _scheduleNextForegroundPull();
    }
  }

  Duration _maxDuration(Duration a, Duration b) {
    return a.compareTo(b) >= 0 ? a : b;
  }

  Duration _nextForegroundPullDelay() {
    if (_hasPendingLocalQueue()) {
      return _maxDuration(
        _baseForegroundPullInterval,
        const Duration(seconds: 45),
      );
    }

    final now = DateTime.now();
    if (_fastPullUntil != null && now.isBefore(_fastPullUntil!)) {
      return _baseForegroundPullInterval;
    }
    if (_consecutiveEmptyPulls >= 8) {
      return _maxDuration(
          _baseForegroundPullInterval, const Duration(minutes: 5));
    }
    if (_consecutiveEmptyPulls >= 4) {
      return _maxDuration(
          _baseForegroundPullInterval, const Duration(minutes: 2));
    }

    var nextDelay =
        _maxDuration(_baseForegroundPullInterval, const Duration(seconds: 60));
    final suggestedDelay = _activeServerSuggestedPullDelay();
    if (suggestedDelay != null) {
      nextDelay = _maxDuration(nextDelay, suggestedDelay);
    }
    return nextDelay;
  }

  void _scheduleNextForegroundPull() {
    _foregroundPullTimer?.cancel();
    if (!mounted || !_isForeground) return;
    final delay = _jitteredDelay(_nextForegroundPullDelay());
    _foregroundPullTimer = Timer(delay, () {
      if (!mounted || !_isForeground) return;
      schedulePull(
          reason: 'foreground-${delay.inSeconds}s', delay: Duration.zero);
      _scheduleNextForegroundPull();
    });
  }

  Duration? _activeServerSuggestedPullDelay() {
    final expiresAt = _serverSuggestedDelayExpiresAt;
    if (_serverSuggestedForegroundPullDelay == null || expiresAt == null) {
      return null;
    }
    if (DateTime.now().isAfter(expiresAt)) {
      _serverSuggestedForegroundPullDelay = null;
      _serverSuggestedDelayExpiresAt = null;
      return null;
    }
    return _serverSuggestedForegroundPullDelay;
  }

  Duration _jitteredDelay(Duration baseDelay) {
    final ms = baseDelay.inMilliseconds;
    if (ms <= 0) return baseDelay;

    final minFactor = 1 - _foregroundPullJitterRatio;
    final maxFactor = 1 + _foregroundPullJitterRatio;
    final factor = minFactor + (_random.nextDouble() * (maxFactor - minFactor));
    final jittered = (ms * factor).round();
    return Duration(milliseconds: jittered.clamp(1000, 10 * 60 * 1000));
  }

  Future<void> _restoreLastSyncTime() async {
    final raw = await _storage.read(key: _lastSyncStorageKey);
    if (raw == null) return;
    final parsed = DateTime.tryParse(raw)?.toUtc();
    if (parsed == null || !mounted) return;
    state = state.copyWith(lastSyncTime: parsed);
  }

  Future<void> _persistLastSyncTime(DateTime syncTimeUtc) async {
    await _storage.write(
      key: _lastSyncStorageKey,
      value: syncTimeUtc.toIso8601String(),
    );
  }

  Duration _resolveFullSyncInterval() {
    if (kIsWeb) return const Duration(seconds: 90);
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return const Duration(seconds: 180);
      case TargetPlatform.android:
        return const Duration(seconds: 120);
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return const Duration(seconds: 90);
    }
  }

  Duration _resolveForegroundPullInterval() {
    if (kIsWeb) return const Duration(seconds: 20);
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return const Duration(seconds: 30);
      case TargetPlatform.android:
        return const Duration(seconds: 45);
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return const Duration(seconds: 45);
    }
  }

  SyncCircuitStatus _currentCircuitStatus() {
    return SyncCircuitStatus(
      consecutiveFullFailures: _consecutiveFullFailures,
      consecutivePullFailures: _consecutivePullFailures,
      fullFailureThreshold: _fullFailureThreshold,
      pullFailureThreshold: _pullFailureThreshold,
      fullOpenUntil: _fullCircuitOpenUntil,
      pullOpenUntil: _pullCircuitOpenUntil,
    );
  }

  void _publishCircuitStatus() {
    if (!mounted) return;
    state = state.copyWith(
      circuitStatus: _currentCircuitStatus(),
      error: state.error,
    );
  }

  bool _isCircuitOpen({required bool pullOnly}) {
    final now = DateTime.now();
    final openUntil = pullOnly ? _pullCircuitOpenUntil : _fullCircuitOpenUntil;
    if (openUntil == null) return false;
    if (now.isBefore(openUntil)) return true;

    if (pullOnly) {
      _pullCircuitOpenUntil = null;
      _consecutivePullFailures = 0;
    } else {
      _fullCircuitOpenUntil = null;
      _consecutiveFullFailures = 0;
    }
    _publishCircuitStatus();
    return false;
  }

  Duration _retryDelay({required bool pullOnly, required int failures}) {
    final cappedFailures = min(failures, 6);
    final baseSeconds =
        pullOnly ? min(2 * cappedFailures, 20) : min(4 * cappedFailures, 40);
    final jitterMs = _random.nextInt(850);
    return Duration(seconds: baseSeconds, milliseconds: jitterMs);
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    return null;
  }

  String _toIsoString(dynamic raw) {
    if (raw is String) return raw;
    if (raw is DateTime) return raw.toIso8601String();
    return DateTime.now().toIso8601String();
  }

  int _p95(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final idx = ((sorted.length * 0.95).ceil() - 1).clamp(0, sorted.length - 1);
    return sorted[idx];
  }

  void _addSample(List<int> bucket, int value) {
    bucket.add(max(0, value));
    if (bucket.length > _sampleWindow) {
      bucket.removeRange(0, bucket.length - _sampleWindow);
    }
  }

  void _updateMetrics({
    int? queueDepth,
    int? stalenessMs,
    bool error = false,
    bool retry = false,
  }) {
    final prev = state.metrics;
    final next = prev.copyWith(
      queueDepth: queueDepth ?? prev.queueDepth,
      pushLatencyP95Ms: _p95(_pushLatencySamples),
      pullLatencyP95Ms: _p95(_pullLatencySamples),
      pullStalenessMs: _pullStalenessSamples.isEmpty
          ? (stalenessMs ?? prev.pullStalenessMs)
          : _p95(_pullStalenessSamples),
      errorCount: error ? prev.errorCount + 1 : prev.errorCount,
      retryCount: retry ? prev.retryCount + 1 : prev.retryCount,
    );
    state = state.copyWith(metrics: next);
  }

  List<String> _extractIds(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  Future<void> _applyAckToExpenseQueues(
    ExpenseLocalDatasource expDs,
    Map<String, dynamic>? ack,
  ) async {
    if (ack == null) return;
    final upserts = [
      ..._extractIds(ack['appliedUpserts']),
      ..._extractIds(ack['skippedUpserts']),
    ];
    final deletions = [
      ..._extractIds(ack['appliedDeletions']),
      ..._extractIds(ack['skippedDeletions']),
    ];
    for (final id in upserts) {
      await expDs.clearPendingUpsert(id);
    }
    for (final id in deletions) {
      await expDs.clearPendingDeletion(id);
    }
  }

  Future<void> _applyAckToBudgetQueues(
    BudgetLocalDatasource budgetDs,
    Map<String, dynamic>? ack,
  ) async {
    if (ack == null) return;
    final upserts = [
      ..._extractIds(ack['appliedUpserts']),
      ..._extractIds(ack['skippedUpserts']),
    ];
    final deletions = [
      ..._extractIds(ack['appliedDeletions']),
      ..._extractIds(ack['skippedDeletions']),
    ];
    for (final id in upserts) {
      await budgetDs.clearPendingUpsert(id);
    }
    for (final id in deletions) {
      await budgetDs.clearPendingDeletion(id);
    }
  }

  Future<void> _applyAckToGoalQueues(
    GoalLocalDatasource goalDs,
    Map<String, dynamic>? ack,
  ) async {
    if (ack == null) return;
    final upserts = [
      ..._extractIds(ack['appliedUpserts']),
      ..._extractIds(ack['skippedUpserts']),
    ];
    final deletions = [
      ..._extractIds(ack['appliedDeletions']),
      ..._extractIds(ack['skippedDeletions']),
    ];
    for (final id in upserts) {
      await goalDs.clearPendingUpsert(id);
    }
    for (final id in deletions) {
      await goalDs.clearPendingDeletion(id);
    }
  }

  void _markFailure({required bool pullOnly}) {
    if (pullOnly) {
      _consecutivePullFailures += 1;
      if (_consecutivePullFailures >= _pullFailureThreshold) {
        _pullCircuitOpenUntil = DateTime.now().add(_pullCircuitDuration);
      }
    } else {
      _consecutiveFullFailures += 1;
      if (_consecutiveFullFailures >= _fullFailureThreshold) {
        _fullCircuitOpenUntil = DateTime.now().add(_fullCircuitDuration);
      }
    }
    _publishCircuitStatus();
  }

  void _markSuccess({required bool pullOnly}) {
    if (pullOnly) {
      _consecutivePullFailures = 0;
      _pullCircuitOpenUntil = null;
    } else {
      _consecutiveFullFailures = 0;
      _fullCircuitOpenUntil = null;
    }
    _publishCircuitStatus();
  }

  /// On startup: fire sync once after a short delay to let the widget tree
  /// and token storage settle. sync() already gates on the token directly,
  /// so no polling is needed.
  Future<void> _autoSyncOnStartup() async {
    await _restoreSyncTimeFuture;
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final hasPendingQueue = _hasPendingLocalQueue();
    final lastSync = state.lastSyncTime;
    final recentlySynced = lastSync != null &&
        DateTime.now().toUtc().difference(lastSync.toUtc()) <=
            _startupFreshSyncSkipWindow;
    if (!hasPendingQueue && recentlySynced) {
      schedulePull(
        reason: 'startup-fresh-skip',
        delay: const Duration(seconds: 2),
      );
      return;
    }

    await sync();
  }

  Future<void> sync({
    bool pushChanges = true,
    bool showSyncingState = true,
  }) async {
    final startedAt = DateTime.now();
    final isPullOnly = !pushChanges;
    var retryScheduled = false;

    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pullDebounceTimer?.cancel();
    _pullDebounceTimer = null;

    if (_isCircuitOpen(pullOnly: isPullOnly)) {
      debugPrint(
          '[FinFlow Sync] ⏭ Skipped — ${isPullOnly ? 'pull' : 'full'} circuit is open');
      return;
    }

    // Gate on the JWT token directly — same source of truth as AuthInterceptor.
    // This is more reliable than the in-memory isConnected flag which can be
    // stale after hot-reload or a race with _restoreSession().
    final token = await _storage.read(key: TokenKeys.accessToken);
    if (token == null) {
      debugPrint('[FinFlow Sync] ⏭ Skipped — no access token in storage');
      return;
    }

    // Prevent concurrent syncs/pulls
    if (state.isSyncing || _pullOnlyInProgress) {
      debugPrint('[FinFlow Sync] ⏭ Skipped — sync already in progress');
      if (showSyncingState) {
        _queuedWhileSyncing = true;
      }
      return;
    }

    if (showSyncingState) {
      _queuedWhileSyncing = false;
      state = state.copyWith(isSyncing: true);
      debugPrint('[FinFlow Sync] 🔄 Starting sync...');
    } else {
      _pullOnlyInProgress = true;
      debugPrint('[FinFlow Sync] 👀 Starting pull-only sync...');
    }
    try {
      final dio = _ref.read(dioProvider);

      // ── Push local deltas ────────────────────────────────────────────────
      final expDs = _ref.read(expenseDatasourceProvider);
      final budgetDs = _ref.read(budgetDatasourceProvider);
      final goalDs = _ref.read(goalDatasourceProvider);
      final expState = _ref.read(expenseProvider);
      final expenseById = {for (final e in expState.expenses) e.id: e};
      final pendingDelSet = expDs.getPendingDeletions().toSet();
      final pendingExpUpsertSet = expDs.getPendingUpserts().toSet();
      final pendingBudgetUpsertsSet = budgetDs.getPendingUpserts().toSet();
      final pendingBudgetDeletesSet = budgetDs.getPendingDeletions().toSet();
      final pendingGoalUpsertsSet = goalDs.getPendingUpserts().toSet();
      final pendingGoalDeletesSet = goalDs.getPendingDeletions().toSet();

      var queueDepth = pendingDelSet.length +
          pendingExpUpsertSet.length +
          pendingBudgetUpsertsSet.length +
          pendingBudgetDeletesSet.length +
          pendingGoalUpsertsSet.length +
          pendingGoalDeletesSet.length +
          _pendingSuggestionInteractions.length;
      _updateMetrics(queueDepth: queueDepth);

      if (pushChanges) {
        final now = DateTime.now().toIso8601String();
        final suggestionInteractionsToPush = _pendingSuggestionInteractions
            .map((event) => event.toJson())
            .toList(growable: false);

        final expenses = <Map<String, dynamic>>[];
        for (final id in expDs.getPendingUpserts()) {
          final e = expenseById[id];
          if (e == null) continue;
          expenses.add({
            'id': e.id,
            'amount': e.amount,
            'description': e.description,
            'category': e.category.name,
            'date': e.date.toIso8601String(),
            'notes': e.note,
            'receiptImageBase64': e.receiptImageBase64,
            'receiptImageMimeType': e.receiptImageMimeType,
            'receiptImageUrl': e.receiptImageUrl,
            'receiptStorageKey': e.receiptStorageKey,
            'receiptOcrText': e.receiptOcrText,
            'isIncome': e.isIncome,
            'isRecurring': e.isRecurring,
            'recurringRule': e.recurringFrequency?.name,
            'recurringDueDay': e.recurringDueDay,
            'updatedAt': e.updatedAt.toUtc().toIso8601String(),
            'deleted': false,
          });
        }

        final pendingDelIds = expDs.getPendingDeletions();
        for (final id in pendingDelIds) {
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

        final allBudgets = budgetDs.getAll();
        final budgetById = {for (final b in allBudgets) b.id: b};
        final budgets = <Map<String, dynamic>>[];
        for (final id in budgetDs.getPendingUpserts()) {
          final b = budgetById[id];
          if (b == null) continue;
          budgets.add({
            'id': b.id,
            'categoryKey': b.categoryKey,
            'allocatedAmount': b.allocatedAmount,
            'month': b.month,
            'year': b.year,
            'carryForward': b.carryForward,
            'updatedAt': b.updatedAt.toUtc().toIso8601String(),
            'deleted': false,
          });
        }
        for (final id in budgetDs.getPendingDeletions()) {
          final alreadyPresent = budgets.any((b) => b['id'] == id);
          if (!alreadyPresent) {
            budgets.add({
              'id': id,
              'updatedAt': now,
              'deleted': true,
            });
          }
        }

        final allGoals = goalDs.getAll();
        final goalById = {for (final g in allGoals) g.id: g};
        final goals = <Map<String, dynamic>>[];
        for (final id in goalDs.getPendingUpserts()) {
          final g = goalById[id];
          if (g == null) continue;
          goals.add({
            'id': g.id,
            'title': g.title,
            'emoji': g.emoji,
            'targetAmount': g.targetAmount,
            'currentAmount': g.currentAmount,
            'deadline': g.deadline?.toIso8601String(),
            'colorIndex': g.colorIndex,
            'updatedAt': g.updatedAt.toUtc().toIso8601String(),
            'deleted': false,
          });
        }
        final pendingGoalDelIds = goalDs.getPendingDeletions();
        for (final id in pendingGoalDelIds) {
          final alreadyPresent = goals.any((g) => g['id'] == id);
          if (!alreadyPresent) {
            goals.add({'id': id, 'updatedAt': now, 'deleted': true});
          }
        }

        final hasPayload = expenses.isNotEmpty ||
            budgets.isNotEmpty ||
            goals.isNotEmpty ||
            suggestionInteractionsToPush.isNotEmpty;

        if (hasPayload) {
          debugPrint(
              '[FinFlow Sync] 📤 Delta push: ${expenses.length} expenses, ${budgets.length} budgets, ${goals.length} goals, ${suggestionInteractionsToPush.length} suggestion events');
          final pushRes = await dio.post(
            ApiEndpoints.syncPush,
            data: {
              'syncVersion': _syncVersion,
              if (expenses.isNotEmpty) 'expenses': expenses,
              if (budgets.isNotEmpty) 'budgets': budgets,
              if (goals.isNotEmpty) 'goals': goals,
              if (suggestionInteractionsToPush.isNotEmpty)
                'suggestionInteractions': suggestionInteractionsToPush,
            },
            options: Options(headers: {
              'x-sync-retry-count': _consecutiveFullFailures.toString(),
            }),
          );

          final pushData = pushRes.data is Map<String, dynamic>
              ? (pushRes.data['data'] as Map<String, dynamic>?)
              : null;
          final ack = pushData?['ack'] as Map<String, dynamic>?;

          await _applyAckToExpenseQueues(
            expDs,
            ack?['expenses'] as Map<String, dynamic>?,
          );
          await _applyAckToBudgetQueues(
            budgetDs,
            ack?['budgets'] as Map<String, dynamic>?,
          );
          await _applyAckToGoalQueues(
            goalDs,
            ack?['goals'] as Map<String, dynamic>?,
          );
          if (suggestionInteractionsToPush.isNotEmpty) {
            final removeCount = suggestionInteractionsToPush.length;
            if (_pendingSuggestionInteractions.length <= removeCount) {
              _pendingSuggestionInteractions.clear();
            } else {
              _pendingSuggestionInteractions.removeRange(0, removeCount);
            }
          }

          queueDepth = expDs.getPendingDeletions().length +
              expDs.getPendingUpserts().length +
              budgetDs.getPendingUpserts().length +
              budgetDs.getPendingDeletions().length +
              goalDs.getPendingUpserts().length +
              goalDs.getPendingDeletions().length +
              _pendingSuggestionInteractions.length;
          _addSample(
            _pushLatencySamples,
            DateTime.now().difference(startedAt).inMilliseconds,
          );
          _updateMetrics(queueDepth: queueDepth);
          debugPrint('[FinFlow Sync] ✅ Delta push successful');
        }
      }

      // ── Pull server changes ──────────────────────────────────────────────
      // toUtc() ensures the ISO string has a 'Z' suffix so the Node.js server
      // parses it as UTC rather than its local timezone, preventing the
      // subsequent pull from silently skipping server-side changes that
      // occurred within the UTC-offset window.
      final since = state.lastSyncTime?.toUtc().toIso8601String() ?? '';
      final pullQuery = <String, dynamic>{'syncVersion': _syncVersion};
      if (since.isNotEmpty) {
        pullQuery['since'] = since;
      }
      final pullRes = await dio.get(
        ApiEndpoints.syncPull,
        queryParameters: pullQuery,
        options: Options(headers: {
          'x-sync-retry-count': _consecutivePullFailures.toString(),
        }),
      );

      final pullData = pullRes.data['data'];
      final suggestedPullDelayMs =
          (pullData?['suggestedPullDelayMs'] as num?)?.toInt();
      if (suggestedPullDelayMs != null &&
          suggestedPullDelayMs >= 5000 &&
          suggestedPullDelayMs <= 5 * 60 * 1000) {
        _serverSuggestedForegroundPullDelay =
            Duration(milliseconds: suggestedPullDelayMs);
        _serverSuggestedDelayExpiresAt =
            DateTime.now().add(const Duration(minutes: 10));
      }

      final serverExpenses = (pullData?['expenses'] as List?) ?? [];
      final expNotifier = _ref.read(expenseProvider.notifier);
      final pendingExpenseDeletes = expDs.getPendingDeletions().toSet();
      final pendingExpenseUpserts = expDs.getPendingUpserts().toSet();
      final pendingBudgetDeletes = budgetDs.getPendingDeletions().toSet();
      final pendingBudgetUpserts = budgetDs.getPendingUpserts().toSet();
      final pendingGoalDeletes = goalDs.getPendingDeletions().toSet();
      final pendingGoalUpserts = goalDs.getPendingUpserts().toSet();

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
        final serverUpdatedAt = _parseDateTime(se['updatedAt']);
        final localUpdatedAt = expenseById[expId]?.updatedAt.toUtc();
        final hasLocalPending = pendingExpenseDeletes.contains(expId) ||
            pendingExpenseUpserts.contains(expId);

        if (hasLocalPending &&
            serverUpdatedAt != null &&
            localUpdatedAt != null &&
            serverUpdatedAt.isAfter(localUpdatedAt)) {
          await expDs.clearPendingUpsert(expId);
          await expDs.clearPendingDeletion(expId);
        } else if (hasLocalPending) {
          continue;
        }

        if (se['deleted'] == true) {
          toDelete.add(expId);
        } else {
          // Map server field names → local entity field names.
          final mapped = <String, dynamic>{
            'id': expId,
            'amount': se['amount'],
            'description': se['description'],
            'category': se['category'],
            'date': _toIsoString(se['date']),
            'note': se['notes'], // server: notes → local: note
            'receiptImageBase64': se['receiptImageBase64'],
            'receiptImageMimeType': se['receiptImageMimeType'],
            'receiptImageUrl': se['receiptImageUrl'],
            'receiptStorageKey': se['receiptStorageKey'],
            'receiptOcrText': se['receiptOcrText'],
            'isIncome': se['isIncome'] ?? false,
            'isRecurring': se['isRecurring'] ?? false,
            'recurringFrequency': se['recurringRule'], // server name
            'recurringDueDay': (se['recurringDueDay'] as num?)?.toInt(),
            'updatedAt': _toIsoString(se['updatedAt']),
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
        final allBudgets = budgetDs.getAll();
        final localBudgetById = {for (final b in allBudgets) b.id: b};
        for (final raw in serverBudgets) {
          final sb = raw as Map<String, dynamic>;
          final budgetId = sb['id'] as String?;
          if (budgetId == null) continue;
          final serverUpdatedAt = _parseDateTime(sb['updatedAt']);
          final localUpdatedAt = localBudgetById[budgetId]?.updatedAt.toUtc();
          final hasLocalPending = pendingBudgetUpserts.contains(budgetId) ||
              pendingBudgetDeletes.contains(budgetId);

          if (hasLocalPending &&
              serverUpdatedAt != null &&
              localUpdatedAt != null &&
              serverUpdatedAt.isAfter(localUpdatedAt)) {
            await budgetDs.clearPendingUpsert(budgetId);
            await budgetDs.clearPendingDeletion(budgetId);
          } else if (hasLocalPending) {
            continue;
          }

          final month = (sb['month'] as num?)?.toInt();
          final year = (sb['year'] as num?)?.toInt();
          if (month == null || year == null) continue;

          if (sb['deleted'] == true) {
            await budgetDs.deleteBudget(
              budgetId,
              month,
              year,
              trackPending: false,
            );
          } else {
            try {
              final b = Budget(
                id: budgetId,
                categoryKey: sb['categoryKey'] as String,
                allocatedAmount: (sb['allocatedAmount'] as num).toDouble(),
                month: month,
                year: year,
                carryForward: (sb['carryForward'] as bool?) ?? false,
                updatedAt: _parseDateTime(sb['updatedAt']) ?? DateTime.now(),
              );
              await budgetDs.saveBudget(b, trackPending: false);
            } catch (_) {}
          }
        }
        _ref.read(budgetProvider.notifier).refresh();
        debugPrint('[FinFlow Sync] 💰 Synced ${serverBudgets.length} budgets');
      }

      // ── Sync goals from cloud ────────────────────────────────────────────
      final serverGoals = (pullData?['goals'] as List?) ?? [];
      if (serverGoals.isNotEmpty) {
        final localGoals = goalDs.getAll();
        final localGoalById = {for (final g in localGoals) g.id: g};
        final toUpsertGoals = <SavingsGoal>[];
        var deletedCount = 0;

        for (final raw in serverGoals) {
          final sg = raw as Map<String, dynamic>;
          final goalId = sg['id'] as String?;
          if (goalId == null) continue;
          final serverUpdatedAt = _parseDateTime(sg['updatedAt']);
          final localUpdatedAt = localGoalById[goalId]?.updatedAt.toUtc();
          final hasLocalPending = pendingGoalDeletes.contains(goalId) ||
              pendingGoalUpserts.contains(goalId);

          if (hasLocalPending &&
              serverUpdatedAt != null &&
              localUpdatedAt != null &&
              serverUpdatedAt.isAfter(localUpdatedAt)) {
            await goalDs.clearPendingDeletion(goalId);
            await goalDs.clearPendingUpsert(goalId);
          } else if (hasLocalPending) {
            continue;
          }

          if (sg['deleted'] == true) {
            await goalDs.delete(goalId, trackPending: false);
            deletedCount++;
            continue;
          }

          final deadline = sg['deadline'];
          final mapped = <String, dynamic>{
            'id': goalId,
            'title': (sg['title'] as String?) ?? 'Goal',
            'emoji': (sg['emoji'] as String?) ?? '🎯',
            'targetAmount': ((sg['targetAmount'] as num?) ?? 0).toDouble(),
            'currentAmount': ((sg['currentAmount'] as num?) ?? 0).toDouble(),
            'deadline': deadline == null
                ? null
                : (deadline is String
                    ? deadline
                    : (deadline as DateTime).toIso8601String()),
            'colorIndex': (sg['colorIndex'] as num?)?.toInt() ?? 0,
            'updatedAt': _toIsoString(sg['updatedAt']),
          };

          try {
            toUpsertGoals.add(SavingsGoal.fromJson(mapped));
          } catch (_) {}
        }

        for (final goal in toUpsertGoals) {
          await goalDs.save(goal, trackPendingUpsert: false);
        }

        _ref.read(goalsProvider.notifier).refresh();
        debugPrint(
            '[FinFlow Sync] 🎯 Synced ${toUpsertGoals.length} goals, deleted $deletedCount');
      }

      final serverMarkedUnchanged = pullData?['unchanged'] == true;
      final hasServerDelta = serverExpenses.isNotEmpty ||
          serverBudgets.isNotEmpty ||
          serverGoals.isNotEmpty ||
          serverUser != null;
      final hasPendingQueue = queueDepth > 0;
      if (isPullOnly) {
        if ((serverMarkedUnchanged || !hasServerDelta) && !hasPendingQueue) {
          _consecutiveEmptyPulls = min(_consecutiveEmptyPulls + 1, 24);
        } else {
          _consecutiveEmptyPulls = 0;
        }
      }

      final serverTimeRaw = pullData?['serverTime'] as String?;
      final syncTimeUtc = DateTime.tryParse(serverTimeRaw ?? '')?.toUtc() ??
          DateTime.now().toUtc();
      final stalenessMs = syncTimeUtc
          .difference(state.lastSyncTime ?? syncTimeUtc)
          .inMilliseconds
          .clamp(0, 7 * 24 * 3600 * 1000)
          .toInt();
      _addSample(
        _pullLatencySamples,
        DateTime.now().difference(startedAt).inMilliseconds,
      );
      _addSample(_pullStalenessSamples, stalenessMs);
      await _persistLastSyncTime(syncTimeUtc);

      _markSuccess(pullOnly: isPullOnly);
      _updateMetrics(stalenessMs: stalenessMs);

      state = state.copyWith(
        isSyncing: showSyncingState ? false : state.isSyncing,
        lastSyncTime: syncTimeUtc,
        error: null,
      );
      debugPrint('[FinFlow Sync] 🎉 Sync complete at ${DateTime.now()}');
    } on DioException catch (e, st) {
      debugPrint('[FinFlow Sync] ❌ Sync error: $e');
      if (kDebugMode) debugPrint(st.toString());
      _markFailure(pullOnly: isPullOnly);
      _updateMetrics(error: true, retry: true);

      final retryDelay = _retryDelay(
        pullOnly: isPullOnly,
        failures:
            isPullOnly ? _consecutivePullFailures : _consecutiveFullFailures,
      );
      if (!_isCircuitOpen(pullOnly: isPullOnly)) {
        if (isPullOnly) {
          schedulePull(reason: 'retry-pull', delay: retryDelay);
          retryScheduled = true;
        } else {
          scheduleSync(reason: 'retry-full', delay: retryDelay);
          retryScheduled = true;
        }
      }

      state = state.copyWith(
        isSyncing: showSyncingState ? false : state.isSyncing,
        error: formatDioError(e),
      );
    } catch (e, st) {
      debugPrint('[FinFlow Sync] ❌ Sync error: $e');
      if (kDebugMode) debugPrint(st.toString());
      _markFailure(pullOnly: isPullOnly);
      _updateMetrics(error: true, retry: true);

      final retryDelay = _retryDelay(
        pullOnly: isPullOnly,
        failures:
            isPullOnly ? _consecutivePullFailures : _consecutiveFullFailures,
      );
      if (!_isCircuitOpen(pullOnly: isPullOnly)) {
        if (isPullOnly) {
          schedulePull(reason: 'retry-pull', delay: retryDelay);
          retryScheduled = true;
        } else {
          scheduleSync(reason: 'retry-full', delay: retryDelay);
          retryScheduled = true;
        }
      }

      state = state.copyWith(
        isSyncing: showSyncingState ? false : state.isSyncing,
        error: e.toString(),
      );
    } finally {
      _pullOnlyInProgress = false;
      if (mounted && _isForeground) {
        _scheduleNextForegroundPull();
      }
      // If writes arrived while syncing, run one compact follow-up sync.
      if (showSyncingState &&
          _queuedWhileSyncing &&
          mounted &&
          !retryScheduled) {
        scheduleSync(
          reason: 'queued-follow-up',
          delay: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> fetchServerTelemetry() async {
    final token = await _storage.read(key: TokenKeys.accessToken);
    if (token == null) return null;
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.syncTelemetry);
      final payload = res.data;
      if (payload is Map<String, dynamic>) {
        return payload['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(ref),
);

final syncConflictSummaryProvider = Provider<SyncConflictSummary>((ref) {
  ref.watch(syncProvider);
  return ref.read(syncProvider.notifier).getLocalConflictSummary();
});

final syncConflictRecordsProvider =
    FutureProvider.autoDispose<List<SyncConflictRecord>>((ref) async {
  ref.watch(syncProvider.select((s) => s.metrics.queueDepth));
  return ref.read(syncProvider.notifier).buildConflictRecords();
});

final syncCircuitStatusProvider = Provider<SyncCircuitStatus>((ref) {
  return ref.watch(syncProvider.select((s) => s.circuitStatus));
});
