import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../home/presentation/widgets/home_speed_dial_fab.dart';

class GoalsSpeedDialFab extends ConsumerStatefulWidget {
  const GoalsSpeedDialFab({super.key});

  @override
  ConsumerState<GoalsSpeedDialFab> createState() => _GoalsSpeedDialFabState();
}

class _GoalsSpeedDialFabState extends ConsumerState<GoalsSpeedDialFab>
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

    if (isRecording || isAnalyzing) {
      return VoiceRecordingStopButton(
        isAnalyzing: isAnalyzing,
        subtitle: 'احكِ هدفك بالعامية بحرية',
        onStop: () {
          if (!isAnalyzing) {
            ref
                .read(voiceRecordingProvider.notifier)
                .stopRecording(context: context);
          }
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Upper two buttons: expand smoothly upwards without taking space when closed
        SizeTransition(
          sizeFactor: _expandAnimation,
          alignment: Alignment.bottomCenter,
          child: ScaleTransition(
            scale: _expandAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Button: Pencil (Add Goal Form)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _ActionCircleButton(
                    icon: Icons.edit_outlined,
                    onTap: () {
                      _close();
                      context.push('/add-goal');
                    },
                  ),
                ),

                // Middle Button: Mic (Voice Recording in goal mode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _ActionCircleButton(
                    icon: Icons.mic_none_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _close();
                      ref.read(voiceRecordingProvider.notifier).startRecording(
                            context: context,
                            mode: VoiceRecordingMode.goal,
                          );
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
                  turns: _isOpen ? 0.125 : 0.0, // 45 degrees turns + to x
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
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
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
              color: AppColors.mainGreen,
              size: 24.0,
            ),
          ),
        ),
      ),
    );
  }
}
