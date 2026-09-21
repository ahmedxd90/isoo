from pathlib import Path
p = Path('lib/core/data/saki_service.dart')
s = p.read_text()
start = s.index('Future<List<Map<String, dynamic>>> _apiList')
end = s.index('\n  Future<Map<String, dynamic>> _apiPost', start)
block = s[start:end]
block = block.replace(
    '      final d = jsonDecode(raw);',
    """      late final dynamic d;
      try {
        d = jsonDecode(raw);
      } on FormatException catch (error) {
        throw StateError('api[$action] invalid_json: $error body=$raw');
      }""",
    1,
)
block = block.replace(
    "      return List<Map<String, dynamic>>.from(d['data'] as List? ?? const []);",
    """      final data = d['data'];
      return data is List
          ? List<Map<String, dynamic>>.from(data)
          : <Map<String, dynamic>>[];""",
    1,
)
s = s[:start] + block + s[end:]
p.write_text(s)
