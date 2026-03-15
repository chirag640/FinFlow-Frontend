import 'package:equatable/equatable.dart';

class GroupMember extends Equatable {
  final String id;
  final String name;
  final String? phone;

  const GroupMember({required this.id, required this.name, this.phone});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone};

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        id: (j['id'] ?? j['_id']) as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
      );

  /// Parses a raw GroupMemberDoc returned directly by the NestJS API (uses _id).
  factory GroupMember.fromServerJson(Map<String, dynamic> j) => GroupMember(
        id: (j['_id'] ?? j['id']) as String,
        name: j['name'] as String,
      );

  @override
  List<Object?> get props => [id, name];
}
