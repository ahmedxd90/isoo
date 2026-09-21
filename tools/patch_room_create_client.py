from pathlib import Path
p=Path('lib/core/data/saki_service.dart')
s=p.read_text()
start=s.index('  Future<Map<String, dynamic>> createRoom({')
end=s.index('\n  Future<', start+20)
block=s[start:end]
block=block.replace("        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');", "        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');\n        r.headers.set('X-Access-Token', apiToken!);")
old="""        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
"""
new="""        final response = await r.close();
        final raw = await response.transform(utf8.decoder).join();
        late final dynamic d;
        try {
          d = jsonDecode(raw);
        } on FormatException catch (error) {
          throw StateError('api[room_create] invalid_json: $error body=$raw');
        }
        if (response.statusCode >= 400 || d['ok'] != true) {
          if (response.statusCode >= 400) {
            throw StateError(
              'api[room_create] http=${response.statusCode} '
              '${d['error'] ?? raw}',
            );
          }
"""
if old not in block: raise SystemExit('client room block not found')
block=block.replace(old,new,1)
p.write_text(s[:start]+block+s[end:])
