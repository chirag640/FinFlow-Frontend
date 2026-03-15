import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/hive_service.dart';

/// Maps memberId → UPI VPA string, persisted locally in Hive.
/// UPI IDs are device-local by design — not sent to the server.
class UpiIdNotifier extends StateNotifier<Map<String, String>> {
  UpiIdNotifier() : super(_load());

  static Map<String, String> _load() {
    final box = HiveService.upiIds;
    return Map<String, String>.fromEntries(
      box
          .toMap()
          .entries
          .map((e) => MapEntry(e.key.toString(), e.value.toString())),
    );
  }

  void set(String memberId, String upiId) {
    HiveService.upiIds.put(memberId, upiId);
    state = {...state, memberId: upiId};
  }

  void remove(String memberId) {
    HiveService.upiIds.delete(memberId);
    state = Map<String, String>.from(state)..remove(memberId);
  }
}

final upiIdProvider = StateNotifierProvider<UpiIdNotifier, Map<String, String>>(
  (ref) => UpiIdNotifier(),
);
