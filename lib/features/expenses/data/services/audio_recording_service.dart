import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract class AudioRecordingService {
  Future<bool> hasPermission();
  Future<String?> startRecording({
    void Function()? onSafetyWarning,
    void Function(String path)? onMaxDurationReached,
  });
  Future<String?> stopRecording();
  Future<void> cancelRecording();
  bool get isRecording;
  Stream<double> get amplitudeStream;
  Future<void> dispose();
}

class RecordAudioRecordingService implements AudioRecordingService {
  final AudioRecorder _recorder;
  bool _isRecording = false;
  String? _currentFilePath;
  Timer? _maxDurationTimer;
  Timer? _warningTimer;
  Timer? _amplitudeTimer;
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  RecordAudioRecordingService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUDIO_DEBUG] Permission check error: $e');
      }
      return false;
    }
  }

  @override
  Future<String?> startRecording({
    void Function()? onSafetyWarning,
    void Function(String path)? onMaxDurationReached,
  }) async {
    if (_isRecording) return _currentFilePath;

    final granted = await hasPermission();
    if (!granted) {
      if (kDebugMode) {
        debugPrint('[AUDIO_DEBUG] Microphone permission denied');
      }
      return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/baqy_voice_$timestamp.m4a';
      _currentFilePath = filePath;

      // AAC/m4a, mono, 16kHz, continuous recording without silence limits
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 32000,
      );

      await _recorder.start(config, path: filePath);
      _isRecording = true;

      // Amplitude polling every 100ms
      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        if (!_isRecording) return;
        try {
          final amp = await _recorder.getAmplitude();
          // Normalize current dB (-60 to 0) into 0.0 to 1.0 range
          final currentDb = amp.current;
          final normalized = currentDb <= -60
              ? 0.0
              : currentDb >= 0
                  ? 1.0
                  : (currentDb + 60) / 60;
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(normalized);
          }
        } catch (_) {}
      });

      // 55-second safety warning callback
      _warningTimer?.cancel();
      _warningTimer = Timer(const Duration(seconds: 55), () {
        if (_isRecording && onSafetyWarning != null) {
          if (kDebugMode) {
            debugPrint('[AUDIO_DEBUG] 55 seconds reached: Safety warning triggered');
          }
          onSafetyWarning();
        }
      });

      // 60-second strict safety limit
      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(const Duration(seconds: 60), () async {
        if (_isRecording) {
          if (kDebugMode) {
            debugPrint('[AUDIO_DEBUG] 60 seconds limit reached: Stopping recording safely');
          }
          final path = await stopRecording();
          if (path != null && onMaxDurationReached != null) {
            onMaxDurationReached(path);
          }
        }
      });

      if (kDebugMode) {
        debugPrint('[AUDIO_DEBUG] Recording started at: $filePath');
      }

      return filePath;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AUDIO_DEBUG] Start recording failed: $e\n$st');
      }
      _isRecording = false;
      return null;
    }
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) return _currentFilePath;

    _warningTimer?.cancel();
    _maxDurationTimer?.cancel();
    _amplitudeTimer?.cancel();

    try {
      final savedPath = await _recorder.stop();
      _isRecording = false;
      final finalPath = savedPath ?? _currentFilePath;

      if (kDebugMode && finalPath != null) {
        final file = File(finalPath);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        debugPrint(
          '[AUDIO_DEBUG] Recording stopped. File: $finalPath, exists: $exists, size: $size bytes',
        );
      }

      return finalPath;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AUDIO_DEBUG] Stop recording error: $e\n$st');
      }
      _isRecording = false;
      return _currentFilePath;
    }
  }

  @override
  Future<void> cancelRecording() async {
    _warningTimer?.cancel();
    _maxDurationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _isRecording = false;

    try {
      await _recorder.cancel();
      if (_currentFilePath != null) {
        final file = File(_currentFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUDIO_DEBUG] Cancel recording error: $e');
      }
    } finally {
      _currentFilePath = null;
    }
  }

  @override
  Future<void> dispose() async {
    _warningTimer?.cancel();
    _maxDurationTimer?.cancel();
    _amplitudeTimer?.cancel();
    if (!_amplitudeController.isClosed) {
      await _amplitudeController.close();
    }
    await _recorder.dispose();
  }
}

