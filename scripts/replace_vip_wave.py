from pathlib import Path
p = Path('/home/ubuntu/work/repo/lib/features/rooms/rooms_page.dart')
s = p.read_text()
start = s.index('class _VipVoiceWaveState')
replacement = '''class _VipVoiceWaveState extends State<_VipVoiceWave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = (widget.profile['vip_level'] as num?)?.toInt() ?? 0;
    final colors = level >= 6
        ? const [Colors.red, Colors.amber, Colors.blue]
        : const [Color(0xFF38BDF8), Color(0xFF2563EB), Color(0xFF38BDF8)];
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final size = 56 + (_controller.value * 5);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors[1].withValues(alpha: .9), width: 2),
            boxShadow: [BoxShadow(color: colors[0].withValues(alpha: .55), blurRadius: 10, spreadRadius: 2)],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final height = 8.0 + (((i + 1) % 3) * 5) + (_controller.value * 4);
                return Container(
                  width: 3,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(4)),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
'''
p.write_text(s[:start] + replacement)
