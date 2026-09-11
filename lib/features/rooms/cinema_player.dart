import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/data/saki_service.dart';

class CinemaPlayer extends StatefulWidget {
  const CinemaPlayer({
    super.key,
    required this.roomId,
    required this.service,
    required this.canControl,
  });
  final String roomId;
  final SakiService service;
  final bool canControl;

  @override
  State<CinemaPlayer> createState() => _CinemaPlayerState();
}

class _CinemaPlayerState extends State<CinemaPlayer> {
  YoutubePlayerController? _controller;
  StreamSubscription<List<Map<String, dynamic>>>? _stateSubscription;
  Timer? _heartbeat;
  String? _videoId;
  String _title = 'اختر فيلمًا أو فيديو من YouTube';
  bool _playing = false;
  double _volume = 1;
  double _position = 0;
  bool _applyingRemote = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _stateSubscription = widget.service
        .roomCinemaStateStream(widget.roomId)
        .listen(_applyStateRows);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final row = await widget.service.roomCinemaState(widget.roomId);
    if (row != null) await _applyStateRows([row]);
  }

  Future<void> _applyStateRows(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final row = rows.last;
    final id = row['video_id']?.toString();
    if (id == null || id.isEmpty) return;
    final changedAt = DateTime.tryParse(row['changed_at']?.toString() ?? '');
    var position = (row['position_seconds'] as num?)?.toDouble() ?? 0;
    final playing = row['is_playing'] == true;
    if (playing && changedAt != null) {
      position +=
          DateTime.now().toUtc().difference(changedAt.toUtc()).inMilliseconds /
          1000;
    }
    _title = row['video_title']?.toString() ?? 'YouTube';
    _volume = (row['volume'] as num?)?.toDouble() ?? 1;
    _playing = playing;
    _position = position.clamp(0, double.infinity);
    if (!mounted) return;
    setState(() {});
    if (_videoId != id) {
      _videoId = id;
      _controller?.close();
      _controller = YoutubePlayerController.fromVideoId(
        videoId: id,
        params: const YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
        ),
      );
      _initialised = true;
      if (mounted) setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAndStartVideo(id, _position, _playing);
      });
      return;
    } else if (!_applyingRemote && _controller != null) {
      _applyingRemote = true;
      await _controller!.seekTo(seconds: _position, allowSeekAhead: true);
      if (_playing) {
        await _controller!.playVideo();
      } else {
        await _controller!.pauseVideo();
      }
      await _controller!.setVolume((_volume * 100).round());
      _applyingRemote = false;
    }
    if (_playing && _controller != null) {
      await _playWithAutoplayFallback();
    }
  }

  Future<void> _loadAndStartVideo(
    String id,
    double position,
    bool shouldPlay,
  ) async {
    final controller = _controller;
    if (controller == null || _videoId != id) return;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await controller.loadVideoById(videoId: id, startSeconds: position);
      await controller.setVolume((_volume * 100).round());
      if (shouldPlay) await _playWithAutoplayFallback();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تشغيل هذا الفيديو داخل المشغل')),
        );
      }
    }
  }

  Future<void> _playWithAutoplayFallback() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      // Android WebView blocks unmuted autoplay. Start muted, then restore volume.
      await controller.mute();
      await controller.playVideo();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await controller.setVolume((_volume * 100).round());
      if (_volume > 0) await controller.unMute();
    } catch (_) {
      // The user can still start playback with the visible play button.
    }
  }

  Future<double> _currentPosition() async {
    if (_controller == null) return _position;
    try {
      return await _controller!.currentTime;
    } catch (_) {
      return _position;
    }
  }

  Future<Map<String, dynamic>?> _publish({
    String? videoId,
    String? title,
    bool? playing,
    double? position,
    double? volume,
  }) async {
    if (!widget.canControl || _applyingRemote) return null;
    return widget.service.setRoomCinemaState(
      widget.roomId,
      videoId: videoId ?? _videoId ?? '',
      videoTitle: title ?? _title,
      isPlaying: playing ?? _playing,
      positionSeconds: position ?? await _currentPosition(),
      volume: volume ?? _volume,
    );
  }

  Future<void> _togglePlay() async {
    if (_videoId == null) return;
    final next = !_playing;
    setState(() => _playing = next);
    await _publish(playing: next, position: await _currentPosition());
  }

  Future<void> _seekBy(double seconds) async {
    final next = (await _currentPosition() + seconds)
        .clamp(0, double.infinity)
        .toDouble();
    await _controller?.seekTo(seconds: next, allowSeekAhead: true);
    await _publish(position: next);
  }

  Future<void> _changeVolume(double value) async {
    setState(() => _volume = value);
    await _controller?.setVolume((value * 100).round());
    await _publish(volume: value);
  }

  Future<void> _openSearch() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _YoutubeSearchSheet(),
    );
    if (result == null) return;
    final id = result['videoId'] ?? _extractVideoId(result['url'] ?? '');
    if (id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل رابط YouTube صحيحًا')),
        );
      }
      return;
    }
    final state = await _publish(
      videoId: id,
      title: result['title']?.trim().isEmpty == true
          ? 'YouTube'
          : result['title'],
      playing: true,
      position: 0,
    );
    if (state != null) await _applyStateRows([state]);
  }

  String? _extractVideoId(String value) {
    final text = value.trim();
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(text)) return text;
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'] ??
          (uri.pathSegments.length > 1 ? uri.pathSegments[1] : null);
    }
    return null;
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _stateSubscription?.cancel();
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_playing && widget.canControl && _heartbeat == null) {
      _heartbeat = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _publish(),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 1),
      decoration: BoxDecoration(
        color: const Color(0xFF240609),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB88732)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 106,
            child: _controller == null || !_initialised
                ? const Center(
                    child: Icon(
                      Icons.movie_creation_outlined,
                      color: Colors.amber,
                      size: 46,
                    ),
                  )
                : YoutubePlayer(controller: _controller!),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.movie_filter_rounded,
                      color: Colors.amber,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.canControl)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _openSearch,
                        icon: const Icon(
                          Icons.manage_search_rounded,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: widget.canControl ? () => _seekBy(-10) : null,
                      icon: const Icon(
                        Icons.replay_10_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.canControl ? _togglePlay : null,
                      icon: Icon(
                        _playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.amber,
                        size: 30,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.canControl ? () => _seekBy(10) : null,
                      icon: const Icon(
                        Icons.forward_10_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 22,
                  child: Slider(
                    value: _volume.clamp(0, 1),
                    onChanged: widget.canControl ? _changeVolume : null,
                    activeColor: Colors.amber,
                    inactiveColor: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YoutubeSearchSheet extends StatefulWidget {
  const _YoutubeSearchSheet();
  @override
  State<_YoutubeSearchSheet> createState() => _YoutubeSearchSheetState();
}

class _YoutubeSearchSheetState extends State<_YoutubeSearchSheet> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await SakiService.instance.searchYouTube(query);
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر البحث: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ابحث عن فيديو بالاسم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: 'مثال: أغنية أو فيلم',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final item = _results[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    leading: item['thumbnail'] == null
                        ? const Icon(Icons.movie)
                        : Image.network(
                            item['thumbnail'].toString(),
                            width: 96,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                    title: Text(
                      item['title']?.toString() ?? 'YouTube',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(item['channelTitle']?.toString() ?? ''),
                    trailing: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.redAccent,
                    ),
                    onTap: () => Navigator.pop(context, {
                      'videoId': item['videoId'].toString(),
                      'title': item['title'].toString(),
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
