import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/custom_toast.dart';
import '../../shared/widgets/saki_widgets.dart';

const _loveGold = Color(0xFFFFD77A);
const _lovePink = Color(0xFFFF6B91);
const _loveInk = Color(0xFF170F20);
const _lovePanel = Color(0xD91C1424);
const _loveAssets = 'assets/love_house/';

class LoveHousePage extends StatefulWidget {
  const LoveHousePage({super.key});

  @override
  State<LoveHousePage> createState() => _LoveHousePageState();
}

class _LoveHousePageState extends State<LoveHousePage> {
  Map<String, dynamic> _state = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final state = await SakiService.instance.loveHouseState();
      if (mounted) setState(() => _state = state);
    } catch (error) {
      if (mounted) {
        CustomToast.show(context, _loveError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invitePartner() async {
    final recipientId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LoveMutualFriendsSheet(),
    );
    if (recipientId == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (_) => const _LoveInviteConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await SakiService.instance.sendLovePartnerInvite(recipientId);
      if (!mounted) return;
      CustomToast.show(context, 'تم إرسال الدعوة؛ خُصم 300,000 ذهب مؤقتًا');
      await _load();
    } catch (error) {
      if (mounted) CustomToast.show(context, _loveError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endRelationship() async {
    final relationship = _asMap(_state['relationship']);
    final relationshipId = relationship['id']?.toString();
    if (relationshipId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF211728),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'إنهاء علاقة بيت الحب؟',
          textAlign: TextAlign.right,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'سيُفك ارتباط الخاتم وتختفي العلاقة من بيتكما. لا يوجد استرداد لرسوم إنشاء العلاقة بعد قبول الدعوة.',
          textAlign: TextAlign.right,
          style: TextStyle(color: Color(0xFFD6C8D7), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB4234F),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء العلاقة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await SakiService.instance.endLoveRelationship(relationshipId);
      if (!mounted) return;
      CustomToast.show(context, 'تم فك ارتباط بيت الحب');
      await _load();
    } catch (error) {
      if (mounted) CustomToast.show(context, _loveError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _asMap(_state['profile']);
    final relationship = _asMap(_state['relationship']);
    final partner = _asMap(relationship['partner']);
    final outgoing = _asMap(_state['outgoing_invite']);
    final incoming = _asMap(_state['incoming_invite']);
    final hasRelationship = relationship.isNotEmpty;
    final goldBalance = (_state['gold_balance'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: _loveInk,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            '${_loveAssets}palace_background.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: _loveInk),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x990D0811),
                  Color(0x66160C18),
                  Color(0xF2110B17),
                ],
              ),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: _LoveWaveLayer())),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  left: 8,
                  child: hasRelationship
                      ? PopupMenuButton<String>(
                          tooltip: 'خيارات بيت الحب',
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            size: 28,
                          ),
                          color: const Color(0xFF24182B),
                          onSelected: (_) => _endRelationship(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'unlink',
                              child: Text(
                                'إلغاء ربط خاتم CP',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(width: 48, height: 48),
                ),
                Positioned(
                  top: 8,
                  right: 14,
                  child: IconButton(
                    tooltip: 'رجوع',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 58, 18, 20),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _loveGold),
                        )
                      : RefreshIndicator(
                          color: _loveGold,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 4),
                              const Text(
                                'بيت الحب',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _loveGold,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 7),
                              const Text(
                                'حكاية تبدأ بمتابعة متبادلة وخاتم واحد',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFF2DDEA),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 22),
                              _GoldBalanceCard(balance: goldBalance),
                              const SizedBox(height: 22),
                              if (hasRelationship)
                                _RelationshipCard(
                                  profile: profile,
                                  partner: partner,
                                  relationship: relationship,
                                )
                              else
                                _EmptyLoveHouse(
                                  outgoing: outgoing,
                                  incoming: incoming,
                                  busy: _busy,
                                  onInvite: _invitePartner,
                                ),
                              const SizedBox(height: 18),
                              const SizedBox(height: 18),
                              const _MutualFollowNote(),
                            ],
                          ),
                        ),
                ),
                if (_busy)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: .35),
                      child: const Center(
                        child: CircularProgressIndicator(color: _loveGold),
                      ),
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

