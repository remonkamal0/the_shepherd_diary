import 'package:the_shepherd_diary/data/appointments/local_appointment_repository.dart';
import 'package:flutter/widgets.dart';

import 'ui/features/priest/priest_app.dart';

void main() => runApp(
  PriestApp(
    repository: LocalAppointmentRepository(),
    forPriest: (id) => LocalAppointmentRepository(priestId: id),
  ),
);
