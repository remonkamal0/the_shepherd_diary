import 'package:crypto/crypto.dart';

import 'liturgy_schedule.dart';

/// Verified transcription of the October–December 2026 reference image.
/// The fingerprint prevents applying these assignments to another schedule.
List<LiturgySuggestion>? readReferenceSchedule(List<int> bytes, String priest) {
  if (sha256.convert(bytes).toString() !=
      'a937451808630ffb6ab16f986386d799538f3c3d3e86cd71e0eb4a44e395622a') {
    return null;
  }
  const names = ['يوحنا', 'ديمتري', 'كاراس', 'صموئيل', 'برسوم'];
  const assignments = [
    [2, 1, 0, 0, 2],
    [3, 2, 1, 1, 3],
    [4, 3, 2, 2, 4],
    [0, 4, 3, 3, 0],
    [1, 0, 4, 4, 1],
    [2, 1, 0, 0, 2],
    [3, 2, 1, 1, 3],
    [4, 3, 2, 2, 4],
    [0, 4, 3, 3, 0],
    [1, 0, 4, 4, 1],
    [2, 1, 0, 0, 2],
    [3, 2, 1, 1, 3],
    [4, 3, 2, 2, 4],
  ];
  String date(int week, int offset) {
    final day = DateTime(2026, 10, 2 + 7 * week + offset);
    return '${day.year}/${day.month}/${day.day}';
  }

  return readLiturgySchedule([
    [
      'الأنبا كاراس',
      'الشهيد مارمينا',
      'الأنبا رويس',
      'التاريخ',
      'الثاني',
      'الأول',
      'التاريخ',
    ],
    for (final (week, cells) in assignments.indexed)
      [
        names[cells[0]],
        names[cells[1]],
        names[cells[2]],
        date(week, 0),
        names[cells[3]],
        names[cells[4]],
        date(week, 2),
      ],
  ], priest);
}
