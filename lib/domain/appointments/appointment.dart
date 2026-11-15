enum Service {
  liturgy('القداسات', ['الكنيسة أو مكان القداس']),
  sermon('العظات', [
    'الموضوع',
    'الاجتماع أو المؤتمر',
    'رابط التحضير على Drive',
    'القراءات',
    'المراجع',
  ]),
  communion('المناولات الخارجية', [
    'اسم الحالة',
    'العنوان',
    'الهاتف',
    'اسم المبلّغ',
    'هاتف المبلّغ',
  ]),
  baptism('المعمودية', ['اسم المُعمَّد', 'اسم الأب', 'اسم الأم', 'الكنيسة']),
  wedding('الأكاليل والخطوبات', [
    'العريس',
    'العروس',
    'الكنيسة',
    'العنوان',
    'اسم المبلّغ',
    'هاتف المبلّغ',
  ]),
  funeral('العزاء والجنازات', [
    'اسم المتوفى',
    'الكنيسة',
    'العنوان',
    'اسم المبلّغ',
    'هاتف المبلّغ',
  ]),
  liturgical('الخدمات الليتورجية', [
    'اسم الطفل',
    'العنوان',
    'اسم المبلّغ',
    'هاتف المبلّغ',
  ]),
  visit('الافتقاد', [
    'اسم الأسرة',
    'العنوان',
    'بيانات الزوج وأب اعترافه',
    'بيانات الزوجة وأب اعترافها',
    'بيانات الأبناء',
    'طلبات المتابعة',
  ]),
  confession('الاعترافات', [
    'اسم المعترف',
    'السن',
    'الهاتف',
    'العمل أو الدراسة',
    'العنوان',
  ]),
  family('متطلبات الأسرة', ['المطلوب', 'العنوان']);

  const Service(this.label, this.fields);
  final String label;

  final List<String> fields;
}

enum SundayLiturgy {
  first('القداس الأول', 'الأنبا رويس'),
  second('القداس الثاني', 'مارمينا');

  const SundayLiturgy(this.label, this.church);
  final String church;
  final String label;
}

class Appointment {
  static const preparationKey = 'حالة التحضير';
  static const preparationStates = ['مطلوبة', 'جاري التحضير', 'جاهزة'];
  const Appointment({
    required this.id,
    required this.service,
    required this.when,
    required this.fields,
    this.kind,
    this.sundayLiturgy,
    this.liturgyId,
    this.followUp,
    this.confessionSessions = const [],
    this.done = false,
  });

  final String id;
  final Service service;
  final DateTime when;
  final Map<String, String> fields;
  final String? kind;
  final SundayLiturgy? sundayLiturgy;

  SundayLiturgy? get sundaySlot =>
      service == Service.liturgy && when.weekday == DateTime.sunday
      ? sundayLiturgy ?? SundayLiturgy.first
      : null;
  final String? liturgyId;
  final DateTime? followUp;
  final List<DateTime> confessionSessions;
  final bool done;

  bool isConfessionOverdue(DateTime now) {
    final due = followUp;
    return service == Service.confession &&
        due != null &&
        DateTime(now.year, now.month, now.day).isAfter(due);
  }

  String get title => fields[service.fields.first] ?? service.label;
}
