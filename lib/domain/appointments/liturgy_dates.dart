List<DateTime> readLiturgyDates(String text) {
  const digits = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
  final normalized = text
      .replaceAllMapped(
        RegExp('[٠-٩۰-۹]'),
        (match) => (digits.indexOf(match[0]!) % 10).toString(),
      )
      .replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e]'), '');
  final dates = <DateTime>{};
  final pattern = RegExp(
    r'(?<!\d)(\d{1,4})[ \t]*[/.-][ \t]*(\d{1,2})[ \t]*[/.-][ \t]*(\d{1,4})(?!\d)',
  );
  for (final match in pattern.allMatches(normalized)) {
    final yearFirst = match[1]!.length == 4;
    final yearText = match[yearFirst ? 1 : 3]!;
    if (yearText.length != 4) continue;
    final year = int.parse(yearText);
    final month = int.parse(match[2]!);
    final day = int.parse(match[yearFirst ? 3 : 1]!);
    if (year < 2000 || year > 2100) continue;
    final date = DateTime(year, month, day);
    if (date.year == year && date.month == month && date.day == day) {
      dates.add(date);
    }
  }
  return dates.toList()..sort();
}
