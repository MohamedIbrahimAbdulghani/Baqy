import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

abstract class PasscodeEmailService {
  Future<bool> sendPasscodeResetEmail({
    required String recipientEmail,
    required String newPasscode,
    String? userName,
  });
}

class PasscodeEmailServiceImpl implements PasscodeEmailService {
  PasscodeEmailServiceImpl({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<bool> sendPasscodeResetEmail({
    required String recipientEmail,
    required String newPasscode,
    String? userName,
  }) async {
    final brevoApiKey = dotenv.env['BREVO_API_KEY']?.trim();
    final resendApiKey = dotenv.env['RESEND_API_KEY']?.trim();
    final webhookUrl = dotenv.env['EMAIL_WEBHOOK_URL']?.trim();
    final serviceId = dotenv.env['EMAILJS_SERVICE_ID']?.trim();
    final templateId = dotenv.env['EMAILJS_TEMPLATE_ID']?.trim();
    final publicKey = dotenv.env['EMAILJS_PUBLIC_KEY']?.trim();

    final htmlContent = '''
<div dir="rtl" style="font-family: Arial, Tahoma, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #E8E3D8; border-radius: 16px; background-color: #FFFFFF; color: #1F2420;">
  <div style="text-align: center; margin-bottom: 20px;">
    <h2 style="color: #2F6B5A; margin: 0; font-size: 24px;">تطبيق Baqy</h2>
    <p style="color: #5F675F; font-size: 13px; margin: 4px 0 0 0;">إدارة المصاريف الذكية</p>
  </div>
  <p style="font-size: 15px; line-height: 1.5; margin: 0 0 16px 0;">
    مرحباً <strong>${userName ?? 'عزيزي المستخدم'}</strong>،
  </p>
  <p style="font-size: 14px; line-height: 1.6; color: #333333; margin: 0 0 16px 0;">
    تم طلب رمز مرور جديد لفتح تطبيق Baqy الخاص بك. استخدم الرمز التالي لفتح التطبيق:
  </p>
  <div style="background-color: #E3EEE9; padding: 18px; border-radius: 12px; text-align: center; margin: 20px 0;">
    <span style="font-size: 12px; color: #2F6B5A; display: block; font-weight: 600; margin-bottom: 6px;">رمز المرور الجديد الخاص بك:</span>
    <span style="font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #2F6B5A;">$newPasscode</span>
  </div>
  <p style="font-size: 13px; color: #5F675F; line-height: 1.5; margin: 16px 0 0 0;">
    يمكنك الآن فتح التطبيق بهذا الرمز وتغييره في أي وقت من شاشة الإعدادات.
  </p>
</div>
''';

    // 1. Brevo REST API (Most popular free transactional email: 300 emails/day free)
    if (brevoApiKey != null && brevoApiKey.isNotEmpty) {
      try {
        final response = await _httpClient.post(
          Uri.parse('https://api.brevo.com/v3/smtp/email'),
          headers: {
            'accept': 'application/json',
            'api-key': brevoApiKey,
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'sender': {
              'name': 'Baqy App',
              'email': dotenv.env['BREVO_SENDER_EMAIL'] ?? 'support@baqy.app',
            },
            'to': [
              {'email': recipientEmail, 'name': userName ?? 'User'},
            ],
            'subject': 'Baqy - رمز المرور الجديد لفتح التطبيق',
            'htmlContent': htmlContent,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (kDebugMode) {
            debugPrint('[PasscodeEmailService] Sent successfully via Brevo to $recipientEmail');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('[PasscodeEmailService] Brevo response error (${response.statusCode}): ${response.body}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PasscodeEmailService] Brevo error: $e');
        }
      }
    }

    // 2. Resend REST API (3,000 emails/month free)
    if (resendApiKey != null && resendApiKey.isNotEmpty) {
      try {
        final response = await _httpClient.post(
          Uri.parse('https://api.resend.com/emails'),
          headers: {
            'Authorization': 'Bearer $resendApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'from': dotenv.env['RESEND_FROM_EMAIL'] ?? 'Baqy App <onboarding@resend.dev>',
            'to': [recipientEmail],
            'subject': 'Baqy - رمز المرور الجديد لفتح التطبيق',
            'html': htmlContent,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (kDebugMode) {
            debugPrint('[PasscodeEmailService] Sent successfully via Resend to $recipientEmail');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('[PasscodeEmailService] Resend response error (${response.statusCode}): ${response.body}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PasscodeEmailService] Resend error: $e');
        }
      }
    }

    // 3. Custom Webhook URL
    if (webhookUrl != null && webhookUrl.isNotEmpty) {
      try {
        final response = await _httpClient.post(
          Uri.parse(webhookUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': recipientEmail,
            'passcode': newPasscode,
            'userName': userName ?? 'مستخدم باقي',
            'appName': 'Baqy',
            'subject': 'Baqy - رمز المرور الجديد لفتح التطبيق',
            'html': htmlContent,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PasscodeEmailService] Webhook error: $e');
        }
      }
    }

    // 4. EmailJS Configuration
    if (serviceId != null &&
        serviceId.isNotEmpty &&
        templateId != null &&
        templateId.isNotEmpty &&
        publicKey != null &&
        publicKey.isNotEmpty) {
      try {
        final response = await _httpClient.post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'service_id': serviceId,
            'template_id': templateId,
            'user_id': publicKey,
            'template_params': {
              'to_email': recipientEmail,
              'user_email': recipientEmail,
              'passcode': newPasscode,
              'new_pin': newPasscode,
              'user_name': userName ?? 'مستخدم باقي',
              'app_name': 'Baqy',
            },
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PasscodeEmailService] EmailJS error: $e');
        }
      }
    }

    // 5. FormSubmit (Zero-config direct dispatch to recipient email):
    try {
      final response = await _httpClient.post(
        Uri.parse('https://formsubmit.co/ajax/$recipientEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Origin': 'https://baqy.app',
          'Referer': 'https://baqy.app',
        },
        body: jsonEncode({
          'name': 'تطبيق Baqy',
          '_subject': 'Baqy - رمز المرور الجديد لفتح التطبيق',
          'رمز_المرور_الجديد': newPasscode,
          'رسالة': 'مرحباً، رمز المرور الجديد الخاص بك لفتح تطبيق Baqy هو: $newPasscode',
          '_template': 'box',
          '_captcha': 'false',
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && (decoded['success'] == 'true' || decoded['success'] == true)) {
          if (kDebugMode) {
            debugPrint('[PasscodeEmailService] Sent successfully via FormSubmit to $recipientEmail');
          }
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PasscodeEmailService] FormSubmit error: $e');
      }
    }

    // If no email provider succeeded or none is configured:
    if (kDebugMode) {
      debugPrint('====================================================');
      debugPrint('❌ [BAQY SECURITY] PASSCODE RESET EMAIL NOT SENT');
      debugPrint('📧 Recipient: $recipientEmail');
      debugPrint('🔢 Generated Passcode: $newPasscode');
      debugPrint('ℹ️ Please set BREVO_API_KEY, RESEND_API_KEY, or EMAIL_WEBHOOK_URL in .env to deliver real emails to Gmail');
      debugPrint('====================================================');
    }

    return false;
  }
}
