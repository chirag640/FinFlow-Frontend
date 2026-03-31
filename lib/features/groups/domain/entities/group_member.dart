import 'package:equatable/equatable.dart';

class GroupMember extends Equatable {
  final String id;
  final String name;
  final String? username;
  final String? userId;
  final String? phone;

  const GroupMember({
    required this.id,
    required this.name,
    this.username,
    this.userId,
    this.phone,
  });

  String get handle {
    final raw = username?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw.startsWith('@') ? raw : '@$raw';
    }

    final trimmed = name.trim();
    if (trimmed.startsWith('@')) return trimmed;

    if (userId != null && userId!.isNotEmpty) {
      final slug = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      return slug.isEmpty ? trimmed : '@$slug';
    }

    return trimmed;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'userId': userId,
        'phone': phone,
      };

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        id: (j['id'] ?? j['_id']) as String,
        name: j['name'] as String,
        username: j['username'] as String?,
        userId: j['userId'] as String?,
        phone: j['phone'] as String?,
      );

  /// Parses a raw GroupMemberDoc returned directly by the NestJS API (uses _id).
  factory GroupMember.fromServerJson(Map<String, dynamic> j) => GroupMember(
        id: (j['_id'] ?? j['id']) as String,
        name: j['name'] as String,
        username: j['username'] as String?,
        userId: j['userId'] as String?,
      );

  @override
  List<Object?> get props => [id, name, username, userId];
}
