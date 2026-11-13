import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/utils/category_matcher.dart';
import '../../../../core/utils/goal_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/category_item.dart';
import '../../domain/models/parsed_expense.dart';
import '../../domain/parser/egyptian_expense_parser.dart';
import 'gemini_system_prompt.dart';

/// Error types encountered during Gemini audio requests.
enum GeminiAudioErrorType {
  none,
  modelNotFound, // 404
  invalidKey, // 401, 403
  rateLimited, // 429
  serverError, // 5xx
  network, // Socket, Timeout, ClientException
  badRequest, // 400
  emptyAudio,
  unknown,
}

/// Result object returned by [GeminiExpenseParser.parseAudio].
class AudioParseResult {
  final String transcript;
  final List<ParsedExpense> operations;
  final int requestDurationMs;
  final int fileSizeBytes;
  final String rawResponse;

  const AudioParseResult({
    required this.transcript,
    required this.operations,
    this.requestDurationMs = 0,
    this.fileSizeBytes = 0,
    this.rawResponse = '',
  });

  @override
  String toString() =>
      'AudioParseResult(transcript: "$transcript", operations: ${operations.length}, time: ${requestDurationMs}ms)';
}

/// Result object returned by [GeminiExpenseParser.parseGoalAudio].
class GoalAudioParseResult {
  final String transcript;
  final String goalName;
  final int targetAmountEgp;
  final String icon;
  final int requestDurationMs;
  final int fileSizeBytes;
  final String rawResponse;

  const GoalAudioParseResult({
    required this.transcript,
    required this.goalName,
    required this.targetAmountEgp,
    required this.icon,
    this.requestDurationMs = 0,
    this.fileSizeBytes = 0,
    this.rawResponse = '',
  });
}

/// Gemini AI parser for colloquial Egyptian Arabic expense statements
/// supporting both audio file analysis and text parsing with dynamic categories,
/// user rules, and rigorous verification.
class GeminiExpenseParser {
  final http.Client _client;
  final String? _apiKeyOverride;
  final String? modelOverride;

  /// Default model name for audio and text processing.
  /// Configurable in this single constant.
  static const String modelName = 'gemini-3.6-flash';

  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const List<String> defaultCategoryNames = [
    'أكل',
    'مشروبات وكافيهات',
    'سوبر ماركت',
    'مواصلات',
    'سيارة',
    'ملابس',
    'إلكترونيات',
    'بيت وأثاث',
    'إيجار',
    'فواتير واتصالات',
    'اشتراكات',
    'صحة',
    'عناية شخصية',
    'تعليم',
    'ترفيه',
    'سفر',
    'أطفال',
    'حيوانات أليفة',
    'هدايا ومناسبات',
    'صدقات',
    'استثمار وادخار',
    'ديون وأقساط',
    'أخرى',
  ];

