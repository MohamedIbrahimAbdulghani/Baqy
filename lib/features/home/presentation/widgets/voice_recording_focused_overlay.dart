import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';

/// Full-screen edge-to-edge immersive Voice Recording Studio.
///
/// Dynamically adapts to active Theme (Dark & Light Mode).
/// Completely covers the screen with an edge-to-edge focused studio,
/// with a large pulsating hero mic, 23-bar soundwave visualizer,
/// digital timer, and spacious Cancel / Send controls.
class VoiceRecordingFocusedOverlay extends ConsumerStatefulWidget {
  const VoiceRecordingFocusedOverlay({
    super.key,
    required this.onStop,
    this.onCancel,
    this.subtitle,
    this.isAnalyzing = false,
  });

  final VoidCallback onStop;
  final VoidCallback? onCancel;
  final String? subtitle;
  final bool isAnalyzing;

  @override
  ConsumerState<VoiceRecordingFocusedOverlay> createState() =>
      _VoiceRecordingFocusedOverlayState();
}

class _VoiceRecordingFocusedOverlayState
    extends ConsumerState<VoiceRecordingFocusedOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !widget.isAnalyzing) {
          HapticFeedback.lightImpact();
          widget.onCancel?.call();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [
                      Color(0xFF0D1612),
                      Color(0xFF13201A),
                      Color(0xFF0A110E),
                    ]
                  : const [
                      Color(0xFFFAF7F2),
                      Color(0xFFF3EFE7),
                      Color(0xFFE9E4D8),
                    ],
            ),
          ),
          child: SafeArea(
            child: widget.isAnalyzing
                ? _buildAnalyzingView(isDark)
                : _buildRecordingView(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingView(bool isDark) {
    return Consumer(
      builder: (context, ref, _) {
        final durationSeconds = ref.watch(voiceRecordingDurationProvider);
        final amplitude = ref.watch(voiceAmplitudeProvider);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // 1. Top Bar: Cancel button + Title + Live badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel 'X' icon
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : AppColors.lightSecondaryText,
                      size: 28.0,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onCancel?.call();
                    },
                    tooltip: 'إلغاء',
                  ),

                  // Title
                  Text(
                    'تسجيل المصاريف بالصوت',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.lightSecondaryText,
                    ),
                  ),

                  // Live Pulsing Dot
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 5.0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(
                        alpha: isDark ? 0.15 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: const Color(0xFFE53935).withValues(
                          alpha: isDark ? 0.35 : 0.25,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            return Container(
                              width: 8.0,
                              height: 8.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE53935).withValues(
                                  alpha: 0.4 + (_pulseController.value * 0.6),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'مباشر',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE53935),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // 2. Central Hero Stage: Pulsing Mic & Audio Wave Rings
              SizedBox(
                width: 220.0,
                height: 220.0,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final dynamicAmp = amplitude.clamp(0.0, 1.0);
                    final pulseVal = _pulseController.value;
                    final scale = 1.0 + (pulseVal * 0.08) + (dynamicAmp * 0.18);
                    final mult = isDark ? 1.0 : 0.8;
                    final outerOpacity = ((0.06 + (pulseVal * 0.06) + (dynamicAmp * 0.15)) * mult).clamp(0.0, 0.35);
                    final middleOpacity = ((0.12 + (pulseVal * 0.08) + (dynamicAmp * 0.2)) * mult).clamp(0.0, 0.45);
                    final innerOpacity = ((0.2 + (pulseVal * 0.1) + (dynamicAmp * 0.25)) * mult).clamp(0.0, 0.6);

                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Outermost ripple ring
                        Transform.scale(
                          scale: scale * 1.25,
                          child: Container(
                            width: 200.0,
                            height: 200.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.mainGreen.withValues(alpha: outerOpacity),
                            ),
                          ),
                        ),
                        // Middle ripple ring
                        Transform.scale(
                          scale: scale * 1.1,
                          child: Container(
                            width: 155.0,
                            height: 155.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.mainGreen.withValues(alpha: middleOpacity),
                            ),
                          ),
                        ),
                        // Inner ripple ring
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 120.0,
                            height: 120.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.mainGreen.withValues(alpha: innerOpacity),
                            ),
                          ),
                        ),
                        child!,
                      ],
                    );
                  },
                  child: Container(
                    width: 92.0,
                    height: 92.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF3BA676),
                          AppColors.mainGreen,
                          Color(0xFF1E5E41),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.mainGreen.withValues(alpha: isDark ? 0.45 : 0.35),
                          blurRadius: 28.0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 46.0,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 3. Digital Large Timer Counter
              Text(
                _formatDuration(durationSeconds),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 38.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),

              const SizedBox(height: 18),

              // 4. Dynamic Soundwave Frequency Visualizer (23 Bars)
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(260, 44),
                      painter: _ImmersiveVoiceWavePainter(
                        waveValue: _waveController.value,
                        amplitude: amplitude,
                        color: AppColors.mainGreen,
                      ),
                    );
                  },
                ),
              ),

              const Spacer(flex: 3),

              // 5. Friendly Tip Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightDividers,
                  ),
                  boxShadow: isDark
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                ),
                child: Text(
                  widget.subtitle ?? 'اتكلم براحتك بالعامية:\n"صرفت 120 جنيه في كارفور و 30 جنيه قهوة"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white.withValues(alpha: 0.75) : AppColors.lightSecondaryText,
                    fontSize: 13.0,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 6. Bottom Dual Actions
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    flex: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onCancel?.call();
                        },
                        borderRadius: BorderRadius.circular(28.0),
                        child: Container(
                          height: 54.0,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(28.0),
                            border: Border.all(
                              color: const Color(0xFFE53935).withValues(alpha: isDark ? 0.4 : 0.3),
                              width: 1.2,
                            ),
                            boxShadow: isDark
                                ? const []
                                : const [
                                    BoxShadow(
                                      color: Color(0x0A000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: isDark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Send / Finish Button
                  Expanded(
                    flex: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onStop();
                        },
                        borderRadius: BorderRadius.circular(28.0),
                        child: Container(
                          height: 54.0,
                          decoration: BoxDecoration(
                            color: AppColors.mainGreen,
                            borderRadius: BorderRadius.circular(28.0),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.mainGreen.withValues(alpha: isDark ? 0.4 : 0.3),
                                blurRadius: 16.0,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.check_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'تم، احسبها',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyzingView(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _waveController,
            child: Container(
              width: 110.0,
              height: 110.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.mainGreen.withValues(alpha: isDark ? 0.3 : 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.mainGreen,
                  size: 64,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'بحلل كلامك دلوقتي…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ثواني وهنستخرج كل المصاريف بدقة ونعرضها عليك للتأكيد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14.0,
              color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.lightSecondaryText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          const SizedBox(
            width: 36.0,
            height: 36.0,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.mainGreen),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic wave painter rendering 23 symmetrical frequency bars for the immersive studio
class _ImmersiveVoiceWavePainter extends CustomPainter {
  _ImmersiveVoiceWavePainter({
    required this.waveValue,
    required this.amplitude,
    required this.color,
  });

  final double waveValue;
  final double amplitude;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 23;
    const double barWidth = 3.5;
    const double barRadius = 2.0;
    final double spacing =
        (size.width - (barCount * barWidth)) / (barCount - 1);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final double progress = (i + 1) / (barCount + 1);
      final double bell = math.sin(progress * math.pi); // bell curve
      final double ripple =
          (math.sin(waveValue * 2 * math.pi + (i * 0.45)) + 1) / 2;
      final double idleHeight = 6.0 + (ripple * 5.0 * bell);
      final double voiceHeight = amplitude * 32.0 * bell;
      final double totalHeight =
          (idleHeight + voiceHeight).clamp(5.0, size.height);

      final double x = i * (barWidth + spacing);
      final double y = (size.height - totalHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, totalHeight),
        const Radius.circular(barRadius),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ImmersiveVoiceWavePainter oldDelegate) {
    return oldDelegate.waveValue != waveValue ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color;
  }
}
