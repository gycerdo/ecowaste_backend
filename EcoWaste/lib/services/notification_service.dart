// ─────────────────────────────────────────────────────────────────────────────
// 📁 SAVE TO: lib/services/notification_service.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Handles SMS and Email notifications via the EcoWaste backend relay.
///
/// IMPORTANT: Neither SMS nor email is sent directly from the app.
/// All requests go through your backend at [_backendBase], which holds
/// credentials server-side (MamboSMS token, SMTP password, etc.).
///
/// Backend endpoints expected:
///   POST /api/notifications/sms    { to, message }
///   POST /api/notifications/email  { to_email, to_name, subject, body, is_html, from_email, from_name }
class NotificationService {
  // ── Backend relay base URL ──────────────────────────────────────────────────
  static const String _backendBase =
      'https://ecowaste-backend-v8i9.onrender.com/api';

  // Email sender identity
  static const String _fromEmail = 'support@simuvote.com';
  static const String _fromName  = 'EcoWaste Support';

  // ── Retry / timeout settings ────────────────────────────────────────────────
  static const int      _maxRetries   = 3;
  static const Duration _retryDelay   = Duration(seconds: 5);
  static const Duration _smsTimeout   = Duration(seconds: 40);
  static const Duration _emailTimeout = Duration(seconds: 45);

  // ════════════════════════════════════════════════════════════════════════════
  // DEBUG LOGGER
  // ════════════════════════════════════════════════════════════════════════════

  static void _log(String tag, String msg) {
    if (kDebugMode) debugPrint('[$tag] $msg');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LOW-LEVEL HTTP WITH RETRY
  // ════════════════════════════════════════════════════════════════════════════

  static Future<http.Response?> _postWithRetry({
    required String url,
    required Map<String, dynamic> body,
    required Duration timeout,
    required String tag,
  }) async {
    http.Response? lastResponse;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      _log(tag, 'Attempt $attempt/$_maxRetries → POST $url');
      _log(tag, 'Body: ${jsonEncode(body)}');

      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept':       'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(timeout);

        lastResponse = response;
        _log(tag, 'HTTP ${response.statusCode} ← ${response.body}');

        // 2xx → success, stop retrying
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        // 4xx → client error, no point retrying
        if (response.statusCode >= 400 && response.statusCode < 500) {
          _log(tag, 'Client error ${response.statusCode}, not retrying');
          return response;
        }

        // 5xx → server error, retry
        _log(tag, 'Server error ${response.statusCode}, will retry');
      } on Exception catch (e) {
        _log(tag, 'Exception on attempt $attempt: $e');
      }

      if (attempt < _maxRetries) {
        final delay = _retryDelay * attempt;
        _log(tag, 'Waiting ${delay.inSeconds}s before retry…');
        await Future.delayed(delay);
      }
    }

    _log(tag, 'All $_maxRetries attempts exhausted');
    return lastResponse;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SMS
  // ════════════════════════════════════════════════════════════════════════════

