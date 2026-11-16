import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:baqy/features/expenses/data/services/gemini_expense_parser.dart';

void main() {
  test('Gemini fallback sequence: 3.6-flash (429) -> 3.8-flash (429) -> 3.5-flash-lite (200)', () async {
    final requestedUrls = <String>[];

    final mockClient = MockClient((request) async {
      requestedUrls.add(request.url.path);

      if (request.url.path.contains('gemini-3.6-flash')) {
        return http.Response(
          jsonEncode({'error': {'code': 429, 'message': 'Rate limited'}}),
          429,
          headers: {'content-type': 'application/json'},
        );
      } else if (request.url.path.contains('gemini-3.8-flash')) {
        return http.Response(
          jsonEncode({'error': {'code': 429, 'message': 'Quota exceeded'}}),
          429,
          headers: {'content-type': 'application/json'},
        );
      } else if (request.url.path.contains('gemini-3.5-flash-lite')) {
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

    final parser = GeminiExpenseParser(client: mockClient, apiKey: 'test_key');
    expect(GeminiExpenseParser.modelName, 'gemini-3.6-flash');

    // Create temp audio file
    final tempDir = Directory.systemTemp.createTempSync();
    final audioFile = File('${tempDir.path}/test_fallback.m4a');
    audioFile.writeAsBytesSync(List.filled(200, 1));

    final result = await parser.parseAudio(audioFile);

    expect(result, isNotNull);
    expect(result!.transcript, 'فطار ب 50 جنيه');
    expect(result.operations.length, 1);
    expect(result.operations.first.amount, 50);

    // Verify exactly 1 request per model on 429, moving to next model
    expect(requestedUrls.length, 3);
    expect(requestedUrls[0], contains('gemini-3.6-flash'));
    expect(requestedUrls[1], contains('gemini-3.8-flash'));
    expect(requestedUrls[2], contains('gemini-3.5-flash-lite'));

    tempDir.deleteSync(recursive: true);
  });
}

