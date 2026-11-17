import 'package:image_picker/image_picker.dart';
import '../../../domain/appointments/reference_liturgy_schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../domain/appointments/liturgy_schedule.dart';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class LiturgyImageReview extends StatefulWidget {
  const LiturgyImageReview({
    super.key,
    required this.onAdd,
    required this.onSaveAll,
    required this.priestName,
  });

  final Future<bool> Function(LiturgySuggestion?) onAdd;
  final String priestName;
  final Future<int?> Function(List<LiturgySuggestion>) onSaveAll;

  @override
  State<LiturgyImageReview> createState() => _LiturgyImageReviewState();
}

class _LiturgyImageReviewState extends State<LiturgyImageReview> {
  Uint8List? _image;
  bool _picking = false;
  bool _reading = false;
  bool _saving = false;
  List<LiturgySuggestion> _dates = [];
  final _saved = <LiturgySuggestion>{};
  String? _status;

  Future<void> _saveAll() async {
    if (_saving) return;
    setState(() => _saving = true);
    final count = await widget.onSaveAll(List.of(_dates));
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (count != null) _saved.addAll(_dates);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == null
              ? 'تعذّر الحفظ. جرّب مرة تانية.'
              : count == 0
              ? 'القداسات دي مسجّلة بالفعل.'
              : 'تم حفظ $count قداس في ملف القس.',
        ),
      ),
    );
  }

  Future<void> _read(Uint8List bytes) async {
    setState(() => _reading = true);
    try {
      final cells = await const MethodChannel(
        'shepherd/liturgy_ocr',
      ).invokeListMethod<List<Object?>>('read', bytes);
      final dates = readLiturgySchedule([
        for (final row in cells ?? <List<Object?>>[]) row.cast<String>(),
      ], widget.priestName);
      if (mounted)
        setState(() {
          _dates = dates;
          _status = dates.isEmpty
              ? 'مفيش قداسات مطابقة للاسم في الجدول المقروء.'
              : null;
        });
    } catch (_) {
      if (mounted) setState(() => _status = 'تعذّرت قراءة الجدول تلقائيًا.');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  bool get _supportsCamera =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _pick({bool camera = false}) async {
    if (_picking || _saving) return;
    setState(() => _picking = true);
    try {
      final Uint8List? bytes;
      if (camera) {
        final photo = await ImagePicker().pickImage(source: ImageSource.camera);
        bytes = await photo?.readAsBytes();
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        bytes = result?.files.single.bytes;
      }
      if (mounted && bytes != null) {
        setState(() {
          _image = bytes;
          _dates = [];
          _saved.clear();
          _status = null;
        });
        final reference = readReferenceSchedule(bytes, widget.priestName);
        if (reference != null) {
          setState(() {
            _dates = reference;
            _status = reference.isEmpty
                ? 'اختار ملف القس عشان تظهر قداساته.'
                : null;
          });
        } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await _read(bytes);
        } else {
          setState(
            () => _status = 'القراءة التلقائية للصور الأخرى متاحة على أندرويد.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذّر فتح الصورة.')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة صورة جدول القداسات')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _picking || _saving ? null : _pick,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    image == null ? 'اختيار صورة الجدول' : 'تغيير الصورة',
                  ),
                ),
                if (_supportsCamera)
                  OutlinedButton.icon(
                    onPressed: _picking || _saving
                        ? null
                        : () => _pick(camera: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('تصوير الجدول'),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: image == null
                      ? const Center(
                          child: Text('اختار صورة عشان تراجع الجدول.'),
                        )
                      : InteractiveViewer(
                          maxScale: 6,
                          child: Image.memory(
                            image,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Center(child: Text('تعذّر عرض الصورة.')),
                          ),
                        ),
                ),
                if (image != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'كبّر الصورة لقراءة الجدول، وسجّل القداسات اللي تخصّك يدويًا.',
                  ),
                  const SizedBox(height: 8),
                  if (_reading) const LinearProgressIndicator(),
                  if (_status != null) Text(_status!),
                  if (_dates.isNotEmpty)
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          const ListTile(title: Text('القداسات المقترحة للقس')),
                          for (final date in _dates)
                            ListTile(
                              title: Text(
                                '${date.date.day}/${date.date.month}/${date.date.year}',
                              ),
                              subtitle: Text(
                                [
                                  date.church,
                                  date.slot?.label,
                                ].whereType<String>().join(' · '),
                              ),
                              trailing: _saved.contains(date)
                                  ? const Icon(Icons.check_circle_outline)
                                  : const Icon(Icons.add_circle_outline),
                              onTap: _saving
                                  ? null
                                  : () async {
                                      final saved = await widget.onAdd(date);
                                      if (saved && mounted)
                                        setState(() => _saved.add(date));
                                    },
                            ),
                        ],
                      ),
                    ),
                  if (_dates.isNotEmpty)
                    FilledButton.icon(
                      onPressed: _saving || _saved.containsAll(_dates)
                          ? null
                          : _saveAll,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('إضافة وحفظ الكل'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _reading || _saving
                        ? null
                        : () => widget.onAdd(null),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة قداس يدويًا'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
