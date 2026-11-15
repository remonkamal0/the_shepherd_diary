import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/appointments/appointment.dart';
import 'priest_appointment_editor.dart';

class ServiceInbox extends StatefulWidget {
  const ServiceInbox({super.key, required this.schedule});
  final Future<bool> Function(Service, String) schedule;

  @override
  State<ServiceInbox> createState() => _ServiceInboxState();
}

class _ServiceInboxState extends State<ServiceInbox> {
  static const _key = 'shepherd.serviceRequests';
  final _title = TextEditingController();
  Service _service = Service.visit;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _change(Future<bool> Function(List<String>) change) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = prefs.getStringList(_key) ?? [];
      if (await change(items) && !await prefs.setStringList(_key, items)) {
        throw StateError('Request persistence failed');
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذّر تحديث الطلبات.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('طلبات الخدمة')),
    body: FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('تعذّر تحميل الطلبات.'));
        final prefs = snapshot.data;
        if (prefs == null)
          return const Center(child: CircularProgressIndicator());
        final items = prefs.getStringList(_key) ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<Service>(
              initialValue: _service,
              decoration: const InputDecoration(labelText: 'نوع الخدمة'),
              items: [
                for (final service in Service.values)
                  if (service != Service.confession)
                    DropdownMenuItem(
                      value: service,
                      child: Text(service.label),
                    ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => _service = value);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'اسم أو عنوان الطلب',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      final title = _title.text.trim();
                      if (title.isEmpty) return;
                      _change((items) async {
                        items.add(jsonEncode([_service.name, title]));
                        _title.clear();
                        return true;
                      });
                    },
              child: const Text('حفظ طلب بدون موعد'),
            ),
            const SizedBox(height: 16),
            for (final (index, encoded) in items.indexed)
              _request(index, jsonDecode(encoded) as List),
          ],
        );
      },
    ),
  );

  Widget _request(int index, List data) {
    final service = Service.values.byName(data[0] as String);
    final title = data[1] as String;
    return Card.outlined(
      child: ListTile(
        title: Text(title),
        subtitle: Text(service.label),
        trailing: TextButton(
          onPressed: _busy
              ? null
              : () => _change((items) async {
                  if (!await widget.schedule(service, title)) return false;
                  items.removeAt(index);
                  return true;
                }),
          child: const Text('حدد موعد'),
        ),
      ),
    );
  }
}

class ServiceArchive extends StatefulWidget {
  const ServiceArchive({
    super.key,
    required this.items,
    required this.open,
    required this.copy,
  });
  final List<Appointment> Function() items;
  final Future<void> Function(Appointment) open;
  final Future<void> Function(Appointment) copy;

  @override
  State<ServiceArchive> createState() => _ServiceArchiveState();
}

class _ServiceArchiveState extends State<ServiceArchive> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final items =
        widget
            .items()
            .where(
              (item) =>
                  item.service != Service.confession &&
                  item.when.isBefore(today) &&
                  [
                    item.service.label,
                    ...item.fields.values,
                  ].any((value) => value.toLowerCase().contains(_query)),
            )
            .toList()
          ..sort((first, second) => second.when.compareTo(first.when));
    return Scaffold(
      appBar: AppBar(title: const Text('أرشيف الخدمات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'ابحث بالاسم أو المكان أو الخدمة',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('مفيش خدمات قديمة مطابقة.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.service.label} · ${appointmentDate(context, item.when)}',
                        ),
                        onTap: () async {
                          await widget.open(item);
                          if (mounted) setState(() {});
                        },
                        trailing: IconButton(
                          tooltip: 'نسخ كموعد جديد',
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () => widget.copy(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