  static const Map<String, String> categoryDescriptions = {
    'أكل': 'الوجبات، المطاعم، الفطار، الغدا، العشا، الخضار واللحوم، الدليفري، السندوتشات (مثل: جبت أكل، اتغديت، فطار، طلبت دليفري)',
    'مشروبات وكافيهات': 'القهوة، الشاي، العصائر، الفرابيه، المشروبات الساقعة، قعدة الكافيه، الشيشة (مثل: شربت عصير، قهوة، حاجة ساقعة، فرابيه، شيشة)',
    'سوبر ماركت': 'مشتريات السوبرماركت والهايبر المجمعة وطلبات البيت (مثل: نزلت سوبر ماركت جبت شيبسي وجبنة وساقعة بـ 450، هايبر، طلبات البيت)',
    'مواصلات': 'الأوبر، التاكسي، المترو، الميكروباص، التوك توك، الأتوبيس، تذاكر المواصلات (مثل: ركبت توك توك، اوبر، تاكسي، مترو)',
    'سيارة': 'بنزين، غسيل، صيانة سيارة، ركنة، زيت، كاوتش، ميكانيكي (مثل: حطيت بنزين، غسيل عربية)',
    'ملابس': 'اللبس، الهدوم، التيشيرتات، البناطيل، الأحذية، الفساتين (مثل: اشتريت لبس، بنطلون، جزمة)',
    'إلكترونيات': 'الموبايلات، الشواحن، السماعات، الكابلات، الشاشات، الكمبيوتر، باوربانك (مثل: شاحن، سماعة)',
    'بيت وأثاث': 'أثاث المنزل، ديكور، أجهزة منزلية، مستلزمات البيت، أدوات المطبخ',
    'إيجار': 'إيجار شقة، إيجار محل، إيجار سكن',
    'فواتير واتصالات': 'فاتورة الكهرباء، المياه، الغاز، شحن رصيد الموبايل، باقات النت والإنترنت (مثل: دفعت باقة نت، جددت باقة، شحنت رصيد، فاتورة موبايل)',
    'اشتراكات': 'اشتراك الجيم، نتفلكس، سبوتيفاي، شاهد، الخدمات الشهرية والنوادي',
    'صحة': 'أدوية، كشف طبيب، صيدلية، تحاليل، مستشفى، علاج',
    'عناية شخصية': 'برفيوم وعطور، حلاقة وكوافير، مستحضرات تجميل، مزيل عرق، بادز، شامبو، كوزمتكس (مثل: برفيوم، بادز، مزيل عرق، شامبو، حلاقة)',
    'تعليم': 'كتب، كورسات، دورات تدريبية، دروس خصوصية، مصاريف دراسية',
    'ترفيه': 'سينما، ألعاب، بلايستيشن، فسح، مسرح، كورة، أنشطة ترفيهية',
    'سفر': 'تذاكر طيران، فنادق، رحلات ومصايف، قطارات السفر بين المدن',
    'أطفال': 'حفاضات، لبن أطفال، ألعاب أطفال، مستلزمات وملابس أطفال',
    'حيوانات أليفة': 'أكل ومستلزمات وعلاج الحيوانات الأليفة (كلاب، قطط)',
    'هدايا ومناسبات': 'هدايا أعياد ميلاد، أفراح، عيدية، مناسبات اجتماعية',
    'صدقات': 'صدقة للأقارب أو المحتاجين، زكاة، تبرعات، إطعام، كفالة يتيم، فلوس لله (مثل: طلعت 200 جنيه لله، اتبرعت بـ 200، اديت عمتي 2000 جنيه صدقة، كفالة يتيم)',
    'استثمار وادخار': 'شراء ذهب وسبائك وعملات ذهبية، شراء دولار وعملات أجنبية، أسهم وبورصة، أقساط الجمعية (مثل: اشتريت دولار، اشتريت ذهب، جبت سبيكة، اشتريت أسهم، حطيت في الجمعية)',
    'ديون وأقساط': 'سداد قسط شقة أو سيارة، سداد سلف، ديون شخصية، قروض (مثل: قسط الشقة، سداد سلف)',
    'أخرى': 'أي مصروف نادر لا يندرج تحت أي مما سبق (يستخدم فقط كآخر ملاذ)',
  };

