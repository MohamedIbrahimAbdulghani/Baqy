import 'dart:convert';
import 'dart:io';
import 'package:baqy/features/expenses/data/services/gemini_expense_parser.dart';
import 'package:baqy/features/expenses/domain/models/category_item.dart';
import 'package:baqy/features/expenses/domain/models/parsed_expense.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Section 3 Verifications & Audio Parser Tests', () {
    final sampleCategories = [
      const CategoryItem(id: 1, name: 'أكل', icon: 'restaurant', color: '#4E8B7A'),
      const CategoryItem(id: 2, name: 'مواصلات', icon: 'directions_bus', color: '#4E8B7A'),
      const CategoryItem(id: 3, name: 'ملابس', icon: 'checkroom', color: '#4E8B7A'),
      const CategoryItem(id: 4, name: 'استثمار وادخار', icon: 'trending_up', color: '#4E8B7A'),
      const CategoryItem(id: 5, name: 'صدقات', icon: 'favorite', color: '#4E8B7A'),
      const CategoryItem(id: 6, name: 'عناية شخصية', icon: 'spa', color: '#4E8B7A'),
      const CategoryItem(id: 7, name: 'أخرى', icon: 'more_horiz', color: '#9A9488'),
    ];

    test('1. Amount not in transcript -> marks needs_review and zeros amount, does not reject response', () {
      const transcript = 'ركبت توك توك بـ 30 جنيه وجبت فطار بـ 50';

      final operations = [
        const ParsedExpense(
          amount: 30,
          description: 'توك توك',
          category: 'مواصلات',
          sourceText: 'ركبت توك توك بـ 30 جنيه',
          confidence: 0.95,
        ),
        // Amount 999 does NOT exist in transcript
        const ParsedExpense(
          amount: 999,
          description: 'حاجة خيالية',
          category: 'أخرى',
          sourceText: 'حاجة خيالية',
          confidence: 0.90,
        ),
      ];

      final verified = GeminiExpenseParser.verifyAndNormalizeAudioOperations(
        transcript: transcript,
        operations: operations,
        categories: sampleCategories,
        defaultNames: GeminiExpenseParser.defaultCategoryNames,
      );

      expect(verified.length, 2);
      // First operation: valid
      expect(verified[0].amount, 30);
      expect(verified[0].needsReview, false);

      // Second operation: amount cleared, needs_review set to true
      expect(verified[1].amount, isNull);
      expect(verified[1].needsReview, true);
    });

    test('2. source_text is substring of transcript (with normalization)', () {
      const transcript = 'اشتريت لبس ب 3000 جنيه';

      final operations = [
        const ParsedExpense(
          amount: 3000,
          description: 'لبس',
          category: 'ملابس',
          sourceText: 'اشتريت لبس ب 3000 جنيه',
          confidence: 0.98,
        ),
      ];

      final verified = GeminiExpenseParser.verifyAndNormalizeAudioOperations(
        transcript: transcript,
        operations: operations,
        categories: sampleCategories,
        defaultNames: GeminiExpenseParser.defaultCategoryNames,
      );

      expect(verified.length, 1);
      expect(verified[0].sourceText, 'اشتريت لبس ب 3000 جنيه');
    });

    test('3. AI proposed new category duplicates existing category -> merged to existing and not marked new', () {
      const transcript = 'اشتريت فطار ب 60 جنيه';

      // AI proposed "أكل" or "اكل" as a new category
      final operations = [
        const ParsedExpense(
          amount: 60,
          description: 'فطار',
          category: 'اكل',
          isNewCategory: true,
          newCategoryProposal: ParsedExpenseCategoryProposal(
            name: 'اكل',
            icon: 'restaurant',
            color: '#4E8B7A',
          ),
          sourceText: 'اشتريت فطار ب 60 جنيه',
          confidence: 0.95,
        ),
      ];

      final verified = GeminiExpenseParser.verifyAndNormalizeAudioOperations(
        transcript: transcript,
        operations: operations,
        categories: sampleCategories,
        defaultNames: GeminiExpenseParser.defaultCategoryNames,
      );

      expect(verified.length, 1);
      // Must NOT be marked new category
      expect(verified[0].isNewCategory, false);
      expect(verified[0].newCategoryProposal, isNull);
      // Must be mapped to canonical existing category
      expect(verified[0].category, 'أكل');
    });

    test('4. Genuine new category proposed by AI -> sanitized icon and kept as new category', () {
      const transcript = 'اشتريت كتب دراسية ب 400 جنيه';

      final operations = [
        const ParsedExpense(
          amount: 400,
          description: 'كتب دراسية',
          category: 'كتب ومراجع',
          isNewCategory: true,
          newCategoryProposal: ParsedExpenseCategoryProposal(
            name: 'كتب ومراجع',
            icon: 'book',
            color: '#3498DB',
          ),
          sourceText: 'اشتريت كتب دراسية ب 400 جنيه',
          confidence: 0.95,
        ),
      ];

      final verified = GeminiExpenseParser.verifyAndNormalizeAudioOperations(
        transcript: transcript,
        operations: operations,
        categories: sampleCategories,
        defaultNames: GeminiExpenseParser.defaultCategoryNames,
      );

      expect(verified.length, 1);
      expect(verified[0].isNewCategory, true);
      expect(verified[0].category, 'كتب ومراجع');
      expect(verified[0].newCategoryProposal?.icon, 'book');
    });

    test('5. New category with non-whitelisted icon falls back to default more_horiz', () {
      const transcript = 'صيانة كيبورد ب 200';

      final operations = [
        const ParsedExpense(
          amount: 200,
          description: 'كيبورد',
          category: 'صيانة خاصة',
          isNewCategory: true,
          newCategoryProposal: ParsedExpenseCategoryProposal(
            name: 'صيانة خاصة',
            icon: 'totally_unknown_custom_icon_123',
            color: '#3498DB',
          ),
          sourceText: 'صيانة كيبورد ب 200',
          confidence: 0.90,
        ),
      ];

      final verified = GeminiExpenseParser.verifyAndNormalizeAudioOperations(
        transcript: transcript,
        operations: operations,
        categories: sampleCategories,
        defaultNames: GeminiExpenseParser.defaultCategoryNames,
      );

      expect(verified.length, 1);
      expect(verified[0].isNewCategory, true);
      expect(verified[0].newCategoryProposal?.icon, 'more_horiz');
    });

    test('6. Unknown category without is_new_category does NOT fall silently to أخرى, keeps name and marks needs_review', () {
      const transcript = 'دفعت 500 جنيه استشارات';

      final operations = [
        const ParsedExpense(
          amount: 500,
          description: 'استشارات',
          category: 'استشارات قانونية',
          isNewCategory: false,
          sourceText: 'دفعت 500 جنيه استشارات',
          confidence: 0.95,
        ),
      ];

      final verified = GeminiExpenseParser.verifyAndNormalizeAudioOperations(
        transcript: transcript,
        operations: operations,
        categories: sampleCategories,
        defaultNames: GeminiExpenseParser.defaultCategoryNames,
      );

      expect(verified.length, 1);
      // Does NOT fall to 'أخرى' silently!
      expect(verified[0].category, 'استشارات قانونية');
      // Needs review flag is set
      expect(verified[0].needsReview, true);
    });

    test('7. Foreign amounts stored for reference only and not added to amount_egp', () {
      const transcript = 'اشتريت \$150 ب 8400 جنيه';

      final operations = [
        const ParsedExpense(
          amount: 8400,
          description: 'دولار',
          category: 'استثمار وادخار',
          foreignAmount: 150.0,
          foreignCurrency: 'USD',
          sourceText: 'اشتريت \$150 ب 8400 جنيه',
          confidence: 0.98,
        ),
      ];

      final verified = GeminiExpenseParser.verifyAndNormalizeAudioOperations(
        transcript: transcript,
        operations: operations,
        categories: sampleCategories,
        defaultNames: GeminiExpenseParser.defaultCategoryNames,
      );

      expect(verified.length, 1);
      expect(verified[0].amount, 8400);
      expect(verified[0].foreignAmount, 150.0);
      expect(verified[0].foreignCurrency, 'USD');
    });

    test('8. parseAudio with mock client sends audio/mp4 inline_data and returns verified result', () async {
      final mockRawResponse = jsonEncode({
        'transcript': 'ركبت مواصلات ب 70 جنيه وانا رايح المحكمة، وانا راجع ركبت ب 50، وجبت فطار ب 60، وجبت بتنجان مخلل ب 10، وجبت لبس ب 3000',
        'operations': [
          {
            'amount_egp': 70,
            'description': 'مواصلات',
            'category_name': 'مواصلات',
            'is_new_category': false,
            'source_text': 'ركبت مواصلات ب 70 جنيه',
            'confidence': 0.98,
            'needs_review': false,
          },
          {
            'amount_egp': 50,
            'description': 'مواصلات',
            'category_name': 'مواصلات',
            'is_new_category': false,
            'source_text': 'وانا راجع ركبت ب 50',
            'confidence': 0.98,
            'needs_review': false,
          },
          {
            'amount_egp': 60,
            'description': 'فطار',
            'category_name': 'أكل',
            'is_new_category': false,
            'source_text': 'وجبت فطار ب 60',
            'confidence': 0.98,
            'needs_review': false,
          },
          {
            'amount_egp': 10,
            'description': 'بتنجان مخلل',
            'category_name': 'أكل',
            'is_new_category': false,
            'source_text': 'وجبت بتنجان مخلل ب 10',
            'confidence': 0.95,
            'needs_review': false,
          },
          {
            'amount_egp': 3000,
            'description': 'لبس',
            'category_name': 'ملابس',
            'is_new_category': false,
            'source_text': 'وجبت لبس ب 3000',
            'confidence': 0.98,
            'needs_review': false,
          },
        ]
      });

      final mockHttp = MockClient((request) async {
        expect(request.url.path, contains(':generateContent'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final contents = body['contents'] as List<dynamic>;
        final parts = contents.first['parts'] as List<dynamic>;
        expect(parts[0]['inline_data']['mime_type'], 'audio/mp4');
        expect(parts[1]['text'], 'حلّل التسجيل ده.');

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': mockRawResponse}
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final parser = GeminiExpenseParser(client: mockHttp, apiKey: 'test_key');

      // Create a dummy audio file
      final tempFile = File('${Directory.systemTemp.path}/test_voice.m4a');
      await tempFile.writeAsBytes(List.filled(500, 0));

      final result = await parser.parseAudio(
        tempFile,
        categories: sampleCategories,
      );

      expect(result, isNotNull);
      expect(result!.transcript, contains('المحكمة'));
      expect(result.operations.length, 5);
      expect(result.operations[0].category, 'مواصلات');
      expect(result.operations[0].amount, 70);
      expect(result.operations[1].amount, 50);
      expect(result.operations[2].amount, 60);
      expect(result.operations[3].amount, 10);
      expect(result.operations[4].amount, 3000);
      expect(result.operations[4].category, 'ملابس');

      await tempFile.delete();
    });
  });
}
