import 'appointment.dart';

class AppointmentOverview {
  AppointmentOverview(Iterable<Appointment> appointments, DateTime now) {
    for (final item in appointments) {
      if (item.isConfessionOverdue(now) ||
          (item.service == Service.visit &&
              item.followUp?.isAfter(now) == false)) {
        dueCount++;
      }
      if (item.service == Service.confession ||
          item.done ||
          item.when.isBefore(now)) {
        continue;
      }
      if (next == null || item.when.isBefore(next!.when)) next = item;
    }
    final upcoming = next;
    if (upcoming?.service == Service.liturgy) {
      sermon = appointments
          .where(
            (item) =>
                item.service == Service.sermon &&
                item.liturgyId == upcoming!.id,
          )
          .firstOrNull;
    }
  }

  Appointment? next;
  Appointment? sermon;
  int dueCount = 0;
}
