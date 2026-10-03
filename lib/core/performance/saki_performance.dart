import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Lightweight, conservative performance policy for Android devices.
/// It does not disable application features; it only limits decoded image
/// memory and exposes lifecycle state to media widgets.
class SakiPerformance {
  SakiPerformance._();

  static final ValueNotifier<bool> appInBackground = ValueNotifier<bool>(false);
  static SakiPerformanceTier tier = SakiPerformanceTier.balanced;
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    tier = _detectTier();
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = switch (tier) {
      SakiPerformanceTier.low => 60,
      SakiPerformanceTier.balanced => 100,
      SakiPerformanceTier.high => 160,
    };
    imageCache.maximumSizeBytes = switch (tier) {
      SakiPerformanceTier.low => 24 * 1024 * 1024,
      SakiPerformanceTier.balanced => 48 * 1024 * 1024,
      SakiPerformanceTier.high => 80 * 1024 * 1024,
    };
    WidgetsBinding.instance.addObserver(_LifecycleObserver());
  }

  static int cacheWidthFor(BuildContext context, double logicalWidth) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cap = switch (tier) {
      SakiPerformanceTier.low => 720,
      SakiPerformanceTier.balanced => 1080,
      SakiPerformanceTier.high => 1440,
    };
    return (logicalWidth * dpr).round().clamp(96, cap);
  }

  static SakiPerformanceTier _detectTier() {
    if (kIsWeb) return SakiPerformanceTier.high;
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return SakiPerformanceTier.balanced;
    final view = views.first;
    final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
    final pixels = view.physicalSize.width * view.physicalSize.height;
    final processors = Platform.numberOfProcessors;
    if (processors <= 4 || logicalWidth < 360 || pixels < 1.6e6) {
      return SakiPerformanceTier.low;
    }
    if (processors >= 8 && pixels >= 3.0e6) {
      return SakiPerformanceTier.high;
    }
    return SakiPerformanceTier.balanced;
  }
}

enum SakiPerformanceTier { low, balanced, high }

class _LifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SakiPerformance.appInBackground.value = switch (state) {
      AppLifecycleState.resumed => false,
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached ||
      AppLifecycleState.hidden => true,
    };
  }
}
