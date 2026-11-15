import 'package:flutter/material.dart';
import '../../../domain/appointments/appointment.dart';

extension ServiceIcon on Service {
  IconData get icon => switch (this) {
    Service.liturgy => Icons.church_outlined,
    Service.sermon => Icons.menu_book_outlined,
    Service.communion => Icons.location_on_outlined,
    Service.baptism => Icons.water_drop_outlined,
    Service.wedding => Icons.favorite_border,
    Service.funeral => Icons.local_florist_outlined,
    Service.liturgical => Icons.water_outlined,
    Service.visit => Icons.home_outlined,
    Service.confession => Icons.event_available_outlined,
    Service.family => Icons.checklist_outlined,
  };
}
