import 'package:equatable/equatable.dart';

class GroupSettlementDispute extends Equatable {
  final String status;
  final String reason;
  final String? note;
  final DateTime disputedAt;
  final String disputedByUserId;
  final DateTime? resolvedAt;
  final String? resolvedByUserId;
  final String? resolutionNote;

  const GroupSettlementDispute({
    required this.status,
    required this.reason,
    this.note,
    required this.disputedAt,
    required this.disputedByUserId,
    this.resolvedAt,
    this.resolvedByUserId,
    this.resolutionNote,
  });

  bool get isOpen => status == 'open';

  factory GroupSettlementDispute.fromJson(Map<String, dynamic> json) {
    return GroupSettlementDispute(
      status: (json['status'] as String?) ?? 'open',
      reason: (json['reason'] as String?) ?? '',
      note: json['note'] as String?,
      disputedAt: _parseDateTime(json['disputedAt']) ?? DateTime.now().toUtc(),
      disputedByUserId: (json['disputedByUserId'] as String?) ?? '',
      resolvedAt: _parseDateTime(json['resolvedAt']),
      resolvedByUserId: json['resolvedByUserId'] as String?,
      resolutionNote: json['resolutionNote'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        status,
        reason,
        note,
        disputedAt,
        disputedByUserId,
        resolvedAt,
        resolvedByUserId,
        resolutionNote,
      ];
}

class GroupSettlementAudit extends Equatable {
  final String id;
  final String groupId;
  final String settlementExpenseId;
  final String fromMemberId;
  final String toMemberId;
  final double amount;
  final DateTime settledAt;
  final String recordedByUserId;
  final String status;
  final GroupSettlementDispute? dispute;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GroupSettlementAudit({
    required this.id,
    required this.groupId,
    required this.settlementExpenseId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.settledAt,
    required this.recordedByUserId,
    required this.status,
    required this.dispute,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDisputed => status == 'disputed' && dispute?.isOpen == true;
  bool get isResolved => status == 'resolved';

  factory GroupSettlementAudit.fromServerJson(Map<String, dynamic> json) {
    return GroupSettlementAudit(
      id: (json['id'] ?? json['_id']) as String,
      groupId: (json['groupId'] as String?) ?? '',
      settlementExpenseId: (json['settlementExpenseId'] as String?) ?? '',
      fromMemberId: (json['fromMemberId'] as String?) ?? '',
      toMemberId: (json['toMemberId'] as String?) ?? '',
      amount: ((json['amount'] as num?) ?? 0).toDouble(),
      settledAt: _parseDateTime(json['settledAt']) ?? DateTime.now().toUtc(),
      recordedByUserId: (json['recordedByUserId'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'recorded',
      dispute: json['dispute'] is Map<String, dynamic>
          ? GroupSettlementDispute.fromJson(
              json['dispute'] as Map<String, dynamic>,
            )
          : null,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        settlementExpenseId,
        status,
        dispute,
        updatedAt,
      ];
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  if (raw is String) return DateTime.tryParse(raw)?.toUtc();
  return null;
}
