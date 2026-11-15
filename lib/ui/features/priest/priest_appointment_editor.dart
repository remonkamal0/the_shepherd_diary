import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/appointments/appointment_workflow.dart';
import 'priest_appointment_link.dart';
import 'package:flutter/material.dart';

import '../../../domain/appointments/appointment.dart';

class AppointmentEditor extends StatefulWidget {
  const AppointmentEditor({
    super.key,
    required this.service,
    required this.liturgies,
    this.initial,
    this.initialDate,
    this.prefill = const {},
    this.appointments = const [],
  });

  final Service service;
  final List<Appointment> liturgies;
  final Appointment? initial;
  final DateTime? initialDate;
  final Map<String, String> prefill;
  final List<Appointment> appointments;

  @override
  State<AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<AppointmentEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late DateTime _when;
  DateTime? _followUp;
  bool _allDay = false;
  String _preparation = Appointment.preparationStates.first;
  int? _endMinute;

  Future<void> _pickEnd() async {
    final minutes = _endMinute ?? (_when.hour * 60 + _when.minute);
    final time = await showTimePicker(
      helpText: 'اختار الوقت',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (time != null && mounted) {
      setState(() => _endMinute = time.hour * 60 + time.minute);
    }
  }

  final _interval = TextEditingController();
  late final List<DateTime> _sessions;

  void _recordToday() {
    final now = DateTime.now();
    setState(() {
      _when = now;
      if (!_sessions.any((date) => DateUtils.isSameDay(now, date))) {
        _sessions.insert(0, now);
      }
    });
  }

  String? _kind;
  SundayLiturgy _sundayLiturgy = SundayLiturgy.first;

  bool get _isSundayLiturgy =>
      widget.service == Service.liturgy && _when.weekday == DateTime.sunday;
  void _fillSundayChurch() {
    if (_isSundayLiturgy) {
      _fields[Service.liturgy.fields.first]!.text = _sundayLiturgy.church;
    }
  }

  String? _liturgyId;
  bool _done = false;
  bool _saving = false;
  final _checklist = TextEditingController();
  final _reason = TextEditingController();
  Set<String> _checked = {};
  String get _templateKey => 'shepherd.serviceTemplate.${widget.service.name}';
  bool get _rescheduled =>
      widget.initial != null && widget.initial!.when != _when;

  Future<void> _template({required bool save}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (save) {
        final saved = await prefs.setString(
          _templateKey,
          jsonEncode({
            'hour': _when.hour,
            'minute': _when.minute,
            if (widget.service == Service.liturgy)
              'place': _fields[widget.service.fields.first]?.text ?? '',
            'kind': _kind,
            'slot': _sundayLiturgy.name,
            'checklist': _checklist.text,
          }),
        );
        if (!saved) throw StateError('Template save failed');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ قالب الخدمة')));
        return;
      }
      final data = prefs.getString(_templateKey);
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مفيش قالب محفوظ للخدمة دي.')),
        );
        return;
      }
      final template = jsonDecode(data) as Map<String, dynamic>;
      setState(() {
        _when = DateTime(
          _when.year,
          _when.month,
          _when.day,
          template['hour'] as int,
          template['minute'] as int,
        );
        _kind = template['kind'] as String?;
        _sundayLiturgy = SundayLiturgy.values.byName(
          template['slot'] as String,
        );
        if (template['place'] case final String place) {
          _fields[widget.service.fields.first]?.text = place;
        }
        _checklist.text = template['checklist'] as String;
        _checked.clear();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تحميل أو حفظ قالب الخدمة.')),
        );
      }
    }
  }

  List<String> get _kinds => switch (widget.service) {
    Service.liturgy => ['خديم', 'شريك', 'شريك وعليه عظة'],
    Service.wedding => ['إكليل', 'خطوبة'],
    Service.funeral => ['جنازة', 'عزاء', 'صلاة التالت'],
    Service.communion => ['مرة واحدة', 'أسبوعياً', 'شهرياً'],
    Service.liturgical => ['صلاة الطشت', 'تبريك منزل', 'مسحة المرضى', 'أخرى'],
    Service.sermon => ['عظة قداس', 'اجتماع', 'مؤتمر'],
    _ => [],
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _when = initial?.when ?? widget.initialDate ?? DateTime.now();
    _followUp = initial?.followUp;
    final savedPreparation = initial?.fields[Appointment.preparationKey];
    if (savedPreparation != null &&
        Appointment.preparationStates.contains(savedPreparation)) {
      _preparation = savedPreparation;
    }
    _allDay = initial?.fields['طول اليوم'] == 'true';
    _endMinute = int.tryParse(initial?.fields['وقت النهاية'] ?? '');
    _sessions = [...?initial?.confessionSessions];
    _interval.text = initial?.fields['فترة المتابعة بالأيام'] ?? '';
    _sundayLiturgy =
        initial?.sundaySlot ??
        SundayLiturgy.values
            .where((slot) => slot.name == widget.prefill["sundaySlot"])
            .firstOrNull ??
        SundayLiturgy.first;
    _kind = initial?.kind ?? _kinds.firstOrNull;
    _liturgyId = initial?.liturgyId;
    _done = initial?.done ?? false;
    _checklist.text = initial?.fields[AppointmentWorkflow.checklistKey] ?? '';
    _checked = (initial?.fields['serviceChecklistDone'] ?? '')
        .split('\n')
        .toSet();
    _fields = {
      for (final label in widget.service.fields)
        label: TextEditingController(
          text: initial?.fields[label] ?? widget.prefill[label],
        ),
    };
    if (initial == null) _fillSundayChurch();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _interval.dispose();
    _checklist.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate({bool followUp = false}) async {
    final current = followUp ? _followUp ?? _when : _when;
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      helpText: followUp ? 'اختار تاريخ المتابعة' : 'اختار تاريخ الموعد',
      cancelText: 'إلغاء',
      confirmText: 'التالي',
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      helpText: 'اختار الوقت',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (followUp) {
        _followUp = selected;
      } else {
        final wasSunday = _isSundayLiturgy;
        _when = selected;
        if (!wasSunday) {
          _fillSundayChurch();
        } else if (!_isSundayLiturgy) {
          final church = _fields[Service.liturgy.fields.first]!;
          if (church.text == _sundayLiturgy.church) church.clear();
        }
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (!_allDay &&
        _endMinute != null &&
        _endMinute! <= _when.hour * 60 + _when.minute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختار وقت انتهاء بعد وقت البداية في نفس اليوم.'),
        ),
      );
      return;
    }
    if (widget.service == Service.liturgy &&
        widget.liturgies.any(
          (item) =>
              item.id != widget.initial?.id &&
              DateUtils.isSameDay(item.when, _when) &&
              (!_isSundayLiturgy || item.sundaySlot == _sundayLiturgy),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSundayLiturgy
                ? '${_sundayLiturgy.label} مسجل بالفعل للأحد ده.'
                : 'فيه قداس مسجل بالفعل في اليوم ده.',
          ),
        ),
      );
      return;
    }
    final appointment = Appointment(
      id:
          widget.initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      service: widget.service,
      when: _when,
      fields: {
        if (widget.service != Service.confession) ...{
          AppointmentWorkflow.checklistKey: _checklist.text.trim(),
          'serviceChecklistDone': _checked
              .intersection(
                _checklist.text.split('\n').map((line) => line.trim()).toSet(),
              )
              .join('\n'),
          AppointmentWorkflow.historyKey: [
            if (widget.initial?.fields[AppointmentWorkflow.historyKey]
                case final history? when history.isNotEmpty)
              history,
            if (_rescheduled)
              '${widget.initial!.when.toIso8601String()} ← ${_when.toIso8601String()} ${_reason.text.trim()}',
          ].join('\n'),
        },
        if (widget.service == Service.sermon)
          Appointment.preparationKey: _preparation,
        if (_allDay) 'طول اليوم': 'true',
        if (!_allDay && _endMinute != null)
          'وقت النهاية': _endMinute.toString(),
        if (widget.service == Service.confession)
          'فترة المتابعة بالأيام': _interval.text.trim(),
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      },
      kind: _kind,
      sundayLiturgy: _isSundayLiturgy ? _sundayLiturgy : null,
      liturgyId: _liturgyId,
      followUp: widget.service == Service.confession
          ? DateTime(
              _when.year,
              _when.month,
              _when.day + int.parse(_interval.text.trim()),
            )
          : _followUp,
      done: _done,
      confessionSessions: List.unmodifiable(_sessions),
    );
    final conflicts = widget.appointments
        .where((item) => AppointmentWorkflow.overlaps(appointment, item))
        .toList();
    if (conflicts.isNotEmpty) {
      _saving = true;
      final keep = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('فيه تعارض في المواعيد'),
          content: SingleChildScrollView(
            child: Text(
              conflicts
                  .map(
                    (item) =>
                        '${item.title} · ${appointmentDate(dialog, item.when)}',
                  )
                  .join('\n'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('راجع الموعد'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('احفظ رغم التعارض'),
            ),
          ],
        ),
      );
      _saving = false;
      if (!mounted || keep != true) return;
    }
    Navigator.pop(context, appointment);
  }

  @override
  Widget build(BuildContext context) {
    final firstField = widget.service.fields.first;
    return Scaffold(
      appBar: AppBar(title: Text(widget.service.label)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: const Color(0xFFF5ECDD),
                    side: const BorderSide(color: Color(0xFFE8E1D8)),
                  ),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    widget.service == Service.confession
                        ? 'آخر اعتراف · ${appointmentDate(context, _when)}'
                        : appointmentDate(context, _when),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.service != Service.confession) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('طول اليوم'),
                    value: _allDay,
                    onChanged: (value) => setState(() => _allDay = value),
                  ),
                  if (!_allDay)
                    OutlinedButton.icon(
                      onPressed: _pickEnd,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        _endMinute == null
                            ? 'إضافة وقت الانتهاء'
                            : MaterialLocalizations.of(context).formatTimeOfDay(
                                TimeOfDay(
                                  hour: _endMinute! ~/ 60,
                                  minute: _endMinute! % 60,
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                if (_isSundayLiturgy) ...[
                  DropdownButtonFormField<SundayLiturgy>(
                    initialValue: _sundayLiturgy,
                    decoration: const InputDecoration(
                      labelText: 'ترتيب القداس',
                    ),
                    items: [
                      for (final slot in SundayLiturgy.values)
                        DropdownMenuItem(value: slot, child: Text(slot.label)),
                    ],
                    onChanged: (slot) {
                      if (slot != null) {
                        setState(() {
                          _sundayLiturgy = slot;
                          _fillSundayChurch();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_kinds.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _kind,
                    decoration: InputDecoration(
                      labelText: widget.service == Service.liturgy
                          ? 'الدور'
                          : widget.service == Service.liturgical
                          ? 'نوع الصلاة'
                          : 'النوع',
                    ),
                    items: [
                      for (final kind in _kinds)
                        DropdownMenuItem(value: kind, child: Text(kind)),
                    ],
                    onChanged: (kind) => setState(() => _kind = kind),
                  ),
                if (widget.service == Service.communion &&
                    widget.liturgies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _liturgyId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'القداس المرتبط',
                      ),
                      items: [
                        for (final item in widget.liturgies)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.title} · ${appointmentDate(context, item.when)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) => setState(() => _liturgyId = id),
                    ),
                  ),
                if (widget.service == Service.sermon)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _preparation,
                      decoration: const InputDecoration(
                        labelText: Appointment.preparationKey,
                      ),
                      items: [
                        for (final status in Appointment.preparationStates)
                          DropdownMenuItem(value: status, child: Text(status)),
                      ],
                      onChanged: (status) {
                        if (status != null)
                          setState(() => _preparation = status);
                      },
                    ),
                  ),
                ...appointmentLinks(widget.initial?.fields),
                for (final entry in _fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText:
                            widget.service == Service.liturgical &&
                                entry.key == firstField
                            ? switch (_kind) {
                                'تبريك منزل' => 'اسم الأسرة',
                                'مسحة المرضى' => 'اسم المريض',
                                'أخرى' => 'اسم الشخص أو الأسرة',
                                _ => 'اسم الطفل',
                              }
                            : entry.key,
                      ),
                      validator: (value) =>
                          entry.key == firstField &&
                              (value == null || value.trim().isEmpty)
                          ? 'الحقل مطلوب'
                          : null,
                    ),
                  ),
                if (widget.service == Service.confession)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: _interval,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'فترة المتابعة بالأيام',
                      ),
                      validator: (value) {
                        final days = int.tryParse(value?.trim() ?? '');
                        return days == null || days < 1 || days > 3650
                            ? 'اكتب فترة من ١ إلى ٣٦٥٠ يوم'
                            : null;
                      },
                    ),
                  ),
                if (widget.service == Service.confession) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _recordToday,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('تم الاعتراف اليوم'),
                  ),
                  if (_sessions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'سجل الجلسات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final date in _sessions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: Text(appointmentDate(context, date)),
                      ),
                  ],
                ],
                if (widget.service != Service.confession) ...[
                  if (widget.service != Service.visit)
                    SwitchListTile(
                      title: const Text('تمت الخدمة'),
                      value: _done,
                      onChanged: (value) => setState(() => _done = value),
                    ),
                  if (_rescheduled)
                    TextField(
                      controller: _reason,
                      decoration: const InputDecoration(
                        labelText: 'سبب تغيير الموعد (اختياري)',
                      ),
                    ),
                  if (widget.initial?.fields[AppointmentWorkflow.historyKey]
                      case final history? when history.isNotEmpty)
                    ExpansionTile(
                      title: const Text('سجل تغيير الموعد'),
                      children: [ListTile(title: Text(history))],
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _checklist,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'قائمة التجهيز',
                      helperText: 'اكتب كل مهمة في سطر',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  for (final task
                      in _checklist.text
                          .split('\n')
                          .map((line) => line.trim())
                          .where((line) => line.isNotEmpty)
                          .toSet())
                    CheckboxListTile(
                      title: Text(task),
                      value: _checked.contains(task),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _checked.add(task);
                        } else {
                          _checked.remove(task);
                        }
                      }),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _template(save: false),
                        child: const Text('استخدم قالب الخدمة'),
                      ),
                      TextButton(
                        onPressed: () => _template(save: true),
                        child: const Text('احفظ كقالب خدمة'),
                      ),
                    ],
                  ),
                ],
                if (widget.service == Service.visit) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تم الافتقاد'),
                    value: _done,
                    onChanged: (value) => setState(() => _done = value),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(followUp: true),
                    icon: const Icon(Icons.event_repeat_outlined),
                    label: Text(
                      _followUp == null
                          ? 'تحديد المتابعة'
                          : appointmentDate(context, _followUp!),
                    ),
                  ),
                  if (_followUp != null)
                    TextButton(
                      onPressed: () => setState(() => _followUp = null),
                      child: const Text('إلغاء المتابعة'),
                    ),
                ],
                const SizedBox(height: 24),
                FilledButton(onPressed: _save, child: const Text('حفظ الموعد')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String appointmentDate(BuildContext context, DateTime date) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatShortDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}
