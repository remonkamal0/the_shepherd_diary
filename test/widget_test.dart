import 'package:the_shepherd_diary/data/appointments/local_appointment_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_shepherd_diary/ui/features/priest/priest_app.dart';

void main() {
  testWidgets('Saving a liturgy creates a sermon', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      PriestApp(repository: LocalAppointmentRepository()),
    );
    await tester.tap(find.text('تصفح الخدمات التجريبية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الخدمات').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('القداسات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة موعد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'كنيسة العذراء');
    await tester.scrollUntilVisible(
      find.text('حفظ الموعد'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('حفظ الموعد'));
    await tester.pumpAndSettle();
    expect(find.text('كنيسة العذراء'), findsWidgets);
    await tester.pageBack();

    await tester.pumpAndSettle();
    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('تحضير عظة القداس'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('تحضير عظة القداس'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      PriestApp(repository: LocalAppointmentRepository()),
    );
    await tester.tap(find.text('تصفح الخدمات التجريبية'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('كنيسة العذراء'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('كنيسة العذراء'), findsWidgets);
  });
}
