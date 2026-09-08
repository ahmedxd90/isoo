import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/data/saki_service.dart';

const _redeemOrange = Color(0xFFF97316);
const _redeemCyan = Color(0xFF06B6D4);
const _redeemInk = Color(0xFF172033);

class RedeemCodePage extends StatefulWidget {
  const RedeemCodePage({super.key});
  @override
  State<RedeemCodePage> createState() => _RedeemCodePageState();
}

class _RedeemCodePageState extends State<RedeemCodePage> {
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _code.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6,12}$').hasMatch(code)) {
      _showResult(
        success: false,
        title: 'صيغة الكود غير صحيحة',
        message: 'استخدم أحرفًا وأرقامًا من 6 إلى 12 خانة.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await SakiService.instance.redeemSakiCode(code);
      if (!mounted) return;
      await _showResult(
        success: true,
        title: 'تم استرداد الكود بنجاح',
        result: result,
      );
      if (mounted) _code.clear();
    } catch (error) {
      if (!mounted) return;
      final key = error.toString();
      final message = key.contains('code_already_used')
          ? 'تم استخدام هذا الكود من حسابك مسبقًا.'
          : key.contains('code_expired')
          ? 'انتهت صلاحية هذا الكود.'
          : key.contains('code_max_uses_reached')
          ? 'تم الوصول إلى الحد الأقصى لاستخدام هذا الكود.'
          : key.contains('code_inactive')
          ? 'هذا الكود غير فعال حاليًا.'
          : key.contains('code_not_found')
          ? 'الكود غير صحيح أو غير موجود.'
          : 'تعذر استرداد الكود. حاول مرة أخرى.';
      _showResult(success: false, title: 'فشل استرداد الكود', message: message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showResult({
    required bool success,
    required String title,
    String? message,
    Map<String, dynamic>? result,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RedeemResultSheet(
        success: success,
        title: title,
        message: message,
        result: result,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8FC),
    appBar: AppBar(
      title: const Text(
        'استرداد كود',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: _redeemInk,
      elevation: 0,
      surfaceTintColor: Colors.white,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [_redeemOrange, _redeemCyan],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2206B6D4),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              children: [
                FaIcon(FontAwesomeIcons.ticket, color: Colors.white, size: 34),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'استرداد مكافآتك',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'أدخل كودًا صالحًا لتحصل على المكافآت المرتبطة به.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'كود الاسترداد',
            style: TextStyle(color: _redeemInk, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 12,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'مثال: SAKI2026',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const FaIcon(
                FontAwesomeIcons.ticket,
                color: _redeemCyan,
                size: 17,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _redeemCyan, width: 2),
              ),
            ),
            onChanged: (value) {
              final upper = value.toUpperCase().replaceAll(
                RegExp(r'[^A-Z0-9]'),
                '',
              );
              if (upper != value) {
                _code.value = TextEditingValue(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              }
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _loading ? null : _redeem,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const FaIcon(FontAwesomeIcons.gift, size: 17),
              label: Text(
                _loading ? 'جارٍ التحقق...' : 'استرداد الكود',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _redeemOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'كل كود يمكن استخدامه مرة واحدة فقط لكل مستخدم، وتتحقق قاعدة البيانات من الصلاحية والحد الأقصى قبل إضافة أي مكافأة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

class _RedeemResultSheet extends StatelessWidget {
  const _RedeemResultSheet({
    required this.success,
    required this.title,
    this.message,
    this.result,
  });
  final bool success;
  final String title;
  final String? message;
  final Map<String, dynamic>? result;

  @override
  Widget build(BuildContext context) {
    final rewards =
        (result?['rewards'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    return Container(
      constraints: const BoxConstraints(maxHeight: 620),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 34,
                backgroundColor: success
                    ? const Color(0xFFE9FBEF)
                    : const Color(0xFFFFF1F2),
                child: Icon(
                  success ? Icons.check_rounded : Icons.error_outline_rounded,
                  color: success ? Colors.green : Colors.red,
                  size: 38,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _redeemInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 9),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              if (success && rewards.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'المكافآت التي حصلت عليها',
                    style: TextStyle(
                      color: _redeemInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...rewards.map((reward) => _RewardTile(reward: reward)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: success ? _redeemCyan : _redeemOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'حسنًا',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.reward});
  final Map<String, dynamic> reward;
  @override
  Widget build(BuildContext context) {
    final type = reward['type']?.toString();
    final title = type == 'gold'
        ? '${reward['quantity'] ?? 0} عملة ذهبية'
        : type == 'vip'
        ? 'VIP ${reward['level'] ?? 0}'
        : type == 'wealth'
        ? 'رفع مستوى الثروة إلى ${reward['level'] ?? 0}'
        : (reward['name'] ?? 'عنصر من المتجر').toString();
    final subtitle = reward['expires_at'] == null
        ? 'مكافأة دائمة'
        : 'ينتهي في ${_formatDate(reward['expires_at'].toString())}';
    final asset = type == 'vip'
        ? 'assets/trace_vip/images/ic_vip_${reward['level'] ?? 1}.png'
        : type == 'store_item'
        ? 'assets/trace_profile/images/${reward['asset_key'] ?? 'ic_guard_avatar_frame.webp'}'
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: asset == null
                ? FaIcon(
                    type == 'gold'
                        ? FontAwesomeIcons.coins
                        : type == 'wealth'
                        ? FontAwesomeIcons.chartLine
                        : FontAwesomeIcons.gift,
                    color: type == 'gold' ? Colors.amber : _redeemCyan,
                  )
                : Image.asset(
                    asset,
                    errorBuilder: (_, _, _) =>
                        const FaIcon(FontAwesomeIcons.gift, color: _redeemCyan),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _redeemInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
