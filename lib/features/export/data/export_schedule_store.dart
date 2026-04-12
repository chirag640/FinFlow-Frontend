import '../../../core/storage/hive_service.dart';
import '../domain/export_schedule.dart';

class ExportScheduleStore {
  static const _key = 'export_schedules';

  static List<ExportSchedule> load() {
    final raw = HiveService.settings.get(_key, defaultValue: const <dynamic>[]);
    if (raw is! List) return const <ExportSchedule>[];

    return raw
        .whereType<Map>()
        .map((entry) =>
            ExportSchedule.fromJson(Map<String, dynamic>.from(entry)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static Future<void> saveAll(List<ExportSchedule> schedules) {
    final encoded = schedules.map((schedule) => schedule.toJson()).toList();
    return HiveService.settings.put(_key, encoded);
  }
}
