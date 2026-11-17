import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../domain/appointments/liturgy_schedule.dart';
import 'priest_liturgy_image_review.dart';
import 'priest_service_inbox.dart';
import 'dart:ui' show ImageFilter;
import 'priest_service_workflow_screen.dart';
import 'priest_preparation_library.dart';
import '../../../domain/appointments/appointment_overview.dart';
import 'priest_service_icons.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/appointments/appointment.dart';
import 'priest_calendar.dart';
import 'priest_appointment_editor.dart';
import '../../../domain/appointments/appointment_repository.dart';
import 'priest_theme.dart';
import 'priest_service_report.dart';
import 'priest_profile.dart';

class PriestServices extends StatefulWidget {
  const PriestServices({
    super.key,
    required this.repository,
    this.priestId = "",
    this.priestName,
  });

  final AppointmentRepository repository;
  final String priestId;
  final String? priestName;

  @override
  State<PriestServices> createState() => _PriestServicesState();
}

class _PriestServicesState extends State<PriestServices> {
  final _appointments = <Appointment>[];
  late SharedPreferences _preferences;
  bool _loading = true;
  bool _showWeek = false;
  int _tab = 0;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final items = await widget.repository.load();
      if (mounted) setState(() => _appointments.addAll(items));
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _persist(List<Appointment> previous) async {
    try {
      await widget.repository.save(_appointments);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _appointments
            ..clear()
            ..addAll(previous);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر حفظ التغييرات. حاول مرة تانية.')),
        );
      }
      return false;
    }
  }

  Future<void> _remove(Appointment item) async {
    final previous = List<Appointment>.of(_appointments);
    setState(
      () => _appointments.removeWhere(
        (candidate) =>
            candidate.id == item.id ||
            (item.service == Service.liturgy && candidate.liturgyId == item.id),
      ),
    );
    await _persist(previous);
  }

  List<Appointment> get _liturgies =>
      _appointments.where((item) => item.service == Service.liturgy).toList();

  Future<bool> _edit(
    Service service, [
    Appointment? initial,
    DateTime? initialDate,
    Map<String, String> prefill = const {},
  ]) async {
    final result = await Navigator.push<Appointment>(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentEditor(
          service: service,
          liturgies: _liturgies,
          appointments: List.unmodifiable(_appointments),
          initial: initial,
          initialDate: initialDate,
          prefill: prefill,
        ),
      ),
    );
    if (result == null || !mounted) return false;
    final previous = List<Appointment>.of(_appointments);
    setState(() => _save(result));
    final saved = await _persist(previous);
    if (saved &&
        mounted &&
        initial == null &&
        result.service == Service.liturgy &&
        result.when.isAfter(DateTime.now()) &&
        result.fields['طول اليوم'] != 'true' &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await _offerCalendar(result);
    }
    return saved;
  }

  Future<void> _offerCalendar(Appointment item) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('إضافة لتقويم الموبايل'),
        content: const Text(
          'اختار التنبيه قبل القداس في تقويم الموبايل، وبعدها احفظ الحدث.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('لاحقًا'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('فتح التقويم'),
          ),
        ],
      ),
    );
    if (!mounted || add != true) return;
    final start = item.when;
    final endMinute = int.tryParse(item.fields['وقت النهاية'] ?? '');
    final end = endMinute == null
        ? start.add(const Duration(hours: 1))
        : DateTime(
            start.year,
            start.month,
            start.day,
            endMinute ~/ 60,
            endMinute % 60,
          );
    try {
      await const MethodChannel(
        'shepherd/calendar',
      ).invokeMethod<void>('addEvent', {
        'title': item.sundaySlot?.label ?? 'قداس',
        'location': item.title,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      });
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('القداس اتحفظ في التطبيق. تعذّر فتح تقويم الموبايل.'),
          ),
        );
      }
    }
  }

  Future<int?> _saveImported(List<LiturgySuggestion> drafts) async {
    final previous = List<Appointment>.of(_appointments);
    var added = 0;
    for (final draft in drafts) {
      final exists = _appointments.any(
        (item) =>
            item.service == Service.liturgy &&
            DateUtils.isSameDay(item.when, draft.date) &&
            item.sundaySlot == draft.slot,
      );
      if (exists) continue;
      _appointments.add(
        Appointment(
          id: 'import-${draft.date.toIso8601String()}-${draft.slot?.name ?? "single"}',
          service: Service.liturgy,
          when: draft.date,
          fields: {
            Service.liturgy.fields.first: draft.church,
            'طول اليوم': 'true',
          },
          sundayLiturgy: draft.slot,
        ),
      );
      added++;
    }
    if (added == 0) return 0;
    setState(() {});
    return await _persist(previous) ? added : null;
  }

  void _save(Appointment appointment) {
    final index = _appointments.indexWhere((item) => item.id == appointment.id);
    if (index == -1) {
      _appointments.add(appointment);
    } else {
      _appointments[index] = appointment;
    }
    if (appointment.service != Service.liturgy) return;
    final linkedIndex = _appointments.indexWhere(
      (item) =>
          item.service == Service.sermon && item.liturgyId == appointment.id,
    );
    if (appointment.kind == 'شريك' && linkedIndex == -1) return;
    final linked = linkedIndex == -1 ? null : _appointments[linkedIndex];
    final sermon = Appointment(
      id: linked?.id ?? '${appointment.id}-sermon',
      service: Service.sermon,
      when: appointment.when,
      fields: linked?.fields ?? {'الموضوع': 'تحضير عظة القداس'},
      kind: 'عظة قداس',
      liturgyId: appointment.id,
    );
    if (linkedIndex == -1) {
      _appointments.add(sermon);
    } else {
      _appointments[linkedIndex] = sermon;
    }
  }

  void _openNotifications(List<Appointment> agenda) {
    final now = DateTime.now();
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (pageContext) => Scaffold(
          backgroundColor: paper,
          appBar: AppBar(
            backgroundColor: paper,
            title: const Text(
              'الإشعارات',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: agenda.isEmpty
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ServiceIcon(Icons.notifications_none_rounded),
                        SizedBox(height: 16),
                        Text('مفيش تنبيهات لليوم.'),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                      itemCount: agenda.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final item = agenda[index];
                        final overdue = item.isConfessionOverdue(now);
                        final followUp =
                            overdue || !DateUtils.isSameDay(item.when, now);
                        final date = followUp
                            ? item.followUp ?? item.when
                            : item.when;
                        final allDay =
                            !followUp && item.fields['طول اليوم'] == 'true';
                        final hour = (date.hour + 11) % 12 + 1;
                        final minute = date.minute.toString().padLeft(2, '0');
                        final time = allDay
                            ? 'طول اليوم'
                            : '$hour:$minute ${date.hour < 12 ? 'ص' : 'م'}';
                        final label = overdue
                            ? 'اعتراف متأخر'
                            : followUp
                            ? 'متابعة'
                            : item.service.label;
                        return Card.outlined(
                          margin: EdgeInsets.zero,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Color(0xFFE8E1D8)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: _ServiceIcon(item.service.icon),
                            title: Text(
                              item.service == Service.confession
                                  ? label
                                  : item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: charcoal,
                              ),
                            ),
                            subtitle: Text(
                              '${item.service == Service.confession ? '' : '$label · '}${date.day}/${date.month}/${date.year} · $time',
                              style: TextStyle(
                                color: overdue
                                    ? Theme.of(pageContext).colorScheme.error
                                    : gold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _loadFailed) {
      return Scaffold(
        appBar: AppBar(title: const Text('يوميات الكاهن')),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('تعذّر تحميل المواعيد. اقفل الصفحة وافتحها تاني.'),
        ),
      );
    }
    final today = DateTime.now();
    final overview = AppointmentOverview(_appointments, today);
    final next = overview.next;
    final sermon = overview.sermon;
    final agenda =
        _appointments
            .where(
              (item) =>
                  DateUtils.isSameDay(item.when, today) ||
                  DateUtils.isSameDay(item.followUp, today),
            )
            .toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    final weekEnd = DateTime(today.year, today.month, today.day + 7);
    final dayStart = DateUtils.dateOnly(today);
    final week =
        _appointments
            .where(
              (item) =>
                  item.service != Service.confession &&
                  !item.when.isBefore(dayStart) &&
                  item.when.isBefore(weekEnd),
            )
            .toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    final visibleAgenda = _showWeek ? week : agenda;
    final notifications = [
      ...agenda,
      for (final item in _appointments)
        if (item.isConfessionOverdue(today) && !agenda.contains(item)) item,
    ];
    Widget calendar() => PriestCalendar(
      items: _appointments,
      onAdd: (service, day) => _edit(service, null, day),
      onOpen: (item) => _edit(item.service, item),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const ['يوميات الكاهن', 'الخدمات', 'النتيجة', 'التقارير'][_tab],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () => _openNotifications(notifications),
            icon: Badge.count(
              count: notifications.length,
              isLabelVisible: notifications.isNotEmpty,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: const ColoredBox(color: Color(0xF0292F32)),
                ),
              ),
            ),
            NavigationBar(
              height: 76,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              selectedIndex: _tab,
              onDestinationSelected: (index) {
                if (index == 4) {
                  _openNotifications(notifications);
                } else {
                  setState(() => _tab = index);
                }
              },
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11,
                  color: selected
                      ? const Color(0xFFF1DFC3)
                      : const Color(0xFFD5D1CA),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                );
              }),
              destinations: const [
                NavigationDestination(
                  icon: _NavIcon(Icons.home_outlined),
                  selectedIcon: _NavIcon(Icons.home_rounded, selected: true),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: _NavIcon(Icons.grid_view_outlined),
                  selectedIcon: _NavIcon(
                    Icons.grid_view_rounded,
                    selected: true,
                  ),
                  label: 'الخدمات',
                ),
                NavigationDestination(
                  icon: _NavIcon(Icons.calendar_month_outlined, calendar: true),
                  selectedIcon: _NavIcon(
                    Icons.calendar_month_rounded,
                    calendar: true,
                    selected: true,
                  ),
                  label: 'النتيجة',
                ),
                NavigationDestination(
                  icon: _NavIcon(Icons.table_chart_outlined),
                  selectedIcon: _NavIcon(
                    Icons.table_chart_rounded,
                    selected: true,
                  ),
                  label: 'التقارير',
                ),
                NavigationDestination(
                  icon: _NavIcon(Icons.notifications_none_rounded),
                  label: 'التنبيهات',
                ),
              ],
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            children: [
              if (_tab == 2) calendar(),
              if (_tab == 0) ...[
                PriestProfile(
                  preferences: _preferences,
                  priestId: widget.priestId,
                  priestName: widget.priestName,
                  onChanged: () {
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 24),
                if (next != null) ...[
                  Card.outlined(
                    margin: EdgeInsets.zero,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'الخدمة الجاية',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: gold,
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _ServiceIcon(next.service.icon),
                            title: Text(next.title),
                            subtitle: Text(
                              [
                                next.service.label,
                                next.sundaySlot?.label,
                                next.kind,
                                appointmentDate(context, next.when),
                              ].whereType<String>().join(' · '),
                            ),
                            onTap: () => _edit(next.service, next),
                          ),
                          if (sermon != null)
                            OutlinedButton.icon(
                              onPressed: () => _edit(Service.sermon, sermon),
                              icon: const Icon(Icons.menu_book_outlined),
                              label: Text(
                                'فتح تحضير العظة · ${sermon.fields[Appointment.preparationKey] ?? Appointment.preparationStates.first}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (overview.dueCount > 0)
                  Card.outlined(
                    child: ListTile(
                      leading: const Icon(
                        Icons.event_busy_outlined,
                        color: gold,
                      ),
                      title: const Text('متابعات مستحقة'),
                      trailing: Text('${overview.dueCount}'),
                      subtitle: const Text('الافتقاد والاعتراف'),
                      onTap: () => _openNotifications(
                        _appointments
                            .where(
                              (item) =>
                                  item.isConfessionOverdue(today) ||
                                  (item.service == Service.visit &&
                                      item.followUp?.isAfter(today) == false),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final weekly in [false, true])
                      OutlinedButton.icon(
                        icon: Icon(
                          weekly
                              ? Icons.fact_check_outlined
                              : Icons.today_outlined,
                        ),
                        label: Text(weekly ? 'مراجعة الأسبوع' : 'يوم الخدمة'),
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ServiceWorkflowScreen(
                              weekly: weekly,
                              items: () => _appointments,
                              onEdit: (item) => _edit(item.service, item),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _HomeDashboard(
                  todayCount: agenda.length,
                  weekCount: week.length,
                  notificationCount: notifications.length,
                  onToday: () => setState(() => _showWeek = false),
                  onWeek: () => setState(() => _showWeek = true),
                  onNotifications: () => _openNotifications(notifications),
                  onCalendar: () => setState(() => _tab = 2),
                  onReports: () => setState(() => _tab = 3),
                ),
                const SizedBox(height: 24),
                Text(
                  _showWeek ? 'أجندة الأسبوع' : 'أجندة اليوم',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ChoiceChip(
                    label: const Text('الأيام السبعة القادمة'),
                    selected: _showWeek,
                    onSelected: (value) => setState(() => _showWeek = value),
                  ),
                ),
                const SizedBox(height: 8),
                if (visibleAgenda.isEmpty)
                  const Card.outlined(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(
                        Icons.event_available_outlined,
                        color: gold,
                      ),
                      title: Text('مفيش مواعيد مسجلة في الفترة دي.'),
                    ),
                  ),
                for (final item in visibleAgenda)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(item.service.icon, color: gold),
                    title: Text(item.title),
                    subtitle: Text(
                      _showWeek || DateUtils.isSameDay(item.when, today)
                          ? appointmentDate(context, item.when)
                          : 'متابعة · ${appointmentDate(context, item.followUp!)}',
                    ),
                    onTap: () => _edit(item.service, item),
                  ),
              ],
              if (_tab == 1) ...[
                Row(
                  children: [
                    Expanded(
                      child: _ServiceShortcut(
                        icon: Icons.folder_open_outlined,
                        label: 'مكتبة التحضير',
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PreparationLibrary(
                              sermons: () => _appointments
                                  .where(
                                    (item) => item.service == Service.sermon,
                                  )
                                  .toList(),
                              onEdit: (item) => _edit(Service.sermon, item),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ServiceShortcut(
                        icon: Icons.inbox_outlined,
                        label: 'طلبات الخدمة',
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ServiceInbox(
                              schedule: (service, title) => _edit(
                                service,
                                null,
                                null,
                                {service.fields.first: title},
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ServiceShortcut(
                        icon: Icons.archive_outlined,
                        label: 'أرشيف الخدمات',
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ServiceArchive(
                              items: () => _appointments,
                              open: (item) => _edit(item.service, item),
                              copy: (item) =>
                                  _edit(item.service, null, null, item.fields),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (_tab == 1 || _tab == 3)
                for (final service in Service.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFFDAD8D4)),
                      ),
                      tileColor: Colors.white,
                      leading: _ServiceIcon(service.icon),
                      title: Text(service.label),
                      trailing: const Icon(Icons.chevron_left, color: gold),
                      onTap: () {
                        if (_tab == 1) {
                          _openService(service);
                        } else {
                          final items =
                              _appointments
                                  .where((item) => item.service == service)
                                  .toList()
                                ..sort((a, b) => a.when.compareTo(b.when));
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceReport(
                                items: items,
                                service: service,
                                onEdit: (item) => _edit(service, item),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openService(Service service) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _ServicePage(
          service: service,
          items: () =>
              _appointments.where((item) => item.service == service).toList()
                ..sort((a, b) => a.when.compareTo(b.when)),
          edit: (item) => _edit(service, item),
          remove: _remove,
          priestName: widget.priestName ?? '',
          saveImported: _saveImported,
          addFromImage: (draft) => _edit(service, null, draft?.date, {
            if (draft != null) service.fields.first: draft.church,
            if (draft?.slot case final slot?) 'sundaySlot': slot.name,
          }),
          related: (item) => _appointments
              .where((candidate) => candidate.liturgyId == item.id)
              .toList(),
          editRelated: (item) => _edit(item.service, item),
        ),
      ),
    );
  }
}

class _ServicePage extends StatefulWidget {
  const _ServicePage({
    required this.service,
    required this.items,
    required this.edit,
    required this.remove,
    required this.addFromImage,
    required this.saveImported,
    required this.priestName,
    required this.related,
    required this.editRelated,
  });

  final Service service;
  final List<Appointment> Function() items;
  final Future<void> Function(Appointment?) edit;
  final Future<void> Function(Appointment) remove;
  final Future<bool> Function(LiturgySuggestion?) addFromImage;
  final Future<int?> Function(List<LiturgySuggestion>) saveImported;
  final String priestName;
  final List<Appointment> Function(Appointment) related;
  final Future<void> Function(Appointment) editRelated;

  @override
  State<_ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<_ServicePage> {
  Future<void> _edit([Appointment? item]) async {
    await widget.edit(item);
    if (mounted) setState(() {});
  }

  Future<void> _openRelated(Appointment liturgy) async {
    final related = widget.related(liturgy);
    final selected = await showModalBottomSheet<Appointment>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(liturgy.sundaySlot?.label ?? liturgy.title),
              subtitle: Text(appointmentDate(sheetContext, liturgy.when)),
            ),
            if (related.isEmpty)
              const ListTile(title: Text('مفيش عظة أو مناولة مرتبطة بالقداس.')),
            for (final item in related)
              ListTile(
                leading: Icon(item.service.icon, color: gold),
                title: Text(item.title),
                subtitle: Text(item.service.label),
                onTap: () => Navigator.pop(sheetContext, item),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      await widget.editRelated(selected);
      if (mounted) setState(() {});
    }
  }

  Future<void> _remove(Appointment item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الموعد؟'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await widget.remove(item);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'تقرير ',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceReport(
                  items: items,
                  service: widget.service,
                  onEdit: _edit,
                ),
              ),
            ),
          ),
        ],
        backgroundColor: paper,
        title: Text(
          widget.service.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.service == Service.liturgy) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiturgyImageReview(
                              onAdd: widget.addFromImage,
                              onSaveAll: widget.saveImported,
                              priestName: widget.priestName,
                            ),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('رفع صورة جدول القداسات'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة موعد'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: items.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ServiceIcon(widget.service.icon),
                    const SizedBox(height: 16),
                    Text(
                      'مفيش مواعيد مسجلة.',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card.outlined(
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _edit(item),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            14,
                            14,
                            6,
                            14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ServiceIcon(item.service.icon),
                              const SizedBox(width: 12),
                              Expanded(child: _AppointmentSummary(item)),
                              PopupMenuButton<String>(
                                tooltip: 'خيارات الموعد',
                                onSelected: (action) {
                                  if (action == 'related') {
                                    _openRelated(item);
                                  } else if (action == 'edit') {
                                    _edit(item);
                                  } else {
                                    _remove(item);
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (item.service == Service.liturgy)
                                    const PopupMenuItem(
                                      value: 'related',
                                      child: Text('العظة والمناولات المرتبطة'),
                                    ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('تعديل الموعد'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('حذف الموعد'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF5ECDD),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Icon(icon, color: gold),
  );
}

class _AppointmentSummary extends StatelessWidget {
  const _AppointmentSummary(this.item);

  final Appointment item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final day = item.when;
    const months = [
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
    final hour = (day.hour + 11) % 12 + 1;
    final minute = day.minute.toString().padLeft(2, '0');
    final period = day.hour < 12 ? 'ص' : 'م';
    final status = [
      if (item.sundaySlot case final slot?) slot.label,
      ?item.kind,
      if (item.done) 'تم الافتقاد',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: charcoal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${day.day} ${months[day.month - 1]} ${day.year}، $hour:$minute $period',
          style: text.bodySmall?.copyWith(color: const Color(0xFF625C53)),
        ),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF5ECDD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Text(
                status,
                style: text.labelMedium?.copyWith(color: gold),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.todayCount,
    required this.weekCount,
    required this.notificationCount,
    required this.onToday,
    required this.onWeek,
    required this.onNotifications,
    required this.onCalendar,
    required this.onReports,
  });

  final int todayCount;
  final int weekCount;
  final int notificationCount;
  final VoidCallback onToday;
  final VoidCallback onWeek;
  final VoidCallback onNotifications;
  final VoidCallback onCalendar;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'لوحة المتابعة',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        for (final (icon, label, count, action) in [
          (Icons.today_outlined, 'مواعيد ومتابعات اليوم', todayCount, onToday),
          (
            Icons.date_range_outlined,
            'مواعيد الأيام السبعة القادمة',
            weekCount,
            onWeek,
          ),
          (
            Icons.notifications_none_rounded,
            'التنبيهات',
            notificationCount,
            onNotifications,
          ),
        ])
          Card.outlined(
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.white,
            child: ListTile(
              leading: Icon(icon, color: gold),
              title: Text(label),
              trailing: Text(
                '$count',
                style: text.titleLarge?.copyWith(
                  color: charcoal,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onTap: action,
            ),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onCalendar,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('فتح النتيجة'),
            ),
            OutlinedButton.icon(
              onPressed: onReports,
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('فتح التقارير'),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon(this.icon, {this.selected = false, this.calendar = false});

  final IconData icon;
  final bool selected;
  final bool calendar;

  @override
  Widget build(BuildContext context) {
    if (calendar) {
      return Transform.translate(
        offset: const Offset(0, -8),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFFE8C789) : gold,
            border: Border.all(color: const Color(0xFFF1DFC3), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18292F32),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: selected ? charcoal : Colors.white,
            size: 24,
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF414548) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 22,
        color: selected ? const Color(0xFFF1DFC3) : const Color(0xFFD5D1CA),
      ),
    );
  }
}

class _ServiceShortcut extends StatelessWidget {
  const _ServiceShortcut({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE8E1D8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Column(
      children: [
        Icon(icon, color: gold),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
