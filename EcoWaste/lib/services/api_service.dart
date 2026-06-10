// ─────────────────────────────────────────────────────────────────────────────
// 📁 SAVE TO: lib/services/api_service.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class ApiService {
  // ── Backend URL ───────────────────────────────────────────────────────────
  static const String _baseUrl =
      'https://ecowaste-backend-v8i9.onrender.com/api';

  // ── Gemini API ────────────────────────────────────────────────────────────
  static const String _geminiKey = 'YOUR_GEMINI_KEY_HERE';
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-1.5-flash:generateContent';

  static const Map<String, String> _geminiHeaders = {
    'Content-Type': 'application/json',
  };

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const _keyToken      = 'auth_token';
  static const _keyUsername   = 'auth_username';
  static const _keyFullName   = 'auth_full_name';
  static const _keyEmail      = 'auth_email';
  static const _keyUserId     = 'auth_user_id';
  static const _keyEcoPoints  = 'auth_eco_points';
  static const _keyTotalKg    = 'auth_total_kg';
  static const _keyRole       = 'auth_role';
  static const _keyPhone      = 'auth_phone';

  // ── Header helpers ────────────────────────────────────────────────────────
  static Future<Map<String, String>> get _authHeaders async {
    final token = await getToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  static void _log(String tag, String msg) {
    if (kDebugMode) debugPrint('[$tag] $msg');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OTP METHODS - PRIMARY (WITH AUTO-FILL SUPPORT)
  // ══════════════════════════════════════════════════════════════════════════

  /// Send OTP - Returns OTP code for auto-fill in development
  static Future<Map<String, dynamic>> sendOtp({
    String? phone,
    String? email,
    String name = 'User',
  }) async {
    const tag = 'SEND_OTP';
    _log(tag, 'phone=$phone email=$email name=$name');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/send-otp'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'phone': phone,
              'email': email,
              'name': name,
            }),
          )
          .timeout(const Duration(seconds: 35));

      final data = _safeJsonDecode(response.body);
      _log(tag, 'HTTP ${response.statusCode}: ${response.body}');

      final success = response.statusCode == 200 || response.statusCode == 201;
      
      // Extract OTP for auto-fill (development mode)
      String? otpCode;
      if (data['otp'] != null) {
        otpCode = data['otp'].toString();
      } else if (data['devOtp'] != null) {
        otpCode = data['devOtp'].toString();
      }

      return {
        'success': success,
        'message': data['message'] ?? (success ? 'OTP sent' : 'Failed to send OTP'),
        'otp': otpCode,  // Auto-fill OTP
        'channel': data['channel'],
        'sentTo': data['sentTo'] ?? phone ?? email,
        'data': data,
      };
    } catch (e) {
      _log(tag, 'Exception: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// Verify OTP with backend
  static Future<Map<String, dynamic>> verifyOtp({
    String? phone,
    String? email,
    required String otp,
  }) async {
    const tag = 'VERIFY_OTP';
    _log(tag, 'Verifying OTP=$otp phone=$phone email=$email');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/verify-otp'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'phone': phone,
              'email': email,
              'code': otp,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = _safeJsonDecode(response.body);
      _log(tag, 'HTTP ${response.statusCode}: ${response.body}');

      return {
        'success': response.statusCode == 200,
        'verified': data['verified'] == true,
        'message': data['message'] ?? '',
        'data': data,
      };
    } catch (e) {
      _log(tag, 'Exception: $e');
      return {
        'success': false,
        'verified': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// Resend OTP
  static Future<Map<String, dynamic>> resendOtp({
    String? phone,
    String? email,
    String name = 'User',
  }) async {
    const tag = 'RESEND_OTP';
    _log(tag, 'phone=$phone email=$email');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/resend-otp'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'phone': phone,
              'email': email,
              'name': name,
            }),
          )
          .timeout(const Duration(seconds: 35));

      final data = _safeJsonDecode(response.body);
      _log(tag, 'HTTP ${response.statusCode}: ${response.body}');

      String? otpCode;
      if (data['otp'] != null) {
        otpCode = data['otp'].toString();
      }

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'OTP resent',
        'otp': otpCode,
        'data': data,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Register a new user or collector.
  static Future<ApiResponse> register({
    required String fullName,
    required String username,
    required String phone,
    String? email,
    String? driverLicense,
    String? vehicleType,
    required String password,
    String role = 'user',
  }) async {
    const tag = 'REGISTER';
    try {
      final body = <String, dynamic>{
        'full_name': fullName,
        'username':  username,
        'phone':     phone,
        'password':  password,
        'role':      role,
      };
      if (email         != null && email.isNotEmpty)         body['email']           = email;
      if (driverLicense != null && driverLicense.isNotEmpty) body['driver_license']  = driverLicense;
      if (vehicleType   != null && vehicleType.isNotEmpty)   body['vehicle_type']    = vehicleType;

      _log(tag, 'Registering $username ($role)');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register'),
            headers: _jsonHeaders,
            body:    jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _log(tag, 'HTTP ${response.statusCode}: ${response.body}');

      final success = response.statusCode == 201;
      if (success && data['token'] != null) await _saveSession(data);

      return ApiResponse(
        success: success,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      _log(tag, 'Exception: $e');
      return ApiResponse(
        success: false,
        message: 'Haiwezi kufikia server. Angalia muunganiko wako.',
      );
    }
  }

  /// Login with email, phone, username, or driverId.
  static Future<ApiResponse> login({
    String? email,
    String? phone,
    String? username,
    String? driverId,
    required String password,
  }) async {
    const tag = 'LOGIN';
    try {
      final body = <String, dynamic>{'password': password};
      if (email    != null && email.isNotEmpty)    body['email']     = email;
      if (phone    != null && phone.isNotEmpty)    body['phone']     = phone;
      if (username != null && username.isNotEmpty) body['username']  = username;
      if (driverId != null && driverId.isNotEmpty) body['driver_id'] = driverId;

      _log(tag, 'Login attempt');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: _jsonHeaders,
            body:    jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _log(tag, 'HTTP ${response.statusCode}: ${response.body}');

      final success = response.statusCode == 200;
      if (success && data['token'] != null) await _saveSession(data);

      return ApiResponse(
        success: success,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      _log(tag, 'Exception: $e');
      return ApiResponse(
        success: false,
        message: 'Haiwezi kufikia server. Angalia muunganiko wako.',
      );
    }
  }

  /// Legacy OTP methods (backward-compat)
  static Future<ApiResponse> sendOtpLegacy(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/send-otp'),
            headers: _jsonHeaders,
            body:    jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kutuma OTP.');
    }
  }

  static Future<ApiResponse> verifyOtpLegacy(String phone, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/verify-otp'),
            headers: _jsonHeaders,
            body:    jsonEncode({'phone': phone, 'code': code}),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'OTP verification imeshindwa.',
      );
    }
  }

  static Future<ApiResponse> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResponse(success: false, message: 'Hujaingia.');
      }
      final response = await http
          .get(
            Uri.parse('$_baseUrl/auth/profile'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Haiwezi kufikia server.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WELCOME NOTIFICATION
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> sendWelcomeNotification({
    required String name,
    String? phone,
    String? email,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/notifications/welcome'),
            headers: _jsonHeaders,
            body:    jsonEncode({'name': name, 'phone': phone, 'email': email}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Fallback to direct delivery
    }

    await NotificationService.sendWelcomeNotification(
      name:  name,
      phone: phone,
      email: email,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COLLECTORS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> getNearbyCollectors({
    double? lat,
    double? lng,
    double radiusKm = 10,
  }) async {
    try {
      final token  = await getToken();
      final params = <String, String>{'radius': radiusKm.toString()};
      if (lat != null) params['lat'] = lat.toString();
      if (lng != null) params['lng'] = lng.toString();

      final uri = Uri.parse('$_baseUrl/collectors/nearby')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${token ?? ''}'})
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(
        success: true,
        message: 'simulated',
        data:    {'collectors': _simulatedCollectors(lat, lng)},
      );
    }
  }

  static Future<ApiResponse> updateCollectorLocation({
    required double lat,
    required double lng,
    required bool   isOnline,
    String locationSource = 'gps',
  }) async {
    try {
      final headers  = await _authHeaders;
      final response = await http
          .put(
            Uri.parse('$_baseUrl/collectors/location'),
            headers: headers,
            body: jsonEncode({
              'latitude':        lat,
              'longitude':       lng,
              'is_online':       isOnline,
              'location_source': locationSource,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Location update failed.');
    }
  }

  static Future<ApiResponse> getCollectorJobs({String status = 'pending'}) async {
    try {
      final token = await getToken();
      final uri   = Uri.parse('$_baseUrl/collectors/jobs')
          .replace(queryParameters: {'status': status});
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${token ?? ''}'})
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(
        success: true,
        message: 'simulated',
        data:    {'jobs': _simulatedJobs()},
      );
    }
  }

  static Future<ApiResponse> acceptJob(int jobId) async {
    try {
      final headers  = await _authHeaders;
      final response = await http
          .post(
            Uri.parse('$_baseUrl/collectors/jobs/$jobId/accept'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kukubali kazi.');
    }
  }

  static Future<ApiResponse> completeJob(int jobId, {double? weightKg}) async {
    try {
      final headers  = await _authHeaders;
      final response = await http
          .post(
            Uri.parse('$_baseUrl/collectors/jobs/$jobId/complete'),
            headers: headers,
            body: jsonEncode({'weight_kg': weightKg}),
          )
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kukamilisha kazi.');
    }
  }

  static Future<ApiResponse> bookCollector({
    required int    collectorId,
    required String wasteType,
    double?  estimatedKg,
    String?  notes,
    double?  userLat,
    double?  userLng,
    String?  address,
  }) async {
    try {
      final headers  = await _authHeaders;
      final response = await http
          .post(
            Uri.parse('$_baseUrl/collectors/book'),
            headers: headers,
            body: jsonEncode({
              'collector_id':   collectorId,
              'waste_type':     wasteType,
              'estimated_kg':   estimatedKg,
              'notes':          notes,
              'user_latitude':  userLat,
              'user_longitude': userLng,
              'address':        address,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 201,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kuweka booking.');
    }
  }

  static Future<ApiResponse> lookupCollectorByPhone(String phone) async {
    try {
      final token = await getToken();
      final uri   = Uri.parse('$_baseUrl/collectors/lookup')
          .replace(queryParameters: {'phone': phone});
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${token ?? ''}'})
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Phone lookup imeshindwa.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WASTE LOGS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> logWaste({
    required String wasteType,
    int     containerCount   = 1,
    double? weightKg,
    String? photoUrl,
    double? aiConfidence,
    String? aiDetectedType,
    int?    collectionPointId,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    try {
      final headers  = await _authHeaders;
      final response = await http
          .post(
            Uri.parse('$_baseUrl/waste/log'),
            headers: headers,
            body: jsonEncode({
              'waste_type':          wasteType,
              'container_count':     containerCount,
              'weight_kg':           weightKg,
              'photo_url':           photoUrl,
              'ai_confidence':       aiConfidence,
              'ai_detected_type':    aiDetectedType,
              'collection_point_id': collectionPointId,
              'latitude':            latitude,
              'longitude':           longitude,
              'notes':               notes,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 201,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kurekodi taka.');
    }
  }

  static Future<ApiResponse> getWasteLogs() async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResponse(success: false, message: 'Hujaingia.');
      }
      final response = await http
          .get(
            Uri.parse('$_baseUrl/waste/my-logs'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final logs = data['logs'] ?? data['data'] ?? [];
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    {'logs': logs},
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kupata rekodi.');
    }
  }

  static Future<ApiResponse> getMyLogs() => getWasteLogs();

  static Future<ApiResponse> deleteWasteLog(int logId) async {
    try {
      final headers  = await _authHeaders;
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/waste/log/$logId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kufuta rekodi.');
    }
  }

  static Future<ApiResponse> updateWasteLog({
    required int    logId,
    String?  wasteType,
    double?  weightKg,
    String?  notes,
    String?  status,
  }) async {
    try {
      final headers = await _authHeaders;
      final body    = <String, dynamic>{};
      if (wasteType != null) body['waste_type'] = wasteType;
      if (weightKg  != null) body['weight_kg']  = weightKg;
      if (notes     != null) body['notes']       = notes;
      if (status    != null) body['status']      = status;
      final response = await http
          .put(
            Uri.parse('$_baseUrl/waste/log/$logId'),
            headers: headers,
            body:    jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kusasisha rekodi.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAP — COLLECTION POINTS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> getCollectionPoints({
    String?  type,
    double?  lat,
    double?  lng,
  }) async {
    try {
      final params = <String, String>{};
      if (type != null) params['type'] = type;
      if (lat  != null) params['lat']  = lat.toString();
      if (lng  != null) params['lng']  = lng.toString();
      final uri = Uri.parse('$_baseUrl/map/collection-points')
          .replace(queryParameters: params.isEmpty ? null : params);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kupata maeneo.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VEHICLES
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> getNearbyVehicles({double? lat, double? lng}) async {
    try {
      final token  = await getToken();
      final params = <String, String>{};
      if (lat != null) params['lat'] = lat.toString();
      if (lng != null) params['lng'] = lng.toString();
      final uri = Uri.parse('$_baseUrl/vehicles/nearby')
          .replace(queryParameters: params.isEmpty ? null : params);
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${token ?? ''}'})
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kupata magari.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATS & LEADERBOARD
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> getMyStats() async {
    try {
      final token = await getToken();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/stats/me'),
            headers: {'Authorization': 'Bearer ${token ?? ''}'},
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kupata takwimu.');
    }
  }

  static Future<ApiResponse> getLeaderboard() async {
    try {
      final token = await getToken();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/stats/leaderboard'),
            headers: {'Authorization': 'Bearer ${token ?? ''}'},
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kupata orodha.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RECYCLING CENTERS & BOOKINGS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> getRecyclingCenters({String? wasteType}) async {
    try {
      final token  = await getToken();
      final params = wasteType != null
          ? <String, String>{'waste_type': wasteType}
          : <String, String>{};
      final uri = Uri.parse('$_baseUrl/bookings/centers')
          .replace(queryParameters: params.isEmpty ? null : params);
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${token ?? ''}'})
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kupata vituo.');
    }
  }

  static Future<ApiResponse> createBooking({
    required int    centerId,
    required String bookingDate,
    required String timeSlot,
    List<String>    wasteTypes   = const [],
    double?  estimatedKg,
    String?  notes,
  }) async {
    try {
      final headers  = await _authHeaders;
      final response = await http
          .post(
            Uri.parse('$_baseUrl/bookings'),
            headers: headers,
            body: jsonEncode({
              'center_id':    centerId,
              'booking_date': bookingDate,
              'time_slot':    timeSlot,
              'waste_types':  wasteTypes,
              'estimated_kg': estimatedKg,
              'notes':        notes,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 201,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kuhifadhi nafasi.');
    }
  }

  static Future<ApiResponse> getMyBookings({String? status}) async {
    try {
      final token  = await getToken();
      final params = status != null
          ? <String, String>{'status': status}
          : <String, String>{};
      final uri = Uri.parse('$_baseUrl/bookings/mine')
          .replace(queryParameters: params.isEmpty ? null : params);
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${token ?? ''}'})
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kupata nafasi.');
    }
  }

  static Future<ApiResponse> getBookingById(int id) async {
    try {
      final token = await getToken();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/bookings/$id'),
            headers: {'Authorization': 'Bearer ${token ?? ''}'},
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kupata booking.');
    }
  }

  static Future<ApiResponse> cancelBooking([
    int?    positionalId,
    int?    id,
    String? reason,
  ]) async {
    final bookingId = positionalId ?? id;
    if (bookingId == null) {
      return ApiResponse(success: false, message: 'Booking ID inahitajika.');
    }
    try {
      final headers  = await _authHeaders;
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/bookings/$bookingId'),
            headers: headers,
            body: reason != null ? jsonEncode({'reason': reason}) : null,
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kufuta nafasi.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> getNotifications() async {
    try {
      final token = await getToken();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/notifications'),
            headers: {'Authorization': 'Bearer ${token ?? ''}'},
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kupata arifa.');
    }
  }

  static Future<ApiResponse> markNotificationRead(int notifId) async {
    try {
      final headers  = await _authHeaders;
      final response = await http
          .put(
            Uri.parse('$_baseUrl/notifications/$notifId/read'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse(
        success: response.statusCode == 200,
        message: data['message'] ?? '',
        data:    data,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Imeshindwa kusasisha arifa.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GEMINI VISION — AI WASTE CLASSIFICATION
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> verifyAI(String imageBase64) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_geminiUrl?key=$_geminiKey'),
            headers: _geminiHeaders,
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'inline_data': {
                        'mime_type': 'image/jpeg',
                        'data':      imageBase64,
                      },
                    },
                    {
                      'text':
                          'You are a waste classification AI for EcoWaste app. '
                          'Analyze this image and classify the waste type. '
                          'Reply ONLY with valid JSON — no markdown, no extra text:\n'
                          '{"detected_type":"Plastic","confidence":95.5,'
                          '"description":"Clear plastic water bottle"}\n'
                          'detected_type must be exactly one of: '
                          'Plastic, Paper, Glass, Metal, Organic, E-Waste, '
                          'Mixed Waste. '
                          'confidence is a number 0-100. '
                          'description is a short phrase.',
                    },
                  ],
                }
              ],
              'generationConfig': {'maxOutputTokens': 300},
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final raw  = jsonDecode(response.body) as Map<String, dynamic>;
        final text = raw['candidates'][0]['content']['parts'][0]['text'] as String;
        final clean = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final data  = jsonDecode(clean) as Map<String, dynamic>;
        return ApiResponse(success: true, message: 'Detected', data: data);
      } else {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = err['error']?['message'] as String? ??
            'Gemini error ${response.statusCode}';
        if (response.statusCode == 429) {
          return ApiResponse(
            success: false,
            message: 'Rate limit. Subiri kidogo kisha jaribu tena.',
          );
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          return ApiResponse(
            success: false,
            message: 'Gemini API key si sahihi.',
          );
        }
        return ApiResponse(success: false, message: msg);
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'AI verification imeshindwa: $e',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GEMINI CHATBOT
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> chatWithAI({
    required List<Map<String, String>> messages,
  }) async {
    try {
      final geminiMessages = messages
          .map((m) => {
                'role': m['role'] == 'assistant' ? 'model' : 'user',
                'parts': [
                  {'text': m['content']!}
                ],
              })
          .toList();

      final response = await http
          .post(
            Uri.parse('$_geminiUrl?key=$_geminiKey'),
            headers: _geminiHeaders,
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {
                    'text':
                        'You are EcoBot, a helpful AI assistant for the '
                        'EcoWaste app. You specialize in waste management, '
                        'recycling, and environmental sustainability in '
                        'Tanzania and Africa. Give concise, practical answers. '
                        'Respond in the same language the user writes in '
                        '(Swahili or English).',
                  }
                ],
              },
              'contents':          geminiMessages,
              'generationConfig':  {'maxOutputTokens': 600},
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final raw   = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = raw['candidates'][0]['content']['parts'][0]['text'] as String;
        return ApiResponse(
          success: true,
          message: 'OK',
          data:    {'reply': reply},
        );
      } else {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: false,
          message: err['error']?['message'] ?? 'Chat error ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Chat imeshindwa: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GEMINI TEXT GENERATION
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> generateText({
    required String prompt,
    int maxTokens = 800,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_geminiUrl?key=$_geminiKey'),
            headers: _geminiHeaders,
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {
                    'text':
                        'You are an expert in environmental science, waste '
                        'management, and sustainability in East Africa. '
                        'Produce well-structured, professional text.',
                  }
                ],
              },
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ],
                }
              ],
              'generationConfig': {'maxOutputTokens': maxTokens},
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final raw  = jsonDecode(response.body) as Map<String, dynamic>;
        final text = raw['candidates'][0]['content']['parts'][0]['text'] as String;
        return ApiResponse(success: true, message: 'OK', data: {'text': text});
      } else {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(
          success: false,
          message: err['error']?['message'] ??
              'Text generation error ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Text generation imeshindwa: $e',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _keyToken, _keyUsername, _keyFullName, _keyEmail,
      _keyUserId, _keyEcoPoints, _keyTotalKg, _keyRole, _keyPhone,
    ]) {
      await prefs.remove(key);
    }
  }

  static Future<bool>    isLoggedIn()  async => (await getToken()) != null;
  static Future<String?> getToken()    async =>
      (await SharedPreferences.getInstance()).getString(_keyToken);
  static Future<String?> getUsername() async =>
      (await SharedPreferences.getInstance()).getString(_keyUsername);
  static Future<String?> getFullName() async =>
      (await SharedPreferences.getInstance()).getString(_keyFullName);
  static Future<String?> getEmail()    async =>
      (await SharedPreferences.getInstance()).getString(_keyEmail);
  static Future<String?> getRole()     async =>
      (await SharedPreferences.getInstance()).getString(_keyRole);
  static Future<String?> getPhone()    async =>
      (await SharedPreferences.getInstance()).getString(_keyPhone);
  static Future<int?>    getEcoPoints() async =>
      (await SharedPreferences.getInstance()).getInt(_keyEcoPoints);
  static Future<double?> getTotalKg()  async =>
      (await SharedPreferences.getInstance()).getDouble(_keyTotalKg);

  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, data['token']);
    final user = data['user'] as Map<String, dynamic>?;
    if (user != null) {
      await prefs.setString(_keyUsername,  user['username']   ?? '');
      await prefs.setString(_keyFullName,  user['full_name']  ?? '');
      await prefs.setString(_keyEmail,     user['email']      ?? '');
      await prefs.setString(_keyRole,      user['role']       ?? 'user');
      await prefs.setString(_keyPhone,     user['phone']      ?? '');
      await prefs.setInt(   _keyUserId,    user['id']         ?? 0);
      await prefs.setInt(   _keyEcoPoints, user['eco_points'] ?? 0);
      final kg = user['total_kg'];
      if (kg != null) {
        await prefs.setDouble(
          _keyTotalKg,
          double.tryParse(kg.toString()) ?? 0,
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIMULATION DATA (fallback when backend is unreachable)
  // ══════════════════════════════════════════════════════════════════════════

  static List<Map<String, dynamic>> _simulatedCollectors(
      double? lat, double? lng) {
    final baseLat = lat ?? -6.1722;
    final baseLng = lng ?? 35.7395;
    return [
      {
        'id': 1, 'full_name': 'Juma Ally Hassan',
        'username': 'juma_collector', 'phone': '+255712345678',
        'vehicle_type': 'Pikipiki', 'driver_license': 'T123 ABC',
        'latitude': baseLat + 0.005, 'longitude': baseLng + 0.003,
        'distance_km': 0.8, 'is_online': true,
        'location_source': 'gps', 'eco_points': 340,
      },
      {
        'id': 2, 'full_name': 'Fatuma Mwanga',
        'username': 'fatuma_mbebaji', 'phone': '+255754321098',
        'vehicle_type': 'Gari Dogo', 'driver_license': 'T456 DEF',
        'latitude': baseLat - 0.008, 'longitude': baseLng + 0.006,
        'distance_km': 1.2, 'is_online': true,
        'location_source': 'gps', 'eco_points': 520,
      },
      {
        'id': 3, 'full_name': 'Mohamed Salim',
        'username': 'moha_taka', 'phone': '+255769876543',
        'vehicle_type': 'Mkokoteni', 'driver_license': null,
        'latitude': baseLat + 0.012, 'longitude': baseLng - 0.009,
        'distance_km': 2.1, 'is_online': false,
        'location_source': 'phone_lookup', 'eco_points': 150,
      },
      {
        'id': 4, 'full_name': 'Amina Rashid',
        'username': 'amina_clean', 'phone': '+255723456789',
        'vehicle_type': 'Baiskeli', 'driver_license': 'T789 GHI',
        'latitude': baseLat - 0.003, 'longitude': baseLng - 0.011,
        'distance_km': 3.4, 'is_online': true,
        'location_source': 'gps', 'eco_points': 890,
      },
    ];
  }

  static List<Map<String, dynamic>> _simulatedJobs() => [
    {
      'id': 101, 'customer_name': 'Ali Khamis',
      'username': 'ali_user', 'address': 'Mtaa wa Karume, Dodoma',
      'location': '-6.1800, 35.7390', 'waste_type': 'Plastic',
      'estimated_kg': 5.0, 'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 102, 'customer_name': 'Zuhura Bakari',
      'username': 'zuhura_taka', 'address': 'Kijitonyama, Dodoma',
      'location': '-6.1650, 35.7420', 'waste_type': 'Mixed Waste',
      'estimated_kg': 12.5, 'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    },
  ];
}

// ── Response wrapper ──────────────────────────────────────────────────────────

class ApiResponse {
  final bool                   success;
  final String                 message;
  final Map<String, dynamic>?  data;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  @override
  String toString() =>
      'ApiResponse(success=$success, message=$message)';
}

// ── OTP send result (richer than ApiResponse) ─────────────────────────────────

class OtpSendResult {
  final bool               success;
  final String             message;
  final OtpDeliveryResult? delivery;
  final Map<String, dynamic>? backendData;

  /// Only non-null in debug mode — never show to users in production
  final String? otp;

  const OtpSendResult({
    required this.success,
    required this.message,
    this.delivery,
    this.backendData,
    this.otp,
  });

  @override
  String toString() =>
      'OtpSendResult(success=$success, message=$message, '
      'delivery=${delivery?.summary})';
}