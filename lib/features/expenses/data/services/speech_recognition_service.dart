import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract class SpeechRecognitionService {
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechRecognitionError error)? onError,
  });

  Future<void> listen({
    required void Function(String recognizedWords, {bool isFinal}) onResult,
    Duration? listenFor,
    Duration? pauseFor,
  });

  Future<void> stop();

  Future<void> cancel();

  bool get isListening;

  Future<bool> get hasPermission;

  bool get isAvailable;
}

class SpeechToTextServiceImpl implements SpeechRecognitionService {
  SpeechToTextServiceImpl([stt.SpeechToText? speech])
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechRecognitionError error)? onError,
  }) async {
    _speech.errorListener = onError;
    _speech.statusListener = onStatus;

    if (_speech.isAvailable) {
      return true;
    }

    return _speech.initialize(
      onStatus: onStatus,
      onError: onError,
    );
  }

  @override
  Future<void> listen({
    required void Function(String recognizedWords, {bool isFinal}) onResult,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    String localeId = 'ar-EG';
    try {
      final locales = await _speech.locales();
      if (locales.isNotEmpty) {
        // Try picking ar-EG (or ar_EG) first
        final arEg = locales.where((l) {
          final id = l.localeId.toLowerCase().replaceAll('_', '-');
          return id == 'ar-eg' || id.startsWith('ar-eg-');
        }).firstOrNull;

        if (arEg != null) {
          localeId = arEg.localeId;
        } else {
          // Fallback to any Arabic locale (e.g. ar-SA, ar, etc.)
          final anyAr = locales.where((l) {
            final id = l.localeId.toLowerCase().replaceAll('_', '-');
            return id.startsWith('ar-') || id == 'ar';
          }).firstOrNull;

          if (anyAr != null) {
            localeId = anyAr.localeId;
          }
        }
      }
    } catch (_) {}

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, isFinal: result.finalResult);
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: listenFor ?? const Duration(minutes: 10),
        pauseFor: pauseFor ?? const Duration(minutes: 10),
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> get hasPermission => _speech.hasPermission;

  @override
  bool get isAvailable => _speech.isAvailable;
}

