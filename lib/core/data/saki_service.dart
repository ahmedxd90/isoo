import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SakiAuthUser {
  const SakiAuthUser({
    required this.id,
    this.email,
    this.userMetadata = const {},
  });
  final String id;
  final String? email;
  final Map<String, dynamic> userMetadata;
}

class SakiService {
  SakiService._();
  static final instance = SakiService._();
  static const apiBaseUrl = 'https://sakichat.freecpanel.shop/api.php';
  String? apiToken;
  String? apiUserId;
  Map<String, dynamic>? _profileCache;

  Future<List<Map<String, dynamic>>> _apiList(
    String action, {
    Map<String, String> query = const {},
  }) async {
    if (apiToken == null) throw StateError('unauthorized');
    final uri = Uri.parse('$apiBaseUrl?action=$action&access_token=$apiToken')
        .replace(
          queryParameters: {
            'action': action,
            'access_token': apiToken!,
            ...query,
          },
        );
    final c = HttpClient();
    try {
      final r = await c.getUrl(uri);
      r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
      r.headers.set('X-Access-Token', apiToken!);
      final response = await r.close();
      final raw = await response.transform(utf8.decoder).join();
      late final dynamic d;
      try {
        d = jsonDecode(raw);
      } on FormatException catch (error) {
        throw StateError('api[$action] invalid_json: $error body=$raw');
      }
      if (response.statusCode >= 400 || d['ok'] != true) {
        throw StateError(
          'api[$action] http=${response.statusCode} '
          '${d['error'] ?? raw}',
        );
      }
      final data = d['data'];
      return data is List
          ? List<Map<String, dynamic>>.from(data)
          : <Map<String, dynamic>>[];
    } finally {
      c.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _apiPost(
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (apiToken == null) throw StateError('unauthorized');
    final c = HttpClient();
    try {
      final r = await c.postUrl(
        Uri.parse('$apiBaseUrl?action=$action&access_token=$apiToken'),
      );
      r.headers.contentType = ContentType.json;
      r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
      r.headers.set('X-Access-Token', apiToken!);
      r.write(jsonEncode(payload));
      final d = jsonDecode(
        await (await r.close()).transform(utf8.decoder).join(),
      );
      if (d['ok'] != true) {
        throw StateError(d['error']?.toString() ?? 'api_failed');
      }
      return Map<String, dynamic>.from(d['data'] as Map? ?? const {});
    } finally {
      c.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _apiMap(
    String action, {
    Map<String, String> query = const {},
  }) async {
    if (apiToken == null) throw StateError('unauthorized');
    final uri = Uri.parse('$apiBaseUrl?action=$action&access_token=$apiToken')
        .replace(
          queryParameters: {
            'action': action,
            'access_token': apiToken!,
            ...query,
          },
        );
    final c = HttpClient();
    try {
      final r = await c.getUrl(uri);
      r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
      r.headers.set('X-Access-Token', apiToken!);
      final response = await r.close();
      final raw = await response.transform(utf8.decoder).join();
      final d = jsonDecode(raw);
      if (response.statusCode >= 400 || d['ok'] != true) {
        throw StateError(
          'api[$action] http=${response.statusCode} '
          '${d['error'] ?? raw}',
        );
      }
      final data = d['data'];
      return data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
    } on FormatException catch (error) {
      throw StateError('api[$action] invalid_json: $error');
    } finally {
      c.close(force: true);
    }
  }

  Future<void> restoreApiSession() async {
    final prefs = await SharedPreferences.getInstance();
    apiToken = prefs.getString('saki_api_token');
    apiUserId = prefs.getString('saki_api_user_id');
    if (apiToken == null) return;
    try {
      final profile = await myProfile();
      if (profile == null) {
        apiToken = null;
        apiUserId = null;
        await prefs.remove('saki_api_token');
        await prefs.remove('saki_api_user_id');
      }
    } catch (_) {
      apiToken = null;
      apiUserId = null;
      await prefs.remove('saki_api_token');
      await prefs.remove('saki_api_user_id');
    }
  }

  Future<String> _uploadApi(XFile file, String kind) async {
    final c = HttpClient();
    try {
      final boundary = '----saki${DateTime.now().microsecondsSinceEpoch}';
      final r = await c.postUrl(
        Uri.parse('$apiBaseUrl?action=upload_asset&access_token=$apiToken'),
      );
      r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
      r.headers.set('X-Access-Token', apiToken ?? '');
      r.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      final bytes = await file.readAsBytes();
      var name = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      if (!name.contains('.')) {
        name = '$name.${kind == 'reels' ? 'mp4' : 'jpg'}';
      }
      r.write(
        '--$boundary\r\nContent-Disposition: form-data; name="kind"\r\n\r\n$kind\r\n',
      );
      r.write(
        '--$boundary\r\nContent-Disposition: form-data; name="file"; filename="$name"\r\nContent-Type: application/octet-stream\r\n\r\n',
      );
      r.add(bytes);
      r.write('\r\n--$boundary--\r\n');
      final response = await r.close();
      final raw = await response.transform(utf8.decoder).join();
      final d = jsonDecode(raw);
      if (d['ok'] != true) {
        throw StateError(d['error']?.toString() ?? 'upload_failed ($raw)');
      }
      return d['data']['url'].toString();
    } finally {
      c.close(force: true);
    }
  }

  SakiAuthUser? get currentUser => apiUserId == null
      ? null
      : SakiAuthUser(
          id: apiUserId!,
          email: _profileCache?['email']?.toString(),
          userMetadata: _profileCache ?? const {},
        );
  String get uid => apiUserId ?? (throw StateError('unauthorized'));

  String? familyAliasValidationMessage(String alias) {
    final value = alias.trim();
    if (value.length < 5) {
      return 'لقب العائلة يجب أن يتكون من 5 أحرف أو أرقام على الأقل.';
    }
    if (!RegExp(r'^[A-Za-z0-9_\u0600-\u06FF]+$').hasMatch(value)) {
      return 'لقب العائلة يسمح بالأحرف والأرقام والشرطة السفلية فقط، دون مسافات أو رموز.';
    }
    return null;
  }

  Future<Map<String, dynamic>?> myProfile() async {
    if (apiToken != null) {
      final httpClient = HttpClient();
      try {
        final request = await httpClient.getUrl(
          Uri.parse('$apiBaseUrl?action=me&access_token=$apiToken'),
        );
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $apiToken',
        );
        request.headers.set('X-Access-Token', apiToken!);
        final response = await request.close();
        final decoded = jsonDecode(
          await response.transform(utf8.decoder).join(),
        );
        if (response.statusCode >= 400 || decoded['ok'] != true) {
          throw StateError(
            'api[me] http=${response.statusCode} '
            '${decoded['error'] ?? decoded}',
          );
        }
        final profile = Map<String, dynamic>.from(decoded['data'] as Map);
        _profileCache = profile;
        return profile;
      } finally {
        httpClient.close(force: true);
      }
    }
    final data = await client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return data;
  }

  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(
        Uri.parse('$apiBaseUrl?action=google_login'),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({'action': 'google_login', 'id_token': idToken}),
      );
      final response = await request.close();
      final decoded = jsonDecode(await response.transform(utf8.decoder).join());
      if (response.statusCode >= 400 || decoded['ok'] != true) {
        throw StateError(decoded['error']?.toString() ?? 'google_login_failed');
      }
      apiToken = decoded['token']?.toString();
      final prefs = await SharedPreferences.getInstance();
      if (apiToken != null) await prefs.setString('saki_api_token', apiToken!);
      final profile = Map<String, dynamic>.from(decoded['data'] as Map);
      _profileCache = profile;
      apiUserId = profile['id']?.toString();
      if (apiUserId != null) {
        await prefs.setString('saki_api_user_id', apiUserId!);
      }
      return profile;
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final c = HttpClient();
    try {
      final r = await c.postUrl(Uri.parse('$apiBaseUrl?action=register'));
      r.headers.contentType = ContentType.json;
      r.write(
        jsonEncode({
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
        }),
      );
      final d = jsonDecode(
        await (await r.close()).transform(utf8.decoder).join(),
      );
      if (d['ok'] != true) {
        throw StateError(d['error']?.toString() ?? 'register_failed');
      }
      return Map<String, dynamic>.from(d['data'] as Map);
    } finally {
      c.close(force: true);
    }
  }

  Future<void> logout() async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(Uri.parse('$apiBaseUrl?action=logout'));
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        await r.close();
      } finally {
        c.close(force: true);
      }
      apiToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saki_api_token');
    }
    await client.auth.signOut();
  }

  Future<List<Map<String, dynamic>>> userBadges(String userId) async {
    if (apiToken != null) {
      return _apiList('user_badges', query: {'user_id': userId});
    }
    final rows = await client.rpc(
      'user_badges_for_profile',
      params: {'p_user_id': userId},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> userTasksSnapshot() async {
    final rows = await client.rpc('user_tasks_snapshot');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> claimDailyLogin() async {
    final rows = await client.rpc('claim_user_daily_login');
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? const {} : list.first;
  }

  Future<Map<String, dynamic>> dailyLoginStatus() async {
    final rows = await client.rpc('user_daily_login_status');
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? const {'claimed': true} : list.first;
  }

  Future<Map<String, dynamic>> recordUserTask(
    String taskKey, {
    int increment = 1,
  }) async {
    final rows = await client.rpc(
      'record_user_task_event',
      params: {'p_task_key': taskKey, 'p_increment': increment},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? const {} : list.first;
  }

  Future<bool> isSuperAdmin() async {
    if (apiToken != null) {
      final profile = await myProfile();
      return profile?['is_super_admin'] == true ||
          profile?['is_super_admin']?.toString() == '1';
    }
    final result = await client.rpc('is_saki_super_admin');
    return result == true;
  }

  Future<Map<String, dynamic>> adminAccess() async {
    final result = await client.rpc('admin_my_access');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> adminAuditLog({int limit = 100}) async {
    final rows = await client.rpc(
      'admin_list_audit_log',
      params: {'p_limit': limit},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> adminDashboard() async {
    final result = await client.rpc('saki_admin_dashboard');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> adminFamilies() async {
    final rows = await client
        .from('trace_families')
        .select('id,name,invite_code,status,created_at,owner_id')
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> adminLevels() async {
    final rows = await client
        .from('trace_level_rewards')
        .select('id,level,title,description,reward_type,reward_value')
        .order('level')
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> adminSetFamilyStatus(String id, String status) async {
    await client.rpc(
      'admin_set_family_status',
      params: {'p_family_id': id, 'p_status': status},
    );
  }

  Future<Map<String, dynamic>> startPkBattle(
    String roomId,
    String channelName,
  ) async {
    final row = await client.rpc(
      'start_pk_battle',
      params: {
        'p_room_id': roomId,
        'p_channel_name': channelName,
        'p_duration_seconds': 300,
      },
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Future<Map<String, dynamic>> acceptPkBattle(String battleId) async {
    final row = await client.rpc(
      'accept_pk_battle',
      params: {'p_battle_id': battleId},
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Future<Map<String, dynamic>> addPkPoints(String battleId, int points) async {
    final row = await client.rpc(
      'add_pk_points',
      params: {'p_battle_id': battleId, 'p_points': points},
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Future<Map<String, dynamic>> finishPkBattle(String battleId) async {
    final row = await client.rpc(
      'finish_pk_battle',
      params: {'p_battle_id': battleId},
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Stream<List<Map<String, dynamic>>> pkBattlesStream(String roomId) => client
      .from('pk_battles')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: false)
      .limit(1);

  Future<List<Map<String, dynamic>>> wealthRanking() async {
    final rows = await client
        .from('saki_account_modules')
        .select('user_id,gold_coins,profiles(username,avatar_url,vip_level)')
        .order('gold_coins', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> roomRanking() async {
    final rows = await client
        .from('rooms')
        .select('id,name,room_id,image_url,room_members(count)')
        .eq('is_active', true)
        .limit(50);
    final result = List<Map<String, dynamic>>.from(rows);
    int count(Map<String, dynamic> row) {
      final members = row['room_members'];
      if (members is List && members.isNotEmpty && members.first is Map) {
        return (members.first['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    }

    result.sort((a, b) => count(b).compareTo(count(a)));
    return result;
  }

  Future<List<Map<String, dynamic>>> globalWealthRanking(String period) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=global_rank&period=$period&mode=wealth&access_token=$apiToken',
          ),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final rows = await client.rpc(
      'global_gift_user_leaderboard',
      params: {'p_period': period, 'p_mode': 'wealth'},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> globalRoomRanking(String period) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=global_rank&period=$period&mode=room&access_token=$apiToken',
          ),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final rows = await client.rpc(
      'global_gift_room_leaderboard',
      params: {'p_period': period},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>?> activeAppBan() async {
    final profile = await client
        .from('profiles')
        .select('is_super_admin')
        .eq('id', uid)
        .maybeSingle();
    if (profile?['is_super_admin'] == true) return null;
    return client
        .from('app_bans')
        .select('expires_at,reason')
        .eq('user_id', uid)
        .maybeSingle();
  }

  Future<void> adminAddGold(int sakiId, int amount) async {
    await client.rpc(
      'admin_add_gold',
      params: {'p_saki_id': sakiId, 'p_amount': amount},
    );
  }

  Future<void> adminSetVip(int sakiId, int level, int days) async {
    await client.rpc(
      'admin_set_vip',
      params: {'p_saki_id': sakiId, 'p_level': level, 'p_days': days},
    );
  }

  Future<void> adminBanApp(
    int sakiId,
    Duration? duration,
    String reason,
  ) async {
    await client.rpc(
      'admin_ban_app',
      params: {
        'p_saki_id': sakiId,
        'p_duration': duration?.inSeconds == null
            ? null
            : '${duration!.inSeconds} seconds',
        'p_reason': reason,
      },
    );
  }

  Future<void> adminSetSakiId(String userId, int newId) async {
    await client.rpc(
      'admin_set_saki_id',
      params: {'p_user_id': userId, 'p_new_id': newId},
    );
  }

  Future<void> adminUpdateUserSakiId(String userId, int newId) async {
    await client.rpc(
      'admin_update_user_profile',
      params: {'p_user_id': userId, 'p_new_saki_id': newId},
    );
  }

  Future<void> adminSetUserRole(String userId, String role) async {
    await client.rpc(
      'admin_set_user_role',
      params: {'p_user_id': userId, 'p_role': role},
    );
  }

  Future<List<Map<String, dynamic>>> adminUsers(String query) async {
    final rows = await client.rpc(
      'admin_list_users',
      params: {
        'p_query': query.isEmpty ? null : query,
        'p_limit': 50,
        'p_offset': 0,
      },
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> adminGiftCatalog() async {
    final rows = await client
        .from('room_gift_catalog')
        .select()
        .order('sort_order')
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String> adminUploadGift(XFile file) async {
    if (apiToken != null) return _uploadApi(file, 'gifts');
    final bytes = await File(file.path).readAsBytes();
    final extension = file.path.split('.').last.toLowerCase();
    final path =
        '$uid/admin-gift-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final contentType = switch (extension) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'mp4' => 'video/mp4',
      'svga' => 'application/octet-stream',
      _ => 'application/octet-stream',
    };
    await client.storage
        .from('rooms')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return client.storage.from('rooms').getPublicUrl(path);
  }

  Future<String> adminUploadRoomEmoji(XFile file) async {
    if (apiToken != null) return _uploadApi(file, 'emojis');
    final bytes = await File(file.path).readAsBytes();
    final extension = file.path.split('.').last.toLowerCase();
    final path =
        '$uid/room-emoji-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage
        .from('rooms')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/gif',
          ),
        );
    return client.storage.from('rooms').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> roomEmojis({bool admin = false}) async {
    final rows = admin
        ? await client
              .from('room_emojis')
              .select()
              .order('created_at', ascending: false)
        : await client
              .from('room_emojis')
              .select()
              .eq('is_active', true)
              .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> adminCreateRoomEmoji({
    required String name,
    required String gifUrl,
  }) async {
    await client.from('room_emojis').insert({
      'name': name.trim(),
      'gif_url': gifUrl,
    });
  }

  Future<void> adminUpdateRoomEmoji(
    String id, {
    required String name,
    String? gifUrl,
    bool? active,
  }) async {
    final updates = <String, dynamic>{'name': name.trim()};
    if (gifUrl != null) updates['gif_url'] = gifUrl;
    if (active != null) updates['is_active'] = active;
    await client.from('room_emojis').update(updates).eq('id', id);
  }

  Future<void> adminDeleteRoomEmoji(String id) async {
    await client.from('room_emojis').delete().eq('id', id);
  }

  Stream<List<Map<String, dynamic>>> roomEmojiEventsStream(String roomId) =>
      client
          .from('room_emoji_events')
          .stream(primaryKey: ['id'])
          .eq('room_id', roomId)
          .order('created_at');

  Future<void> sendRoomEmoji(String roomId, String emojiId) async {
    await client.from('room_emoji_events').insert({
      'room_id': roomId,
      'user_id': uid,
      'emoji_id': emojiId,
    });
  }

  Future<String> adminUploadStoreFile(XFile file) async {
    if (apiToken != null) return _uploadApi(file, 'store');
    final bytes = await File(file.path).readAsBytes();
    final extension = file.path.split('.').last.toLowerCase();
    final path =
        '$uid/store-${DateTime.now().microsecondsSinceEpoch}.$extension';
    final contentType = switch (extension) {
      'mp4' => 'video/mp4',
      'gif' => 'image/gif',
      'svga' => 'application/octet-stream',
      _ => 'image/png',
    };
    await client.storage
        .from('store')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return client.storage.from('store').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> storeProducts({String? category}) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final suffix = category == null
            ? ''
            : '&category=${Uri.encodeQueryComponent(category)}';
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=store_products$suffix&access_token=$apiToken',
          ),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final rows = category == null
        ? await client
              .from('saki_store_products')
              .select()
              .eq('is_active', true)
        : await client
              .from('saki_store_products')
              .select()
              .eq('is_active', true)
              .eq('category', category);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> adminStoreProducts() async {
    final rows = await client
        .from('saki_store_products')
        .select()
        .order('created_at', ascending: false)
        .limit(300);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> adminCreateStoreProduct({
    required String category,
    required String name,
    required int price,
    int durationDays = 7,
    double discountPercent = 0,
    required String mediaType,
    required String mediaUrl,
    required String thumbnailUrl,
  }) async {
    await client.from('saki_store_products').insert({
      'category': category,
      'name': name.trim(),
      'price': price,
      'duration_days': 7,
      'discount_percent': discountPercent,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
    });
  }

  Future<List<Map<String, dynamic>>> storeInventory() async {
    final rows = await client
        .from('saki_store_inventory')
        .select(
          'quantity,equipped,purchased_at,expires_at,product:saki_store_products(*)',
        )
        .eq('user_id', uid)
        .order('purchased_at', ascending: false)
        .limit(300);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> activeProfileFrame(String userId) async {
    final rows = await client
        .from('saki_store_inventory')
        .select(
          'expires_at,product:saki_store_products!inner(id,category,media_type,media_url,thumbnail_url)',
        )
        .eq('user_id', userId)
        .eq('equipped', true)
        .eq('product.category', 'frame')
        .limit(1);
    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first);
    final expiresAt = DateTime.tryParse(row['expires_at']?.toString() ?? '');
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) return null;
    final product = row['product'];
    return product is Map ? Map<String, dynamic>.from(product) : null;
  }

  Future<Map<String, dynamic>> storeBuy(String productId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=store_buy&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'product_id': productId}));
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
          throw StateError(d['error']?.toString() ?? 'store_buy_failed');
        }
        return Map<String, dynamic>.from(d['data'] as Map? ?? {});
      } finally {
        c.close(force: true);
      }
    }
    final rows = await client.rpc(
      'saki_store_buy',
      params: {'p_product_id': productId},
    );
    return Map<String, dynamic>.from((rows as List).first);
  }

  Future<void> storeEquip(String productId, bool equipped) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=store_equip&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(
          jsonEncode({
            'product_id': productId,
            'equipped': equipped,
            'category': 'frame',
          }),
        );
        if ((await r.close()).statusCode >= 400) {
          throw StateError('store_equip_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    await client.rpc(
      'saki_store_equip',
      params: {'p_product_id': productId, 'p_equipped': equipped},
    );
  }

  Future<Map<String, dynamic>?> equippedEntrance(String userId) async {
    final row = await client
        .from('saki_store_inventory')
        .select('product:saki_store_products(*)')
        .eq('user_id', userId)
        .eq('equipped', true)
        .limit(20);
    for (final item in List<Map<String, dynamic>>.from(row)) {
      final product = Map<String, dynamic>.from(item['product'] ?? const {});
      if (product['category'] == 'entrance') return product;
    }
    return null;
  }

  Future<Map<String, dynamic>?> equippedEntranceInRoom(
    String roomId,
    String userId,
  ) async {
    final result = await client.rpc(
      'saki_get_equipped_entrance',
      params: {'p_room_id': roomId, 'p_user_id': userId},
    );
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> claimEntrance(
    String roomId,
    String productId,
    String playToken,
  ) async {
    await client.rpc(
      'saki_store_claim_entrance',
      params: {
        'p_room_id': roomId,
        'p_product_id': productId,
        'p_play_token': playToken,
      },
    );
  }

  Future<void> claimEquippedEntranceOnJoin(String roomId) async {
    final product = await equippedEntrance(uid);
    if (product == null) return;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    final playToken =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await claimEntrance(roomId, product['id'] as String, playToken);
  }

  Future<void> adminCreateGift({
    required String name,
    required String icon,
    required String category,
    required int price,
    String? mediaUrl,
    String mediaType = 'emoji',
  }) async {
    await client.from('room_gift_catalog').insert({
      'name': name,
      'icon': icon,
      'category': category,
      'price': price,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'sort_order': 99,
      'is_active': true,
    });
  }

  Future<void> adminUpdateGift(String id, Map<String, dynamic> values) async =>
      client.from('room_gift_catalog').update(values).eq('id', id);
  Future<void> adminDeleteGift(String id) async {
    await client.rpc('admin_delete_room_gift', params: {'p_gift_id': id});
  }

  Future<List<Map<String, dynamic>>> adminRooms() async {
    final rows = await client
        .from('rooms')
        .select('id,room_id,name,owner_id,is_official,is_pinned,pin_priority')
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> adminSetRoomId(
    String roomId,
    String newRoomId,
    bool official,
  ) async {
    await client.rpc(
      'admin_set_room_id',
      params: {
        'p_room_id': roomId,
        'p_new_room_id': newRoomId,
        'p_official': official,
      },
    );
  }

  Future<void> adminSetRoomPresentation(
    String roomId, {
    required bool official,
    required bool pinned,
    required int priority,
  }) async {
    await client.rpc(
      'admin_set_room_presentation',
      params: {
        'p_room_id': roomId,
        'p_official': official,
        'p_pinned': pinned,
        'p_pin_priority': priority,
      },
    );
  }

  Stream<List<Map<String, dynamic>>> giftAnnouncementsStream() {
    if (apiToken != null) {
      return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
        final c = HttpClient();
        try {
          final r = await c.getUrl(
            Uri.parse('$apiBaseUrl?action=global_gifts&access_token=$apiToken'),
          );
          final d = jsonDecode(
            await (await r.close()).transform(utf8.decoder).join(),
          );
          return List<Map<String, dynamic>>.from(d['data'] as List);
        } finally {
          c.close(force: true);
        }
      });
    }
    return client
        .from('gift_announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(20);
  }

  Future<String> myCountry() async {
    final profile = await myProfile();
    final country = (profile?['country'] as String?)?.trim();
    return country == null || country.isEmpty ? 'الأردن' : country;
  }

  Future<List<Map<String, dynamic>>> countries() async {
    if (apiToken != null) {
      final httpClient = HttpClient();
      try {
        final request = await httpClient.getUrl(
          Uri.parse('$apiBaseUrl?action=countries'),
        );
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $apiToken',
        );
        final response = await request.close();
        final decoded = jsonDecode(
          await response.transform(utf8.decoder).join(),
        );
        if (response.statusCode >= 400) {
          throw StateError('countries_api_failed');
        }
        return List<Map<String, dynamic>>.from(decoded['data'] as List);
      } finally {
        httpClient.close(force: true);
      }
    }
    final rows = await client
        .from('countries')
        .select('code,name_ar,flag')
        .order('name_ar')
        .limit(250);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> completeProfile({
    required String username,
    required String country,
    required String gender,
    XFile? avatar,
  }) async {
    if (apiToken != null) {
      final httpClient = HttpClient();
      try {
        String? avatarUrl;
        if (avatar != null) {
          final bytes = await File(avatar.path).readAsBytes();
          final boundary = 'saki_${DateTime.now().microsecondsSinceEpoch}';
          final upload = await httpClient.postUrl(
            Uri.parse(
              '$apiBaseUrl?action=avatar_upload&access_token=$apiToken',
            ),
          );
          upload.headers.set(
            HttpHeaders.authorizationHeader,
            'Bearer $apiToken',
          );
          upload.headers.contentType = ContentType(
            'multipart',
            'form-data',
            parameters: {'boundary': boundary},
          );
          upload.write(
            '--$boundary\r\nContent-Disposition: form-data; name="avatar"; filename="avatar.jpg"\r\nContent-Type: image/jpeg\r\n\r\n',
          );
          upload.add(bytes);
          upload.write('\r\n--$boundary--\r\n');
          final uploadResponse = await upload.close();
          final uploadData = jsonDecode(
            await uploadResponse.transform(utf8.decoder).join(),
          );
          if (uploadResponse.statusCode >= 400 || uploadData['ok'] != true) {
            throw StateError('avatar_upload_failed');
          }
          avatarUrl = uploadData['data']['avatar_url']?.toString();
        }
        final request = await httpClient.postUrl(
          Uri.parse(
            '$apiBaseUrl?action=profile_complete&access_token=$apiToken',
          ),
        );
        request.headers.contentType = ContentType.json;
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $apiToken',
        );
        final payload = <String, dynamic>{
          'username': username.trim(),
          'country': country,
          'gender': gender,
        };
        if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
        request.write(jsonEncode(payload));
        final response = await request.close();
        final decoded = jsonDecode(
          await response.transform(utf8.decoder).join(),
        );
        if (response.statusCode >= 400 || decoded['ok'] != true) {
          throw StateError(
            decoded['error']?.toString() ?? 'profile_complete_failed',
          );
        }
        return;
      } finally {
        httpClient.close(force: true);
      }
    }
    String? avatarUrl;
    if (avatar != null) {
      final bytes = await File(avatar.path).readAsBytes();
      final extension = avatar.path.split('.').last.toLowerCase();
      final path =
          '$uid/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$extension',
            ),
          );
      avatarUrl = client.storage.from('avatars').getPublicUrl(path);
    }
    final updates = <String, dynamic>{
      'username': username.trim(),
      'display_name': username.trim(),
      'country': country,
      'gender': gender,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    await client.from('profiles').update(updates).eq('id', uid);
  }

  Future<Map<String, dynamic>?> myOwnedRoom() async {
    if (apiToken != null) {
      final rows = await _apiList('room_owned');
      return rows.isEmpty ? null : rows.first;
    }
    throw StateError('unauthorized');
  }

  Future<Map<String, dynamic>> startLiveBroadcast({
    required String roomId,
    required String channelName,
    required String title,
  }) async {
    final row = await client.rpc(
      'start_live_broadcast',
      params: {
        'p_room_id': roomId,
        'p_channel_name': channelName,
        'p_title': title,
      },
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Future<void> endLiveBroadcast(String channelName) async {
    await client.rpc(
      'end_live_broadcast',
      params: {'p_channel_name': channelName},
    );
  }

  Future<List<Map<String, dynamic>>> liveBroadcasts() async {
    final rows = await client
        .from('live_broadcasts')
        .select(
          'id,room_id,host_id,channel_name,title,avatar_url,status,started_at,rooms:room_id(id,room_id,owner_id,name,description,country,room_type,image_url,background_url,seat_count,is_active)',
        )
        .eq('status', 'live')
        .order('started_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> feed({bool followingOnly = false}) async {
    if (apiToken != null) {
      final httpClient = HttpClient();
      try {
        final request = await httpClient.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=posts_feed&limit=40&access_token=$apiToken',
          ),
        );
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $apiToken',
        );
        request.headers.set('X-Access-Token', apiToken!);
        final response = await request.close();
        final decoded = jsonDecode(
          await response.transform(utf8.decoder).join(),
        );
        if (response.statusCode >= 400 || decoded['ok'] != true) {
          throw StateError(
            'api[posts_feed] http=${response.statusCode} '
            '${decoded['error'] ?? decoded}',
          );
        }
        return List<Map<String, dynamic>>.from(decoded['data'] as List);
      } finally {
        httpClient.close(force: true);
      }
    }
    final selection =
        'id,author_id,content,visibility,created_at,profiles:author_id(id,username,display_name,saki_id,avatar_url,vip_level,vip_expires_at,wealth_level),post_media(id,storage_path,sort_order),post_likes(user_id),post_comments(id),post_shares(user_id)';
    final data = followingOnly
        ? await _followingPosts(selection)
        : await client
              .from('posts')
              .select(selection)
              .order('created_at', ascending: false)
              .limit(40);
    return List<Map<String, dynamic>>.from(data).map((post) {
      final likes = List<Map<String, dynamic>>.from(
        post['post_likes'] ?? const [],
      );
      final comments = List<Map<String, dynamic>>.from(
        post['post_comments'] ?? const [],
      );
      final shares = List<Map<String, dynamic>>.from(
        post['post_shares'] ?? const [],
      );
      final media =
          List<Map<String, dynamic>>.from(post['post_media'] ?? const [])..sort(
            (a, b) => (a['sort_order'] as int? ?? 0).compareTo(
              b['sort_order'] as int? ?? 0,
            ),
          );
      return {
        ...post,
        '_liked': likes.any((like) => like['user_id'] == uid),
        '_likes_count': likes.length,
        '_comments_count': comments.length,
        '_shares_count': shares.length,
        '_media': media,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _followingPosts(String selection) async {
    final follows = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', uid);
    final ids = List<Map<String, dynamic>>.from(follows)
        .map((row) => row['following_id'] as String)
        .toList();
    if (ids.isEmpty) return [];
    return List<Map<String, dynamic>>.from(
      await client
          .from('posts')
          .select(selection)
          .inFilter('author_id', ids)
          .order('created_at', ascending: false)
          .limit(40),
    );
  }

  Future<void> createPost({
    required String content,
    required List<XFile> images,
    required String visibility,
  }) async {
    if (apiToken != null) {
      final media = <String>[];
      for (final image in images.take(10)) {
        media.add(await _uploadApi(image, 'posts'));
      }
      final httpClient = HttpClient();
      try {
        final request = await httpClient.postUrl(
          Uri.parse('$apiBaseUrl?action=post_create&access_token=$apiToken'),
        );
        request.headers.contentType = ContentType.json;
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $apiToken',
        );
        request.headers.set('X-Access-Token', apiToken!);
        request.write(
          jsonEncode({
            'content': content.trim(),
            'visibility': visibility,
            'media': media,
          }),
        );
        final response = await request.close();
        final raw = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(raw);
        if (response.statusCode >= 400 || decoded['ok'] != true) {
          throw StateError(
            decoded['error']?.toString() ?? 'post_create_failed',
          );
        }
        return;
      } finally {
        httpClient.close(force: true);
      }
    }
    final post = await client
        .from('posts')
        .insert({
          'author_id': uid,
          'content': content.trim().isEmpty ? null : content.trim(),
          'visibility': visibility,
        })
        .select('id')
        .single();
    final postId = post['id'] as String;
    for (var i = 0; i < images.length && i < 10; i++) {
      final file = File(images[i].path);
      final bytes = await file.readAsBytes();
      final extension = images[i].path.split('.').last.toLowerCase();
      final path = '$uid/$postId/$i.$extension';
      await client.storage
          .from('posts')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$extension',
            ),
          );
      await client.from('post_media').insert({
        'post_id': postId,
        'storage_path': path,
        'sort_order': i,
      });
    }
  }

  Future<void> togglePostLike(String postId, bool liked) async {
    if (apiToken != null) {
      final httpClient = HttpClient();
      try {
        final request = await httpClient.postUrl(
          Uri.parse('$apiBaseUrl?action=post_like_toggle'),
        );
        request.headers.contentType = ContentType.json;
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $apiToken',
        );
        request.write(jsonEncode({'post_id': postId}));
        final response = await request.close();
        if (response.statusCode >= 400) throw StateError('post_like_failed');
        return;
      } finally {
        httpClient.close(force: true);
      }
    }
    if (liked) {
      await client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    } else {
      await client.from('post_likes').insert({
        'post_id': postId,
        'user_id': uid,
      });
    }
  }

  Future<List<Map<String, dynamic>>> comments(String postId) async {
    if (apiToken != null) {
      final httpClient = HttpClient();
      try {
        final request = await httpClient.getUrl(
          Uri.parse('$apiBaseUrl?action=post_comments&post_id=$postId'),
        );
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $apiToken',
        );
        final response = await request.close();
        final decoded = jsonDecode(
          await response.transform(utf8.decoder).join(),
        );
        if (response.statusCode >= 400) throw StateError('comments_api_failed');
        return List<Map<String, dynamic>>.from(decoded['data'] as List);
      } finally {
        httpClient.close(force: true);
      }
    }
    final data = await client
        .from('post_comments')
        .select(
          'id,content,created_at,user_id,profiles:user_id(username,avatar_url,vip_level,vip_expires_at)',
        )
        .eq('post_id', postId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  String postMediaUrl(String storagePath) => storagePath.startsWith('http')
      ? storagePath
      : client.storage.from('posts').getPublicUrl(storagePath);

  Future<void> addComment(String postId, String content) async {
    if (apiToken != null) {
      final httpClient = HttpClient();
      try {
        final request = await httpClient.postUrl(
          Uri.parse('$apiBaseUrl?action=post_comment_create'),
        );
        request.headers.contentType = ContentType.json;
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $apiToken',
        );
        request.write(
          jsonEncode({'post_id': postId, 'content': content.trim()}),
        );
        final response = await request.close();
        if (response.statusCode >= 400) {
          throw StateError('comment_create_failed');
        }
        return;
      } finally {
        httpClient.close(force: true);
      }
    }
    await client.from('post_comments').insert({
      'post_id': postId,
      'user_id': uid,
      'content': content.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> reels({bool followingOnly = false}) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse('$apiBaseUrl?action=reels_feed&access_token=$apiToken'),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final selection =
        'id,author_id,video_url,description,visibility,created_at,profiles:author_id(username,avatar_url,saki_id,vip_level,vip_expires_at,wealth_level),reel_likes(user_id),reel_comments(id)';
    final data = followingOnly
        ? await _followingReels(selection)
        : await client
              .from('reels')
              .select(selection)
              .order('created_at', ascending: false)
              .limit(30);
    return List<Map<String, dynamic>>.from(data).map((reel) {
      final likes = List<Map<String, dynamic>>.from(
        reel['reel_likes'] ?? const [],
      );
      return {
        ...reel,
        '_liked': likes.any((like) => like['user_id'] == uid),
        '_likes_count': likes.length,
        '_comments_count': List<Map<String, dynamic>>.from(
          reel['reel_comments'] ?? const [],
        ).length,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _followingReels(String selection) async {
    final follows = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', uid);
    final ids = List<Map<String, dynamic>>.from(follows)
        .map((row) => row['following_id'] as String)
        .toList();
    if (ids.isEmpty) return [];
    return List<Map<String, dynamic>>.from(
      await client
          .from('reels')
          .select(selection)
          .inFilter('author_id', ids)
          .order('created_at', ascending: false)
          .limit(30),
    );
  }

  Future<void> createReel({
    required XFile video,
    required String description,
    required String visibility,
  }) async {
    if (apiToken != null) {
      final url = await _uploadApi(video, 'reels');
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=reel_create&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.headers.set('X-Access-Token', apiToken ?? '');
        r.write(
          jsonEncode({
            'video_url': url,
            'description': description.trim(),
            'visibility': visibility,
          }),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
          throw StateError(d['error']?.toString() ?? 'reel_create_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = await File(video.path).readAsBytes();
    final extension = video.path.split('.').last.toLowerCase();
    final path = '$uid/$id.$extension';
    await client.storage
        .from('reels')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'video/$extension',
          ),
        );
    final url = client.storage.from('reels').getPublicUrl(path);
    await client.from('reels').insert({
      'author_id': uid,
      'video_url': url,
      'video_path': path,
      'description': description.trim(),
      'visibility': visibility,
    });
  }

  Future<void> toggleReelLike(String reelId, bool liked) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse(
            '$apiBaseUrl?action=reel_like_toggle&access_token=$apiToken',
          ),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'reel_id': reelId}));
        if ((await r.close()).statusCode >= 400) {
          throw StateError('reel_like_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    if (liked) {
      await client
          .from('reel_likes')
          .delete()
          .eq('reel_id', reelId)
          .eq('user_id', uid);
    } else {
      await client.from('reel_likes').insert({
        'reel_id': reelId,
        'user_id': uid,
      });
    }
  }

  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final term = query.trim();
    if (term.isEmpty) return [];
    final sakiId = int.tryParse(term);
    final filters =
        'username.ilike.%$term%,display_name.ilike.%$term%${sakiId == null ? '' : ',saki_id.eq.$sakiId'}';
    final data = await client
        .from('profiles')
        .select(
          'id,username,display_name,saki_id,avatar_url,bio,country,gender',
        )
        .or(filters)
        .neq('id', uid)
        .limit(30);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>?> userProfile(String userId) async {
    if (apiToken != null) {
      final rows = await _apiList('user_profile', query: {'user_id': userId});
      return rows.isEmpty ? null : rows.first;
    }
    final data = await client
        .from('profiles')
        .select(
          'id,username,display_name,saki_id,avatar_url,bio,country,country_code,gender,created_at,vip_level,vip_expires_at,wealth_xp,wealth_level,is_super_admin,admin_role',
        )
        .eq('id', userId)
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> familyBadgeForUser(String userId) async {
    if (apiToken != null) return null;
    final rows = await client
        .from('family_members')
        .select(
          'role,families:family_id(id,name,family_alias,level,avatar_url)',
        )
        .eq('user_id', userId)
        .eq('status', 'active')
        .limit(1);
    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first);
    final family = row['families'];
    if (family is! Map) return null;
    return {
      ...Map<String, dynamic>.from(family),
      'role': row['role']?.toString() ?? 'member',
    };
  }

  Future<bool> isCurrentUserSuperAdmin() async {
    final row = await client
        .from('profiles')
        .select('is_super_admin')
        .eq('id', uid)
        .maybeSingle();
    return row?['is_super_admin'] == true;
  }

  Future<Map<String, int>> userProfileStats(String userId) async {
    if (apiToken != null) {
      final rows = await _apiList(
        'user_profile_stats',
        query: {'user_id': userId},
      );
      if (rows.isEmpty) return {'posts': 0, 'followers': 0, 'following': 0};
      return rows.first.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      );
    }
    final followers = await client
        .from('follows')
        .select('follower_id')
        .eq('following_id', userId);
    final following = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    final posts = await client
        .from('posts')
        .select('id')
        .eq('author_id', userId);
    return {
      'followers': List<Map<String, dynamic>>.from(followers).length,
      'following': List<Map<String, dynamic>>.from(following).length,
      'posts': List<Map<String, dynamic>>.from(posts).length,
    };
  }

  Future<List<Map<String, dynamic>>> conversations() async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse('$apiBaseUrl?action=conversations&access_token=$apiToken'),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final memberships = await client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', uid);
    final ids = List<Map<String, dynamic>>.from(memberships)
        .map((row) => row['conversation_id'] as String)
        .toList();
    if (ids.isEmpty) return [];
    final data = await client
        .from('conversations')
        .select(
          'id,created_at,conversation_members(user_id,profiles:user_id(id,username,display_name,avatar_url,saki_id,vip_level,vip_expires_at,wealth_level))',
        )
        .inFilter('id', ids)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String> createConversation(String otherUserId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse(
            '$apiBaseUrl?action=conversation_create&access_token=$apiToken',
          ),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.headers.set('X-Access-Token', apiToken!);
        r.write(jsonEncode({'user_id': otherUserId}));
        final response = await r.close();
        final raw = await response.transform(utf8.decoder).join();
        late final dynamic d;
        try {
          d = jsonDecode(raw);
        } on FormatException catch (error) {
          throw StateError(
            'api[conversation_create] invalid_json: $error body=$raw',
          );
        }
        if (response.statusCode >= 400) {
          throw StateError(
            'api[conversation_create] http=${response.statusCode} '
            '${d['error'] ?? raw}',
          );
        }
        if (d['ok'] != true) {
          throw StateError(
            d['error']?.toString() ?? 'conversation_create_failed',
          );
        }
        return d['data']['id'].toString();
      } finally {
        c.close(force: true);
      }
    }
    try {
      final result = await client.rpc(
        'create_private_conversation',
        params: {'p_other_user_id': otherUserId},
      );
      if (result is String && result.isNotEmpty) return result;
      if (result is Map && result['id'] is String) {
        return result['id'] as String;
      }
      if (result is List && result.isNotEmpty && result.first is Map) {
        final row = Map<String, dynamic>.from(result.first as Map);
        if (row['id'] is String) return row['id'] as String;
      }
      throw Exception('invalid_conversation_response:${result.runtimeType}');
    } on PostgrestException catch (error) {
      throw Exception('${error.code ?? 'rpc_error'}:${error.message}');
    }
  }

  Future<List<Map<String, dynamic>>> followers() async {
    final rows = await client
        .from('follows')
        .select(
          'follower_id,created_at,profiles:follower_id(id,username,display_name,avatar_url,saki_id,vip_level,vip_expires_at)',
        )
        .eq('following_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    final followingRows = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', uid);
    final followingIds = List<Map<String, dynamic>>.from(followingRows)
        .map((row) => row['following_id']?.toString())
        .whereType<String>()
        .toSet();
    return List<Map<String, dynamic>>.from(rows)
        .map(
          (row) => {
            ...row,
            '_following': followingIds.contains(row['follower_id']),
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> socialNotifications() async {
    final rows = await client
        .from('notifications')
        .select(
          '*,profiles:actor_id(id,username,display_name,avatar_url,saki_id,vip_level,vip_expires_at)',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    const systemTypes = {
      'system',
      'announcement',
      'daily_login',
      'coin_purchase',
      'vip_purchase',
      'wealth_upgrade',
      'level_upgrade',
      'reward',
      'entrance_purchase',
      'frame_purchase',
      'room_kick',
      'room_ban',
    };
    return List<Map<String, dynamic>>.from(rows)
        .where((row) => !systemTypes.contains(row['type']?.toString()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> systemNotifications() async {
    final rows = await client
        .from('notifications')
        .select(
          '*,profiles:actor_id(id,username,display_name,avatar_url,saki_id,vip_level,vip_expires_at)',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(200);
    const socialTypes = {
      'follow',
      'friend_request',
      'like',
      'comment',
      'message',
      'social',
    };
    final result = List<Map<String, dynamic>>.from(rows)
        .where((row) => !socialTypes.contains(row['type']?.toString()))
        .toList();
    final badges = await userBadges(uid);
    var badgeIndex = 0;
    return result.map((row) {
      if (row['type']?.toString() == 'badge_earned' &&
          badgeIndex < badges.length) {
        return {...row, '_badge': badges[badgeIndex++]};
      }
      return row;
    }).toList();
  }

  Future<void> markNotificationsRead({String? type}) async {
    var query = client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid);
    if (type != null) query = query.eq('type', type);
    await query;
  }

  Future<bool> isUserBlocked(String userId) async {
    final row = await client
        .from('user_blocks')
        .select('blocker_id')
        .eq('blocker_id', uid)
        .eq('blocked_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<bool> isBlockedByUser(String userId) async {
    final row = await client
        .from('user_blocks')
        .select('blocker_id')
        .eq('blocker_id', userId)
        .eq('blocked_id', uid)
        .maybeSingle();
    return row != null;
  }

  Future<void> blockUser(String userId) async {
    await client.from('user_blocks').upsert({
      'blocker_id': uid,
      'blocked_id': userId,
    });
  }

  Future<void> unblockUser(String userId) async {
    await client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', userId);
  }

  Future<List<Map<String, dynamic>>> blockedUsers() async {
    final rows = await client
        .from('user_blocks')
        .select('blocked_id,profiles:blocked_id(id,username,avatar_url)')
        .eq('blocker_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> deleteOwnChatMessages() async {
    await client.from('messages').delete().eq('sender_id', uid);
  }

  Future<void> reportUser(
    String userId,
    String category, {
    String? details,
    String? roomId,
    String? evidenceUrl,
  }) async {
    await client.from('user_reports').insert({
      'reporter_id': uid,
      'reported_id': userId,
      'category': category,
      'details': details?.trim(),
      'room_id': roomId,
      'evidence_url': evidenceUrl,
    });
  }

  Future<String> uploadReportEvidence(XFile video) async {
    final bytes = await File(video.path).readAsBytes();
    final extension = video.path.split('.').last.toLowerCase();
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await client.storage
        .from('report_evidence')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: extension == 'mov'
                ? 'video/quicktime'
                : 'video/$extension',
          ),
        );
    return client.storage.from('report_evidence').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> adminReports() async {
    final rows = await client
        .from('user_reports')
        .select(
          '*,reporter:reporter_id(id,username,avatar_url),reported:reported_id(id,username,avatar_url)',
        )
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> adminUpdateReportStatus(String id, String status) async {
    await client.from('user_reports').update({'status': status}).eq('id', id);
  }

  Future<String?> conversationPeerId(String conversationId) async {
    final rows = await client
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', conversationId)
        .neq('user_id', uid)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['user_id'] as String?;
  }

  Future<String> uploadChatImage(XFile image) async {
    final bytes = await File(image.path).readAsBytes();
    final extension = image.path.split('.').last.toLowerCase();
    final path =
        '$uid/chat/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$extension',
          ),
        );
    return client.storage.from('avatars').getPublicUrl(path);
  }

  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    if (apiToken != null) {
      return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
        final c = HttpClient();
        try {
          final r = await c.getUrl(
            Uri.parse(
              '$apiBaseUrl?action=messages&conversation_id=$conversationId&access_token=$apiToken',
            ),
          );
          final d = jsonDecode(
            await (await r.close()).transform(utf8.decoder).join(),
          );
          return List<Map<String, dynamic>>.from(d['data'] as List);
        } finally {
          c.close(force: true);
        }
      });
    }
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at');
  }

  Stream<List<Map<String, dynamic>>> messageReactionsStream(
    String conversationId,
  ) {
    return client
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at');
  }

  Future<void> reactToMessage({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=message_react&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(
          jsonEncode({
            'message_id': messageId,
            'conversation_id': conversationId,
            'emoji': emoji,
          }),
        );
        if ((await r.close()).statusCode >= 400) {
          throw StateError('message_react_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    await client.from('message_reactions').upsert({
      'message_id': messageId,
      'conversation_id': conversationId,
      'user_id': uid,
      'emoji': emoji,
    }, onConflict: 'message_id,user_id');
  }

  Stream<List<Map<String, dynamic>>> inboxMessagesStream() {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at');
  }

  Future<void> sendMessage(
    String conversationId,
    String body, {
    String messageType = 'text',
    String? mediaUrl,
    String? mediaName,
  }) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=message_send&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(
          jsonEncode({
            'conversation_id': conversationId,
            'body': body.trim(),
            'message_type': messageType,
            'media_url': mediaUrl,
            'media_name': mediaName,
          }),
        );
        if ((await r.close()).statusCode >= 400) {
          throw StateError('message_send_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    await client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'body': body.trim(),
      'message_type': messageType,
      'media_url': mediaUrl,
      'media_name': mediaName,
    });
    await client
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }

  Future<List<Map<String, dynamic>>> rooms() async {
    if (apiToken != null) {
      return _apiList('rooms_feed');
    }
    final data = await client.rpc('get_trending_rooms');
    return List<Map<String, dynamic>>.from(data).map((room) {
      final owner = <String, dynamic>{
        'username': room['owner_username'],
        'avatar_url': room['owner_avatar_url'],
        'vip_level': room['owner_vip_level'],
        'vip_expires_at': room['owner_vip_expires_at'],
      };
      return {
        ...room,
        'profiles': owner,
        '_members_count': (room['member_count'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  Future<Set<String>> followedRoomIds() async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse('$apiBaseUrl?action=room_followed&access_token=$apiToken'),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return Set<String>.from((d['data'] as List).map((e) => e.toString()));
      } finally {
        c.close(force: true);
      }
    }
    final rows = await client
        .from('room_follows')
        .select('room_id')
        .eq('user_id', uid)
        .limit(500);
    return rows
        .map<String>((row) => (row['room_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> joinRoom(String roomId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=room_join&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'room_id': roomId}));
        final response = await r.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode >= 400) {
          throw StateError(
            'room_join_failed http=${response.statusCode} ${responseBody.trim()}',
          );
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    await client.rpc('enter_room', params: {'p_room_id': roomId});
  }

  Future<bool> isRoomBanned(String roomId) async {
    if (apiToken != null) {
      final rows = await _apiList('room_ban_check', query: {'room_id': roomId});
      return rows.isNotEmpty && rows.first['banned'] == true;
    }
    final row = await client
        .from('room_bans')
        .select('expires_at')
        .eq('room_id', roomId)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return false;
    final expiresAt = DateTime.tryParse(row['expires_at']?.toString() ?? '');
    return expiresAt == null || expiresAt.isAfter(DateTime.now().toUtc());
  }

  Stream<List<Map<String, dynamic>>> roomBanStream(String roomId) {
    if (apiToken != null) {
      return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
        final banned = await isRoomBanned(roomId);
        return banned
            ? <Map<String, dynamic>>[
                {'room_id': roomId},
              ]
            : const [];
      });
    }
    return client
        .from('room_bans')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('room_id', roomId)
        .eq('user_id', uid);
  }

  Future<void> touchRoomPresence(String roomId) async {
    if (apiToken != null) {
      await _apiPost('room_presence', {'room_id': roomId});
      return;
    }
    await client.rpc('touch_room_presence', params: {'p_room_id': roomId});
  }

  Future<void> leaveRoom(String roomId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=room_leave&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'room_id': roomId}));
        if ((await r.close()).statusCode >= 400) {
          throw StateError('room_leave_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    try {
      await client.rpc('leave_room', params: {'p_room_id': roomId});
      return;
    } catch (_) {
      // Keep a direct fallback for installations that have not applied the migration yet.
    }
    Object? memberError;
    Object? seatError;
    try {
      await client
          .from('room_members')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', uid);
    } catch (error) {
      memberError = error;
    }
    try {
      await client
          .from('room_seats')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', uid);
    } catch (error) {
      seatError = error;
    }
    if (memberError != null) throw memberError;
    if (seatError != null) throw seatError;
  }

  Future<List<Map<String, dynamic>>> roomSeats(String roomId) async {
    if (apiToken != null) {
      return _apiList('room_seats', query: {'room_id': roomId});
    }
    final data = await client
        .from('room_seats')
        .select(
          'seat_no,user_id,joined_at,is_speaking,profiles:user_id(id,username,avatar_url)',
        )
        .eq('room_id', roomId)
        .order('seat_no');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> roomMembers(String roomId) async {
    if (apiToken != null) {
      final rows = await _apiList('room_members', query: {'room_id': roomId});
      return rows;
    }
    final rows = await client
        .from('room_members')
        .select(
          'user_id,joined_at,profiles:user_id(id,username,avatar_url,vip_level,vip_expires_at)',
        )
        .eq('room_id', roomId)
        .gte(
          'last_seen',
          DateTime.now()
              .toUtc()
              .subtract(const Duration(seconds: 75))
              .toIso8601String(),
        )
        .order('joined_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows)
        .map((row) => Map<String, dynamic>.from(row['profiles'] ?? {}))
        .where((profile) => profile['id'] != null)
        .toList();
  }

  Future<RoomGiftRankingResult> roomGiftRanking(
    String roomId,
    String period,
  ) async {
    final now = DateTime.now().toUtc();
    final days = period == 'شهري'
        ? 30
        : period == 'أسبوعي'
        ? 7
        : 1;
    final since = now.subtract(Duration(days: days)).toIso8601String();
    final rows = await client
        .from('room_gifts')
        .select(
          'sender_id,total_price,created_at,profiles:sender_id(id,username,avatar_url,vip_level,vip_expires_at)',
        )
        .eq('room_id', roomId)
        .gte('created_at', since)
        .limit(1000);
    final grouped = <String, Map<String, dynamic>>{};
    for (final raw in List<Map<String, dynamic>>.from(rows)) {
      final profile = Map<String, dynamic>.from(raw['profiles'] ?? {});
      final id = raw['sender_id']?.toString();
      if (id == null || id.isEmpty) continue;
      final item = grouped.putIfAbsent(
        id,
        () => {'gold': 0, 'profile': profile},
      );
      item['gold'] =
          (item['gold'] as int) + ((raw['total_price'] as num?)?.toInt() ?? 0);
    }
    final result = grouped.values.toList()
      ..sort((a, b) => (b['gold'] as int).compareTo(a['gold'] as int));
    return RoomGiftRankingResult(
      result,
      result.fold<int>(0, (sum, row) => sum + (row['gold'] as int)),
    );
  }

  Stream<List<Map<String, dynamic>>> roomMembersStream(String roomId) {
    if (apiToken != null) {
      return Stream.periodic(const Duration(seconds: 3))
          .asyncMap((_) => roomMembers(roomId));
    }
    return client
        .from('room_members')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('room_id', roomId)
        .order('joined_at', ascending: false)
        .asyncMap((rows) async {
          final result = <Map<String, dynamic>>[];
          final cutoff = DateTime.now().toUtc().subtract(
            const Duration(seconds: 75),
          );
          for (final row in rows) {
            final lastSeen = DateTime.tryParse(
              row['last_seen']?.toString() ?? '',
            );
            if (lastSeen == null || lastSeen.isBefore(cutoff)) continue;
            final profile = await userProfile(row['user_id'] as String);
            if (profile != null) result.add(profile);
          }
          return result;
        });
  }

  Future<void> claimRoomSeat(String roomId, int seatNo) async {
    if (apiToken != null) {
      await _apiPost('seat_claim', {'room_id': roomId, 'seat_no': seatNo});
      return;
    }
    await client.rpc(
      'claim_room_seat',
      params: {'p_room_id': roomId, 'p_seat_no': seatNo},
    );
  }

  Future<void> leaveRoomSeat(String roomId) async {
    if (apiToken != null) {
      await _apiPost('seat_leave', {'room_id': roomId});
      return;
    }
    await client.rpc('leave_room_seat', params: {'p_room_id': roomId});
  }

  Stream<List<Map<String, dynamic>>> roomMessagesStream(
    String roomId, {
    DateTime? after,
  }) {
    if (apiToken != null) {
      return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
        final c = HttpClient();
        try {
          final r = await c.getUrl(
            Uri.parse(
              '$apiBaseUrl?action=room_messages&room_id=$roomId&access_token=$apiToken',
            ),
          );
          final d = jsonDecode(
            await (await r.close()).transform(utf8.decoder).join(),
          );
          return List<Map<String, dynamic>>.from(d['data'] as List);
        } finally {
          c.close(force: true);
        }
      });
    }
    return client
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .gte(
          'created_at',
          (after ?? DateTime.fromMillisecondsSinceEpoch(0))
              .toUtc()
              .toIso8601String(),
        )
        .order('created_at')
        .asyncMap((rows) async {
          final result = <Map<String, dynamic>>[];
          for (final row in rows) {
            final copy = Map<String, dynamic>.from(row);
            copy['profiles'] = await userProfile(row['sender_id'] as String);
            result.add(copy);
          }
          return result;
        });
  }

  Stream<List<Map<String, dynamic>>> roomSeatsStream(String roomId) {
    if (apiToken != null) {
      return Stream.periodic(const Duration(seconds: 2))
          .asyncMap((_) => roomSeats(roomId));
    }
    return client
        .from('room_seats')
        .stream(primaryKey: ['room_id', 'seat_no'])
        .eq('room_id', roomId)
        .order('seat_no')
        .asyncMap((rows) async {
          if (rows.isEmpty) return <Map<String, dynamic>>[];
          final userIds = rows
              .map((row) => row['user_id']?.toString())
              .whereType<String>()
              .toSet()
              .toList();
          final profilesFuture = client
              .from('profiles')
              .select(
                'id,username,display_name,saki_id,avatar_url,bio,country,country_code,gender,created_at,vip_level,vip_expires_at,wealth_xp,wealth_level,is_super_admin',
              )
              .inFilter('id', userIds);
          final inventoryFuture = client
              .from('saki_store_inventory')
              .select(
                'user_id,expires_at,product:saki_store_products(category,media_type,media_url,thumbnail_url)',
              )
              .inFilter('user_id', userIds)
              .eq('equipped', true)
              .limit(100);
          final loaded = await Future.wait<dynamic>([
            profilesFuture,
            inventoryFuture,
          ]);
          final profiles = <String, Map<String, dynamic>>{
            for (final profile in List<Map<String, dynamic>>.from(loaded[0]))
              profile['id'].toString(): Map<String, dynamic>.from(profile),
          };
          final frames = <String, Map<String, dynamic>>{};
          for (final item in List<Map<String, dynamic>>.from(loaded[1])) {
            final product = item['product'];
            final expiry = DateTime.tryParse(
              item['expires_at']?.toString() ?? '',
            );
            final userId = item['user_id']?.toString();
            if (userId != null &&
                product is Map &&
                product['category']?.toString() == 'frame' &&
                (expiry == null || expiry.isAfter(DateTime.now()))) {
              frames[userId] = {
                'active_frame_url':
                    (product['media_url'] ?? product['thumbnail_url'])
                        ?.toString() ??
                    '',
                'active_frame_media_type': product['media_type']?.toString(),
              };
            }
          }
          return rows.map((row) {
            final copy = Map<String, dynamic>.from(row);
            final userId = row['user_id']?.toString();
            final profile = userId == null ? null : profiles[userId];
            if (profile != null &&
                frames[userId]?['active_frame_url']?.toString().isNotEmpty ==
                    true) {
              profile.addAll(frames[userId]!);
            }
            copy['profiles'] = profile;
            return copy;
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> roomSettingsStream(String roomId) =>
      client.from('rooms').stream(primaryKey: ['id']).eq('id', roomId).limit(1);

  Stream<List<Map<String, dynamic>>> roomCinemaStateStream(String roomId) =>
      client
          .from('room_cinema_state')
          .stream(primaryKey: ['room_id'])
          .eq('room_id', roomId)
          .limit(1);

  Future<Map<String, dynamic>?> roomCinemaState(String roomId) async {
    final row = await client
        .from('room_cinema_state')
        .select()
        .eq('room_id', roomId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> setRoomCinemaState(
    String roomId, {
    required String videoId,
    required String videoTitle,
    required bool isPlaying,
    required double positionSeconds,
    required double volume,
  }) async {
    final row = await client.rpc(
      'set_room_cinema_state',
      params: {
        'p_room_id': roomId,
        'p_video_id': videoId,
        'p_video_title': videoTitle,
        'p_is_playing': isPlaying,
        'p_position_seconds': positionSeconds,
        'p_volume': volume,
      },
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Future<List<Map<String, dynamic>>> searchYouTube(String query) async {
    final response = await client.functions.invoke(
      'youtube-search',
      body: {'query': query.trim(), 'maxResults': 8},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return List<Map<String, dynamic>>.from(data['items'] ?? const []);
  }

  Future<Map<String, dynamic>> zegoRoomToken(
    String roomId, {
    String? userName,
  }) async {
    final data = await _apiMap(
      'zego_token',
      query: {
        'room_id': roomId.trim(),
        if (userName != null && userName.trim().isNotEmpty)
          'user_name': userName.trim(),
      },
    );
    if (data['token'] == null || data['appId'] == null) {
      throw StateError(
        data['error']?.toString() ?? 'تعذر إنشاء توكن ZEGOCLOUD',
      );
    }
    return data;
  }

  Future<void> sendRoomMessage(
    String roomId,
    String body, {
    String type = 'chat',
    Map<String, dynamic> payload = const {},
  }) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse(
            '$apiBaseUrl?action=room_message_send&access_token=$apiToken',
          ),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(
          jsonEncode({
            'room_id': roomId,
            'body': body,
            'type': type,
            'payload': payload,
          }),
        );
        if ((await r.close()).statusCode >= 400) {
          throw StateError('room_message_send_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    final mute = await client
        .from('room_mutes')
        .select('expires_at,mute_chat')
        .eq('room_id', roomId)
        .eq('user_id', uid)
        .maybeSingle();
    if (mute != null && mute['mute_chat'] != false) {
      final expires = mute['expires_at'] == null
          ? null
          : DateTime.tryParse(mute['expires_at'].toString());
      if (expires == null || expires.isAfter(DateTime.now())) {
        throw Exception('تم كتمك في هذه الغرفة');
      }
    }
    await client.from('room_messages').insert({
      'room_id': roomId,
      'sender_id': uid,
      'body': body,
      'message_type': type,
      'payload': payload,
    });
  }

  Future<void> clearRoomMessages(String roomId) async {
    await client.rpc('clear_room_messages', params: {'p_room_id': roomId});
  }

  Future<List<Map<String, dynamic>>> roomMusic(String roomId) async {
    final rows = await client
        .from('room_music')
        .select(
          'id,room_id,owner_id,title,artist,cover_url,audio_url,duration_seconds,storage_path,created_at',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> roomPlaylist(String roomId) async {
    final rows = await client
        .from('room_playlist')
        .select(
          'id,room_id,track_id,added_by,position,created_at,room_music(*)',
        )
        .eq('room_id', roomId)
        .order('position')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addRoomPlaylistTrack(String roomId, String trackId) async {
    await client.from('room_playlist').upsert({
      'room_id': roomId,
      'track_id': trackId,
      'added_by': uid,
    }, onConflict: 'room_id,track_id');
  }

  Future<void> removeRoomPlaylistTrack(String playlistId) async {
    await client.from('room_playlist').delete().eq('id', playlistId);
  }

  Future<Map<String, dynamic>> uploadRoomMusic(
    String roomId,
    String title,
    List<int> bytes,
    String extension,
    String contentType,
  ) async {
    final safeExtension = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$safeExtension';
    await client.storage
        .from('room_music')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    final url = client.storage.from('room_music').getPublicUrl(path);
    final row = await client
        .from('room_music')
        .insert({
          'room_id': null,
          'owner_id': uid,
          'title': title,
          'artist': 'SAKI Creator',
          'storage_path': path,
          'audio_url': url,
        })
        .select(
          'id,room_id,owner_id,title,artist,cover_url,audio_url,duration_seconds,storage_path,created_at',
        )
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> activeRoomMusic(String roomId) async {
    final row = await client
        .from('room_music_state')
        .select(
          'room_id,music_id,owner_id,is_playing,position_seconds,volume,started_at,repeat_mode,shuffle_mode,updated_at,room_music(*)',
        )
        .eq('room_id', roomId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Stream<List<Map<String, dynamic>>> roomMusicStateStream(String roomId) =>
      client
          .from('room_music_state')
          .stream(primaryKey: ['room_id'])
          .eq('room_id', roomId);

  Future<void> setActiveRoomMusic(
    String roomId, {
    String? musicId,
    String? ownerId,
    required bool isPlaying,
    double positionSeconds = 0,
    double volume = 1,
    DateTime? startedAt,
    String repeatMode = 'off',
    bool shuffleMode = false,
  }) async {
    await client.rpc(
      'set_room_music_state',
      params: {
        'p_room_id': roomId,
        'p_music_id': musicId,
        'p_owner_id': ownerId,
        'p_is_playing': isPlaying,
        'p_position_seconds': positionSeconds,
        'p_volume': volume,
        'p_started_at': startedAt?.toUtc().toIso8601String(),
        'p_repeat_mode': repeatMode,
        'p_shuffle_mode': shuffleMode,
      },
    );
  }

  Future<bool> isRoomModerator(String roomId) async {
    final row = await client
        .from('room_moderators')
        .select('user_id')
        .eq('room_id', roomId)
        .eq('user_id', uid)
        .maybeSingle();
    return row != null;
  }

  Future<bool> isUserRoomModerator(String roomId, String userId) async {
    final row = await client
        .from('room_moderators')
        .select('user_id')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<bool> isFollowingRoom(String roomId) async {
    final row = await client
        .from('room_follows')
        .select('room_id')
        .eq('room_id', roomId)
        .eq('user_id', uid)
        .maybeSingle();
    return row != null;
  }

  Future<void> toggleRoomFollow(String roomId, bool followed) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse(
            '$apiBaseUrl?action=room_follow_toggle&access_token=$apiToken',
          ),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'room_id': roomId}));
        if ((await r.close()).statusCode >= 400) {
          throw StateError('room_follow_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    if (followed) {
      await client
          .from('room_follows')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', uid);
    } else {
      await client.from('room_follows').insert({
        'room_id': roomId,
        'user_id': uid,
      });
    }
  }

  Future<void> setRoomSpeaking(String roomId, bool speaking) async {
    await client
        .from('room_seats')
        .update({'is_speaking': speaking})
        .eq('room_id', roomId)
        .eq('user_id', uid);
  }

  Future<void> addRoomModerator(String roomId, String userId) async {
    await client.from('room_moderators').upsert({
      'room_id': roomId,
      'user_id': userId,
      'created_by': uid,
    });
    await recordRoomActivity(roomId, 'moderator_added', targetUserId: userId);
  }

  Future<void> removeRoomModerator(String roomId, String userId) async {
    await client
        .from('room_moderators')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', userId);
    await recordRoomActivity(roomId, 'moderator_removed', targetUserId: userId);
  }

  Future<void> roomBan(String roomId, String userId, Duration? duration) async {
    final expiresAt = duration == null
        ? null
        : DateTime.now().toUtc().add(duration).toIso8601String();
    await client.rpc(
      'saki_room_ban_and_remove',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_expires_at': expiresAt,
      },
    );
  }

  Future<List<Map<String, dynamic>>> roomBansForOwner(String roomId) async {
    final rows = await client
        .from('room_bans')
        .select(
          'user_id,expires_at,created_at,profiles:user_id(id,username,avatar_url,saki_id)',
        )
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> removeRoomBan(String roomId, String userId) async {
    await client
        .from('room_bans')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', userId);
    await recordRoomActivity(roomId, 'user_unbanned', targetUserId: userId);
  }

  Future<void> updateRoomSettings(
    String roomId, {
    int? seatCount,
    String? imageUrl,
    String? backgroundUrl,
    String? name,
    String? announcement,
    String? category,
    String? themeKey,
    int? membershipFee,
    double? rewardRate,
    String? micPermission,
  }) async {
    final values = <String, dynamic>{};
    if (seatCount != null) values['seat_count'] = seatCount;
    if (imageUrl != null) values['image_url'] = imageUrl;
    if (backgroundUrl != null) values['background_url'] = backgroundUrl;
    if (name != null) values['name'] = name.trim();
    if (announcement != null) values['announcement'] = announcement.trim();
    if (category != null) values['category'] = category;
    if (themeKey != null) values['theme_key'] = themeKey;
    values['membership_fee'] = 0;
    values['reward_rate'] = 0;
    if (micPermission != null) values['mic_permission'] = micPermission;
    await client
        .from('rooms')
        .update(values)
        .eq('id', roomId)
        .eq('owner_id', uid);
  }

  Future<String> uploadRoomImage(String roomId, XFile image) async {
    final bytes = await File(image.path).readAsBytes();
    if (bytes.isEmpty) throw Exception('empty_image');
    final extension = image.path.split('.').last.toLowerCase();
    final safeExtension =
        const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
    final path =
        '$uid/$roomId-cover-${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    await client.storage
        .from('rooms')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$safeExtension',
          ),
        );
    return client.storage.from('rooms').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> roomModeratorsForOwner(
    String roomId,
  ) async {
    final rows = await client
        .from('room_moderators')
        .select(
          'user_id,created_at,profiles:user_id(id,username,avatar_url,saki_id,vip_level)',
        )
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> roomActivityLogs(String roomId) async {
    final rows = await client
        .from('room_activity_logs')
        .select(
          'id,action,target_user_id,metadata,created_at,profiles:actor_id(username,avatar_url)',
        )
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> recordRoomActivity(
    String roomId,
    String action, {
    String? targetUserId,
    Map<String, dynamic> metadata = const {},
  }) async {
    await client.from('room_activity_logs').insert({
      'room_id': roomId,
      'actor_id': uid,
      'action': action,
      'target_user_id': targetUserId,
      'metadata': metadata,
    });
  }

  Future<String> uploadRoomBackground(String roomId, XFile image) async {
    final bytes = await File(image.path).readAsBytes();
    final extension = image.path.split('.').last.toLowerCase();
    final contentType = extension == 'gif' ? 'image/gif' : 'image/$extension';
    final path =
        '$uid/$roomId-background-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await client.storage
        .from('rooms')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return client.storage.from('rooms').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> roomBackgrounds(String roomId) async {
    final rows = await client
        .from('room_backgrounds')
        .select('id,image_url,created_at')
        .eq('room_id', roomId)
        .eq('owner_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveRoomBackground(String roomId, String imageUrl) async {
    await client.from('room_backgrounds').insert({
      'room_id': roomId,
      'owner_id': uid,
      'image_url': imageUrl,
    });
  }

  Future<void> roomMute(
    String roomId,
    String userId,
    Duration? duration, {
    String kind = 'both',
  }) async {
    final current = await roomModerationStatus(roomId, userId);
    await client.from('room_mutes').upsert({
      'room_id': roomId,
      'user_id': userId,
      'muted_by': uid,
      'expires_at': duration == null
          ? null
          : DateTime.now().add(duration).toIso8601String(),
      'mute_voice': kind == 'voice' || kind == 'both'
          ? true
          : current['mute_voice'] == true,
      'mute_chat': kind == 'chat' || kind == 'both'
          ? true
          : current['mute_chat'] == true,
    });
    await client
        .from('room_seats')
        .update({'is_speaking': false})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<Map<String, dynamic>> roomModerationStatus(
    String roomId,
    String userId,
  ) async {
    final mute = await client
        .from('room_mutes')
        .select('mute_voice,mute_chat,expires_at')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    final ban = await client
        .from('room_bans')
        .select('expires_at')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    return {
      'mute_voice': mute?['mute_voice'] == true,
      'mute_chat': mute?['mute_chat'] == true,
      'banned': ban != null,
      'ban_expires_at': ban?['expires_at'],
    };
  }

  Future<void> roomUnmute(String roomId, String userId, String kind) async {
    final current = await roomModerationStatus(roomId, userId);
    final voice = kind == 'voice' ? false : current['mute_voice'] == true;
    final chat = kind == 'chat' ? false : current['mute_chat'] == true;
    if (!voice && !chat) {
      await client
          .from('room_mutes')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId);
    } else {
      await client
          .from('room_mutes')
          .update({'mute_voice': voice, 'mute_chat': chat})
          .eq('room_id', roomId)
          .eq('user_id', userId);
    }
  }

  Future<void> inviteToRoomSeat(String roomId, String userId) async {
    await client.from('room_seat_invites').insert({
      'room_id': roomId,
      'inviter_id': uid,
      'invitee_id': userId,
    });
  }

  Future<Map<String, dynamic>> createRoom({
    required String name,
    required String description,
    required String country,
    required String type,
    XFile? image,
  }) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=room_create&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.headers.set('X-Access-Token', apiToken!);
        r.write(
          jsonEncode({
            'name': name.trim(),
            'description': description.trim(),
            'country': country,
            'type': type,
          }),
        );
        final response = await r.close();
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
          throw StateError(d['error']?.toString() ?? 'room_create_failed');
        }
        return Map<String, dynamic>.from(d['data'] as Map);
      } finally {
        c.close(force: true);
      }
    }
    final owned = await myOwnedRoom();
    if (owned != null) {
      throw Exception('لديك غرفة منشأة مسبقاً.');
    }
    final inserted = await client
        .from('rooms')
        .insert({
          'owner_id': uid,
          'name': name.trim(),
          'description': description.trim(),
          'country': country,
          'room_type': type,
        })
        .select(
          'id,room_id,owner_id,name,description,country,room_type,image_url,is_active,created_at,profiles:owner_id(username,avatar_url,vip_level,vip_expires_at)',
        )
        .single();
    final roomId = inserted['id'] as String;
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      final extension = image.path.split('.').last.toLowerCase();
      final path = '$uid/$roomId.$extension';
      await client.storage
          .from('rooms')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$extension',
            ),
          );
      final url = client.storage.from('rooms').getPublicUrl(path);
      await client.from('rooms').update({'image_url': url}).eq('id', roomId);
    }
    await client.from('room_members').insert({
      'room_id': roomId,
      'user_id': uid,
    });
    final created = Map<String, dynamic>.from(inserted);
    created['_members_count'] = 1;
    return created;
  }

  Future<Map<String, int>> profileStats() async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse('$apiBaseUrl?action=profile_stats&access_token=$apiToken'),
        );
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.headers.set('X-Access-Token', apiToken!);
        final response = await r.close();
        final raw = await response.transform(utf8.decoder).join();
        final d = jsonDecode(raw);
        if (response.statusCode >= 400 || d['ok'] != true) {
          throw StateError(
            'api[profile_stats] http=${response.statusCode} '
            '${d['error'] ?? raw}',
          );
        }
        return Map<String, int>.from(
          (d['data'] as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ),
        );
      } finally {
        c.close(force: true);
      }
    }
    final posts = await client.from('posts').select('id').eq('author_id', uid);
    final followers = await client
        .from('follows')
        .select('follower_id')
        .eq('following_id', uid);
    final following = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', uid);
    return {
      'posts': List<Map<String, dynamic>>.from(posts).length,
      'followers': List<Map<String, dynamic>>.from(followers).length,
      'following': List<Map<String, dynamic>>.from(following).length,
    };
  }

  Future<void> updateProfile({
    required String username,
    required String bio,
    String? country,
    String? countryCode,
    XFile? avatar,
  }) async {
    if (apiToken != null) {
      final avatarUrl = avatar == null
          ? null
          : await _uploadApi(avatar, 'avatars');
      await _apiPost('profile_update', {
        'username': username.trim(),
        'bio': bio.trim(),
        'country': country,
        'country_code': countryCode,
        'avatar_url': avatarUrl,
      });
      await myProfile();
      return;
    }
    String? avatarUrl;
    if (avatar != null) {
      final bytes = await File(avatar.path).readAsBytes();
      final extension = avatar.path.split('.').last.toLowerCase();
      if (extension == 'gif') {
        final current = await myProfile();
        final vip = (current?['vip_level'] as num?)?.toInt() ?? 0;
        final expiry = DateTime.tryParse(
          current?['vip_expires_at']?.toString() ?? '',
        );
        if (vip < 7 || (expiry != null && !expiry.isAfter(DateTime.now()))) {
          throw Exception('vip7_required_for_gif');
        }
      }
      final path =
          '$uid/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$extension',
            ),
          );
      avatarUrl = client.storage.from('avatars').getPublicUrl(path);
    }
    final updates = <String, dynamic>{
      'username': username.trim(),
      'display_name': username.trim(),
      'bio': bio.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (country != null && country.trim().isNotEmpty) {
      updates['country'] = country.trim();
      updates['country_code'] = countryCode?.trim() ?? '';
    }
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    await client.from('profiles').update(updates).eq('id', uid);
  }

  Future<void> toggleFollow(String otherUserId, bool following) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=follow_toggle&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'user_id': otherUserId}));
        if ((await r.close()).statusCode >= 400) {
          throw StateError('follow_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    if (following) {
      await client
          .from('follows')
          .delete()
          .eq('follower_id', uid)
          .eq('following_id', otherUserId);
    } else {
      await client.from('follows').insert({
        'follower_id': uid,
        'following_id': otherUserId,
      });
    }
  }

  Future<bool> isFollowing(String otherUserId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=following_check&user_id=$otherUserId&access_token=$apiToken',
          ),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return d['data']['following'] == true;
      } finally {
        c.close(force: true);
      }
    }
    final row = await client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', uid)
        .eq('following_id', otherUserId)
        .maybeSingle();
    return row != null;
  }

  Future<String> countryFlag(String? country) async {
    if (country == null || country.trim().isEmpty) return '🌍';
    if (apiToken != null) {
      final rows = await _apiList(
        'country_flag',
        query: {'value': country.trim()},
      );
      return rows.isEmpty ? '🌍' : rows.first['flag']?.toString() ?? '🌍';
    }
    final row = await client
        .from('countries')
        .select('flag')
        .eq('name_ar', country)
        .maybeSingle();
    if (row?['flag'] is String && (row?['flag'] as String).isNotEmpty) {
      return row!['flag'] as String;
    }
    final codeRow = await client
        .from('countries')
        .select('flag')
        .eq('code', country.toUpperCase())
        .maybeSingle();
    return codeRow?['flag'] as String? ?? '🌍';
  }

  Future<List<Map<String, dynamic>>> searchAll(String query) async {
    final term = query.trim();
    if (term.isEmpty) return [];
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=search&q=${Uri.encodeQueryComponent(term)}&access_token=$apiToken',
          ),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final sakiId = int.tryParse(term);
    final profileFilters =
        'username.ilike.%$term%,display_name.ilike.%$term%${sakiId == null ? '' : ',saki_id.eq.$sakiId'}';
    final profiles = await client
        .from('profiles')
        .select(
          'id,username,display_name,saki_id,avatar_url,bio,country,gender',
        )
        .or(profileFilters)
        .limit(30);
    final posts = await client
        .from('posts')
        .select(
          'id,content,created_at,profiles:author_id(username,avatar_url,saki_id,vip_level,vip_expires_at,wealth_level)',
        )
        .ilike('content', '%$term%')
        .eq('visibility', 'public')
        .limit(20);
    final rooms = await client
        .from('rooms')
        .select(
          'id,room_id,name,description,image_url,profiles:owner_id(username)',
        )
        .or('name.ilike.%$term%,description.ilike.%$term%')
        .eq('is_active', true)
        .limit(20);
    return [
      ...List<Map<String, dynamic>>.from(profiles)
          .map((row) => {...row, '_kind': 'profile'}),
      ...List<Map<String, dynamic>>.from(posts)
          .map((row) => {...row, '_kind': 'post'}),
      ...List<Map<String, dynamic>>.from(rooms)
          .map((row) => {...row, '_kind': 'room'}),
    ];
  }

  Future<void> sharePost(String postId) async {
    if (apiToken != null) {
      await _apiPost('content_share', {'type': 'post', 'id': postId});
      return;
    }
    await client.from('post_shares').upsert({
      'post_id': postId,
      'user_id': uid,
    });
  }

  Future<void> shareReel(String reelId) async {
    if (apiToken != null) {
      await _apiPost('content_share', {'type': 'reel', 'id': reelId});
      return;
    }
    await client.from('reel_shares').upsert({
      'reel_id': reelId,
      'user_id': uid,
    });
  }

  Future<List<Map<String, dynamic>>> reelComments(String reelId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=reel_comments&reel_id=$reelId&access_token=$apiToken',
          ),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final data = await client
        .from('reel_comments')
        .select(
          'id,content,created_at,user_id,profiles:user_id(username,avatar_url,vip_level,vip_expires_at,wealth_level)',
        )
        .eq('reel_id', reelId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addReelComment(String reelId, String content) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse(
            '$apiBaseUrl?action=reel_comment_create&access_token=$apiToken',
          ),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'reel_id': reelId, 'content': content.trim()}));
        if ((await r.close()).statusCode >= 400) {
          throw StateError('reel_comment_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    await client.from('reel_comments').insert({
      'reel_id': reelId,
      'user_id': uid,
      'content': content.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> roomBanners() async {
    if (apiToken != null) {
      return _apiList('room_banners');
    }
    final data = await client
        .from('room_banners')
        .select(
          'id,image_url,title,sort_order,target_type,target_user_id,target_room_id',
        )
        .eq('is_active', true)
        .or(
          'starts_at.is.null,starts_at.lte.${DateTime.now().toIso8601String()}',
        )
        .or('ends_at.is.null,ends_at.gt.${DateTime.now().toIso8601String()}')
        .order('sort_order');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> adminBanners() async {
    final data = await client
        .from('room_banners')
        .select(
          'id,image_url,title,sort_order,is_active,target_type,target_user_id,target_room_id,starts_at,ends_at',
        )
        .order('sort_order');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String> uploadBannerImage(XFile image) async {
    final bytes = await File(image.path).readAsBytes();
    final extension = image.path.split('.').last.toLowerCase();
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await client.storage
        .from('banners')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$extension',
          ),
        );
    return client.storage.from('banners').getPublicUrl(path);
  }

  Future<Map<String, dynamic>?> bannerProfileBySakiId(String value) async {
    final result = await client.rpc(
      'resolve_banner_profile',
      params: {'p_saki_id': int.parse(value.trim())},
    );
    if (result == null) return null;
    return await userProfile(result.toString());
  }

  Future<Map<String, dynamic>?> bannerRoomByCode(String value) async {
    final result = await client.rpc(
      'resolve_banner_room',
      params: {'p_room_code': value.trim()},
    );
    if (result == null) return null;
    final row = await client
        .from('rooms')
        .select(
          'id,room_id,owner_id,name,description,country,room_type,image_url,background_url,seat_count,announcement,category,theme_key,membership_fee,reward_rate,mic_permission,is_active,created_at,profiles:owner_id(username,avatar_url,vip_level,vip_expires_at),room_members(user_id)',
        )
        .eq('id', result.toString())
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> createAdminBanner(Map<String, dynamic> values) async {
    await client.from('room_banners').insert(values);
  }

  Future<void> updateAdminBanner(String id, Map<String, dynamic> values) async {
    await client.from('room_banners').update(values).eq('id', id);
  }

  Future<void> deleteAdminBanner(String id) async {
    await client.from('room_banners').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse('$apiBaseUrl?action=notifications&access_token=$apiToken'),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final data = await client
        .from('notifications')
        .select(
          '*,profiles:actor_id(username,display_name,avatar_url,vip_level,vip_expires_at)',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  Stream<List<Map<String, dynamic>>> notificationsStream() {
    if (apiToken != null) {
      return Stream.periodic(const Duration(seconds: 4))
          .asyncMap((_) => notifications());
    }
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          final result = List<Map<String, dynamic>>.from(rows);
          final actorIds = result
              .map((row) => row['actor_id']?.toString())
              .whereType<String>()
              .toSet()
              .toList();
          if (actorIds.isEmpty) return result;
          final profiles = await client
              .from('profiles')
              .select('id,username,display_name,avatar_url')
              .inFilter('id', actorIds);
          final byId = {
            for (final profile in List<Map<String, dynamic>>.from(profiles))
              profile['id'].toString(): profile,
          };
          return result.map((row) {
            final actorId = row['actor_id']?.toString();
            return {
              ...row,
              if (actorId != null && byId[actorId] != null)
                'profiles': byId[actorId],
            };
          }).toList();
        });
  }

  Future<void> markNotificationRead(String id) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse(
            '$apiBaseUrl?action=notifications_read&access_token=$apiToken',
          ),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({}));
        await r.close();
        return;
      } finally {
        c.close(force: true);
      }
    }
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<List<Map<String, dynamic>>> conversationPreviews() async {
    final conversationsList = await conversations();
    final result = <Map<String, dynamic>>[];
    for (final conversation in conversationsList) {
      final id = conversation['id'] as String;
      final messages = await client
          .from('messages')
          .select('id,body,sender_id,created_at,is_read')
          .eq('conversation_id', id)
          .order('created_at', ascending: false)
          .limit(1);
      final unread = await client
          .from('messages')
          .select('id')
          .eq('conversation_id', id)
          .neq('sender_id', uid)
          .eq('is_read', false);
      result.add({
        ...conversation,
        '_last_message': messages.isEmpty ? null : messages.first,
        '_unread_count': unread.length,
      });
    }
    return result;
  }

  Future<void> markConversationRead(String conversationId) async {
    await client
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', uid);
  }

  Future<List<Map<String, dynamic>>> userPosts(String userId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=profile_posts&user_id=$userId&access_token=$apiToken',
          ),
        );
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.headers.set('X-Access-Token', apiToken!);
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final data = await client
        .from('posts')
        .select(
          'id,author_id,content,visibility,created_at,profiles:author_id(id,username,display_name,saki_id,avatar_url,vip_level,vip_expires_at,wealth_level),post_media(id,storage_path,sort_order),post_likes(user_id),post_comments(id),post_shares(user_id)',
        )
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(60);
    return List<Map<String, dynamic>>.from(data).map((post) {
      final likes = List<Map<String, dynamic>>.from(
        post['post_likes'] ?? const [],
      );
      final comments = List<Map<String, dynamic>>.from(
        post['post_comments'] ?? const [],
      );
      final shares = List<Map<String, dynamic>>.from(
        post['post_shares'] ?? const [],
      );
      final media =
          List<Map<String, dynamic>>.from(post['post_media'] ?? const [])..sort(
            (a, b) => (a['sort_order'] as int? ?? 0).compareTo(
              b['sort_order'] as int? ?? 0,
            ),
          );
      return {
        ...post,
        '_liked': likes.any((like) => like['user_id'] == uid),
        '_likes_count': likes.length,
        '_comments_count': comments.length,
        '_shares_count': shares.length,
        '_media': media,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> userReels(String userId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=profile_reels&user_id=$userId&access_token=$apiToken',
          ),
        );
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.headers.set('X-Access-Token', apiToken!);
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final data = await client
        .from('reels')
        .select('id,video_url,description,created_at')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(60);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> userReceivedGifts(String userId) async {
    if (apiToken != null) {
      return _apiList('user_received_gifts', query: {'user_id': userId});
    }
    final rows = await client
        .from('room_gifts')
        .select(
          'gift_id,quantity,total_price,created_at,room_id,room_gift_catalog:gift_id(id,name,icon,price),rooms:room_id(id,name,room_id)',
        )
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(300);
    final grouped = <String, Map<String, dynamic>>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final giftId = row['gift_id']?.toString();
      if (giftId == null) continue;
      final catalog = row['room_gift_catalog'] is Map
          ? Map<String, dynamic>.from(row['room_gift_catalog'] as Map)
          : <String, dynamic>{};
      final room = row['rooms'] is Map
          ? Map<String, dynamic>.from(row['rooms'] as Map)
          : <String, dynamic>{};
      final current = grouped.putIfAbsent(
        giftId,
        () => {
          ...catalog,
          'id': giftId,
          'received_count': 0,
          'received_value': 0,
          'last_received_at': row['created_at'],
          'room_name': room['name']?.toString() ?? 'غرفة SAKI',
        },
      );
      current['received_count'] =
          (current['received_count'] as int) +
          ((row['quantity'] as num?)?.toInt() ?? 1);
      current['received_value'] =
          (current['received_value'] as int) +
          ((row['total_price'] as num?)?.toInt() ?? 0);
      current['room_name'] = room['name']?.toString() ?? current['room_name'];
    }
    return grouped.values.toList();
  }

  Future<List<Map<String, dynamic>>> userVehicles(String userId) async {
    if (apiToken != null) {
      return _apiList('user_vehicles', query: {'user_id': userId});
    }
    final rows = await client
        .from('trace_store_inventory')
        .select(
          'item_id,purchased_at,expires_at,is_active,trace_store_catalog:item_id(id,name,asset_key,price_gold_coins,duration_days,category)',
        )
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('purchased_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows).map((row) {
      final catalog = row['trace_store_catalog'] is Map
          ? Map<String, dynamic>.from(row['trace_store_catalog'] as Map)
          : <String, dynamic>{};
      return {...catalog, ...row};
    }).toList();
  }

  Future<Map<String, dynamic>> accountModules() async {
    if (apiToken != null) {
      return _apiMap('wallet');
    }
    final existing = await client
        .from('saki_account_modules')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (existing != null) return Map<String, dynamic>.from(existing);
    final created = await client
        .from('saki_account_modules')
        .insert({'user_id': uid})
        .select()
        .single();
    return Map<String, dynamic>.from(created);
  }

  Future<Map<String, dynamic>> buffetGetRound(String roomId) async {
    final result = await client.rpc(
      'saki_buffet_get_round',
      params: {'p_room_id': roomId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> buffetPlaceBet({
    required String roomId,
    required int roundId,
    required int foodId,
    required int amount,
  }) async {
    final result = await client.rpc(
      'saki_buffet_place_bet',
      params: {
        'p_room_id': roomId,
        'p_round_id': roundId,
        'p_food_id': foodId,
        'p_amount': amount,
      },
    );
    final rows = result is List ? result : [result];
    return rows.isEmpty
        ? const {}
        : Map<String, dynamic>.from(rows.first as Map);
  }

  Future<Map<String, dynamic>> buffetResolveRound({
    required String roomId,
    required int roundId,
  }) async {
    final result = await client.rpc(
      'saki_buffet_resolve_round',
      params: {'p_room_id': roomId, 'p_round_id': roundId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> buffetFinishRound({
    required String roomId,
    required int roundId,
  }) async {
    final result = await client.rpc(
      'saki_buffet_finish_round',
      params: {'p_room_id': roomId, 'p_round_id': roundId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> buffetLeaderboard(int roundId) async {
    final rows = await client.rpc(
      'saki_buffet_round_leaderboard',
      params: {'p_round_id': roundId},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> buffetHistory(String roomId) async {
    final rows = await client
        .from('saki_buffet_rounds')
        .select('id,winner_food_id,round_number,result_shown_at')
        .eq('room_id', roomId)
        .eq('status', 'finished')
        .order('id', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<int> buffetTodayProfit() async {
    final start = DateTime.now().toUtc();
    final dayStart = DateTime.utc(start.year, start.month, start.day);
    final rows = await client
        .from('saki_buffet_bets')
        .select('payout')
        .eq('user_id', uid)
        .gt('payout', 0)
        .gte('created_at', dayStart.toIso8601String())
        .limit(1000);
    return rows.fold<int>(
      0,
      (sum, row) => sum + ((row['payout'] as num?)?.toInt() ?? 0),
    );
  }

  Future<List<Map<String, dynamic>>> familySquare({String? query}) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse('$apiBaseUrl?action=families&access_token=$apiToken'),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    var request = client.from('family_square').select();
    if (query != null && query.trim().isNotEmpty) {
      request = request.ilike('name', '%${query.trim()}%');
    }
    final rows = await request.order('stars', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> myFamily() async {
    if (apiToken != null) {
      final rows = await _apiList('family_me');
      return rows.isEmpty ? null : rows.first;
    }
    final member = await client
        .from('family_members')
        .select('family_id,role,status,families(*)')
        .eq('user_id', uid)
        .eq('status', 'active')
        .maybeSingle();
    if (member == null) return null;
    final family = Map<String, dynamic>.from(member['families'] ?? const {});
    family['role'] = member['role'];
    return family;
  }

  Future<Map<String, dynamic>> createFamily({
    required String name,
    required String alias,
    required String description,
    String? avatarUrl,
  }) async {
    final aliasError = familyAliasValidationMessage(alias);
    if (aliasError != null) throw Exception(aliasError);
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=family_create&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(
          jsonEncode({
            'name': name.trim(),
            'alias': alias.trim(),
            'description': description.trim(),
            'avatar_url': avatarUrl,
          }),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
          throw StateError(d['error']?.toString() ?? 'family_create_failed');
        }
        return Map<String, dynamic>.from(d['data'] as Map);
      } finally {
        c.close(force: true);
      }
    }
    final result = await client.rpc(
      'create_family',
      params: {
        'p_name': name.trim(),
        'p_alias': alias.trim(),
        'p_description': description.trim(),
        'p_avatar_url': avatarUrl,
      },
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    final rows = List<Map<String, dynamic>>.from(result as List);
    if (rows.isEmpty) throw Exception('تعذر إنشاء العائلة');
    return rows.first;
  }

  Future<void> requestFamilyJoin(String familyId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=family_join&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'family_id': familyId}));
        if ((await r.close()).statusCode >= 400) {
          throw StateError('family_join_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    await client.rpc('request_family_join', params: {'p_family_id': familyId});
  }

  Future<void> leaveFamily(String familyId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=family_leave&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'family_id': familyId}));
        if ((await r.close()).statusCode >= 400) {
          throw StateError('family_leave_failed');
        }
        return;
      } finally {
        c.close(force: true);
      }
    }
    await client.rpc('leave_family', params: {'p_family_id': familyId});
  }

  Future<List<Map<String, dynamic>>> familyJoinRequests(String familyId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=family_requests&family_id=$familyId&access_token=$apiToken',
          ),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    final rows = await client
        .from('family_join_requests')
        .select(
          'id,family_id,user_id,status,created_at,profiles:user_id(id,username,avatar_url,saki_id)',
        )
        .eq('family_id', familyId)
        .eq('status', 'pending')
        .order('created_at')
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> updateFamilySettings({
    required String familyId,
    required String name,
    required String alias,
    required String avatarUrl,
    required String announcement,
  }) async {
    final aliasError = familyAliasValidationMessage(alias);
    if (aliasError != null) throw Exception(aliasError);
    if (apiToken != null) {
      await _apiPost('family_update', {
        'family_id': familyId,
        'name': name.trim(),
        'alias': alias.trim(),
        'avatar_url': avatarUrl,
        'announcement': announcement,
      });
      final family = await myFamily();
      return family ?? {'id': familyId, 'name': name, 'family_alias': alias};
    }
    final row = await client.rpc(
      'update_family_settings',
      params: {
        'p_family_id': familyId,
        'p_name': name,
        'p_alias': alias,
        'p_avatar_url': avatarUrl,
        'p_announcement': announcement,
      },
    );
    return Map<String, dynamic>.from(row is List ? row.first : row);
  }

  Future<void> approveFamilyJoin(String requestId) async {
    if (apiToken != null) {
      await _apiPost('family_request_decide', {
        'request_id': requestId,
        'decision': 'approve',
      });
      return;
    }
    await client.rpc(
      'approve_family_join',
      params: {'p_request_id': requestId},
    );
  }

  Future<void> rejectFamilyJoin(String requestId) async {
    if (apiToken != null) {
      await _apiPost('family_request_decide', {
        'request_id': requestId,
        'decision': 'reject',
      });
      return;
    }
    await client.rpc('reject_family_join', params: {'p_request_id': requestId});
  }

  Future<Map<String, dynamic>> completeFamilyTask(
    String familyId,
    String taskKey, {
    int increment = 1,
  }) async {
    if (apiToken != null) {
      final result = await _apiPost('family_task_complete', {
        'family_id': familyId,
        'task_key': taskKey,
        'increment': increment,
      });
      final data = result['data'];
      return data is List && data.isNotEmpty
          ? Map<String, dynamic>.from(data.first as Map)
          : result;
    }
    final rows = await client.rpc(
      'complete_family_task',
      params: {
        'p_family_id': familyId,
        'p_task_key': taskKey,
        'p_increment': increment,
      },
    );
    return Map<String, dynamic>.from((rows as List).first);
  }

  Future<List<Map<String, dynamic>>> familyWeeklyLeaderboard(
    String familyId,
  ) async {
    final rows = await client.rpc(
      'family_weekly_leaderboard',
      params: {'p_family_id': familyId},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> familyMembers(String familyId) async {
    if (apiToken != null) {
      return _apiList('family_members', query: {'family_id': familyId});
    }
    final rows = await client
        .from('family_members')
        .select(
          'user_id,role,joined_at,profiles:user_id(id,username,avatar_url,saki_id)',
        )
        .eq('family_id', familyId)
        .eq('status', 'active')
        .order('joined_at')
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> familyTasks(String familyId) async {
    if (apiToken != null) {
      return _apiList('family_tasks', query: {'family_id': familyId});
    }
    final rows = await client
        .from('family_tasks')
        .select()
        .eq('family_id', familyId)
        .order('created_at')
        .limit(30);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> familyGiftLeaderboard(
    String familyId,
    String mode,
  ) async {
    final rows = await client.rpc(
      'family_gift_leaderboard',
      params: {'p_family_id': familyId, 'p_mode': mode},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> settleFamilyWeeklyRewards(String familyId) async {
    await client.rpc(
      'settle_family_weekly_rewards',
      params: {'p_family_id': familyId},
    );
  }

  Future<Map<String, dynamic>?> uploadFamilyImage(XFile image) async {
    final bytes = await File(image.path).readAsBytes();
    final extension = image.path.split('.').last.toLowerCase();
    final path =
        '$uid/family_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$extension',
          ),
        );
    return {'url': client.storage.from('avatars').getPublicUrl(path)};
  }

  Future<Map<String, dynamic>> accountModulesForUser(String userId) async {
    final row = await client
        .from('saki_account_modules')
        .select('vip_level,vip_label,wealth_level')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? <String, dynamic>{} : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> purchaseVip(int level) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=vip_purchase&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'level': level}));
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
          throw StateError(d['error']?.toString() ?? 'vip_purchase_failed');
        }
        return Map<String, dynamic>.from(d['data'] as Map);
      } finally {
        c.close(force: true);
      }
    }
    try {
      final rows = await client.rpc('purchase_vip', params: {'p_level': level});
      if (rows is Map) return Map<String, dynamic>.from(rows);
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isEmpty) throw Exception('empty_purchase_result');
      return list.first;
    } on PostgrestException catch (error) {
      throw Exception('${error.code ?? 'rpc_error'}:${error.message}');
    }
  }

  Future<Map<String, dynamic>> giftVip({
    required int sakiId,
    required int level,
  }) async {
    final rows = await client.rpc(
      'gift_vip',
      params: {'p_saki_id': sakiId, 'p_level': level},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) throw Exception('تعذر إرسال VIP');
    return list.first;
  }

  Future<Map<String, dynamic>> convertDiamondsToGold(int amount) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse(
            '$apiBaseUrl?action=diamonds_convert&access_token=$apiToken',
          ),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'amount': amount}));
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
          throw StateError(d['error']?.toString() ?? 'diamonds_convert_failed');
        }
        return Map<String, dynamic>.from(d['data'] as Map);
      } finally {
        c.close(force: true);
      }
    }
    final rows = await client.rpc(
      'convert_diamonds_to_gold',
      params: {'amount': amount},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) throw Exception('تعذر تنفيذ التحويل.');
    return list.first;
  }

  Future<bool> isShippingAgent(String userId) async {
    if (apiToken != null) return false;
    final result = await client.rpc(
      'is_shipping_agent',
      params: {'p_user_id': userId},
    );
    return result == true;
  }

  Future<Map<String, dynamic>> shippingAgentDashboard() async {
    final result = await client.rpc('shipping_agent_dashboard');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>?> shippingFindUser(int sakiId) async {
    final result = await client.rpc(
      'shipping_find_user',
      params: {'p_saki_id': sakiId},
    );
    final rows = List<Map<String, dynamic>>.from(result as List);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>> shippingTopupUser(
    int recipientSakiId,
    int sakiCoins,
  ) async {
    final result = await client.rpc(
      'shipping_topup_user',
      params: {
        'p_recipient_saki_id': recipientSakiId,
        'p_saki_coins': sakiCoins,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> adminShippingAgents() async {
    final result = await client.rpc('admin_shipping_agents');
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<void> adminAssignShippingAgent(int sakiId) async {
    await client.rpc(
      'admin_assign_shipping_agent',
      params: {'p_saki_id': sakiId},
    );
  }

  Future<void> adminRemoveShippingAgent(String userId) async {
    await client.rpc(
      'admin_remove_shipping_agent',
      params: {'p_user_id': userId},
    );
  }

  Future<void> adminAddSakiCoins(String userId, int amount) async {
    await client.rpc(
      'admin_add_saki_coins',
      params: {'p_user_id': userId, 'p_amount': amount},
    );
  }

  Future<void> updateAccountSettings(Map<String, dynamic> settings) async {
    await client
        .from('saki_account_modules')
        .update({
          'settings': settings,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', uid);
  }

  Future<List<Map<String, dynamic>>> roomGiftCatalog({String? category}) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final suffix = category == null || category == 'bag'
            ? ''
            : '&category=${Uri.encodeQueryComponent(category)}';
        final r = await c.getUrl(
          Uri.parse(
            '$apiBaseUrl?action=gift_catalog$suffix&access_token=$apiToken',
          ),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        return List<Map<String, dynamic>>.from(d['data'] as List);
      } finally {
        c.close(force: true);
      }
    }
    var query = client.from('room_gift_catalog').select().eq('is_active', true);
    if (category != null && category != 'bag') {
      query = query.eq('category', category);
    }
    final rows = await query.order('sort_order').limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> roomGiftInventory() async {
    final rows = await client
        .from('room_gift_inventory')
        .select('quantity,gift:gift_id(*)')
        .eq('user_id', uid)
        .gt('quantity', 0);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> sendRoomGift({
    required String roomId,
    required String recipientId,
    required String giftId,
    int quantity = 1,
  }) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=gift_send&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(
          jsonEncode({
            'room_id': roomId,
            'recipient_id': recipientId,
            'gift_id': giftId,
            'quantity': quantity,
          }),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
          throw StateError(d['error']?.toString() ?? 'gift_send_failed');
        }
        return Map<String, dynamic>.from(d['data'] as Map);
      } finally {
        c.close(force: true);
      }
    }
    final rows = await client.rpc(
      'send_room_gift',
      params: {
        'p_room_id': roomId,
        'p_recipient_id': recipientId,
        'p_gift_id': giftId,
        'p_quantity': quantity,
      },
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) throw Exception('تعذر إرسال الهدية');
    return list.first;
  }

  Future<Map<String, dynamic>> sendRoomLuckGift({
    required String roomId,
    required String recipientId,
    required String giftId,
    int quantity = 1,
  }) async {
    final rows = await client.rpc(
      'send_room_luck_gift',
      params: {
        'p_room_id': roomId,
        'p_recipient_id': recipientId,
        'p_gift_id': giftId,
        'p_quantity': quantity,
      },
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) throw Exception('تعذر إرسال هدية الحظ');
    return list.first;
  }

  Future<int> luckDailyPercent() async {
    final row = await client
        .from('luck_daily_settings')
        .select('win_percent')
        .eq('luck_date', DateTime.now().toIso8601String().substring(0, 10))
        .maybeSingle();
    return (row?['win_percent'] as num?)?.toInt() ?? 38;
  }

  Future<int> setLuckDailyPercent(int percent) async {
    final rows = await client.rpc(
      'set_luck_daily_percent',
      params: {'p_percent': percent},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) throw Exception('تعذر تعديل نسبة الحظ');
    return (list.first['win_percent'] as num?)?.toInt() ?? percent;
  }

  Future<int> sentLuckGiftCount(String userId) async {
    final rows = await client
        .from('room_gifts')
        .select('id,room_gift_catalog:gift_id!inner(category)')
        .eq('sender_id', userId)
        .eq('room_gift_catalog.category', 'luck');
    return (rows as List).length;
  }

  Future<Map<String, dynamic>> redeemSakiCode(String code) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=redeem&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'code': code.trim().toUpperCase()}));
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
          throw StateError(d['error']?.toString() ?? 'redeem_failed');
        }
        return Map<String, dynamic>.from(d['data'] as Map? ?? {});
      } finally {
        c.close(force: true);
      }
    }
    try {
      final result = await client.rpc(
        'redeem_saki_code',
        params: {'p_code': code.trim().toUpperCase()},
      );
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (error) {
      throw Exception('${error.code ?? 'rpc_error'}:${error.message}');
    }
  }

  Future<List<Map<String, dynamic>>> adminRedeemCodes() async {
    final rows = await client.rpc('admin_redeem_codes');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> adminCreateRedeemCode({
    required String code,
    required DateTime expiresAt,
    required int maxUses,
    required List<Map<String, dynamic>> rewards,
  }) async {
    try {
      final result = await client.rpc(
        'admin_create_redeem_code',
        params: {
          'p_code': code.trim().toUpperCase(),
          'p_expires_at': expiresAt.toUtc().toIso8601String(),
          'p_max_uses': maxUses,
          'p_rewards': rewards,
        },
      );
      return result.toString();
    } on PostgrestException catch (error) {
      throw Exception('${error.code ?? 'rpc_error'}:${error.message}');
    }
  }

  Future<List<Map<String, dynamic>>> adminTraceStoreCatalog() async {
    final rows = await client
        .from('saki_store_products')
        .select(
          'id,category,name,price,media_type,media_url,thumbnail_url,duration_days,discounted_price,is_active',
        )
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createRoomLuckBag(
    String roomId,
    int totalGold,
    int recipientLimit,
  ) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse(
            '$apiBaseUrl?action=luck_bag_create&access_token=$apiToken',
          ),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(
          jsonEncode({
            'room_id': roomId,
            'total_gold': totalGold,
            'recipient_limit': recipientLimit,
          }),
        );
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
          throw StateError(d['error']?.toString() ?? 'luck_bag_create_failed');
        }
        return Map<String, dynamic>.from(d['data'] as Map);
      } finally {
        c.close(force: true);
      }
    }
    final row = await client.rpc(
      'create_room_luck_bag',
      params: {
        'p_room_id': roomId,
        'p_total_gold': totalGold,
        'p_recipient_limit': recipientLimit,
      },
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Future<Map<String, dynamic>> claimRoomLuckBag(String bagId) async {
    if (apiToken != null) {
      final c = HttpClient();
      try {
        final r = await c.postUrl(
          Uri.parse('$apiBaseUrl?action=luck_bag_claim&access_token=$apiToken'),
        );
        r.headers.contentType = ContentType.json;
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiToken');
        r.write(jsonEncode({'bag_id': bagId}));
        final d = jsonDecode(
          await (await r.close()).transform(utf8.decoder).join(),
        );
        if (d['ok'] != true) {
          throw StateError(d['error']?.toString() ?? 'luck_bag_claim_failed');
        }
        return Map<String, dynamic>.from(d['data'] as Map);
      } finally {
        c.close(force: true);
      }
    }
    final rows = await client.rpc(
      'claim_room_luck_bag',
      params: {'p_bag_id': bagId},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? const {} : list.first;
  }

  Stream<List<Map<String, dynamic>>> roomLuckBagsStream(String roomId) => client
      .from('room_luck_bags')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: false)
      .limit(10);

  Stream<List<Map<String, dynamic>>> allRoomLuckBagsStream() => client
      .from('room_luck_bags')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(50);

  Future<Map<String, dynamic>> enrichRoomLuckBag(
    Map<String, dynamic> bag,
  ) async {
    final senderId = bag['sender_id']?.toString();
    final roomId = bag['room_id']?.toString();
    final profile = senderId == null
        ? null
        : await client
              .from('profiles')
              .select('id,username,avatar_url')
              .eq('id', senderId)
              .maybeSingle();
    final room = roomId == null
        ? null
        : await client
              .from('rooms')
              .select('id,name,room_id,image_url')
              .eq('id', roomId)
              .maybeSingle();
    return {
      ...bag,
      '_sender': profile ?? const <String, dynamic>{},
      '_room': room ?? const <String, dynamic>{},
    };
  }
}

class RoomGiftRankingResult {
  const RoomGiftRankingResult(this.rows, this.total);
  final List<Map<String, dynamic>> rows;
  final int total;
}

final SupabaseClient client = Supabase.instance.client;