class _RelationshipCard extends StatelessWidget {
  const _RelationshipCard({
    required this.profile,
    required this.partner,
    required this.relationship,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic> partner;
  final Map<String, dynamic> relationship;

  @override
  Widget build(BuildContext context) {
    final startedAt = DateTime.tryParse(
      relationship['started_at']?.toString() ?? '',
    );
    final daysTogether = startedAt == null
        ? 1
        : math.max(1, DateTime.now().difference(startedAt).inDays + 1);
    final myName = _displayName(profile);
    final partnerName = _displayName(partner);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: _lovePanel,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _loveGold.withValues(alpha: .68), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _lovePink.withValues(alpha: .16),
            blurRadius: 35,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'مرتبطان في بيت الحب',
            style: TextStyle(
              color: _loveGold,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _FramedPartner(profile: profile, name: myName),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _PulsingRing(),
              ),
              Expanded(
                child: _FramedPartner(profile: partner, name: partnerName),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0x33201228),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _loveGold.withValues(alpha: .35)),
            ),
            child: Text(
              'معًا منذ $daysTogether ${daysTogether == 1 ? 'يوم' : 'يومًا'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'يحفظ بيت الحب ذكرى ارتباطكما وخاتمكما الملكي.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD9CADC),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FramedPartner extends StatelessWidget {
  const _FramedPartner({required this.profile, required this.name});
  final Map<String, dynamic> profile;
  final String name;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SakiAvatar(
              url: profile['avatar_url']?.toString(),
              label: name,
              radius: 34,
            ),
            Image.asset(
              '${_loveAssets}royal_avatar_frame.webp',
              width: 104,
              height: 104,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 5),
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
      if (profile['saki_id'] != null)
        Text(
          'ID ${profile['saki_id']}',
          style: const TextStyle(color: Color(0xFFD8C4D9), fontSize: 10),
        ),
    ],
  );
}

class _PulsingRing extends StatefulWidget {
  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1550),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.scale(
      scale: .88 + _controller.value * .16,
      child: Transform.rotate(
        angle: math.sin(_controller.value * math.pi * 2) * .06,
        child: child,
      ),
    ),
    child: Image.asset(
      '${_loveAssets}royal_couple_ring.webp',
      width: 64,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.favorite, color: _loveGold, size: 48),
    ),
  );
}

class _EmptyLoveHouse extends StatelessWidget {
  const _EmptyLoveHouse({
    required this.outgoing,
    required this.incoming,
    required this.busy,
    required this.onInvite,
  });

