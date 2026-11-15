import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';

import '../../../domain/appointments/appointment.dart';

Future<void> printWeeklySummary(List<Appointment> items) async {
  final font = pdf.Font.ttf(
    await rootBundle.load('assets/fonts/Cairo-Variable.ttf'),
  );
  final document = pdf.Document(theme: pdf.ThemeData.withFont(base: font));
  document.addPage(
    pdf.MultiPage(
      textDirection: pdf.TextDirection.rtl,
      header: (_) => pdf.Padding(
        padding: const pdf.EdgeInsets.only(bottom: 16),
        child: pdf.Text(
          'الملخص الأسبوعي',
          style: const pdf.TextStyle(fontSize: 20),
        ),
      ),
      build: (_) => [
        for (final item in items)
          if (item.service == Service.liturgy ||
              item.service == Service.sermon ||
              item.service == Service.visit ||
              item.service == Service.communion)
            pdf.Container(
              padding: const pdf.EdgeInsets.symmetric(vertical: 8),
              child: pdf.Text(
                '${item.service.label}  •  '
                '${item.when.day}/${item.when.month}  '
                '${item.when.hour}:${item.when.minute.toString().padLeft(2, '0')}',
              ),
            ),
      ],
    ),
  );
  await Printing.layoutPdf(
    name: 'weekly-summary.pdf',
    onLayout: (_) => document.save(),
  );
}
