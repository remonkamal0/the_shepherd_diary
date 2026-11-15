import 'appointment.dart';

abstract interface class AppointmentRepository {
  Future<List<Appointment>> load();
  Future<void> save(List<Appointment> items);
}
