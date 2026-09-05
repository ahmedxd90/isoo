from pathlib import Path

path = Path('/home/ubuntu/work/repo/lib/features/rooms/rooms_page.dart')
text = path.read_text()
start = text.index('class CreateRoomSheet')
new = r'''class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final _name = TextEditingController();
  final _description = TextEditingController(text: 'مرحبا بكم في غرفتي!');
  final _picker = ImagePicker();
  XFile? _image;
  String _country = 'جاري التحديد...';
  String _type = 'public';
  String _category = 'Cp';
  bool _loading = false;
  String? _error;

  static const _categories = ['Cp', 'شعر وموسيقى', 'حفلة', 'سينما', 'ألعاب', 'مسابقات'];

  @override
  void initState() {
    super.initState();
    _loadCountry();
  }

  Future<void> _loadCountry() async {
    try {
      final country = await SakiService.instance.myCountry();
      if (mounted) setState(() => _country = country);
    } catch (_) {
      if (mounted) setState(() => _country = 'الأردن');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (image != null && mounted) setState(() => _image = image);
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم الغرفة');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final room = await SakiService.instance.createRoom(
        name: _name.text,
        description: _description.text,
        country: _country == 'جاري التحديد...' ? 'الأردن' : _country,
        type: _type,
        image: _image,
      );
      if (mounted) Navigator.of(context).pop(room);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white60)),
    border: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
    filled: false,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1534880606858-29b0e8a24e8d?q=80&w=1000&auto=format&fit=crop',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          Container(color: const Color.fromRGBO(15, 10, 5, .78)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 52),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    _glassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                TextField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _input('الرجاء إدخال اسم الغرفة')),
                                const SizedBox(height: 8),
                                TextField(controller: _description, style: const TextStyle(color: Colors.white70, fontSize: 13), decoration: _input('وصف الغرفة'), maxLines: 1),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: _pickImage,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 82,
                                height: 82,
                                child: _image == null
                                    ? Container(color: Colors.white10, child: const Icon(Icons.add_a_photo_outlined, color: Colors.white70, size: 28))
                                    : Image.file(File(_image!.path), fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('فئة الغرفة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categories.map((item) {
                        final selected = item == _category;
                        return GestureDetector(
                          onTap: () => setState(() => _category = item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: selected ? const Color(0xFFFED100) : Colors.transparent),
                            ),
                            child: Text(item, style: TextStyle(color: selected ? const Color(0xFFFED100) : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _glassCard(
                      child: Row(
                        children: [
                          const Text('دولة الغرفة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
                            child: Row(children: [const Text('🌍', style: TextStyle(fontSize: 18)), const SizedBox(width: 7), Text(_country, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('نوع الغرفة', style: TextStyle(color: Colors.white70)),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _type,
                          dropdownColor: const Color(0xFF292929),
                          underline: const SizedBox.shrink(),
                          style: const TextStyle(color: Colors.white),
                          items: const [DropdownMenuItem(value: 'public', child: Text('عامة')), DropdownMenuItem(value: 'private', child: Text('خاصة'))],
                          onChanged: (value) => setState(() => _type = value ?? 'public'),
                        ),
                      ],
                    ),
                    if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))),
                    const Spacer(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _create,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFED100), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 10),
                        child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text('إنشاء غرفة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color.fromRGBO(30, 30, 30, .68), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
    child: child,
  );
}
'''
path.write_text(text[:start] + new)
print('Replaced CreateRoomSheet with full-screen CreateRoomPage')
