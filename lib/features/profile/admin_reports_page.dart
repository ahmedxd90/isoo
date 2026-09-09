import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/data/saki_service.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = SakiService.instance.adminReports();
  }

  void _reload() =>
      setState(() => _future = SakiService.instance.adminReports());

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FAFC),
    appBar: AppBar(
      title: const Text('بلاغات المستخدمين'),
      backgroundColor: const Color(0xFFF97316),
      foregroundColor: Colors.white,
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بلاغات'));
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _ReportCard(row: rows[i], onChanged: _reload),
          ),
        );
      },
    ),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.row, required this.onChanged});
  final Map<String, dynamic> row;
  final VoidCallback onChanged;
  String _name(String key) =>
      (row[key] is Map ? row[key]['username'] : null)?.toString() ?? 'مستخدم';
  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'new';
    final evidence = row['evidence_url']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'بلاغ ضد ${_name('reported')}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusMenu(
                id: row['id'].toString(),
                status: status,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'من: ${_name('reporter')}  •  ${row['category'] ?? 'غير محدد'}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          if ((row['details']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(row['details'].toString()),
          ],
          if (evidence != null && evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            _EvidenceButton(url: evidence),
          ],
        ],
      ),
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({
    required this.id,
    required this.status,
    required this.onChanged,
  });
  final String id, status;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    initialValue: status,
    onSelected: (value) async {
      await SakiService.instance.adminUpdateReportStatus(id, value);
      onChanged();
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'new', child: Text('جديد')),
      PopupMenuItem(value: 'reviewing', child: Text('قيد المراجعة')),
      PopupMenuItem(value: 'resolved', child: Text('تمت المعالجة')),
      PopupMenuItem(value: 'rejected', child: Text('مرفوض')),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFFF97316),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _EvidenceButton extends StatelessWidget {
  const _EvidenceButton({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showDialog<void>(
      context: context,
      builder: (_) => _VideoDialog(url: url),
    ),
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFE9FBFD),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill_rounded, color: Color(0xFF06B6D4)),
          SizedBox(width: 7),
          Text(
            'مشاهدة فيديو الإثبات',
            style: TextStyle(
              color: Color(0xFF087F8C),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.url});
  final String url;
  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final VideoPlayerController controller;
  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          )
        : const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
    actions: [
      TextButton(
        onPressed: () {
          controller.value.isPlaying ? controller.pause() : controller.play();
          setState(() {});
        },
        child: Text(controller.value.isPlaying ? 'إيقاف' : 'تشغيل'),
      ),
    ],
  );
}
