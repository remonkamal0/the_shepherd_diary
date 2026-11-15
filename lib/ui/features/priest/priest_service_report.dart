import 'package:flutter/material.dart';

import '../../../domain/appointments/appointment.dart';
import 'priest_theme.dart';

class ServiceReport extends StatefulWidget {
  const ServiceReport({
    super.key,
    required this.items,
    required this.service,
    required this.onEdit,
  });

  final List<Appointment> items;
  final Service service;
  final Future<void> Function(Appointment) onEdit;

  @override
  State<ServiceReport> createState() => _ServiceReportState();
}

class _ServiceReportState extends State<ServiceReport> {
  DateTimeRange? _period;
  String _query = '';
  bool _overdueOnly = false;

  Future<void> _pickPeriod() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _period,
    );
    if (selected != null && mounted) setState(() => _period = selected);
  }

  void _setLiturgyPeriod({required bool month}) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = month
        ? DateTime(today.year, today.month)
        : DateTime(today.year, today.month, today.day - today.weekday % 7);
    final end = month
        ? DateTime(today.year, today.month + 1, 0)
        : DateTime(start.year, start.month, start.day + 6);
    setState(() => _period = DateTimeRange(start: start, end: end));
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final now = DateTime.now();
    final items = widget.items.where((item) {
      final day = DateUtils.dateOnly(item.when);
      final period = _period;
      return (period == null ||
              (!day.isBefore(period.start) && !day.isAfter(period.end))) &&
          (item.title.toLowerCase().contains(_query) ||
              (item.kind ?? '').contains(_query)) &&
          (!_overdueOnly || item.isConfessionOverdue(now));
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text('تقرير ${service.label}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث في التقرير',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              if (service == Service.liturgy) ...[
                TextButton(
                  onPressed: () => _setLiturgyPeriod(month: false),
                  child: const Text('الأسبوع الحالي'),
                ),
                TextButton(
                  onPressed: () => _setLiturgyPeriod(month: true),
                  child: const Text('الشهر الحالي'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: _pickPeriod,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _period == null
                      ? 'اختيار الفترة'
                      : '${_date(_period!.start)} – ${_date(_period!.end)}',
                ),
              ),
              if (_period != null)
                IconButton(
                  tooltip: 'مسح الفترة',
                  onPressed: () => setState(() => _period = null),
                  icon: const Icon(Icons.close),
                ),
              if (service == Service.confession)
                FilterChip(
                  label: const Text('المتأخر فقط'),
                  selected: _overdueOnly,
                  onSelected: (value) => setState(() => _overdueOnly = value),
                ),
              Text('عدد السجلات ${items.length}'),
            ],
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('مفيش سجلات لعرضها في التقرير.'))
                : LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: (constraints.maxWidth - 32).clamp(
                              0.0,
                              760.0,
                            ),
                          ),
                          child: DataTable(
                            headingRowColor: const WidgetStatePropertyAll(
                              charcoal,
                            ),
                            headingTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            columnSpacing: 24,
                            border: TableBorder.all(
                              color: const Color(0xFFE8E1D8),
                            ),
                            columns: [
                              DataColumn(label: Text('التاريخ')),
                              if (service == Service.liturgy)
                                const DataColumn(label: Text('القداس')),
                              DataColumn(label: Text('الوقت')),
                              DataColumn(label: Text(service.fields.first)),
                              DataColumn(
                                label: Text(
                                  service == Service.liturgy
                                      ? 'الدور'
                                      : 'الحالة أو النوع',
                                ),
                              ),
                              const DataColumn(label: Text('المتابعة')),
                            ],
                            rows: [
                              for (final (index, item) in items.indexed)
                                DataRow(
                                  color: WidgetStatePropertyAll(
                                    index.isEven
                                        ? Colors.white
                                        : const Color(0xFFF5ECDD),
                                  ),
                                  cells: [
                                    DataCell(
                                      Text(
                                        _date(item.when),
                                        textDirection: TextDirection.ltr,
                                      ),
                                    ),
                                    if (service == Service.liturgy)
                                      DataCell(
                                        Text(item.sundaySlot?.label ?? '—'),
                                      ),
                                    DataCell(
                                      Text(
                                        '${(item.when.hour + 11) % 12 + 1}:'
                                        '${item.when.minute.toString().padLeft(2, '0')} '
                                        '${item.when.hour < 12 ? 'ص' : 'م'}',
                                      ),
                                    ),
                                    DataCell(
                                      Text(item.title),
                                      onTap: () async {
                                        await widget.onEdit(item);
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      },
                                    ),
                                    DataCell(
                                      Text(
                                        item.isConfessionOverdue(DateTime.now())
                                            ? 'متأخر'
                                            : item.done
                                            ? 'تم'
                                            : item.kind ?? '—',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item.followUp == null
                                            ? '—'
                                            : _date(item.followUp!),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
