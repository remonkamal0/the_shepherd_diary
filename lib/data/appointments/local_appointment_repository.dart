import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/appointments/appointment.dart';
import '../../domain/appointments/appointment_repository.dart';

class LocalAppointmentRepository implements AppointmentRepository {
  LocalAppointmentRepository({String? priestId})
    : key = priestId == null
          ? 'shepherd.appointments.v1'
          : 'shepherd.appointments.v1.$priestId';

  final String key;

  @override
  Future<List<Appointment>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final json = preferences.getString(key);
    if (json == null) return [];
    return (jsonDecode(json) as List<dynamic>).map((entry) {
      final record = entry as Map<String, dynamic>;
      final followUp = record['followUp'] as String?;
      return Appointment(
        id: record['id'] as String,
        service: Service.values.byName(record['service'] as String),
        when: DateTime.parse(record['when'] as String),
        fields: Map<String, String>.from(record['fields'] as Map),
        kind: record['kind'] as String?,
        sundayLiturgy: SundayLiturgy.values
            .where((slot) => slot.name == record['sundayLiturgy'])
            .firstOrNull,
        liturgyId: record['liturgyId'] as String?,
        followUp: followUp == null ? null : DateTime.parse(followUp),
        done: record['done'] as bool,
        confessionSessions: [
          for (final date in record['confessionSessions'] as List? ?? [])
            DateTime.parse(date as String),
        ],
      );
    }).toList();
  }

  @override
  Future<void> save(List<Appointment> items) async {
    final json = jsonEncode([
      for (final item in items)
        {
          'id': item.id,
          'service': item.service.name,
          'when': item.when.toIso8601String(),
          'fields': item.fields,
          'kind': item.kind,
          'sundayLiturgy': item.sundayLiturgy?.name,
          'liturgyId': item.liturgyId,
          'followUp': item.followUp?.toIso8601String(),
          'done': item.done,
          'confessionSessions': [
            for (final date in item.confessionSessions) date.toIso8601String(),
          ],
        },
    ]);
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, json)) {
      throw StateError('Could not save appointments');
    }
  }
}
