import 'package:flutter/material.dart';

import '../../../domain/appointments/appointment.dart';
import 'priest_appointment_link.dart';

class PreparationLibrary extends StatefulWidget {
  const PreparationLibrary({
    super.key,
    required this.sermons,
    required this.onEdit,
  });

  final List<Appointment> Function() sermons;
  final Future<void> Function(Appointment) onEdit;

  @override
  State<PreparationLibrary> createState() => _PreparationLibraryState();
}

class _PreparationLibraryState extends State<PreparationLibrary> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items =
        widget
            .sermons()
            .where(
              (item) =>
                  item.fields.values.any(
                    (value) => value.toLowerCase().contains(_query),
                  ) ||
                  (item.kind ?? '').contains(_query),
            )
            .toList()
          ..sort((a, b) => b.when.compareTo(a.when));
    return Scaffold(
      appBar: AppBar(title: const Text('مكتبة التحضير')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    labelText: 'ابحث بالموضوع أو المرجع',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('مفيش عظات مطابقة.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final link = Uri.tryParse(
                            item.fields['رابط التحضير على Drive'] ?? '',
                          );
                          return Card.outlined(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.menu_book_outlined),
                                  title: Text(item.title),
                                  subtitle: Text(
                                    [
                                      if (item.kind != null) item.kind!,
                                      item.fields[Appointment.preparationKey] ??
                                          Appointment.preparationStates.first,
                                    ].join(' · '),
                                  ),
                                  onTap: () async {
                                    await widget.onEdit(item);
                                    if (mounted) setState(() {});
                                  },
                                ),
                                if (link != null &&
                                    link.scheme == 'https' &&
                                    link.host.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: AppointmentLink(
                                      label: 'فتح ملف التحضير',
                                      icon: Icons.description_outlined,
                                      destination: link,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
