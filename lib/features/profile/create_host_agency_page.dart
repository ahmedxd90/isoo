import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

class CreateHostAgencyPage extends StatefulWidget {
  const CreateHostAgencyPage({super.key});
  @override
  State<CreateHostAgencyPage> createState() => _CreateHostAgencyPageState();
}

class _CreateHostAgencyPageState extends State<CreateHostAgencyPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _country = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final agency = await SakiService.instance.adminCreateHostAgency(
        name: _name.text.trim(),
        ownerSakiId: int.parse(_owner.text.trim()),
        country: _country.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم إنشاء الوكالة'),
          content: Text(
            'تم إنشاء ${agency['name']}\nكود الوكالة: ${agency['agent_code']}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('موافق'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إضافة وكالة مضيفين')),
    backgroundColor: const Color(0xFFF8FAFC),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'إنشاء وكالة جديدة\nسيتم تعيين المستخدم مالكًا للوكالة وإضافته تلقائيًا كمدير للوكالة.',
              style: TextStyle(height: 1.6, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          _field(
            _name,
            'اسم الوكالة',
            Icons.business_rounded,
            (v) => v == null || v.trim().isEmpty ? 'أدخل اسم الوكالة' : null,
          ),
          const SizedBox(height: 12),
          _field(
            _owner,
            'SAKI ID مالك الوكالة',
            Icons.person_pin_rounded,
            (v) => int.tryParse(v?.trim() ?? '') == null
                ? 'أدخل SAKI ID صحيحًا'
                : null,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _field(
            _country,
            'دولة الوكالة',
            Icons.public_rounded,
            (v) => v == null || v.trim().isEmpty ? 'أدخل الدولة' : null,
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_business_rounded),
              label: Text(_saving ? 'جارٍ الإنشاء...' : 'إنشاء الوكالة'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
    String? Function(String?) validator, {
    TextInputType? keyboard,
  }) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    ),
  );
}
