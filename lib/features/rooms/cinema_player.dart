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
      await _controller!.loadVideoById(videoId: id, startSeconds: _position);
      await _controller!.setVolume((_volume * 100).round());
      _initialised = true;
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
      await _controller!.playVideo();
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

  Future<void> _publish({
    String? videoId,
    String? title,
    bool? playing,
    double? position,
    double? volume,
  }) async {
    if (!widget.canControl || _applyingRemote) return;
    await widget.service.setRoomCinemaState(
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
    final id = _extractVideoId(result['url'] ?? '');
    if (id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل رابط YouTube صحيحًا')),
        );
      }
      return;
    }
    await _publish(
      videoId: id,
      title: result['title']?.trim().isEmpty == true
          ? 'YouTube'
          : result['title'],
    );
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
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF240609),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB88732)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
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
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_movies,
                      color: Colors.amber,
                      size: 18,
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
                        onPressed: _openSearch,
                        icon: const Icon(Icons.search, color: Colors.white),
                      ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: widget.canControl ? () => _seekBy(-10) : null,
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: widget.canControl ? _togglePlay : null,
                      icon: Icon(
                        _playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.amber,
                        size: 36,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.canControl ? () => _seekBy(10) : null,
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.volume_down,
                      color: Colors.white70,
                      size: 17,
                    ),
                    Expanded(
                      child: Slider(
                        value: _volume.clamp(0, 1),
                        onChanged: widget.canControl ? _changeVolume : null,
                        activeColor: Colors.amber,
                        inactiveColor: Colors.white24,
                      ),
                    ),
                    const Icon(
                      Icons.volume_up,
                      color: Colors.white70,
                      size: 17,
                    ),
                  ],
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
  final _url = TextEditingController();
  final _title = TextEditingController();
  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 18,
      right: 18,
      top: 18,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'بحث عن فيديو من YouTube',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'الصق رابط الفيديو. البحث بالكلمات يحتاج مفتاح YouTube Data API.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        TextField(
          controller: _url,
          decoration: const InputDecoration(
            labelText: 'رابط YouTube أو Video ID',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'اسم الفيديو (اختياري)',
            prefixIcon: Icon(Icons.title),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () =>
              Navigator.pop(context, {'url': _url.text, 'title': _title.text}),
          icon: const Icon(Icons.play_arrow),
          label: const Text('تشغيل للجميع'),
        ),
      ],
    ),
  );
}
