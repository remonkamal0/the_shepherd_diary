import '../../../domain/appointments/appointment_repository.dart';
import 'package:flutter/material.dart';

import 'priest_services_screen.dart';
import 'priest_theme.dart';

class PriestWelcome extends StatelessWidget {
  const PriestWelcome({super.key, required this.repository, this.forPriest});

  final AppointmentRepository repository;
  final AppointmentRepository Function(String)? forPriest;

  Future<void> _choosePriest(BuildContext context) async {
    const priests = {
      'youhanna': 'القس يوحنا',
      'demetri': 'القس ديمتري',
      'karas': 'القس كاراس',
      'samuel': 'القس صموئيل',
      'barsoum': 'القس برسوم',
    };
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('اختار ملف الكاهن')),
            for (final entry in priests.entries)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(entry.value),
                onTap: () => Navigator.pop(sheet, entry.key),
              ),
            ListTile(
              title: const Text('المواعيد المحلية السابقة'),
              onTap: () => Navigator.pop(sheet, ''),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || id == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PriestServices(
          repository: id.isEmpty ? repository : forPriest!(id),
          priestId: id,
          priestName: priests[id],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned(
          bottom: -90,
          left: -75,
          child: CircleAvatar(radius: 130, backgroundColor: Color(0xFFEEE3D0)),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.church_outlined, size: 84, color: gold),
                    const SizedBox(height: 10),
                    Text(
                      'يوميات الكاهن',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: charcoal,
                          ),
                    ),
                    const Text(
                      'كنيسة الشهيد العظيم مارمينا بمدينة الاحلام',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    const TextField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _PasswordField(),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => forPriest != null
                          ? _choosePriest(context)
                          : Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PriestServices(repository: repository),
                              ),
                            ),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(
                        forPriest == null
                            ? 'تصفح الخدمات التجريبية'
                            : 'اختار ملف الكاهن',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField();

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextField(
    obscureText: _hidden,
    decoration: InputDecoration(
      labelText: 'كلمة المرور',
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _hidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    ),
  );
}
