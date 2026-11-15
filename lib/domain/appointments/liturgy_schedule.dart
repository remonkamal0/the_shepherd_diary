import 'appointment.dart';
import 'liturgy_dates.dart';

typedef LiturgySuggestion = ({
  DateTime date,
  String church,
  SundayLiturgy? slot,
});

List<LiturgySuggestion> readLiturgySchedule(
  List<List<String>> grid,
  String priest,
) {
  if (grid.isEmpty || priest.isEmpty || grid.any((row) => row.length != 7))
    return [];
  String normalize(String value) => value
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      .replaceAll(RegExp(r'[ًٌٍَُِّْـ\s.]'), '')
      .replaceAll('ى', 'ي');
  final name = normalize(priest.replaceFirst('القس ', ''));
  bool matches(String cell) {
    final value = normalize(cell);
    return value == name || value == 'ا$name' || value == 'القس$name';
  }

  const churches = ['الأنبا كاراس', 'الشهيد مارمينا', 'الأنبا رويس'];
  final results = <LiturgySuggestion>{};
  for (final row in grid.skip(1)) {
    final friday = readLiturgyDates(row[3]).firstOrNull;
    if (friday != null && friday.weekday == DateTime.friday) {
      for (var col = 0; col < churches.length; col++) {
        if (matches(row[col]))
          results.add((
            date: friday,
            church: grid.first[col].trim().isEmpty
                ? churches[col]
                : grid.first[col].trim(),
            slot: null,
          ));
      }
    }
    final sunday = readLiturgyDates(row[6]).firstOrNull;
    if (sunday != null && sunday.weekday == DateTime.sunday) {
      for (final slot in SundayLiturgy.values) {
        if (matches(row[5 - slot.index]))
          results.add((date: sunday, church: slot.church, slot: slot));
      }
    }
  }
  return results.toList()..sort((a, b) => a.date.compareTo(b.date));
}
