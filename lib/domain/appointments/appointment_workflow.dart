import 'appointment.dart';

class AppointmentWorkflow {
  static const checklistKey = 'serviceChecklist';
  static const historyKey = 'serviceReschedulingHistory';

  static bool overlaps(Appointment first, Appointment second) {
    if (first.id == second.id ||
        first.done ||
        second.done ||
        first.service == Service.confession ||
        second.service == Service.confession ||
        first.liturgyId == second.id ||
        second.liturgyId == first.id) {
      return false;
    }
    if (first.when.year != second.when.year ||
        first.when.month != second.when.month ||
        first.when.day != second.when.day)
      return false;
    if (first.fields['طول اليوم'] == 'true' ||
        second.fields['طول اليوم'] == 'true')
      return true;
    return _start(first) < _end(second) && _start(second) < _end(first);
  }

  static int _start(Appointment item) => item.when.hour * 60 + item.when.minute;

  static int _end(Appointment item) {
    final end = int.tryParse(item.fields['وقت النهاية'] ?? '');
    return end != null && end > _start(item) ? end : _start(item) + 1;
  }

  static List<Appointment> during(
    Iterable<Appointment> items,
    DateTime start,
    int days,
  ) {
    final end = DateTime(start.year, start.month, start.day + days);
    return items
        .where(
          (item) =>
              item.service != Service.confession &&
              !item.when.isBefore(start) &&
              item.when.isBefore(end),
        )
        .toList()
      ..sort((a, b) => a.when.compareTo(b.when));
  }
}
