import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:baqy/core/constants/gemini_models_config.dart';
import 'package:baqy/core/utils/fallback_notice_storage.dart';
import 'package:baqy/features/expenses/data/services/gemini_expense_parser.dart';
import 'package:baqy/features/expenses/domain/parser/egyptian_expense_parser.dart';

void main() {
  setUp(() {
    GeminiModelManager.clearExhausted();
    FallbackNoticeStorage.resetForTesting();
  });

  group('STEP 7E: Permanent Tests for Gemini Request Budget & Fallback', () {
    test('1. One recording makes exactly one request when model succeeds', () async {
      int requestCounter = 0;
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestCounter++;
        requestedUrls.add(request.url.path);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'transcript': 'فطار ب 50 جنيه',
                        'operations': [
                          {
                            'amount_egp': 50,
                            'description': 'فطار',
                            'category_name': 'أكل',
                            'is_new_category': false,
                            'source_text': 'فطار ب 50 جنيه',
                            'confidence': 0.99,
                            'needs_review': false,
                          }
                        ]
                      })
                    }
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final parser = GeminiExpenseParser(client: mockClient, apiKey: 'test_key');

      final tempDir = Directory.systemTemp.createTempSync();
      final audioFile = File('${tempDir.path}/test_single_request.m4a');
      audioFile.writeAsBytesSync(List.filled(200, 1));

      final result = await parser.parseAudio(audioFile);

      expect(result, isNotNull);
      expect(result!.operations.length, 1);
      expect(result.operations.first.amount, 50);

      // Exactly ONE request made to Gemini
      expect(requestCounter, 1);
      expect(requestedUrls.length, 1);
      expect(parser.lastRecordingGeminiRequestCount, 1);
      expect(requestedUrls.first, contains('gemini-3.5-flash-lite'));

      tempDir.deleteSync(recursive: true);
    });

    test('2. A 429 on the first model moves to the second and then to the local parser', () async {
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.path);
        // Both first and second models return 429
        return http.Response(
          jsonEncode({'error': {'code': 429, 'message': 'Rate limited'}}),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      // Chain of 2 models
      final parser = GeminiExpenseParser(
        client: mockClient,
        apiKey: 'test_key',
        candidateModelsOverride: [
          'gemini-3.5-flash-lite',
          'gemini-3.8-flash',
        ],
      );

      final tempDir = Directory.systemTemp.createTempSync();
      final audioFile = File('${tempDir.path}/test_429_chain.m4a');
      audioFile.writeAsBytesSync(List.filled(200, 1));

      final geminiResult = await parser.parseAudio(audioFile);

      // Gemini failed, returned null
      expect(geminiResult, isNull);
      expect(requestedUrls.length, 2);
      expect(requestedUrls[0], contains('gemini-3.5-flash-lite'));
      expect(requestedUrls[1], contains('gemini-3.8-flash'));
      expect(parser.lastRecordingGeminiRequestCount, 2);

      // Moves to local parser silently
      const fallbackSpeech = 'فطار ب 50 جنيه وجبت قهوة ب 30 جنيه';
      final localOps = EgyptianExpenseParser.parse(fallbackSpeech);
      expect(localOps.length, 2);
      expect(localOps[0].amount, 50);
      expect(localOps[1].amount, 30);

      tempDir.deleteSync(recursive: true);
    });

    test('3. An exhausted model is skipped for 10 minutes', () async {
      final baseTime = DateTime(2026, 11, 13, 12, 0);

      // Initially not exhausted
      expect(
        GeminiModelManager.isModelExhausted('gemini-3.5-flash-lite', baseTime),
        isFalse,
      );

      // Mark exhausted at baseTime
      GeminiModelManager.markExhausted('gemini-3.5-flash-lite', now: baseTime);

      // Within 10 minutes: still exhausted
      final fiveMinutesLater = baseTime.add(const Duration(minutes: 5));
      expect(
        GeminiModelManager.isModelExhausted('gemini-3.5-flash-lite', fiveMinutesLater),
        isTrue,
      );

      final nineMinutesLater = baseTime.add(const Duration(minutes: 9, seconds: 59));
      expect(
        GeminiModelManager.isModelExhausted('gemini-3.5-flash-lite', nineMinutesLater),
        isTrue,
      );

      // After 10 minutes: no longer exhausted
      final elevenMinutesLater = baseTime.add(const Duration(minutes: 10, seconds: 1));
      expect(
        GeminiModelManager.isModelExhausted('gemini-3.5-flash-lite', elevenMinutesLater),
        isFalse,
      );
    });

    test('4. The daily notice appears once per day only', () async {
      final day1 = DateTime(2026, 11, 13, 10, 0);
      final day1Later = DateTime(2026, 11, 13, 18, 0);
      final day2 = DateTime(2026, 11, 14, 9, 0);

      // First time on Day 1: should show notice
      expect(await FallbackNoticeStorage.shouldShowNoticeToday(day1), isTrue);
      await FallbackNoticeStorage.markNoticeShownToday(day1);

      // Second time on Day 1: should NOT show notice
      expect(await FallbackNoticeStorage.shouldShowNoticeToday(day1Later), isFalse);

      // Next Day (Day 2): should show notice again
      expect(await FallbackNoticeStorage.shouldShowNoticeToday(day2), isTrue);
      await FallbackNoticeStorage.markNoticeShownToday(day2);

      // Later on Day 2: should NOT show notice
      expect(await FallbackNoticeStorage.shouldShowNoticeToday(day2.add(const Duration(hours: 3))), isFalse);
    });

    test('5. No failure type shows a technical error and all fall back silently', () async {
      final failureStatusCodes = [400, 404, 429, 500, 503];

      final tempDir = Directory.systemTemp.createTempSync();
      final audioFile = File('${tempDir.path}/test_failures.m4a');
      audioFile.writeAsBytesSync(List.filled(200, 1));

      for (final status in failureStatusCodes) {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': {'code': status, 'message': 'HTTP error $status'}}),
            status,
            headers: {'content-type': 'application/json'},
          );
        });

        final parser = GeminiExpenseParser(
          client: mockClient,
          apiKey: 'test_key',
          candidateModelsOverride: ['test-model'],
        );

        final result = await parser.parseAudio(audioFile);
        // Silently returns null for local parser fallback
        expect(result, isNull);

        // Does not show "اعتذر الاتصال" or technical error to user
        expect(GeminiModelsConfig.fallbackNoticeText, 'الصوت دلوقتي شغّال بالوضع العادي، ودقته أقل شوية');
        expect(GeminiModelsConfig.fallbackNoticeText.contains('اعتذر الاتصال'), isFalse);
        expect(GeminiModelsConfig.fallbackNoticeText.contains('تعذر الاتصال'), isFalse);
      }

      tempDir.deleteSync(recursive: true);
    });

    test('6. Model fallback sequence tries first model, moves to second on 429, then succeeds', () async {
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.path);
        if (request.url.path.contains('gemini-3.5-flash-lite')) {
          return http.Response(
            jsonEncode({'error': {'code': 429, 'message': 'Rate limited'}}),
            429,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('gemini-3.8-flash')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'transcript': 'فطار ب 50 جنيه',
                          'operations': [
                            {
                              'amount_egp': 50,
                              'description': 'فطار',
                              'category_name': 'أكل',
                              'is_new_category': false,
                              'source_text': 'فطار ب 50 جنيه',
                              'confidence': 0.99,
                              'needs_review': false,
                            }
                          ]
                        })
                      }
                    ]
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final parser = GeminiExpenseParser(
        client: mockClient,
        apiKey: 'test_key',
        candidateModelsOverride: [
          'gemini-3.5-flash-lite',
          'gemini-3.8-flash',
        ],
      );

      final tempDir = Directory.systemTemp.createTempSync();
      final audioFile = File('${tempDir.path}/test_step_fallback.m4a');
      audioFile.writeAsBytesSync(List.filled(200, 1));

      final result = await parser.parseAudio(audioFile);

      expect(result, isNotNull);
      expect(result!.operations.length, 1);
      expect(result.operations.first.amount, 50);

      // Model 1 (429) -> Model 2 (200)
      expect(requestedUrls.length, 2);
      expect(requestedUrls[0], contains('gemini-3.5-flash-lite'));
      expect(requestedUrls[1], contains('gemini-3.8-flash'));
      expect(parser.lastRecordingGeminiRequestCount, 2);

      // Model 1 is now marked exhausted
      expect(
        GeminiModelManager.isModelExhausted('gemini-3.5-flash-lite'),
        isTrue,
      );

      tempDir.deleteSync(recursive: true);
    });
  });
}
