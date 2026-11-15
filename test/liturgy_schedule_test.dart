import 'package:flutter_test/flutter_test.dart';
import 'package:the_shepherd_diary/domain/appointments/appointment.dart';
import 'package:the_shepherd_diary/domain/appointments/liturgy_schedule.dart';

void main() {
  test('Matches priests to Friday headers and Sunday slots', () {
    final grid = [
      [
        'الأنبا كاراس',
        'الشهيد مارمينا',
        'الأنبا رويس',
        'التاريخ',
        'الثاني',
        'الأول',
        'التاريخ',
      ],
      [
        'أ. كاراس',
        'أ. ديمتري',
        'أ. يوحنا',
        '٢٠٢٦/١٠/٠٢',
        'أ. يوحنا',
        'أ. كاراس',
        '٢٠٢٦/١٠/٠٤',
      ],
    ];
    expect(readLiturgySchedule(grid, 'القس يوحنا'), [
      (date: DateTime(2026, 10, 2), church: 'الأنبا رويس', slot: null),
      (
        date: DateTime(2026, 10, 4),
        church: 'مارمينا',
        slot: SundayLiturgy.second,
      ),
    ]);
    expect(readLiturgySchedule(grid, 'القس صموئيل'), isEmpty);
  });
}
