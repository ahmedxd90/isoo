from pathlib import Path
p=Path('/home/ubuntu/isoo/lib/features/rooms/saki_wheel_game_sheet.dart')
s=p.read_text()
start=s.index('  Widget _wheel()')
end=s.index('  Widget _summary()', start)
replacement=r'''  Widget _wheel() {
    return LayoutBuilder(builder: (_, constraints) {
      final size = math.min(constraints.maxWidth, constraints.maxHeight) * .9;
      final items = <Widget>[];
      for (var i = 0; i < _foods.length; i++) {
        final angle = 2 * math.pi * i / _foods.length - math.pi / 2;
        final food = _foods[i];
        final key = food['key'] as String;
        final active = _winner == key ||
            (_round?['status'] == 'result' && _seconds % _foods.length == i);
        items.add(Positioned(
          left: size * .5 + math.cos(angle) * size * .29 - 34,
          top: size * .5 + math.sin(angle) * size * .29 - 34,
          child: GestureDetector(onTap: () => _bet(key), child: _foodBubble(food, active)),
        ));
      }
      items.add(Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('SAKI', style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 22)),
        Text(_winner == null ? 'اختَر واربح' : _food(_winner!)['emoji'] as String, style: const TextStyle(fontSize: 38)),
      ])));
      return SizedBox(width: size, height: size, child: Stack(children: [
        Center(child: Container(width: size * .78, height: size * .78, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF174EB0), border: Border.all(color: _gold, width: 8), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18)]))),
        ...items,
      ]);
    });
  }

  Widget _foodBubble(Map<String, dynamic> food, bool active) {
    final key = food['key'] as String;
    return AnimatedBuilder(animation: _pulse, builder: (_, child) => Transform.scale(
      scale: active ? 1 + _pulse.value * .16 : 1,
      child: Container(width: 68, height: 68, decoration: BoxDecoration(color: active ? Colors.white : Colors.white.withValues(alpha: .93), shape: BoxShape.circle, border: Border.all(color: active ? _gold : Colors.white38, width: active ? 4 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(food['emoji'] as String, style: const TextStyle(fontSize: 26)),
        Text('×${food['x']}', style: TextStyle(color: active ? _blue : Colors.black87, fontSize: 10, fontWeight: FontWeight.w900)),
        if ((_bets[key] ?? 0) > 0) Text('you: ${_bets[key]}', style: const TextStyle(color: _blue, fontSize: 9, fontWeight: FontWeight.w900)),
      ])),
    ));
  }
'''
p.write_text(s[:start]+replacement+s[end:])
