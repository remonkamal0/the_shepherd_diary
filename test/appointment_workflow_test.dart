import 'package:flutter_test/flutter_test.dart';
import 'package:the_shepherd_diary/domain/appointments/appointment.dart';
import 'package:the_shepherd_diary/domain/appointments/appointment_workflow.dart';

Appointment meeting(
  String id,
  int hour,
  int minute, {
  int? end,
  int day = 14,
}) => Appointment(
  id: id,
  service: Service.visit,
  when: DateTime(2026, 11, day, hour, minute),
  fields: {if (end != null) 'وقت النهاية': '$end'},
);

void main() {
  test('warns for overlapping appointments without blocking adjacent ones', () {
    final first = meeting('first', 18, 0, end: 19 * 60);
    expect(
      AppointmentWorkflow.overlaps(first, meeting('inside', 18, 30)),
      isTrue,
    );
    expect(
      AppointmentWorkflow.overlaps(first, meeting('adjacent', 19, 0)),
      isFalse,
    );
    expect(
      AppointmentWorkflow.overlaps(first, meeting('tomorrow', 18, 30, day: 15)),
      isFalse,
    );
    expect(AppointmentWorkflow.overlaps(first, first), isFalse);
  });

  test('uses a half-open date range and returns appointments in order', () {
    final first = meeting('first', 8, 0);
    final second = meeting('second', 10, 0);
    expect(
      AppointmentWorkflow.during(
        [second, meeting('tomorrow', 0, 0, day: 15), first],
        DateTime(2026, 11, 14),
        1,
      ),
      [first, second],
    );
  });
}
