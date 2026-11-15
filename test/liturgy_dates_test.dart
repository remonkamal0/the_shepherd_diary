import 'package:flutter_test/flutter_test.dart';
import 'package:the_shepherd_diary/domain/appointments/liturgy_dates.dart';

void main() {
  test('Extracts valid unique dates from Arabic and mixed OCR text', () {
    expect(
      readLiturgyDates('٢٠٢٦/١١/١٥ | 13/11/2026\n۳۱/۱۱/۲۰۲۶\n15/11/2026'),
      [DateTime(2026, 11, 13), DateTime(2026, 11, 15)],
    );
  });
}
