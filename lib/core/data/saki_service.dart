import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SakiService {
  SakiService._();
  static final instance = SakiService._();
  final SupabaseClient client = Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;
  String get uid => currentUser!.id;

  Future<Map<String, dynamic>?> myProfile() async {
    final data = await client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return data;
  }

  Future<String> myCountry() async {
    final profile = await myProfile();
    final country = (profile?['country'] as String?)?.trim();
    return country == null || country.isEmpty ? 'الأردن' : country;
  }

  Future<Map<String, dynamic>?> myOwnedRoom() async {
    final rows = await client
        .from('rooms')
        .select(
          'id,room_id,owner_id,name,description,country,room_type,image_url,is_active,created_at,profiles:owner_id(username,avatar_url),room_members(user_id)',
        )
        .eq('owner_id', uid)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final room = Map<String, dynamic>.from(rows.first);
    return {
      ...room,
      '_members_count': List<Map<String, dynamic>>.from(
        room['room_members'] ?? const [],
      ).length,
    };
  }

  Future<List<Map<String, dynamic>>> feed({bool followingOnly = false}) async {
    final selection =
        'id,author_id,content,visibility,created_at,profiles:author_id(id,username,display_name,saki_id,avatar_url),post_media(id,storage_path,sort_order),post_likes(user_id),post_comments(id),post_shares(user_id)';
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
    final data = await client
        .from('post_comments')
        .select(
          'id,content,created_at,user_id,profiles:user_id(username,avatar_url)',
        )
        .eq('post_id', postId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addComment(String postId, String content) async {
    await client.from('post_comments').insert({
      'post_id': postId,
      'user_id': uid,
      'content': content.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> reels({bool followingOnly = false}) async {
    final selection =
        'id,author_id,video_url,description,visibility,created_at,profiles:author_id(username,avatar_url,saki_id),reel_likes(user_id),reel_comments(id)';
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
    final data = await client
        .from('profiles')
        .select(
          'id,username,display_name,saki_id,avatar_url,bio,country,gender,created_at',
        )
        .eq('id', userId)
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  Future<Map<String, int>> userProfileStats(String userId) async {
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
          'id,created_at,conversation_members(user_id,profiles:user_id(id,username,display_name,avatar_url,saki_id))',
        )
        .inFilter('id', ids)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String> createConversation(String otherUserId) async {
    final existing = await client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', uid);
    for (final row in List<Map<String, dynamic>>.from(existing)) {
      final members = await client
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', row['conversation_id'] as String);
      if (List<Map<String, dynamic>>.from(members)
          .any((m) => m['user_id'] == otherUserId))
        return row['conversation_id'] as String;
    }
    final conversation = await client
        .from('conversations')
        .insert({'created_by': uid})
        .select('id')
        .single();
    final conversationId = conversation['id'] as String;
    await client.from('conversation_members').insert([
      {'conversation_id': conversationId, 'user_id': uid},
      {'conversation_id': conversationId, 'user_id': otherUserId},
    ]);
    return conversationId;
  }

  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at');
  }

  Future<void> sendMessage(String conversationId, String body) async {
    await client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'body': body.trim(),
    });
    await client
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }

  Future<List<Map<String, dynamic>>> rooms() async {
    final data = await client
        .from('rooms')
        .select(
          'id,room_id,owner_id,name,description,country,room_type,image_url,is_active,created_at,profiles:owner_id(username,avatar_url),room_members(user_id)',
        )
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(data)
        .map(
          (room) => {
            ...room,
            '_members_count': List<Map<String, dynamic>>.from(
              room['room_members'] ?? const [],
            ).length,
          },
        )
        .toList();
  }

  Future<void> joinRoom(String roomId) async {
    await client.from('room_members').upsert({
      'room_id': roomId,
      'user_id': uid,
    });
  }

  Future<void> leaveRoom(String roomId) async {
    await client
        .from('room_members')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', uid);
    await client
        .from('room_seats')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', uid);
  }

  Future<List<Map<String, dynamic>>> roomSeats(String roomId) async {
    final data = await client
        .from('room_seats')
        .select(
          'seat_no,user_id,joined_at,profiles:user_id(id,username,avatar_url)',
        )
        .eq('room_id', roomId)
        .order('seat_no');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> claimRoomSeat(String roomId, int seatNo) async {
    await client
        .from('room_seats')
        .delete()
        .eq('user_id', uid)
        .eq('room_id', roomId);
    await client.from('room_seats').insert({
      'room_id': roomId,
      'seat_no': seatNo,
      'user_id': uid,
    });
  }

  Future<void> leaveRoomSeat(String roomId) async {
    await client
        .from('room_seats')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', uid);
  }

  Stream<List<Map<String, dynamic>>> roomMessagesStream(String roomId) {
    return client
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at');
  }

  Stream<List<Map<String, dynamic>>> roomSeatsStream(String roomId) {
    return client
        .from('room_seats')
        .stream(primaryKey: ['room_id', 'seat_no'])
        .eq('room_id', roomId)
        .order('seat_no');
  }

  Future<Map<String, dynamic>> createRoom({
    required String name,
    required String description,
    required String country,
    required String type,
    XFile? image,
  }) async {
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
          'id,room_id,owner_id,name,description,country,room_type,image_url,is_active,created_at,profiles:owner_id(username,avatar_url)',
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
    XFile? avatar,
  }) async {
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
      'bio': bio.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    await client.from('profiles').update(updates).eq('id', uid);
  }

  Future<void> toggleFollow(String otherUserId, bool following) async {
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
    final row = await client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', uid)
        .eq('following_id', otherUserId)
        .maybeSingle();
    return row != null;
  }

  Future<List<Map<String, dynamic>>> searchAll(String query) async {
    final term = query.trim();
    if (term.isEmpty) return [];
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
          'id,content,created_at,profiles:author_id(username,avatar_url,saki_id)',
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
    await client.from('post_shares').upsert({
      'post_id': postId,
      'user_id': uid,
    });
  }

  Future<void> shareReel(String reelId) async {
    await client.from('reel_shares').upsert({
      'reel_id': reelId,
      'user_id': uid,
    });
  }

  Future<List<Map<String, dynamic>>> reelComments(String reelId) async {
    final data = await client
        .from('reel_comments')
        .select(
          'id,content,created_at,user_id,profiles:user_id(username,avatar_url)',
        )
        .eq('reel_id', reelId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addReelComment(String reelId, String content) async {
    await client.from('reel_comments').insert({
      'reel_id': reelId,
      'user_id': uid,
      'content': content.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> roomBanners() async {
    final data = await client
        .from('room_banners')
        .select('id,image_url,title,sort_order')
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final data = await client
        .from('notifications')
        .select(
          'id,type,entity_id,is_read,created_at,profiles:actor_id(username,avatar_url)',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  Stream<List<Map<String, dynamic>>> notificationsStream() {
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false);
  }

  Future<void> markNotificationRead(String id) async {
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
    final data = await client
        .from('posts')
        .select('id,content,created_at,post_media(storage_path,sort_order)')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(60);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> userReels(String userId) async {
    final data = await client
        .from('reels')
        .select('id,video_url,description,created_at')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(60);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> accountModules() async {
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

  Future<Map<String, dynamic>> convertDiamondsToGold(int amount) async {
    final rows = await client.rpc(
      'convert_diamonds_to_gold',
      params: {'amount': amount},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) throw Exception('تعذر تنفيذ التحويل.');
    return list.first;
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
}
