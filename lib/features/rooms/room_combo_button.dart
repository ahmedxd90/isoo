import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoomComboButton extends StatefulWidget {
  const RoomComboButton({
    super.key,
    required this.count,
    required this.isSending,
    required this.duration,
    required this.onTap,
    required this.onExpired,
  });

  final int count;
  final bool isSending;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onExpired;

  @override
  State<RoomComboButton> createState() => _RoomComboButtonState();
}

class _RoomComboButtonState extends State<RoomComboButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onCountdownStatus)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant RoomComboButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _countdown.duration = widget.duration;
    }
  }

  void _onCountdownStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      widget.onExpired();
    }
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _countdown.forward(from: 0);
    widget.onTap();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _countdown,
    builder: (context, _) {
      final secondsLeft =
          (widget.duration.inMilliseconds * (1 - _countdown.value) / 1000)
              .ceil()
              .clamp(0, widget.duration.inSeconds)
              .toInt();
      final progress = (1 - _countdown.value).clamp(0.0, 1.0);

      return Semantics(
        button: true,
        label: 'كومبو ${widget.count}، تبقى $secondsLeft ثوانٍ',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _handleTap,
          child: AnimatedScale(
            scale: _pressed ? .91 : 1,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutBack,
            child: SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: 108,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: .2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFE58A),
                      ),
                    ),
                  ),
                  Container(
                    width: 91,
                    height: 91,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFC857), Color(0xFFF07812)],
                      ),
                      border: Border.all(color: Colors.white38, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9D28).withValues(alpha: .5),
                          blurRadius: _pressed ? 8 : 18,
                          spreadRadius: _pressed ? 1 : 3,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'كومبو',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '×${widget.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$secondsLeftث',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isSending)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFF9A4D0A),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
