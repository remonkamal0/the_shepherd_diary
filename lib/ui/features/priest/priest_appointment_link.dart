import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppointmentLink extends StatelessWidget {
  const AppointmentLink({
    super.key,
    required this.label,
    required this.icon,
    required this.destination,
  });

  final String label;
  final IconData icon;
  final Uri destination;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: Icon(icon),
    label: Text(label),
    onPressed: () async {
      try {
        if (await launchUrl(destination, mode: LaunchMode.externalApplication))
          return;
      } catch (_) {
        // Platform handlers are optional.
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح الرابط على الجهاز.')),
        );
      }
    },
  );
}

List<Widget> appointmentLinks(Map<String, String>? fields) {
  if (fields == null) return [];
  final address = fields['العنوان']?.trim() ?? '';
  final phone = (fields['هاتف المبلّغ'] ?? fields['الهاتف'] ?? '').trim();
  final drive = Uri.tryParse(fields['رابط التحضير على Drive']?.trim() ?? '');
  return [
    if (address.isNotEmpty)
      AppointmentLink(
        label: 'افتح الخريطة',
        icon: Icons.location_on_outlined,
        destination: Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': address,
        }),
      ),
    if (RegExp(r'^\+?[0-9٠-٩][0-9٠-٩ ()-]+$').hasMatch(phone))
      AppointmentLink(
        label: 'اتصال',
        icon: Icons.call_outlined,
        destination: Uri(
          scheme: 'tel',
          path: phone.replaceAll(RegExp(r'[ ()-]'), ''),
        ),
      ),
    if (drive != null && drive.scheme == 'https' && drive.host.isNotEmpty)
      AppointmentLink(
        label: 'فتح ملف التحضير',
        icon: Icons.description_outlined,
        destination: drive,
      ),
  ];
}