  final Map<String, dynamic> outgoing;
  final Map<String, dynamic> incoming;
  final bool busy;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final hasPending = outgoing.isNotEmpty;
    final recipient = _asMap(incoming['sender']);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 23),
      decoration: BoxDecoration(
        color: _lovePanel,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _loveGold.withValues(alpha: .52)),
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite_border_rounded, color: _lovePink, size: 48),
          const SizedBox(height: 11),
          Text(
            hasPending ? 'دعوتك بانتظار الرد' : 'أنشئ علاقتك الأولى',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPending
                ? 'أُرسلت دعوة الشريك، وهي بانتظار الرد. تنتهي خلال 7 أيام إذا لم يصل رد.'
                : 'اختر صديقًا تتابعانه بعضكما. عند إرسال الدعوة يُخصم 300,000 ذهب مؤقتًا ويُعاد عند الرفض أو انتهاء المهلة.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD8C8D9),
              height: 1.6,
              fontSize: 12,
            ),
          ),
          if (incoming.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SakiAvatar(
                  url: recipient['avatar_url']?.toString(),
                  label: _displayName(recipient),
                  radius: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'لديك دعوة من ${_displayName(recipient)}؛ افتح رسائل النظام للرد.',
                    style: const TextStyle(
                      color: _loveGold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
          if (!hasPending) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onInvite,
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('دعوة شريك'),
                style: FilledButton.styleFrom(
                  foregroundColor: _loveInk,
                  backgroundColor: _loveGold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoldBalanceCard extends StatelessWidget {
  const _GoldBalanceCard({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xB319101E),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _loveGold.withValues(alpha: .35)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.monetization_on_rounded, color: _loveGold, size: 21),
        const SizedBox(width: 8),
        const Text(
          'رصيد الذهب',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 9),
        Text(
          _formatGold(balance),
          style: const TextStyle(
            color: _loveGold,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

class _MutualFollowNote extends StatelessWidget {
  const _MutualFollowNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0x66160C18),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: const Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: _loveGold, size: 18),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'يشترط أن يتابع كل منكما الآخر. الدعوة صالحة 7 أيام، ويُعاد الذهب كاملًا عند الرفض أو انتهاء الصلاحية. إنهاء علاقة مقبولة لا يعيد رسوم إنشائها.',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFFE4D6E4),
              height: 1.55,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoveMutualFriendsSheet extends StatefulWidget {
  const _LoveMutualFriendsSheet();

  @override
  State<_LoveMutualFriendsSheet> createState() =>
      _LoveMutualFriendsSheetState();
}

class _LoveMutualFriendsSheetState extends State<_LoveMutualFriendsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _friends = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await SakiService.instance.loveMutualFriends();
      if (mounted) setState(() => _friends = rows);
    } catch (error) {
      if (mounted) CustomToast.show(context, _loveError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _friends.where((friend) {
      final name =
          '${friend['display_name'] ?? ''} ${friend['username'] ?? ''} ${friend['saki_id'] ?? ''}';
      return name.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();
    return Container(
      height: MediaQuery.sizeOf(context).height * .78,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1420),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'أصدقاؤك المتابعون لك',
              style: TextStyle(
                color: _loveGold,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'تظهر هنا الحسابات التي تتابعها وتتابعك',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                textDirection: TextDirection.rtl,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو معرّف SAKI',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(Icons.search, color: _loveGold),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _loveGold),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          _friends.isEmpty
                              ? 'لا يوجد أصدقاء بمتابعة متبادلة بعد.'
                              : 'لا توجد نتيجة مطابقة.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final friend = filtered[index];
                        final name = _displayName(friend);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          leading: SakiAvatar(
                            url: friend['avatar_url']?.toString(),
                            label: name,
                            radius: 24,
                          ),
                          title: Text(
                            name,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            'ID ${friend['saki_id'] ?? '—'}',
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          trailing: FilledButton(
                            onPressed: () =>
                                Navigator.of(context)
                                    .pop(friend['id']?.toString()),
                            style: FilledButton.styleFrom(
                              backgroundColor: _loveGold,
                              foregroundColor: _loveInk,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'دعوة شريك',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoveInviteConfirmDialog extends StatelessWidget {
  const _LoveInviteConfirmDialog();

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 390,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              '${_loveAssets}palace_background.webp',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xC80E0812), Color(0xE80F0914)],
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: _LoveWaveLayer()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, color: _loveGold, size: 28),
                  const SizedBox(height: 5),
                  const Text(
                    'دعوة ملكية إلى بيت الحب',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _loveGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Image.asset(
                    '${_loveAssets}royal_couple_ring.webp',
                    width: 94,
                    height: 94,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'سيُخصم عند الإرسال',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '300,000 ذهب',
                    style: TextStyle(
                      color: _loveGold,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ستنتهي الدعوة بعد 7 أيام. يُعاد المبلغ كاملًا إذا رُفضت الدعوة أو انتهت دون قبول.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFF1DFEE),
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _loveGold,
                            foregroundColor: _loveInk,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'إرسال الدعوة',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LoveWaveLayer extends StatefulWidget {
  const _LoveWaveLayer();

  @override
  State<_LoveWaveLayer> createState() => _LoveWaveLayerState();
}

class _LoveWaveLayerState extends State<_LoveWaveLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => CustomPaint(
      painter: _LoveWavePainter(_controller.value),
      child: const SizedBox.expand(),
    ),
  );
}

class _LoveWavePainter extends CustomPainter {
  _LoveWavePainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (var band = 0; band < 3; band++) {
      final path = Path();
      final baseY = size.height * (.56 + band * .12);
      final amplitude = 9.0 + band * 3.5;
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 8) {
        final y =
            baseY +
            math.sin(
                  (x / size.width * math.pi * 2) + phase * math.pi * 2 + band,
                ) *
                amplitude;
        path.lineTo(x, y);
      }
      final paint = Paint()
        ..color = (band == 1 ? _lovePink : _loveGold).withValues(
          alpha: .075 + band * .018,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoveWavePainter oldDelegate) =>
      oldDelegate.phase != phase;
}

String _displayName(Map<String, dynamic> profile) {
  final display = profile['display_name']?.toString().trim();
  if (display != null && display.isNotEmpty) return display;
  final username = profile['username']?.toString().trim();
  if (username != null && username.isNotEmpty) return username;
  return 'مستخدم SAKI';
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _formatGold(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

String _loveError(Object error) {
  final text = error.toString();
  if (text.contains('insufficient_gold')) {
    return 'رصيد الذهب غير كافٍ؛ تحتاج إلى 300,000 ذهب.';
  }
  if (text.contains('mutual_follow_required')) {
    return 'يجب أن تتابعا بعضكما قبل إرسال الدعوة.';
  }
  if (text.contains('user_already_has_love_partner')) {
    return 'أحدكما مرتبط بالفعل في بيت الحب.';
  }
  if (text.contains('pending_love_invitation_exists')) {
    return 'لدى أحدكما دعوة شريك أخرى قيد الانتظار.';
  }
  if (text.contains('love_partner_not_found')) {
    return 'تعذر العثور على الحساب المطلوب.';
  }
  return 'تعذر إكمال العملية الآن. تحقق من الاتصال ثم حاول مجددًا.';
}
