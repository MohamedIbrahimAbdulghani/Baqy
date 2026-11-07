import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';

class HomeSpeedDialFab extends ConsumerStatefulWidget {
  const HomeSpeedDialFab({super.key});

  @override
  ConsumerState<HomeSpeedDialFab> createState() => _HomeSpeedDialFabState();
}

class _HomeSpeedDialFabState extends ConsumerState<HomeSpeedDialFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _isOpen ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
        ref.read(voiceRecordingProvider.notifier).preInitialize();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(voiceRecordingProvider);
    final isAnalyzing = ref.watch(voiceIsAnalyzingProvider);
    final pendingAudio = ref.watch(pendingVoiceAudioPathProvider);

    if (isAnalyzing) {
      return const _VoiceAnalyzingCard();
    }

    if (isRecording) {
      return _VoiceRecordingStopButton(
        onStop: () {
          ref.read(voiceRecordingProvider.notifier).stopRecording(context: context);
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Unsaved pending recording banner if app closed before saving
        if (pendingAudio != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14.0),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: Colors.amber.shade600,
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10.0,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mic_external_on_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'عندك تسجيل لسه ما اتحفظش',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref
                        .read(voiceRecordingProvider.notifier)
                        .processAudioFile(pendingAudio, context: context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(40, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'معالجة',
                    style: TextStyle(
                      color: AppColors.mainGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.secondaryText,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    ref
                        .read(voiceRecordingProvider.notifier)
                        .discardPendingAudio();
                  },
                ),
              ],
            ),
          ),
        // Upper two buttons: expand smoothly upwards without taking space when closed
        SizeTransition(
          sizeFactor: _expandAnimation,
          alignment: Alignment.bottomCenter, // Expands from bottom upwards
          child: ScaleTransition(
            scale: _expandAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Button 2 (Pencil - top)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _ActionCircleButton(
                    icon: Icons.edit_outlined,
                    onTap: () {
                      _close();
                      context.push('/add-expense');
                    },
                  ),
                ),

                // Button 1 (Mic - middle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _ActionCircleButton(
                    icon: Icons.mic_none_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _close();
                      ref
                          .read(voiceRecordingProvider.notifier)
                          .startRecording(context: context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Main "+" / "x" Button
        Container(
          width: 58.0,
          height: 58.0,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.mainGreen,
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _toggle,
              customBorder: const CircleBorder(),
              child: Center(
                child: AnimatedRotation(
                  turns: _isOpen ? 0.125 : 0.0, // 45 degrees rotation turns + to x
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 30.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceRecordingStopButton extends StatefulWidget {
  const _VoiceRecordingStopButton({required this.onStop});

  final VoidCallback onStop;

  @override
  State<_VoiceRecordingStopButton> createState() =>
      _VoiceRecordingStopButtonState();
}

class _VoiceRecordingStopButtonState extends State<_VoiceRecordingStopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Live feedback card with timer and amplitude level (no live text)
        Consumer(
          builder: (context, ref, _) {
            final durationSeconds = ref.watch(voiceRecordingDurationProvider);
            final amplitude = ref.watch(voiceAmplitudeProvider);

            return Container(
              margin: const EdgeInsets.only(bottom: 24.0),
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              constraints: const BoxConstraints(maxWidth: 290),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: AppColors.mainGreen.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 14.0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              return Container(
                                width: 9.0,
                                height: 9.0,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.4 + (_pulseController.value * 0.6),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'بسجل...',
                            style: TextStyle(
                              color: AppColors.mainGreen,
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Duration counter (e.g. 00:34)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mainGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          _formatDuration(durationSeconds),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Mic amplitude level wave bars to ensure mic is active
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.mic_rounded,
                        size: 16,
                        color: AppColors.mainGreen,
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(7, (i) {
                        const weights = [0.35, 0.6, 0.9, 1.0, 0.75, 0.5, 0.3];
                        final barHeight =
                            6.0 + (amplitude * 18.0 * weights[i]);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          margin: const EdgeInsets.symmetric(horizontal: 2.0),
                          width: 4.0,
                          height: barHeight.clamp(4.0, 22.0),
                          decoration: BoxDecoration(
                            color: AppColors.mainGreen.withValues(
                              alpha: 0.45 + (amplitude * 0.55),
                            ),
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'احكِ مصاريفك بالعامية بحرية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Multi-ring gradient pulsing stop button
        SizedBox(
          width: 58.0,
          height: 58.0,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.08);
              final outerOpacity = 0.08 + (_pulseController.value * 0.07);
              final middleOpacity = 0.16 + (_pulseController.value * 0.09);
              final innerOpacity = 0.28 + (_pulseController.value * 0.12);

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Outermost gradient wave ring
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 146.0,
                      height: 146.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mainGreen.withValues(alpha: outerOpacity),
                      ),
                    ),
                  ),
                  // Middle wave ring
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 110.0,
                      height: 110.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mainGreen.withValues(alpha: middleOpacity),
                      ),
                    ),
                  ),
                  // Inner soft ring
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 84.0,
                      height: 84.0,
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
              width: 58.0,
              height: 58.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mainGreen,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10.0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onStop();
                  },
                  customBorder: const CircleBorder(),
                  child: const Center(
                    child: Icon(
                      Icons.stop_rounded,
                      color: Colors.white,
                      size: 32.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCircleButton extends StatelessWidget {
  const _ActionCircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48.0,
      height: 48.0,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mainGreen,
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 8.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 24.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceAnalyzingCard extends StatefulWidget {
  const _VoiceAnalyzingCard();

  @override
  State<_VoiceAnalyzingCard> createState() => _VoiceAnalyzingCardState();
}

class _VoiceAnalyzingCardState extends State<_VoiceAnalyzingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: AppColors.mainGreen.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 18.0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _animController,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.mainGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'بحلل كلامك…',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainGreen,
                ),
              ),
              Text(
                'جاري استخراج العمليات بدقة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