  /// Structured JSON response schema for parseAudio.
  static final Map<String, dynamic> audioResponseSchema = {
    'type': 'OBJECT',
    'properties': {
      'transcript': {
        'type': 'STRING',
        'description':
            'الكلام اللي اتقال حرفيًا بالعامية، من غير تلخيص ولا إعادة صياغة. مع تصليح أخطاء السمع والأرقام بالأرقام.',
      },
      'operations': {
        'type': 'ARRAY',
        'description': 'قائمة بكل عمليات الصرف المذكور لها مبلغ',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'amount_egp': {
              'type': 'INTEGER',
              'nullable': true,
              'description':
                  'المبلغ بالجنيه المصري أو null إذا لم يكن هناك مبلغ واضح أو بالعملة الأجنبية فقط',
            },
            'description': {
              'type': 'STRING',
              'description': 'من 1 إلى 4 كلمات تصف الشيء المنفق عليه',
            },
            'category_name': {
              'type': 'STRING',
              'description': 'اسم التصنيف المناسب',
            },
            'is_new_category': {
              'type': 'BOOLEAN',
              'description': 'هل تم اقتراح تصنيف جديد لعدم ملاءمة أي تصنيف حالي',
            },
            'new_category': {
              'type': 'OBJECT',
              'nullable': true,
              'description': 'تفاصيل التصنيف الجديد المقترح',
              'properties': {
                'name': {'type': 'STRING', 'description': 'اسم التصنيف الجديد'},
                'icon': {'type': 'STRING', 'description': 'أيقونة من القائمة المسموحة'},
                'color_hex': {'type': 'STRING', 'description': 'كود اللون hex'},
              },
            },
            'quantity_text': {
              'type': 'STRING',
              'nullable': true,
              'description': 'الكمية أو الوزن أو العيار إن وجد',
            },
            'foreign_amount': {
              'type': 'NUMBER',
              'nullable': true,
              'description': 'المبلغ بالعملة الأجنبية إن وجد',
            },
            'foreign_currency': {
              'type': 'STRING',
              'nullable': true,
              'description': 'رمز العملة الأجنبية',
            },
            'source_text': {
              'type': 'STRING',
              'description': 'الجزء الحرفي من transcript الخاص بالعملية',
            },
            'confidence': {
              'type': 'NUMBER',
              'description': 'درجة الثقة من 0 إلى 1',
            },
            'needs_review': {
              'type': 'BOOLEAN',
              'description': 'هل تحتاج العملية مراجعة',
            },
          },
          'required': [
            'description',
            'category_name',
            'is_new_category',
            'source_text',
            'confidence',
            'needs_review',
          ],
        },
      },
    },
    'required': ['transcript', 'operations'],
  };

  /// Legacy text-only response schema
  static final Map<String, dynamic> responseSchema = {
    'type': 'ARRAY',
    'description': 'قائمة بعمليات المصاريف المستخرجة بدقة',
    'items': audioResponseSchema['properties']['operations']['items'],
  };

  /// Response schema for goal voice utterances
  static final Map<String, dynamic> goalAudioResponseSchema = {
    'type': 'OBJECT',
    'description': 'استخراج هدف التحويش بدقة',
    'properties': {
      'transcript': {
        'type': 'STRING',
        'description': 'النص المسموع حرفيًا',
      },
      'goal_name': {
        'type': 'STRING',
        'description': 'اسم الهدف (الشيء المطلوب شراؤه أو ادخار المال لأجله)',
      },
      'target_amount_egp': {
        'type': 'NUMBER',
        'description': 'المبلغ المطلوب للهدف بالجنيه المصري',
      },
      'icon': {
        'type': 'STRING',
        'enum': GoalIconHelper.allowedKeys,
        'description': 'مفتاح الأيقونة من القائمة المسموحة فقط',
      },
    },
    'required': ['transcript', 'goal_name', 'target_amount_egp', 'icon'],
  };

  /// Logging failure helper adhering to debug-only and zero-financial-data-logging rule
  static void logGeminiFailure(String type, int? statusCode) {
    if (kDebugMode) {
      debugPrint('[VOICE_DEBUG] Gemini failure TYPE: $type, HTTP: $statusCode');
    }
  }

  GeminiExpenseParser({
    http.Client? client,
    String? apiKey,
    this.modelOverride,
  })  : _client = client ?? http.Client(),
        _apiKeyOverride = apiKey;

  /// Tracks the last audio error type for user-friendly error messages.
  GeminiAudioErrorType lastAudioError = GeminiAudioErrorType.none;
  int? lastStatusCode;

  /// User-facing localized error message based on the last error encountered.
  String get lastErrorMessage {
    switch (lastAudioError) {
      case GeminiAudioErrorType.modelNotFound:
        return 'الموديل مش متاح، لازم تحديث للتطبيق';
      case GeminiAudioErrorType.invalidKey:
        return 'مفتاح Gemini مش مظبوط';
      case GeminiAudioErrorType.rateLimited:
        return 'الخدمة مشغولة، جرب بعد دقيقة';
      case GeminiAudioErrorType.serverError:
        return 'الخدمة مشغولة، جرب بعد دقيقة';
      case GeminiAudioErrorType.network:
      default:
        return 'تأكد من الإنترنت';
    }
  }

  String? get apiKey {
    if (_apiKeyOverride != null && _apiKeyOverride.isNotEmpty) {
      return _apiKeyOverride;
    }
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.trim().isNotEmpty) {
        return key.trim();
      }
    } catch (_) {}
    const buildKey = String.fromEnvironment('GEMINI_API_KEY');
    if (buildKey.isNotEmpty) return buildKey;
    return null;
  }

  String get activeModelName {
    if (modelOverride != null && modelOverride!.trim().isNotEmpty) {
      return modelOverride!.trim();
    }
    try {
      final envModel =
          dotenv.env['GEMINI_MODEL'] ?? dotenv.env['GEMINI_AUDIO_MODEL'];
      if (envModel != null && envModel.trim().isNotEmpty) {
        return envModel.trim();
      }
    } catch (_) {}
    return modelName;
  }

  /// Pre-warms the HTTP connection and DNS cache for Gemini in advance
  Future<void> warmUp() async {
    try {
      final key = apiKey;
      if (key == null || key.isEmpty) return;
      final url = Uri.parse('$baseUrl/$activeModelName?key=$key');
      unawaited(_client.get(url).catchError((_) => http.Response('', 500)));
    } catch (_) {}
  }

  /// Builds the resolved system prompt using [geminiSystemPromptTemplate]
  static String buildAudioSystemPrompt({
    required List<String> categories,
    List<({int id, String keyword, String categoryName, int categoryId})>
        userRules = const [],
  }) {
    final catDescriptions = categories.map((c) {
      final desc = categoryDescriptions[c];
      return desc != null ? '- $c: $desc' : '- $c';
    }).join('\n');

    final rulesSection = userRules.isEmpty
        ? 'لا توجد قواعد سابقة.'
        : userRules
            .take(50)
            .map((r) => '- عند ذكر "${r.keyword}" صنّف كـ "${r.categoryName}"')
            .join('\n');

    return geminiSystemPromptTemplate
        .replaceAll('{{CATEGORIES_WITH_DESCRIPTIONS}}', catDescriptions)
        .replaceAll('{{USER_RULES}}', rulesSection);
  }

  /// Sends a continuous audio file to Gemini with responseSchema and returns
  /// verified transcript and operations.
  Future<AudioParseResult?> parseAudio(
    File audioFile, {
    List<CategoryItem> categories = const [],
    List<({int id, String keyword, String categoryName, int categoryId})>
        userRules = const [],
  }) async {
    final key = apiKey;
    if (key == null || key.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[AUDIO_DEBUG] [ERROR] GEMINI_API_KEY is not set or empty.',
        );
      }
      return null;
    }

    if (!await audioFile.exists()) {
      if (kDebugMode) {
        debugPrint(
          '[AUDIO_DEBUG] [ERROR] Audio file does not exist at: ${audioFile.path}',
        );
      }
      return null;
    }

    final fileBytes = await audioFile.readAsBytes();
    final fileSizeBytes = fileBytes.length;
    final fileSizeKb = (fileSizeBytes / 1024).toStringAsFixed(1);

    if (kDebugMode) {
      debugPrint(
        '[AUDIO_DEBUG] Audio file ready: path=${audioFile.path}, size=${fileSizeBytes}B (${fileSizeKb}KB)',
      );
    }

    final effectiveCategories = <String>{
      ...defaultCategoryNames,
      ...categories.map((c) => c.name),
    }.toList();

    final systemPrompt = buildAudioSystemPrompt(
      categories: effectiveCategories,
      userRules: userRules,
    );

    final base64Audio = base64Encode(fileBytes);
    final candidateModels = <String>[
      'gemini-3.6-flash',
      'gemini-3.8-flash',
      'gemini-3.5-flash-lite',
    ];

    final requestPayload = {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inline_data': {
                'mime_type': 'audio/mp4',
                'data': base64Audio,
              }
            },
            {
              'text': 'حلّل التسجيل ده.',
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        'responseSchema': audioResponseSchema,
        'maxOutputTokens': 8192,
        'thinkingConfig': {
          'thinkingBudget': 0,
        },
      }
    };

    // Reset error state
    lastAudioError = GeminiAudioErrorType.none;
    lastStatusCode = null;

    AudioParseResult? result;

    for (int mIndex = 0; mIndex < candidateModels.length; mIndex++) {
      final currentModel = candidateModels[mIndex];
      final url = Uri.parse('$baseUrl/$currentModel:generateContent?key=$key');
      final stopwatch = Stopwatch()..start();

      try {
        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestPayload),
            )
            .timeout(const Duration(seconds: 6));

        stopwatch.stop();
        final latencyMs = stopwatch.elapsedMilliseconds;
        lastStatusCode = response.statusCode;

        if (response.statusCode != 200) {
          if (response.statusCode == 429) {
            logGeminiFailure('429', 429);
            lastAudioError = GeminiAudioErrorType.rateLimited;
          } else if (response.statusCode >= 500 && response.statusCode < 600) {
            logGeminiFailure('5xx', response.statusCode);
            lastAudioError = GeminiAudioErrorType.serverError;
          } else {
            logGeminiFailure('network', response.statusCode);
            lastAudioError = GeminiAudioErrorType.network;
          }

          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        Map<String, dynamic> jsonBody;
        try {
          jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          logGeminiFailure('invalid JSON', response.statusCode);
          lastAudioError = GeminiAudioErrorType.unknown;
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        final candidates = jsonBody['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          logGeminiFailure('invalid JSON', response.statusCode);
          lastAudioError = GeminiAudioErrorType.unknown;
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        final content = candidates.first['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        final rawText = parts?.first?['text'] as String?;
        if (rawText == null || rawText.trim().isEmpty) {
          logGeminiFailure('invalid JSON', response.statusCode);
          lastAudioError = GeminiAudioErrorType.unknown;
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        dynamic decoded;
        try {
          decoded = jsonDecode(rawText);
        } catch (_) {
          logGeminiFailure('invalid JSON', response.statusCode);
          lastAudioError = GeminiAudioErrorType.unknown;
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        if (decoded is! Map<String, dynamic>) {
          logGeminiFailure('invalid JSON', response.statusCode);
          lastAudioError = GeminiAudioErrorType.unknown;
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        final rawTranscript = decoded['transcript'] as String? ?? '';
        final rawOperations = decoded['operations'] as List<dynamic>? ?? [];

        final parsedExpenses = <ParsedExpense>[];
        for (final el in rawOperations) {
          if (el is Map<String, dynamic>) {
            parsedExpenses.add(ParsedExpense.fromJson(el));
          }
        }

        // Section 3: Verification in Code
        final verifiedExpenses = verifyAndNormalizeAudioOperations(
          transcript: rawTranscript,
          operations: parsedExpenses,
          categories: categories,
          defaultNames: effectiveCategories,
        );

        result = AudioParseResult(
          transcript: rawTranscript,
          operations: verifiedExpenses,
          requestDurationMs: latencyMs,
          fileSizeBytes: fileSizeBytes,
          rawResponse: rawText,
        );
        lastAudioError = GeminiAudioErrorType.none;
        break; // Successfully completed!
      } on SocketException catch (_) {
        stopwatch.stop();
        logGeminiFailure('network', null);
        lastAudioError = GeminiAudioErrorType.network;
        if (mIndex + 1 < candidateModels.length) continue;
        break;
      } on TimeoutException catch (_) {
        stopwatch.stop();
        logGeminiFailure('timeout', null);
        lastAudioError = GeminiAudioErrorType.network;
        if (mIndex + 1 < candidateModels.length) continue;
        break;
      } on http.ClientException catch (_) {
        stopwatch.stop();
        logGeminiFailure('network', null);
        lastAudioError = GeminiAudioErrorType.network;
        if (mIndex + 1 < candidateModels.length) continue;
        break;
      } catch (_) {
        stopwatch.stop();
        logGeminiFailure('invalid JSON', lastStatusCode);
        lastAudioError = GeminiAudioErrorType.unknown;
        break;
      }
    }

    return result;
  }

  /// Builds the system prompt for goal audio analysis
  static String buildGoalSystemPrompt() {
    final keysList = GoalIconHelper.allowedKeys.join(', ');
    return '''
أنت مساعد صوتي ذكي لتطبيق باقي في مصر.
وظيفتك تحليل التسجيل الصوتي بالعامية المصرية لاستخراج:
1. transcript: النص الحرفي المسموع بدقة.
2. goal_name: اسم الشيء أو الهدف المراد ادخار المال له (مثال: ايفون، ماك بوك، عربية، مصيف، شقة).
3. target_amount_egp: المبلغ الإجمالي المطلوب للهدف كرقم صحيح بالجنيه المصري (مثال: مية الف -> 100000).
4. icon: مفتاح الأيقونة المناسبة للهدف من هذه القائمة الحصرية فقط:
$keysList

قواعد صارمة:
- لا تختر أي مفتاح غير موجود في القائمة المسموحة.
- إذا لم تكن هناك أيقونة واضحة، اختر "flag".
- لا تختر "savings" إلا لأهداف الطوارئ أو الادخار العام الصريح.
- المبلغ يجب أن يكون مذكورًا في التسجيل. إذا لم يذكر مبلغ، اجعل target_amount_egp يساوي 0.
''';
  }

  /// Sends a continuous audio file to Gemini to extract a goal, amount, and icon.
  Future<GoalAudioParseResult?> parseGoalAudio(File audioFile) async {
    final key = apiKey;
    if (key == null || key.isEmpty) return null;
    if (!await audioFile.exists()) return null;

    final fileBytes = await audioFile.readAsBytes();
    final fileSizeBytes = fileBytes.length;
    final base64Audio = base64Encode(fileBytes);
    final candidateModels = <String>[
      'gemini-3.6-flash',
      'gemini-3.8-flash',
      'gemini-3.5-flash-lite',
    ];

    final requestPayload = {
      'systemInstruction': {
        'parts': [
          {'text': buildGoalSystemPrompt()}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inline_data': {
                'mime_type': 'audio/mp4',
                'data': base64Audio,
              }
            },
            {
              'text': 'حلّل هدف التحويش ده.',
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        'responseSchema': goalAudioResponseSchema,
        'maxOutputTokens': 2048,
        'thinkingConfig': {
          'thinkingBudget': 0,
        },
      }
    };

    lastAudioError = GeminiAudioErrorType.none;
    lastStatusCode = null;
    GoalAudioParseResult? result;

    for (int mIndex = 0; mIndex < candidateModels.length; mIndex++) {
      final currentModel = candidateModels[mIndex];
      final url = Uri.parse('$baseUrl/$currentModel:generateContent?key=$key');
      final stopwatch = Stopwatch()..start();

      try {
        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestPayload),
            )
            .timeout(const Duration(seconds: 6));

        stopwatch.stop();
        final latencyMs = stopwatch.elapsedMilliseconds;
        lastStatusCode = response.statusCode;

        if (response.statusCode != 200) {
          if (response.statusCode == 429) {
            logGeminiFailure('429', 429);
            lastAudioError = GeminiAudioErrorType.rateLimited;
          } else if (response.statusCode >= 500 && response.statusCode < 600) {
            logGeminiFailure('5xx', response.statusCode);
            lastAudioError = GeminiAudioErrorType.serverError;
          } else {
            logGeminiFailure('network', response.statusCode);
            lastAudioError = GeminiAudioErrorType.network;
          }
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        Map<String, dynamic> jsonBody;
        try {
          jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          logGeminiFailure('invalid JSON', response.statusCode);
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        final candidates = jsonBody['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          logGeminiFailure('invalid JSON', response.statusCode);
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        final content = candidates.first['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        final rawText = parts?.first?['text'] as String?;
        if (rawText == null || rawText.trim().isEmpty) {
          logGeminiFailure('invalid JSON', response.statusCode);
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        dynamic decoded;
        try {
          decoded = jsonDecode(rawText);
        } catch (_) {
          logGeminiFailure('invalid JSON', response.statusCode);
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        if (decoded is! Map<String, dynamic>) {
          logGeminiFailure('invalid JSON', response.statusCode);
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        final rawTranscript = decoded['transcript']?.toString() ?? '';
        final goalName = decoded['goal_name']?.toString() ?? '';
        final targetAmountNum = decoded['target_amount_egp'];
        final rawIcon = decoded['icon']?.toString();

        final targetAmountEgp =
            targetAmountNum is num ? targetAmountNum.round() : 0;
        final resolvedIcon = GoalIconHelper.validateOrResolve(
          rawIcon,
          goalName: goalName,
        );

        if (targetAmountEgp <= 0 || goalName.trim().isEmpty) {
          logGeminiFailure('invalid JSON', response.statusCode);
          if (mIndex + 1 < candidateModels.length) continue;
          break;
        }

        result = GoalAudioParseResult(
          transcript: rawTranscript,
          goalName: goalName.trim(),
          targetAmountEgp: targetAmountEgp,
          icon: resolvedIcon,
          requestDurationMs: latencyMs,
          fileSizeBytes: fileSizeBytes,
          rawResponse: rawText,
        );
        lastAudioError = GeminiAudioErrorType.none;
        break;
      } on SocketException catch (_) {
        stopwatch.stop();
        logGeminiFailure('network', null);
        lastAudioError = GeminiAudioErrorType.network;
        if (mIndex + 1 < candidateModels.length) continue;
        break;
      } on TimeoutException catch (_) {
        stopwatch.stop();
        logGeminiFailure('timeout', null);
        lastAudioError = GeminiAudioErrorType.network;
        if (mIndex + 1 < candidateModels.length) continue;
        break;
      } on http.ClientException catch (_) {
        stopwatch.stop();
        logGeminiFailure('network', null);
        lastAudioError = GeminiAudioErrorType.network;
        if (mIndex + 1 < candidateModels.length) continue;
        break;
      } catch (_) {
        stopwatch.stop();
        logGeminiFailure('invalid JSON', lastStatusCode);
        lastAudioError = GeminiAudioErrorType.unknown;
        break;
      }
    }

    return result;
  }

  /// Section 3 Verifications:
  /// - Every amount_egp must be in transcript. If not, mark needs_review and set amount to null.
  /// - source_text substring of transcript.
  /// - Match category with categories table after normalization.
  /// - If new category, prevent duplicates with existing categories, sanitize icon to allowed list.
  /// - If not new category and no match, keep name but mark needs_review (no silent conversion to أخرى).
  /// - Foreign amounts stored for reference only.
  static List<ParsedExpense> verifyAndNormalizeAudioOperations({
    required String transcript,
    required List<ParsedExpense> operations,
    required List<CategoryItem> categories,
    required List<String> defaultNames,
  }) {
    final normTranscript = EgyptianExpenseParser.normalize(transcript);
    final transcriptAmounts =
        EgyptianExpenseParser.extractAllAmounts(transcript).toSet();

    final allExistingCategoryNames = {
      ...defaultNames,
      ...categories.map((c) => c.name),
    };

    final verified = <ParsedExpense>[];

    for (int i = 0; i < operations.length; i++) {
      var op = operations[i];

      // 1. Amount verification in transcript
      if (op.amount != null) {
        final amt = op.amount!;
        final inExtractor = transcriptAmounts.contains(amt);
        final inDigits = transcript.contains(amt.toString()) ||
            transcript.contains(amt.toArabicDigits());
        final inNorm = normTranscript.contains(amt.toString());

        final amountVerified = inExtractor || inDigits || inNorm;
        if (!amountVerified) {
          if (kDebugMode) {
            debugPrint(
              '[AUDIO_DEBUG] [VERIFICATION] Amount $amt for "${op.description}" NOT found in transcript. Setting amount=null and needs_review=true.',
            );
          }
          op = op.copyWith(clearAmount: true, confidence: (op.confidence * 0.5));
        } else {
          if (kDebugMode) {
            debugPrint(
              '[AUDIO_DEBUG] [VERIFICATION] Amount $amt for "${op.description}" verified in transcript.',
            );
          }
        }
      }

      // 2. source_text substring verification
      if (op.sourceText != null && op.sourceText!.trim().isNotEmpty) {
        final normSource = EgyptianExpenseParser.normalize(op.sourceText!);
        final isSubstring = normTranscript.contains(normSource) ||
            transcript.contains(op.sourceText!.trim());
        if (kDebugMode) {
          debugPrint(
            '[AUDIO_DEBUG] [VERIFICATION] source_text "${op.sourceText}" substring check: $isSubstring',
          );
        }
      }

      // 3. Category matching with categories table
      final currentCatName = op.category.trim();
      final matchedItem = CategoryMatcher.matchItem(
        categoryName: currentCatName,
        categories: categories,
      );
      final hasExactOrNormalizedMatch =
          CategoryMatcher.normalize(matchedItem.name) ==
                  CategoryMatcher.normalize(currentCatName) ||
              allExistingCategoryNames.any((n) =>
                  CategoryMatcher.normalize(n) ==
                  CategoryMatcher.normalize(currentCatName));

      if (op.isNewCategory) {
        // AI proposed a new category
        final proposal = op.newCategoryProposal;
        final proposedName = proposal?.name.trim() ?? currentCatName;
        final isDuplicate = allExistingCategoryNames.any((n) =>
            CategoryMatcher.normalize(n) ==
            CategoryMatcher.normalize(proposedName));

        if (isDuplicate) {
          // Prevent duplicate! Bind to existing category
          final resolvedExisting = CategoryMatcher.matchItem(
            categoryName: proposedName,
            categories: categories,
          );
          if (kDebugMode) {
            debugPrint(
              '[AUDIO_DEBUG] [VERIFICATION] Proposed new category "$proposedName" duplicates existing "${resolvedExisting.name}". Merging to existing.',
            );
          }
          op = op.copyWith(
            category: resolvedExisting.name,
            isNewCategory: false,
            clearProposal: true,
          );
        } else {
          // Sanitize icon to allowed whitelist
          final rawIcon = proposal?.icon;
          final sanitizedIcon = CategoryIconHelper.sanitizeIconName(rawIcon);
          final safeProposal = ParsedExpenseCategoryProposal(
            name: proposedName,
            icon: sanitizedIcon,
            color: proposal?.color ?? '#4E8B7A',
          );
          op = op.copyWith(
            category: proposedName,
            isNewCategory: true,
            newCategoryProposal: safeProposal,
          );
        }
      } else {
        // Existing category expected
        if (hasExactOrNormalizedMatch) {
          op = op.copyWith(category: matchedItem.name);
        } else {
          // No match and is_new_category == false: DO NOT silently convert to أخرى!
          // Keep category name as is and mark needs_review = true.
          if (kDebugMode) {
            debugPrint(
              '[AUDIO_DEBUG] [VERIFICATION] Category "$currentCatName" not recognized and not marked new. Keeping name and setting needs_review=true without falling to أخرى.',
            );
          }
          op = op.copyWith(
            confidence: 0.5, // marks needsReview = true
          );
        }
      }

      verified.add(op);
    }

    return verified;
  }

  // ================= Legacy Text-Only Parser =================

  /// Legacy text-only parse method kept for backwards compatibility.
  Future<List<ParsedExpense>?> parse(
    String input, {
    List<String> categories = const [],
    List<({int id, String keyword, String categoryName, int categoryId})>
        userRules = const [],
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return [];

    final key = apiKey;
    if (key == null || key.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '[GEMINI_API] GEMINI_API_KEY is not set or empty. Falling back.');
      }
      return null;
    }

    final effectiveCategories = <String>{
      ...defaultCategoryNames,
      ...categories,
    }.toList();

    final model = activeModelName;
    final url = Uri.parse('$baseUrl/$model:generateContent?key=$key');
    final systemPrompt = buildAudioSystemPrompt(
      categories: effectiveCategories,
      userRules: userRules,
    );

    final requestPayload = {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': trimmed}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
      }
    };

    if (kDebugMode) {
      debugPrint('[VOICE_DEBUG] Gemini parser input text: "$trimmed"');
    }

    try {
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestPayload),
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint(
          '[VOICE_DEBUG] Gemini HTTP response: status ${response.statusCode}, body: ${response.body}',
        );
      }

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            '[GEMINI_API] Request error: HTTP ${response.statusCode}: ${response.body}',
          );
        }
        return null;
      }

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = jsonBody['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final rawText = parts?.first?['text'] as String?;
      if (rawText == null || rawText.trim().isEmpty) return null;

      if (kDebugMode) {
        debugPrint('[VOICE_DEBUG] Raw AI Response: "$rawText"');
      }

      final dynamic decoded = jsonDecode(rawText);
      if (decoded is! List) return null;

      final items = <ParsedExpense>[];
      for (final el in decoded) {
        if (el is Map<String, dynamic>) {
          items.add(ParsedExpense.fromJson(el));
        }
      }

      final processed = postProcessItems(items, trimmed);

      final isValid = validateResponse(
        originalInput: trimmed,
        items: processed,
        currentCategories: effectiveCategories,
      );

      if (!isValid) {
        if (kDebugMode) {
          debugPrint(
              '[GEMINI_API] Validation failed. Falling back to local parser.');
        }
        return null;
      }

      final mapped = processed.map((item) {
        if (item.isNewCategory) return item;
        final matchedCat = CategoryMatcher.matchName(
          categoryName: item.category,
          availableNames: effectiveCategories,
        );
        return item.copyWith(category: matchedCat);
      }).toList();

      return mapped;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[GEMINI_API] Exception during Gemini parse: $e\n$st');
      }
      return null;
    }
  }

  static bool validateResponse({
    required String originalInput,
    required List<ParsedExpense> items,
    required List<String> currentCategories,
  }) {
    if (items.isEmpty) return false;

    final normOriginal = EgyptianExpenseParser.normalize(originalInput);
    final allInputAmountsList =
        EgyptianExpenseParser.extractAllAmounts(originalInput);
    final allInputAmountsSet = allInputAmountsList.toSet();

    for (final item in items) {
      if (item.amount != null) {
        final amount = item.amount!;
        if (amount <= 0) return false;

        final matchedInExtractor = allInputAmountsSet.contains(amount);
        final matchedAsDigits = originalInput.contains(amount.toString()) ||
            originalInput.contains(amount.toArabicDigits());
        final sourceAmounts = item.sourceText != null
            ? EgyptianExpenseParser.extractAllAmounts(item.sourceText!).toSet()
            : <int>{};
        final matchedInSource = sourceAmounts.contains(amount);
        final matchedInNorm = normOriginal.contains(amount.toString());

        if (!matchedInExtractor &&
            !matchedAsDigits &&
            !matchedInSource &&
            !matchedInNorm) {
          if (kDebugMode) {
            debugPrint(
              '[GEMINI_VALIDATION] Failed: amount $amount not found in input text',
            );
          }
          return false;
        }
      }
    }

    return true;
  }

  static List<ParsedExpense> postProcessItems(
    List<ParsedExpense> items,
    String originalInput,
  ) {
    if (items.length <= 1) return items;

    final hasPriceWithB =
        originalInput.contains('ب') || originalInput.contains('بـ');
    if (!hasPriceWithB) return items;

    final unitRegex = RegExp(
      r'(?:جرام|جم|كيلو|كجم|لتر|قطعه|قطع|جيجا|عيار|جنيه\s+دهب|جنيه\s+ذهب|ربع\s+جنيه|نص\s+جنيه|سبيكه|سبيكة)',
    );

    final result = <ParsedExpense>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final normDesc = EgyptianExpenseParser.normalize(item.description);
      final normSource =
          EgyptianExpenseParser.normalize(item.sourceText ?? '');
      final hasUnit =
          unitRegex.hasMatch(normDesc) || unitRegex.hasMatch(normSource);

      final isSuspiciousQuantity = hasUnit &&
          (item.amount == null ||
              (item.amount != null &&
                  item.amount! <= 250 &&
                  !originalInput.contains('ب${item.amount}') &&
                  !originalInput.contains('ب ${item.amount}')));

      if (isSuspiciousQuantity && result.isNotEmpty) {
        final prev = result.removeLast();
        final mergedDesc = '${item.description} ${prev.description}'.trim();
        final qText = item.quantityText ?? (hasUnit ? item.description : null);
        result.add(
          prev.copyWith(
            description: mergedDesc.isNotEmpty ? mergedDesc : prev.description,
            quantityText: qText ?? prev.quantityText,
            category: (mergedDesc.contains('دهب') ||
                    mergedDesc.contains('ذهب') ||
                    mergedDesc.contains('سبيكة') ||
                    mergedDesc.contains('سبيكه'))
                ? 'استثمار وادخار'
                : prev.category,
          ),
        );
      } else if (isSuspiciousQuantity && i + 1 < items.length) {
        final next = items[i + 1];
        final mergedDesc = '${item.description} ${next.description}'.trim();
        final qText = item.quantityText ?? (hasUnit ? item.description : null);
        items[i + 1] = next.copyWith(
          description: mergedDesc.isNotEmpty ? mergedDesc : next.description,
          quantityText: qText ?? next.quantityText,
          category: (mergedDesc.contains('دهب') ||
                  mergedDesc.contains('ذهب') ||
                  mergedDesc.contains('سبيكة') ||
                  mergedDesc.contains('سبيكه'))
              ? 'استثمار وادخار'
              : next.category,
        );
      } else {
        result.add(item);
      }
    }

    return result;
  }
}
