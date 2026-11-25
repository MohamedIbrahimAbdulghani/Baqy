import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../network/network_checker.dart';
import '../widgets/baqy_logo.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/backup/presentation/controllers/backup_sync_controller.dart';
import '../../features/backup/presentation/providers/backup_providers.dart';
import '../../l10n/app_localizations.dart';

/// Reusable pull-to-refresh widget with an interactive, creative floating logo
/// accompanied by an orbital gradient halo and soft frosted overlay.
class BaqyRefresh extends ConsumerStatefulWidget {
  const BaqyRefresh({
    super.key,
    required this.child,
    this.onRefresh,
    this.refreshProviders = const [],
    this.triggerDistance = 80.0,
    this.minDuration = const Duration(milliseconds: 600),
    this.timeout = const Duration(seconds: 10),
  });

  final Widget child;
  final Future<void> Function()? onRefresh;
  final List<dynamic> refreshProviders;
  final double triggerDistance;
  final Duration minDuration;
  final Duration timeout;

  @override
  ConsumerState<BaqyRefresh> createState() => BaqyRefreshState();
}

class BaqyRefreshState extends ConsumerState<BaqyRefresh>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _floatController;
  late final AnimationController _dismissController;
  late final Animation<double> _dismissAnimation;

  double _pullDistance = 0.0;
  bool _isRefreshing = false;
  bool _hasTriggeredHaptic = false;

  bool get isRefreshing => _isRefreshing;

  @override
  void initState() {
    super.initState();
    // Continuous smooth rotation for the orbital halo ring
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Subtle floating / levitation bobbing for the logo
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dismissAnimation = CurvedAnimation(
      parent: _dismissController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _floatController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  void triggerRefresh() {
    if (!_isRefreshing) {
      _startRefresh();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.extentBefore == 0 &&
          (notification.scrollDelta ?? 0) < 0) {
        final delta = -(notification.scrollDelta ?? 0);
        setState(() {
          _pullDistance = (_pullDistance + delta).clamp(0.0, 160.0);
        });

        if (_pullDistance >= widget.triggerDistance && !_hasTriggeredHaptic) {
          _hasTriggeredHaptic = true;
          HapticFeedback.lightImpact();
        }
      } else if (notification.metrics.extentBefore > 0 && _pullDistance > 0) {
        setState(() {
          _pullDistance = 0.0;
          _hasTriggeredHaptic = false;
        });
      }
    } else if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        final delta = -notification.overscroll;
        setState(() {
          _pullDistance = (_pullDistance + delta).clamp(0.0, 160.0);
        });

        if (_pullDistance >= widget.triggerDistance && !_hasTriggeredHaptic) {
          _hasTriggeredHaptic = true;
          HapticFeedback.lightImpact();
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_pullDistance >= widget.triggerDistance && !_isRefreshing) {
        _startRefresh();
      } else if (!_isRefreshing && _pullDistance > 0) {
        setState(() {
          _pullDistance = 0.0;
          _hasTriggeredHaptic = false;
        });
      }
    }

    return false;
  }

  Future<void> _startRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _pullDistance = widget.triggerDistance;
      _hasTriggeredHaptic = false;
    });

    _spinController.repeat();
    _floatController.repeat(reverse: true);

    final minWaitFuture = Future.delayed(widget.minDuration);
    final actionFuture = _performRefreshAction();

    try {
      await Future.wait([actionFuture, minWaitFuture]).timeout(widget.timeout);
    } catch (_) {
      // Timeout or unexpected error handled gracefully
    } finally {
      if (mounted) {
        _spinController.stop();
        _floatController.stop();
        await _dismissController.forward();
        if (mounted) {
          setState(() {
            _isRefreshing = false;
            _pullDistance = 0.0;
          });
          _dismissController.reset();
        }
      }
    }
  }

  Future<void> _performRefreshAction() async {
    final l10n = AppLocalizations.of(context);
    final isOnline = await NetworkChecker.isOnline();

    if (isOnline) {
      try {
        final user = ref.read(currentUserProvider);
        if (user != null) {
          final syncCtrl = ref.read(backupSyncControllerProvider);
          if (syncCtrl != null) {
            final result = await syncCtrl.syncOnManualRefresh();
            if (result == SyncRefreshResult.failure && mounted && l10n != null) {
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.refreshFailed),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      } catch (_) {
        if (mounted && l10n != null) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.refreshFailed),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      if (mounted && l10n != null) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.refreshOffline),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    try {
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
      _refreshLocalProviders();
    } catch (_) {
      if (mounted && l10n != null) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.refreshFailed),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _refreshLocalProviders() {
    for (final provider in widget.refreshProviders) {
      if (provider != null) {
        ref.invalidate(provider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (_pullDistance / widget.triggerDistance).clamp(0.0, 1.0);
    final showOverlay = _isRefreshing || _pullDistance > 5.0;

    // Content scrolls down smoothly with standard natural pull resistance
    final contentTranslation = _pullDistance * 0.55;

    // Soft frosted backdrop tint
    final overlayColor = (isDark ? AppColors.darkBackground : AppColors.lightBackground)
        .withValues(alpha: isDark ? 0.78 : 0.82);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        children: [
          // 1. Screen content with scroll translation
          Transform.translate(
            offset: Offset(0, contentTranslation),
            child: widget.child,
          ),

          // 2. Creative Frosted Glass & Floating Orbital Logo
          if (showOverlay)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _spinController,
                  _floatController,
                  _dismissController,
                ]),
                builder: (context, _) {
                  final dismissFactor = 1.0 - _dismissAnimation.value;
                  final effectiveAlpha = (_isRefreshing ? 1.0 : progress) * dismissFactor;

                  // Floating vertical bobbing (-5px to +5px) with soft ease
                  final floatOffset = _isRefreshing
                      ? math.sin(_floatController.value * math.pi * 2) * 6.0
                      : 0.0;

                  // Scale: grows as user pulls, subtly breathes while refreshing
                  final baseScale = _isRefreshing
                      ? (1.05 + (math.sin(_floatController.value * math.pi * 2) * 0.03))
                      : (0.70 + (progress * 0.35));
                  final effectiveScale = baseScale * dismissFactor;

                  return IgnorePointer(
                    ignoring: !_isRefreshing,
                    child: Opacity(
                      opacity: effectiveAlpha.clamp(0.0, 1.0),
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                          child: Container(
                            color: overlayColor,
                            alignment: Alignment.center,
                            child: RepaintBoundary(
                              child: Transform.scale(
                                scale: effectiveScale.clamp(0.0, 1.5),
                                child: SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Soft ambient aura glow
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isDark
                                                      ? AppColors.mainGreen
                                                      : AppColors.coinGold)
                                                  .withValues(alpha: 0.22),
                                              blurRadius: 36,
                                              spreadRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Orbital Glowing Ring (Fills on pull, spins on refresh)
                                      CustomPaint(
                                        size: const Size(150, 150),
                                        painter: _OrbitalHaloPainter(
                                          progress: progress,
                                          isRefreshing: _isRefreshing,
                                          spinValue: _spinController.value,
                                          isDark: isDark,
                                        ),
                                      ),

                                      // Floating shadow directly under the emblem
                                      Transform.translate(
                                        offset: const Offset(0, 36),
                                        child: Container(
                                          width: 70 - (floatOffset * 0.8),
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: isDark ? 0.35 : 0.16,
                                                ),
                                                blurRadius: 16 + (floatOffset * 0.5),
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Floating Baqy Logo Emblem
                                      Transform.translate(
                                        offset: Offset(0, floatOffset),
                                        child: const BaqyLogo(size: 92.0),
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
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for the creative orbital gradient halo surrounding the logo
class _OrbitalHaloPainter extends CustomPainter {
  const _OrbitalHaloPainter({
    required this.progress,
    required this.isRefreshing,
    required this.spinValue,
    required this.isDark,
  });

  final double progress;
  final bool isRefreshing;
  final double spinValue;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8.0;

    // Faint track ring
    final trackPaint = Paint()
      ..color = (isDark ? Colors.white : AppColors.mainGreen).withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius, trackPaint);

    // Active orbital arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.8;

    if (!isRefreshing) {
      // Pulling state: arc fills smoothly from top (-pi/2)
      arcPaint.color = AppColors.mainGreen;
      final sweepAngle = progress * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        arcPaint,
      );
    } else {
      // Refreshing state: rotating gradient energy arc
      final startAngle = (spinValue * 2 * math.pi) - (math.pi / 2);
      const sweepAngle = math.pi * 1.45; // ~260 degrees arc

      final rect = Rect.fromCircle(center: center, radius: radius);
      arcPaint.shader = ui.Gradient.sweep(
        center,
        [
          AppColors.mainGreen.withValues(alpha: 0.1),
          AppColors.mainGreen,
          AppColors.coinGold,
        ],
        [0.0, 0.6, 1.0],
        TileMode.clamp,
        startAngle,
        startAngle + sweepAngle,
      );

      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalHaloPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isRefreshing != isRefreshing ||
        oldDelegate.spinValue != spinValue ||
        oldDelegate.isDark != isDark;
  }
}