  /// Send a single SMS via backend → MamboSMS.
  /// [phone] accepts: 0719XXXXXX, +255719XXXXXX, 255719XXXXXX
  static Future<SmsResult> sendSms({
    required String phone,
    required String message,
  }) async {
    const tag = 'SMS';
    try {
      final normalized = _normalizePhone(phone);
      _log(tag, 'Original: $phone → Normalized: $normalized');
      _log(tag, 'Message (${message.length} chars): $message');

      final response = await _postWithRetry(
        url:     '$_backendBase/notifications/sms',
        body:    {'to': normalized, 'message': message},
        timeout: _smsTimeout,
        tag:     tag,
      );

      if (response == null) {
        return SmsResult(
          success: false,
          message: 'Hakuna jibu kutoka server (timeout au mtandao mbaya)',
        );
      }

      final data = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = SmsResult(
          success:   true,
          messageId: data['message_id']?.toString() ??
                     data['id']?.toString() ?? '',
          message:   data['message']?.toString() ?? 'SMS imepelekwa',
        );
        _log(tag, '✅ SUCCESS — id=${result.messageId}');
        return result;
      }

      final errMsg = data['message']?.toString() ??
                     data['error']?.toString()   ??
                     data['detail']?.toString()  ??
                     'SMS imeshindwa (HTTP ${response.statusCode})';
      _log(tag, '❌ FAILED — $errMsg');
      return SmsResult(success: false, message: errMsg);

    } catch (e, stack) {
      _log(tag, '💥 EXCEPTION: $e\n$stack');
      return SmsResult(success: false, message: 'Imeshindwa kutuma SMS: $e');
    }
  }

  /// OTP via SMS
  static Future<SmsResult> sendOtpSms({
    required String phone,
    required String otp,
    String appName = 'EcoWaste',
  }) {
    final msg = '$appName: Nambari yako ya uthibitisho ni *$otp*. '
        'Inatumika kwa dakika 10. Usishirikishe na mtu yeyote.';
    return sendSms(phone: phone, message: msg);
  }

  /// Welcome SMS after registration
  static Future<SmsResult> sendWelcomeSms({
    required String phone,
    required String name,
  }) {
    final msg = 'Karibu EcoWaste, $name! '
        'Akaunti yako imefanikiwa kusajiliwa. '
        'Sasa unaweza kurekodi taka na kupata pointi za mazingira.';
    return sendSms(phone: phone, message: msg);
  }

  /// Waste log confirmation SMS
  static Future<SmsResult> sendWasteLogConfirmationSms({
    required String phone,
    required String wasteType,
    required double weightKg,
    required int ecoPoints,
  }) {
    final msg = 'EcoWaste: Rekodi ya taka imepokewa! '
        'Aina: $wasteType | Uzito: ${weightKg.toStringAsFixed(1)}kg | '
        'Pointi: +$ecoPoints. Asante kwa kulinda mazingira!';
    return sendSms(phone: phone, message: msg);
  }

  /// Collector pickup request SMS
  static Future<SmsResult> sendPickupRequestSms({
    required String collectorPhone,
    required String requesterName,
    required String address,
    required String wasteType,
  }) {
    final msg = 'EcoWaste: Ombi jipya la kukusanya taka! '
        'Mteja: $requesterName | Mahali: $address | Aina: $wasteType. '
        'Fungua app kukubali.';
    return sendSms(phone: collectorPhone, message: msg);
  }

  /// Bulk SMS with 300 ms inter-message delay
  static Future<List<SmsResult>> sendBulkSms({
    required List<String> phones,
    required String message,
  }) async {
    final results = <SmsResult>[];
    for (final phone in phones) {
      results.add(await sendSms(phone: phone, message: message));
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return results;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // EMAIL
  // ════════════════════════════════════════════════════════════════════════════

  static Future<EmailResult> sendEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String body,
    bool isHtml = true,
  }) async {
    const tag = 'EMAIL';
    try {
      _log(tag, 'To: $toName <$toEmail> | Subject: $subject');

      final response = await _postWithRetry(
        url: '$_backendBase/notifications/email',
        body: {
          'to_email':   toEmail,
          'to_name':    toName,
          'subject':    subject,
          'body':       body,
          'is_html':    isHtml,
          'from_email': _fromEmail,
          'from_name':  _fromName,
        },
        timeout: _emailTimeout,
        tag:     tag,
      );

      if (response == null) {
        return EmailResult(
          success: false,
          message: 'Hakuna jibu kutoka server',
        );
      }

      final data = _safeJsonDecode(response.body);
      final success = response.statusCode == 200 || response.statusCode == 201;
      final msg = data['message']?.toString() ??
                  data['error']?.toString() ?? '';
      _log(tag, success ? '✅ SUCCESS' : '❌ FAILED — $msg');
      return EmailResult(success: success, message: msg);

    } catch (e) {
      _log(tag, '💥 EXCEPTION: $e');
      return EmailResult(success: false, message: 'Email imeshindwa: $e');
    }
  }

  static Future<EmailResult> sendWelcomeEmail({
    required String email,
    required String name,
  }) =>
      sendEmail(
        toEmail: email,
        toName:  name,
        subject: 'Karibu EcoWaste — Akaunti Yako Imefanikiwa!',
        body:    _welcomeEmailHtml(name),
      );

  static Future<EmailResult> sendOtpEmail({
    required String email,
    required String name,
    required String otp,
  }) =>
      sendEmail(
        toEmail: email,
        toName:  name,
        subject: 'EcoWaste — Nambari Yako ya Uthibitisho ($otp)',
        body:    _otpEmailHtml(name, otp),
      );

  static Future<EmailResult> sendWasteLogEmail({
    required String email,
    required String name,
    required String wasteType,
    required double weightKg,
    required int ecoPoints,
  }) =>
      sendEmail(
        toEmail: email,
        toName:  name,
        subject: 'EcoWaste — Rekodi ya Taka Imepokewa',
        body:    _wasteLogEmailHtml(name, wasteType, weightKg, ecoPoints),
      );

  // ════════════════════════════════════════════════════════════════════════════
  // COMBINED OTP DELIVERY (SMS + EMAIL in parallel)
  // ════════════════════════════════════════════════════════════════════════════

  static Future<OtpDeliveryResult> sendOtp({
    required String otp,
    required String name,
    String? phone,
    String? email,
  }) async {
    SmsResult?   smsResult;
    EmailResult? emailResult;

    final futures = <Future>[];

    if (phone != null && phone.trim().isNotEmpty) {
      futures.add(
        sendOtpSms(phone: phone.trim(), otp: otp)
            .then((r) => smsResult = r),
      );
    }
    if (email != null && email.trim().isNotEmpty) {
      futures.add(
        sendOtpEmail(email: email.trim(), name: name, otp: otp)
            .then((r) => emailResult = r),
      );
    }

    await Future.wait(futures);

    final result = OtpDeliveryResult(
      smsResult:   smsResult,
      emailResult: emailResult,
      anySuccess:  (smsResult?.success  ?? false) ||
                   (emailResult?.success ?? false),
    );

    debugPrint('[OTP] Delivery summary: ${result.summary}');
    return result;
  }

  /// Welcome notification via SMS + Email in parallel
  static Future<void> sendWelcomeNotification({
    required String name,
    String? phone,
    String? email,
  }) async {
    final futures = <Future>[];
    if (phone != null && phone.trim().isNotEmpty) {
      futures.add(sendWelcomeSms(phone: phone.trim(), name: name));
    }
    if (email != null && email.trim().isNotEmpty) {
      futures.add(sendWelcomeEmail(email: email.trim(), name: name));
    }
    await Future.wait(futures);
  }

  /// Waste log notification via SMS + Email in parallel
  static Future<void> sendWasteLogNotification({
    required String name,
    required String wasteType,
    required double weightKg,
    required int ecoPoints,
    String? phone,
    String? email,
  }) async {
    final futures = <Future>[];
    if (phone != null && phone.trim().isNotEmpty) {
      futures.add(sendWasteLogConfirmationSms(
        phone:     phone.trim(),
        wasteType: wasteType,
        weightKg:  weightKg,
        ecoPoints: ecoPoints,
      ));
    }
    if (email != null && email.trim().isNotEmpty) {
      futures.add(sendWasteLogEmail(
        email:     email.trim(),
        name:      name,
        wasteType: wasteType,
        weightKg:  weightKg,
        ecoPoints: ecoPoints,
      ));
    }
    await Future.wait(futures);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIAGNOSTIC PING — call this from your settings/debug screen
  // ════════════════════════════════════════════════════════════════════════════

  /// Sends a test SMS to [phone] and returns a human-readable diagnostic string.
  static Future<String> diagnose(String phone) async {
    final normalized = _normalizePhone(phone);
    final lines = <String>[
      '📱 Input: $phone',
      '🔢 Normalized: $normalized',
      '🌐 Backend: $_backendBase',
    ];

    // Ping backend health
    try {
      final health = await http
          .get(Uri.parse('$_backendBase/../health'))
          .timeout(const Duration(seconds: 10));
      lines.add('🏥 Health endpoint: HTTP ${health.statusCode}');
    } catch (e) {
      lines.add('🏥 Health endpoint: ERROR ($e)');
    }

    // Send real test SMS
    lines.add('📤 Sending test SMS…');
    final result = await sendSms(
      phone:   phone,
      message: 'EcoWaste diagnostic test. Wakati: ${DateTime.now()}',
    );
    lines.add(result.success
        ? '✅ SMS OK — id=${result.messageId}'
        : '❌ SMS FAILED — ${result.message}');

    return lines.join('\n');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // OTP GENERATOR
  // ════════════════════════════════════════════════════════════════════════════

  /// Cryptographically random 6-digit OTP (100000–999999).
  static String generateOtp() {
    final otp = 100000 + Random.secure().nextInt(900000);
    return otp.toString();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PHONE NORMALIZER
  // ════════════════════════════════════════════════════════════════════════════

  /// Normalizes Tanzanian numbers to 255XXXXXXXXX (no leading +).
  ///   0719242796   → 255719242796
  ///  +255719242796 → 255719242796
  ///   255719242796 → 255719242796
  static String _normalizePhone(String phone) {
    // Strip spaces, dashes, parentheses
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()+]'), '');

    if (cleaned.startsWith('255') && cleaned.length == 12) return cleaned;
    if (cleaned.startsWith('0')   && cleaned.length == 10) {
      return '255${cleaned.substring(1)}';
    }
    // Already 9-digit national number (no leading 0)
    if (!cleaned.startsWith('255') && cleaned.length == 9) {
      return '255$cleaned';
    }
    // Fallback — return as-is after stripping non-digits
    return cleaned.replaceAll(RegExp(r'\D'), '');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SAFE JSON DECODE
  // ════════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  // ════════════════════════════════════════════════════════════════════════════
  // EMAIL HTML TEMPLATES
  // ════════════════════════════════════════════════════════════════════════════

  static String _welcomeEmailHtml(String name) => '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="font-family:Arial,sans-serif;background:#f5f5f5;padding:0;margin:0;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center" style="padding:40px 20px;">
      <table width="560" style="background:#fff;border-radius:16px;overflow:hidden;
             box-shadow:0 2px 12px rgba(0,0,0,0.08);max-width:100%;">
        <tr><td style="background:linear-gradient(135deg,#1B5E20,#43A047);
                       padding:32px;text-align:center;">
          <div style="font-size:32px;">🌿</div>
          <h1 style="color:#fff;margin:8px 0 0;font-size:22px;letter-spacing:1px;">EcoWaste</h1>
          <p style="color:rgba(255,255,255,0.8);margin:4px 0 0;font-size:13px;">
            Civic Waste Intelligence</p>
        </td></tr>
        <tr><td style="padding:32px;">
          <h2 style="color:#1A1A1A;margin:0 0 12px;">Karibu, $name! 🎉</h2>
          <p style="color:#555;line-height:1.7;margin:0 0 16px;">
            Akaunti yako ya <strong>EcoWaste</strong> imefanikiwa kusajiliwa.
          </p>
          <ul style="color:#555;line-height:2;padding-left:20px;">
            <li>Rekodi taka zako kwa urahisi</li>
            <li>Pata pointi za mazingira (Eco Points)</li>
            <li>Pata wabebaji wa taka karibu nawe</li>
            <li>Fuatilia takwimu zako za kila siku</li>
          </ul>
          <p style="color:#888;font-size:12px;margin:24px 0 0;line-height:1.6;">
            Kama hukufungua akaunti hii, wasiliana nasi:
            <strong>support@simuvote.com</strong>
          </p>
        </td></tr>
        <tr><td style="background:#f9f9f9;padding:20px;text-align:center;
                       border-top:1px solid #eee;">
          <p style="color:#aaa;font-size:11px;margin:0;">
            © ${DateTime.now().year} EcoWaste · Civic Waste Intelligence<br>
            <a href="mailto:support@simuvote.com"
               style="color:#2E7D32;">support@simuvote.com</a>
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';

  static String _otpEmailHtml(String name, String otp) => '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="font-family:Arial,sans-serif;background:#f5f5f5;padding:0;margin:0;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center" style="padding:40px 20px;">
      <table width="560" style="background:#fff;border-radius:16px;overflow:hidden;
             box-shadow:0 2px 12px rgba(0,0,0,0.08);max-width:100%;">
        <tr><td style="background:linear-gradient(135deg,#1B5E20,#43A047);
                       padding:28px;text-align:center;">
          <div style="font-size:28px;">🔐</div>
          <h1 style="color:#fff;margin:8px 0 0;font-size:20px;">
            EcoWaste — Uthibitisho</h1>
        </td></tr>
        <tr><td style="padding:36px;text-align:center;">
          <p style="color:#555;font-size:15px;margin:0 0 24px;">
            Habari $name,<br>Nambari yako ya uthibitisho ni:</p>
          <div style="background:#E8F5E9;border:2px dashed #2E7D32;
                      border-radius:12px;padding:24px;display:inline-block;">
            <span style="font-size:42px;font-weight:bold;letter-spacing:12px;
                         color:#1B5E20;">$otp</span>
          </div>
          <p style="color:#888;font-size:13px;margin:24px 0 0;line-height:1.7;">
            Nambari hii inatumika kwa <strong>dakika 10</strong> tu.<br>
            <strong style="color:#c0392b;">Usishirikishe na mtu yeyote.</strong>
          </p>
        </td></tr>
        <tr><td style="background:#f9f9f9;padding:18px;text-align:center;
                       border-top:1px solid #eee;">
          <p style="color:#aaa;font-size:11px;margin:0;">
            Kama hukutaka nambari hii, puuza barua pepe hii.<br>
            © ${DateTime.now().year} EcoWaste
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';

  static String _wasteLogEmailHtml(
    String name,
    String wasteType,
    double weightKg,
    int ecoPoints,
  ) =>
      '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="font-family:Arial,sans-serif;background:#f5f5f5;padding:0;margin:0;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center" style="padding:40px 20px;">
      <table width="560" style="background:#fff;border-radius:16px;overflow:hidden;
             box-shadow:0 2px 12px rgba(0,0,0,0.08);max-width:100%;">
        <tr><td style="background:linear-gradient(135deg,#1B5E20,#43A047);
                       padding:28px;text-align:center;">
          <div style="font-size:28px;">✅</div>
          <h1 style="color:#fff;margin:8px 0 0;font-size:20px;">
            Rekodi ya Taka Imepokewa</h1>
        </td></tr>
        <tr><td style="padding:32px;">
          <p style="color:#1A1A1A;font-size:15px;margin:0 0 20px;">
            Habari $name,</p>
          <p style="color:#555;margin:0 0 24px;">
            Rekodi yako ya taka imepokewa kikamilifu. Hapa maelezo:</p>
          <table width="100%" style="border-collapse:collapse;">
            <tr style="background:#E8F5E9;">
              <td style="padding:12px 16px;font-weight:bold;color:#1B5E20;">
                Aina ya Taka</td>
              <td style="padding:12px 16px;color:#333;">$wasteType</td>
            </tr>
            <tr>
              <td style="padding:12px 16px;font-weight:bold;color:#1B5E20;
                         background:#f5f5f5;">Uzito</td>
              <td style="padding:12px 16px;color:#333;background:#f5f5f5;">
                ${weightKg.toStringAsFixed(1)} kg</td>
            </tr>
            <tr style="background:#E8F5E9;">
              <td style="padding:12px 16px;font-weight:bold;color:#1B5E20;">
                Eco Points</td>
              <td style="padding:12px 16px;color:#2E7D32;font-weight:bold;
                         font-size:18px;">+$ecoPoints pts</td>
            </tr>
          </table>
          <p style="color:#888;font-size:13px;margin:24px 0 0;line-height:1.6;">
            Asante kwa kulinda mazingira yetu! 🌍
          </p>
        </td></tr>
        <tr><td style="background:#f9f9f9;padding:18px;text-align:center;
                       border-top:1px solid #eee;">
          <p style="color:#aaa;font-size:11px;margin:0;">
            © ${DateTime.now().year} EcoWaste</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';
}

// ── Result models ─────────────────────────────────────────────────────────────

class SmsResult {
  final bool   success;
  final String message;
  final String messageId;

  const SmsResult({
    required this.success,
    required this.message,
    this.messageId = '',
  });

  @override
  String toString() =>
      'SmsResult(success=$success, messageId=$messageId, message=$message)';
}

class EmailResult {
  final bool   success;
  final String message;

  const EmailResult({required this.success, required this.message});

  @override
  String toString() => 'EmailResult(success=$success, message=$message)';
}

class OtpDeliveryResult {
  final SmsResult?   smsResult;
  final EmailResult? emailResult;
  final bool         anySuccess;

  const OtpDeliveryResult({
    this.smsResult,
    this.emailResult,
    required this.anySuccess,
  });

  String get summary {
    final parts = <String>[];
    if (smsResult   != null) {
      parts.add('SMS: ${smsResult!.success   ? "✅" : "❌ ${smsResult!.message}"}');
    }
    if (emailResult != null) {
      parts.add('Email: ${emailResult!.success ? "✅" : "❌ ${emailResult!.message}"}');
    }
    return parts.join(' | ');
  }
}