import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SakiAvatar extends StatelessWidget {
  const SakiAvatar({super.key, this.url, this.radius = 22, this.label});
  final String? url;
  final double radius;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: SakiColors.royalPurple.withValues(alpha: .25),
      backgroundImage: url == null || url!.isEmpty
          ? null
          : CachedNetworkImageProvider(url!),
      child: url == null || url!.isEmpty
          ? Text(
              (label?.isNotEmpty ?? false) ? label![0].toUpperCase() : 'S',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: radius * .65,
              ),
            )
          : null,
    );
  }
}

class GradientIconBadge extends StatelessWidget {
  const GradientIconBadge({super.key, required this.icon, this.size = 42});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: SakiTheme.gradient,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(icon, color: Colors.white, size: size * .48),
    );
  }
}

class SakiLoading extends StatelessWidget {
  const SakiLoading({super.key, this.label = 'جاري التحميل...'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: SakiColors.cyan),
            const SizedBox(height: 14),
            Text(label, style: const TextStyle(color: SakiColors.muted)),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: SakiColors.royalPurple),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SakiColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}
