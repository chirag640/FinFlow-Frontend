import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/sync_provider.dart';

class SyncConflictResolutionPage extends ConsumerStatefulWidget {
  const SyncConflictResolutionPage({super.key});

  @override
  ConsumerState<SyncConflictResolutionPage> createState() =>
      _SyncConflictResolutionPageState();
}

class _SyncConflictResolutionPageState
    extends ConsumerState<SyncConflictResolutionPage> {
  final Set<String> _resolvingRecordIds = <String>{};

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final syncState = ref.watch(syncProvider);
    final summary = ref.watch(syncConflictSummaryProvider);
    final recordsAsync = ref.watch(syncConflictRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Conflict Resolution'),
      ),
      body: ListView(
        padding: EdgeInsets.all(R.md),
        children: [
          _StatusCard(syncState: syncState, summary: summary),
          const Gap(12),
          recordsAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return _InfoCard(
                  icon: Icons.fact_check_outlined,
                  color: AppColors.success,
                  backgroundColor: AppColors.successLight,
                  title: 'No per-record conflicts in queue',
                  message:
                      'Local queue is clear. If sync still fails, retry sync and re-open this screen.',
                );
              }

              final expenseRecords = records
                  .where((r) => r.entityType == SyncConflictEntityType.expense)
                  .toList();
              final budgetRecords = records
                  .where((r) => r.entityType == SyncConflictEntityType.budget)
                  .toList();
              final goalRecords = records
                  .where((r) => r.entityType == SyncConflictEntityType.goal)
                  .toList();

              return Column(
                children: [
                  _ConflictRecordSection(
                    title: 'Expenses',
                    records: expenseRecords,
                    isSyncing: syncState.isSyncing,
                    resolvingRecordIds: _resolvingRecordIds,
                    onPreferCloud: _resolvePreferCloud,
                    onKeepLocal: _keepLocalAndSync,
                  ),
                  const Gap(10),
                  _ConflictRecordSection(
                    title: 'Budgets',
                    records: budgetRecords,
                    isSyncing: syncState.isSyncing,
                    resolvingRecordIds: _resolvingRecordIds,
                    onPreferCloud: _resolvePreferCloud,
                    onKeepLocal: _keepLocalAndSync,
                  ),
                  const Gap(10),
                  _ConflictRecordSection(
                    title: 'Goals',
                    records: goalRecords,
                    isSyncing: syncState.isSyncing,
                    resolvingRecordIds: _resolvingRecordIds,
                    onPreferCloud: _resolvePreferCloud,
                    onKeepLocal: _keepLocalAndSync,
                  ),
                ],
              );
            },
            loading: () => const _LoadingCard(),
            error: (error, _) => _InfoCard(
              icon: Icons.cloud_off,
              color: AppColors.warningDark,
              backgroundColor: AppColors.warningLight,
              title: 'Unable to load cloud diff',
              message: error.toString(),
            ),
          ),
          const Gap(12),
          FilledButton.icon(
            onPressed: syncState.isSyncing
                ? null
                : () => ref.read(syncProvider.notifier).sync(),
            icon: syncState.isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_rounded),
            label: Text(
              syncState.isSyncing
                  ? 'Syncing changes...'
                  : 'Keep local version and sync now',
            ),
          ),
          const Gap(8),
          OutlinedButton.icon(
            onPressed: (syncState.isSyncing || !summary.hasConflicts)
                ? null
                : () => _confirmDiscardLocal(context, ref),
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Prefer cloud version (discard local pending)'),
          ),
        ],
      ),
    );
  }

  Future<void> _keepLocalAndSync(SyncConflictRecord record) async {
    if (_resolvingRecordIds.contains(record.id)) return;
    await ref.read(syncProvider.notifier).sync();
    if (!mounted) return;
    ref.invalidate(syncConflictRecordsProvider);
  }

  Future<void> _resolvePreferCloud(SyncConflictRecord record) async {
    if (_resolvingRecordIds.contains(record.id)) return;

    final shouldResolve = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Prefer cloud for this record?'),
        content: Text(
          'Pending local change for ${record.id} will be cleared and replaced '
          'with cloud state (if available).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Prefer cloud'),
          ),
        ],
      ),
    );
    if (shouldResolve != true) return;

    setState(() => _resolvingRecordIds.add(record.id));
    await ref.read(syncProvider.notifier).preferCloudForConflict(record);
    if (!mounted) return;

    setState(() => _resolvingRecordIds.remove(record.id));
    ref.invalidate(syncConflictRecordsProvider);
  }

  Future<void> _confirmDiscardLocal(BuildContext context, WidgetRef ref) async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard local pending changes?'),
        content: const Text(
          'This clears unsynced local queue entries and pulls fresh cloud data. '
          'Local items already pushed to cloud are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard pending'),
          ),
        ],
      ),
    );

    if (shouldDiscard != true) return;

    await ref.read(syncProvider.notifier).discardPendingLocalChanges();
    ref.invalidate(syncConflictRecordsProvider);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Local pending queue cleared. Pulling latest cloud state.'),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.syncState, required this.summary});

  final SyncState syncState;
  final SyncConflictSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasConflicts = summary.hasConflicts;
    final toneColor = hasConflicts ? AppColors.warning : AppColors.success;
    final bgColor =
        hasConflicts ? AppColors.warningLight : AppColors.successLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasConflicts
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: toneColor,
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasConflicts
                      ? '${summary.total} local changes need resolution'
                      : 'No local sync conflicts',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: toneColor,
                  ),
                ),
                const Gap(4),
                Text(
                  syncState.error != null
                      ? 'Last sync error: ${syncState.error}'
                      : 'Choose how to resolve pending local writes before your next sync.',
                  style: TextStyle(
                    fontSize: 12,
                    color: toneColor.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictRecordSection extends StatelessWidget {
  const _ConflictRecordSection({
    required this.title,
    required this.records,
    required this.isSyncing,
    required this.resolvingRecordIds,
    required this.onPreferCloud,
    required this.onKeepLocal,
  });

  final String title;
  final List<SyncConflictRecord> records;
  final bool isSyncing;
  final Set<String> resolvingRecordIds;
  final Future<void> Function(SyncConflictRecord record) onPreferCloud;
  final Future<void> Function(SyncConflictRecord record) onKeepLocal;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${records.length} pending',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Gap(8),
          ...records.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ConflictRecordTile(
                record: record,
                disabled: isSyncing || resolvingRecordIds.contains(record.id),
                onPreferCloud: () => onPreferCloud(record),
                onKeepLocal: () => onKeepLocal(record),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictRecordTile extends StatelessWidget {
  const _ConflictRecordTile({
    required this.record,
    required this.disabled,
    required this.onPreferCloud,
    required this.onKeepLocal,
  });

  final SyncConflictRecord record;
  final bool disabled;
  final VoidCallback onPreferCloud;
  final VoidCallback onKeepLocal;

  @override
  Widget build(BuildContext context) {
    final localPreview = _previewMap(record.localData, record.entityType);
    final cloudPreview = _previewMap(record.cloudData, record.entityType);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        border: Border.all(color: Colors.black12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Text(
          record.id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Text(
          '${record.actionType == SyncConflictActionType.upsert ? 'Queued update' : 'Queued delete'} · '
          '${record.changedFields.isEmpty ? 'No field diff' : '${record.changedFields.length} field differences'}',
          style: const TextStyle(fontSize: 11),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (!record.cloudSnapshotAvailable)
            const _InlineWarning(
              message:
                  'Cloud snapshot unavailable. Connect to internet for detailed diff.',
            ),
          if (record.cloudSnapshotAvailable && record.changedFields.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Changed: ${record.changedFields.join(', ')}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const Gap(8),
          _SnapshotBlock(
            title: 'Local Pending',
            values: localPreview,
          ),
          const Gap(8),
          _SnapshotBlock(
            title: 'Cloud Snapshot',
            values: cloudPreview,
          ),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: disabled ? null : onKeepLocal,
                icon: const Icon(Icons.publish_rounded),
                label: const Text('Keep local and sync'),
              ),
              FilledButton.icon(
                onPressed: disabled ? null : onPreferCloud,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Prefer cloud'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, String> _previewMap(
    Map<String, dynamic>? source,
    SyncConflictEntityType entityType,
  ) {
    if (source == null) {
      return const {'state': 'Not available'};
    }
    if (source['deleted'] == true) {
      return const {'state': 'Deleted in cloud'};
    }

    final keys = switch (entityType) {
      SyncConflictEntityType.expense => [
          'amount',
          'description',
          'category',
          'date',
          'note',
          'isIncome',
          'isRecurring',
          'recurringFrequency',
          'recurringDueDay',
          'updatedAt',
        ],
      SyncConflictEntityType.budget => [
          'allocatedAmount',
          'categoryKey',
          'month',
          'year',
          'carryForward',
          'updatedAt',
        ],
      SyncConflictEntityType.goal => [
          'title',
          'targetAmount',
          'currentAmount',
          'deadline',
          'updatedAt',
        ],
    };

    final preview = <String, String>{};
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      preview[key] = _formatValue(source[key]);
    }
    return preview.isEmpty ? const {'state': 'No comparable fields'} : preview;
  }

  String _formatValue(dynamic raw) {
    if (raw == null) return '-';
    if (raw is bool) return raw ? 'Yes' : 'No';
    if (raw is num) return raw.toString();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed.toLocal().toString();
      }
      return raw;
    }
    return raw.toString();
  }
}

class _SnapshotBlock extends StatelessWidget {
  const _SnapshotBlock({required this.title, required this.values});

  final String title;
  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const Gap(6),
          ...values.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 108,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.warningDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Gap(10),
          Expanded(
            child: Text(
              'Loading record-level cloud diffs...',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
