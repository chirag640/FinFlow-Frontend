import 'package:equatable/equatable.dart';

import 'group_member.dart';

class Group extends Equatable {
  final String id;
  final String name;
  final String emoji;
  final String ownerId;
  final List<GroupMember> members;
  final String currentUserId;
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.emoji,
    required this.ownerId,
    required this.members,
    required this.currentUserId,
    required this.createdAt,
  });

  Group copyWith({String? name, String? emoji, List<GroupMember>? members}) =>
      Group(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        ownerId: ownerId,
        members: members ?? this.members,
        currentUserId: currentUserId,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'ownerId': ownerId,
        'members': members.map((m) => m.toJson()).toList(),
        'currentUserId': currentUserId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: (j['emoji'] as String?) ?? '👥',
        ownerId: (j['ownerId'] as String?) ?? '',
        members: (j['members'] as List)
            .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        currentUserId: j['currentUserId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  /// Parses a group response from the NestJS API.
  /// [cloudUserId] is the JWT sub — used to find which member record is "me".
  factory Group.fromServerJson(Map<String, dynamic> j, String cloudUserId) {
    final rawMembers =
        ((j['members'] as List?) ?? []).cast<Map<String, dynamic>>();
    final members =
        rawMembers.map((m) => GroupMember.fromServerJson(m)).toList();

    // The owner member doc has userId == cloudUserId
    final ownerRaw = rawMembers.firstWhere(
      (m) => m['userId'] == cloudUserId,
      orElse: () => rawMembers.isEmpty ? <String, dynamic>{} : rawMembers.first,
    );
    final currentMemberId = ownerRaw.isNotEmpty
        ? ((ownerRaw['_id'] ?? ownerRaw['id']) as String)
        : (members.isNotEmpty ? members.first.id : cloudUserId);

    return Group(
      id: (j['id'] ?? j['_id']) as String,
      name: j['name'] as String,
      emoji: (j['emoji'] as String?) ?? '👥',
      ownerId: (j['ownerId'] as String?) ?? cloudUserId,
      members: members,
      currentUserId: currentMemberId,
      createdAt: j['createdAt'] != null
          ? DateTime.parse(j['createdAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, name, ownerId, members];
}
