import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import 'voice_recording_focused_overlay.dart';

export 'voice_recording_focused_overlay.dart';

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
    final isViewingPastMonth = ref.watch(isViewingPastMonthProvider);

    if (isRecording || isAnalyzing) {
      return const SizedBox.shrink();
    }

    // When viewing an archived/past month, hide the FAB to prevent adding past expenses
    if (isViewingPastMonth && pendingAudio == null) {
      return const SizedBox.shrink();
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
                Expanded(
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
                  icon: Icon(
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
        if (!isViewingPastMonth) ...[
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
      ],
    );
  }
}

typedef VoiceRecordingStopButton = VoiceRecordingFocusedOverlay;

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
