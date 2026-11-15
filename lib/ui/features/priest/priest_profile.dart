import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'priest_theme.dart';

class PriestProfile extends StatelessWidget {
  const PriestProfile({
    super.key,
    required this.preferences,
    required this.onChanged,
    this.priestId = '',
    this.priestName,
  });

  final SharedPreferences preferences;
  final VoidCallback onChanged;
  final String priestId;
  final String? priestName;
  String get scopedPhotoKey => priestId.isEmpty ? photoKey : '.';
  static const nameKey = 'shepherd.priest.name';
  static const photoKey = 'shepherd.priest.photo';

  Future<void> _edit(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ProfileEditor(
        preferences: preferences,
        photoKey: scopedPhotoKey,
        priestName: priestName,
      ),
    );
    if (changed == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final photo = preferences.getString(scopedPhotoKey);
    return Material(
      color: charcoal,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _Avatar(photo == null ? null : base64Decode(photo)),
        title: Text(
          priestName ?? preferences.getString(nameKey) ?? 'أضف اسم الكاهن',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text(
          'كنيسة الشهيد العظيم مارمينا بمدينة الاحلام',
          style: TextStyle(color: Color(0xFFF1DFC3)),
        ),
        trailing: const Icon(Icons.edit_outlined, color: Colors.white),
        onTap: () => _edit(context),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.photo);
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 25,
    backgroundColor: const Color(0xFFF5ECDD),
    foregroundImage: photo == null ? null : MemoryImage(photo!),
    onForegroundImageError: photo == null ? null : (_, _) {},
    child: const Icon(Icons.person_outline, color: gold),
  );
}

class _ProfileEditor extends StatefulWidget {
  final String photoKey;
  final String? priestName;
  const _ProfileEditor({
    required this.preferences,
    required this.photoKey,
    this.priestName,
  });
  final SharedPreferences preferences;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _name = TextEditingController(
    text:
        widget.priestName ??
        widget.preferences.getString(PriestProfile.nameKey),
  );
  late String? _photo = widget.preferences.getString(widget.photoKey);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || !mounted) return;
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.length > 2 * 1024 * 1024) {
        throw const FormatException();
      }
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 128,
        targetHeight: 128,
      );
      codec.dispose();
      if (mounted) {
        setState(() {
          _photo = base64Encode(bytes);
          _error = null;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'اختار صورة صالحة حجمها أقل من ٢ ميجابايت.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتب اسم الكاهن.');
      return;
    }
    setState(() => _busy = true);
    try {
      final preferences = widget.preferences;
      final photo = _photo;
      final saved =
          widget.priestName != null ||
          await preferences.setString(PriestProfile.nameKey, name);
      final photoSaved = photo == null
          ? await preferences.remove(widget.photoKey)
          : await preferences.setString(widget.photoKey, photo);
      if (!saved || !photoSaved) throw StateError('Profile save failed');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر حفظ البيانات.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('بيانات الكاهن'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(_photo == null ? null : base64Decode(_photo!)),
          TextButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('اختيار صورة'),
          ),
          TextField(
            controller: _name,
            readOnly: widget.priestName != null,
            decoration: const InputDecoration(labelText: 'اسم الكاهن'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _busy ? null : _save, child: const Text('حفظ')),
    ],
  );
}
