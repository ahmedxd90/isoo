from pathlib import Path
p = Path('/home/ubuntu/isoo/lib/features/profile/store_pages.dart')
s = p.read_text()
s = s.replace("  String _category = 'frame';\n  late Future", "  String _category = 'frame';\n  bool _isAdmin = false;\n  late Future", 1)
s = s.replace("  void initState() {\n    super.initState();\n    _reload();\n  }\n\n  void _reload()", "  void initState() {\n    super.initState();\n    _reload();\n    SakiService.instance.isCurrentUserSuperAdmin().then((value) {\n      if (mounted) setState(() => _isAdmin = value);\n    });\n  }\n\n  void _reload()", 1)
needle = "      actions: [\n        Container("
replacement = "      actions: [\n        if (_isAdmin)\n          IconButton(\n            tooltip: 'إضافة منتج',\n            icon: const Icon(Icons.add_business_rounded, color: _storeInk),\n            onPressed: () => Navigator.push(\n              context,\n              MaterialPageRoute(builder: (_) => const AdminStorePage()),\n            ),\n          ),\n        Container("
s = s.replace(needle, replacement, 1)
needle = "              const SizedBox(width: 10),\n              Expanded(\n                child: _categoryTab(\n                  'entrance',\n                  Icons.auto_awesome_rounded,\n                  'الدخوليات',\n                ),\n              ),\n"
replacement = needle + "              const SizedBox(width: 10),\n              Expanded(\n                child: _categoryTab(\n                  'bubble',\n                  Icons.chat_bubble_rounded,\n                  'فقاعات',\n                ),\n              ),\n"
if needle not in s:
    raise SystemExit('tabs needle not found')
s = s.replace(needle, replacement, 1)
p.write_text(s)
