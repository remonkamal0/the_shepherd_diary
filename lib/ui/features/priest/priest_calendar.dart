import 'priest_service_icons.dart';
import 'package:flutter/material.dart';

import '../../../domain/appointments/appointment.dart';
import 'priest_theme.dart';

enum CalendarView { day, week, month, year }

class PriestCalendar extends StatefulWidget {
  const PriestCalendar({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onOpen,
  });

  final List<Appointment> items;
  final void Function(Service, DateTime) onAdd;
  final void Function(Appointment) onOpen;

  @override
  State<PriestCalendar> createState() => _PriestCalendarState();
}

class _PriestCalendarState extends State<PriestCalendar> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  Service? _filter;
  CalendarView _view = CalendarView.month;

  DateTime get _weekStart =>
      DateTime(_day.year, _day.month, _day.day - _day.weekday % 7);

  bool _includes(DateTime date) => switch (_view) {
    CalendarView.day || CalendarView.month => DateUtils.isSameDay(date, _day),
    CalendarView.week =>
      !date.isBefore(_weekStart) &&
          date.isBefore(
            DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7),
          ),
    CalendarView.year => date.year == _day.year,
  };

  static const _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  void _move(int offset) {
    setState(
      () => _day = switch (_view) {
        CalendarView.day => DateTime(_day.year, _day.month, _day.day + offset),
        CalendarView.week => DateTime(
          _day.year,
          _day.month,
          _day.day + offset * 7,
        ),
        CalendarView.month => DateTime(_day.year, _day.month + offset),
        CalendarView.year => DateTime(_day.year + offset),
      },
    );
  }

  Future<void> _add() async {
    final service = await showModalBottomSheet<Service>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('اختار نوع الخدمة')),
            for (final service in Service.values)
              ListTile(
                leading: Icon(service.icon, color: gold),
                title: Text(service.label),
                onTap: () => Navigator.pop(sheetContext, service),
              ),
          ],
        ),
      ),
    );
    if (service != null && mounted) widget.onAdd(service, _day);
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_day.year, _day.month);
    final offset = first.weekday % 7;
    final length = DateUtils.getDaysInMonth(_day.year, _day.month);
    final byDay = <int, List<Appointment>>{};
    for (final item in widget.items) {
      final date = item.when;
      if (date.year == _day.year &&
          date.month == _day.month &&
          (_filter == null || item.service == _filter)) {
        (byDay[date.day] ??= []).add(item);
      }
    }
    final selected = widget.items
        .where(
          (item) =>
              (_filter == null || item.service == _filter) &&
              _includes(item.when),
        )
        .toList();
    selected.sort((a, b) => a.when.compareTo(b.when));
    return Card.outlined(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'الفترة السابقة',
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _view == CalendarView.year
                        ? '${_day.year}'
                        : '${_months[_day.month - 1]} ${_day.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'الفترة التالية',
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final (view, label) in [
                  (CalendarView.day, 'يومي'),
                  (CalendarView.week, 'أسبوعي'),
                  (CalendarView.month, 'شهري'),
                  (CalendarView.year, 'سنوي'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _view == view,
                    onSelected: (_) => setState(() => _view = view),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Service>(
              initialValue: _filter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'عرض الخدمات'),
              items: [
                const DropdownMenuItem<Service>(child: Text('كل الخدمات')),
                for (final service in Service.values)
                  DropdownMenuItem(value: service, child: Text(service.label)),
              ],
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 12),
            if (_view == CalendarView.month) ...[
              Row(
                children: [
                  for (final label in [
                    'أحد',
                    'إثن',
                    'ثلا',
                    'أرب',
                    'خمي',
                    'جمع',
                    'سبت',
                  ])
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              for (var row = 0; row * 7 < offset + length; row++)
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: _cell(
                          row * 7 + column - offset + 1,
                          length,
                          byDay,
                        ),
                      ),
                  ],
                ),
            ],
            if (_view == CalendarView.year)
              Wrap(
                spacing: 8,
                children: [
                  for (final (index, month) in _months.indexed)
                    ActionChip(
                      label: Text(month),
                      onPressed: () => setState(() {
                        _day = DateTime(_day.year, index + 1);
                        _view = CalendarView.month;
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            const Divider(),
            Text(switch (_view) {
              CalendarView.week =>
                'مواعيد الأسبوع من ${_weekStart.day} ${_months[_weekStart.month - 1]}',
              CalendarView.year => 'مواعيد سنة ${_day.year}',
              _ => 'مواعيد ${_day.day} ${_months[_day.month - 1]}',
            }),
            if (selected.isEmpty) const Text('مفيش مواعيد في الفترة دي.'),
            for (final item in selected)
              Card.outlined(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _color(item.service).withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      item.service.icon,
                      color: _color(item.service),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    item.service == Service.confession
                        ? 'موعد اعتراف'
                        : item.title,
                  ),
                  subtitle: Text(
                    '${item.when.day} ${_months[item.when.month - 1]} · ${_timeLabel(context, item)}',
                    style: const TextStyle(
                      color: gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: item.service == Service.confession
                      ? null
                      : () => widget.onOpen(item),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('إضافة خدمة'),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(BuildContext context, Appointment item) {
    if (item.fields['طول اليوم'] == 'true') return 'طول اليوم';
    final formatter = MaterialLocalizations.of(context);
    final start = formatter.formatTimeOfDay(TimeOfDay.fromDateTime(item.when));
    final end = int.tryParse(item.fields['وقت النهاية'] ?? '');
    if (end == null || end < 0 || end >= 1440) return start;
    final finish = formatter.formatTimeOfDay(
      TimeOfDay(hour: end ~/ 60, minute: end % 60),
    );
    return '$start – $finish';
  }

  Color _color(Service service) =>
      Colors.primaries[(service.index * 3) % Colors.primaries.length].shade700;

  Widget _cell(int day, int length, Map<int, List<Appointment>> byDay) {
    if (day < 1 || day > length) return const SizedBox(height: 48);
    final active = _day.day == day;
    final services = byDay[day]?.map((item) => item.service).toSet() ?? {};
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            setState(() => _day = DateTime(_day.year, _day.month, day)),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF5ECDD) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Wrap(
                spacing: 2,
                children: [
                  for (final service in services.take(3))
                    CircleAvatar(radius: 2.5, backgroundColor: _color(service)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

