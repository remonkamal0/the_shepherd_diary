import 'priest_weekly_print.dart';
import 'package:flutter/material.dart';

import '../../../domain/appointments/appointment.dart';
import '../../../domain/appointments/appointment_workflow.dart';
import 'priest_appointment_editor.dart';
import 'priest_appointment_link.dart';
import 'priest_service_icons.dart';
import 'priest_theme.dart';

class ServiceWorkflowScreen extends StatefulWidget {
  const ServiceWorkflowScreen({
    super.key,
    required this.weekly,
    required this.items,
    required this.onEdit,
  });

  final bool weekly;
  final List<Appointment> Function() items;
  final Future<void> Function(Appointment) onEdit;

  @override
  State<ServiceWorkflowScreen> createState() => _ServiceWorkflowScreenState();
}

class _ServiceWorkflowScreenState extends State<ServiceWorkflowScreen> {
  Future<void> _edit(Appointment item) async {
    await widget.onEdit(item);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateUtils.dateOnly(DateTime.now());
    final start = widget.weekly
        ? DateTime(now.year, now.month, now.day - now.weekday % 7)
        : now;
    final all = widget.items();
    final items = AppointmentWorkflow.during(all, start, widget.weekly ? 7 : 1);
    final pending = items.where(
      (item) =>
          item.service == Service.sermon &&
          item.fields[Appointment.preparationKey] != 'جاهزة' &&
          !item.done,
    );
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.weekly && items.isNotEmpty)
            IconButton(
              tooltip: 'طباعة الملخص',
              icon: const Icon(Icons.print_outlined),
              onPressed: () async {
                try {
                  await printWeeklySummary(items);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تعذّر فتح الطباعة على الجهاز.'),
                      ),
                    );
                  }
                }
              },
            ),
        ],
        title: Text(widget.weekly ? 'مراجعة الأسبوع' : 'يوم الخدمة'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (items.isEmpty)
                const Center(child: Text('مفيش خدمات في الفترة دي.')),
              if (widget.weekly && items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'تمت ${items.where((item) => item.done).length}'
                    ' · تغيّر موعدها ${items.where((item) => item.fields[AppointmentWorkflow.historyKey]?.isNotEmpty == true).length}'
                    ' · عظات تحتاج تحضير ${pending.length}',
                  ),
                ),
              for (final item in items) _card(context, item, all),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Appointment item, List<Appointment> all) {
    final sermon = all
        .where(
          (candidate) =>
              candidate.service == Service.sermon &&
              candidate.liturgyId == item.id,
        )
        .firstOrNull;
    final status = [
      if (item.done) 'تمت الخدمة',
      if (item.fields[AppointmentWorkflow.historyKey]?.isNotEmpty == true)
        'تغيّر موعدها',
      if (item.service == Service.sermon)
        item.fields[Appointment.preparationKey] ??
            Appointment.preparationStates.first,
    ];
    return Card.outlined(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.service.icon, color: gold),
              title: Text(item.title),
              subtitle: Text(
                [
                  item.service.label,
                  item.fields['طول اليوم'] == 'true'
                      ? 'طول اليوم'
                      : appointmentDate(context, item.when),
                  ...status,
                ].join(' · '),
              ),
              onTap: () => _edit(item),
            ),
            if (!widget.weekly)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...appointmentLinks(item.fields),
                  if (sermon != null)
                    OutlinedButton(
                      onPressed: () => _edit(sermon),
                      child: const Text('فتح تحضير العظة'),
                    ),
                  TextButton(
                    onPressed: () => _edit(item),
                    child: const Text('التجهيز والإتمام وتغيير الموعد'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
