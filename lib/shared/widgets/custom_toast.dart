import 'dart:async';

import 'package:flutter/material.dart';

class CustomToast {
  CustomToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    Color accent = const Color(0xFFB78CFF),
    Duration duration = const Duration(seconds: 3),
  }) {
    final text = message.trim();
    if (text.isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _timer?.cancel();
    _entry?.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _ToastOverlay(
        message: text,
        icon: icon,
        accent: accent,
        onFinished: () {
          if (_entry == entry) {
            entry.remove();
            _entry = null;
          }
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () {
      if (_entry == entry) {
        entry.remove();
        _entry = null;
      }
    });
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.accent,
    required this.onFinished,
    this.icon,
  });

  final String message;
  final IconData? icon;
  final Color accent;
  final VoidCallback onFinished;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 18;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOut,
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: .92, end: 1).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xED171522),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: .42),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .28),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: widget.accent.withValues(alpha: .12),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Container(
                              width: 25,
                              height: 25,
                              decoration: BoxDecoration(
                                color: widget.accent.withValues(alpha: .16),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.icon,
                                color: widget.accent,
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 9),
                          ],
                          Flexible(
                            child: Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
