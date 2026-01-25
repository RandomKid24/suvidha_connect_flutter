import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart';

class ApiService {
  // Update this based on your environment:
  // Production: https://suvidhaconnect.pythonanywhere.com/api
  // Android Emulator: http://10.0.2.2:8000/api
  // iOS Simulator: http://localhost:8000/api
  // Physical Device: http://YOUR_COMPUTER_IP:8000/api (e.g., http://192.168.1.100:8000/api)
  // static const String baseUrl = 'http://192.168.1.15:8000/api'; // Local development
  static const String baseUrl = 'https://suvidhaconnect.pythonanywhere.com/api'; // Production URL
  
  // Test connection
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/services/categories/'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
  
  static Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Always include session cookie if available (for authenticated endpoints)
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId != null && sessionId.isNotEmpty) {
      headers['Cookie'] = 'sessionid=$sessionId';
      print('Including session cookie in request: sessionid=$sessionId');
    } else {
      print('No session cookie found in SharedPreferences');
    }
    
    return headers;
  }
  
  // Extract and save session cookie from response
  static Future<void> _saveSessionCookie(http.Response response) async {
    try {
      print('🍪 Extracting session cookie from response...');
      print('   All response headers:');
      response.headers.forEach((key, value) {
        print('      $key: $value');
      });
      
      // Check all possible cookie header formats (case-insensitive)
      String? cookieHeader;
      for (var key in response.headers.keys) {
        if (key.toLowerCase() == 'set-cookie') {
          cookieHeader = response.headers[key];
          print('   Found Set-Cookie header: $cookieHeader');
          break;
        }
      }
      
      if (cookieHeader != null) {
        // Extract sessionid from cookie string
        // Format: sessionid=abc123; Path=/; HttpOnly; SameSite=Lax
        // Or multiple cookies: sessionid=abc123; csrftoken=xyz; Path=/
        final sessionMatch = RegExp(r'sessionid=([^;,\s]+)').firstMatch(cookieHeader);
        if (sessionMatch != null) {
          final sessionId = sessionMatch.group(1)!;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('session_id', sessionId);
          print('✅ Session ID saved successfully');
          print('   Session ID length: ${sessionId.length}');
          print('   Session ID (first 30 chars): ${sessionId.substring(0, sessionId.length > 30 ? 30 : sessionId.length)}...');
        } else {
          print('⚠️ Could not extract sessionid from cookie header');
          print('   Cookie header value: $cookieHeader');
        }
      } else {
        print('⚠️ No Set-Cookie header found in response');
        print('   Available headers: ${response.headers.keys.toList()}');
        // Try to get session from response cookies if available
        // Note: http package doesn't automatically parse cookies, so we rely on Set-Cookie header
      }
    } catch (e) {
      print('❌ Error saving session cookie: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }
  
  // Authentication
  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    String role = 'customer',
  }) async {
    try {
      // Normalize role - convert 'consumer' to 'customer'
      if (role == 'consumer') {
        role = 'customer';
      }
      // Ensure only valid roles
      if (role != 'customer' && role != 'provider' && role != 'admin') {
        role = 'customer';
      }
      
      print('Registering user: $firstName $lastName');
      print('Register URL: $baseUrl/auth/users/register/');
      print('Role being sent: $role');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/users/register/'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
          'password_confirm': password,
          'phone': phone,
          'role': role,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Registration request timed out after 30 seconds');
        },
      );
      
      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');
      print('Register request body: ${jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': '***',
        'password_confirm': '***',
        'phone': phone,
        'role': role,
      })}');
      
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('Register timeout: $e');
      return {'success': false, 'error': {'message': 'Request timed out. Please check your internet connection and try again.'}};
    } on SocketException catch (e) {
      print('Register network error: $e');
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Register error: $e');
      print('Error type: ${e.runtimeType}');
      return {'success': false, 'error': {'message': 'Registration failed: ${e.toString()}'}};
    }
  }
  
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      // Trim whitespace from inputs
      final trimmedUsername = username.trim();
      final trimmedPassword = password.trim();
      
      print('=== LOGIN REQUEST ===');
      print('Logging in user: $trimmedUsername');
      print('Username length: ${trimmedUsername.length}');
      print('Username bytes: ${utf8.encode(trimmedUsername)}');
      print('Password length: ${trimmedPassword.length}');
      print('Password first char: ${trimmedPassword.isNotEmpty ? trimmedPassword[0] : "empty"}');
      print('Password last char: ${trimmedPassword.isNotEmpty ? trimmedPassword[trimmedPassword.length - 1] : "empty"}');
      print('Login URL: $baseUrl/auth/users/login/');
      
      // Support both username and email - backend will handle it
      final requestBody = jsonEncode({
        'username': trimmedUsername,  // Backend accepts username or email in this field
        'password': trimmedPassword,
      });
      
      print('Request body (JSON): $requestBody');
      print('Request body bytes: ${utf8.encode(requestBody).length} bytes');
      print('====================');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/users/login/'),
        headers: await _getHeaders(),
        body: requestBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Login request timed out after 30 seconds');
        },
      );
      
      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');
      print('Login response headers: ${response.headers}');
      
      // ALWAYS try to save session cookie, even for 403 responses
      // The backend creates a session even if onboarding is incomplete
      await _saveSessionCookie(response);
      
      // Verify session was saved
      final prefs = await SharedPreferences.getInstance();
      final savedSessionId = prefs.getString('session_id');
      print('🔍 Verifying session was saved...');
      print('   Session ID saved: ${savedSessionId != null && savedSessionId.isNotEmpty}');
      if (savedSessionId != null && savedSessionId.isNotEmpty) {
        print('   Session ID (first 30 chars): ${savedSessionId.substring(0, savedSessionId.length > 30 ? 30 : savedSessionId.length)}...');
      } else {
        print('   ⚠️ WARNING: Session ID was not saved after login!');
        print('   This means the backend did not send a Set-Cookie header.');
      }
      
      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print('Login successful - User data: $responseData');
          
          // Backend returns user data directly (UserSerializer output)
          // Save user data to SharedPreferences for quick access
          await prefs.setString('user_data', jsonEncode(responseData));
          await prefs.setBool('is_logged_in', true);
          print('✅ User data saved to SharedPreferences');
          print('✅ Login state saved: is_logged_in = true');
          
          return {'success': true, 'data': responseData};
        } catch (e) {
          print('Failed to parse success response: $e');
          // Even on parse error, if we have a session, mark as logged in
          if (savedSessionId != null && savedSessionId.isNotEmpty) {
            await prefs.setBool('is_logged_in', true);
            print('✅ Login state saved: is_logged_in = true (session exists, parse error)');
          }
          return {'success': true, 'data': {'message': 'Login successful'}};
        }
      } else if (response.statusCode == 403) {
        // 403 might be due to incomplete onboarding, but session was created
        try {
          final errorData = jsonDecode(response.body);
          print('Login returned 403 - Error data: $errorData');
          
          // If we have a session, try to get user info and save it
          if (savedSessionId != null && savedSessionId.isNotEmpty) {
            print('   Session exists, fetching user info...');
            final userInfoResult = await getCurrentUserInfo();
            if (userInfoResult['success'] == true && userInfoResult['data'] != null) {
              final userData = userInfoResult['data'];
              await prefs.setString('user_data', jsonEncode(userData));
              await prefs.setBool('is_logged_in', true);
              print('✅ User data saved from session after 403 response');
              
              // Return success with onboarding info
              return {
                'success': true,
                'data': {
                  'user': userData,
                  'onboarding_complete': errorData['onboarding_complete'] ?? false,
                  'verification_status': errorData['verification_status'],
                }
              };
            }
          }
          
          // Return error but include onboarding info
          return {'success': false, 'error': errorData};
        } catch (e) {
          print('Failed to parse 403 response: $e');
          return {'success': false, 'error': {'message': response.body}};
        }
      } else {
        print('Login failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          print('Parsed error data: $errorData');
          return {'success': false, 'error': errorData};
        } catch (e) {
          print('Failed to parse error response: $e');
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('Login timeout: $e');
      return {'success': false, 'error': {'message': 'Request timed out. Please check your internet connection and try again.'}};
    } on SocketException catch (e) {
      print('Login network error: $e');
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Login error: $e');
      print('Login error type: ${e.runtimeType}');
      return {'success': false, 'error': {'message': 'Login failed: ${e.toString()}'}};
    }
  }
  
  // Service Categories
  static Future<Map<String, dynamic>> getServiceCategories({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('services/categories/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached service categories');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('Fetching service categories from API');
      final response = await http.get(
        Uri.parse('$baseUrl/services/categories/'),
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('Categories response status: ${response.statusCode}');
      print('Categories response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('📦 Categories parsed data: $responseData');
        
        // Extract services list from paginated response
        List<dynamic> servicesList = [];
        if (responseData is List) {
          servicesList = responseData;
          print('📦 Services is a List with ${servicesList.length} items');
        } else if (responseData is Map) {
          if (responseData.containsKey('results')) {
            servicesList = responseData['results'] as List;
            print('📦 Services found in results array: ${servicesList.length} items');
          } else {
            print('⚠️ Response is a Map but no "results" key found. Keys: ${responseData.keys}');
          }
        }
        
        print('📦 Final services list:');
        for (var i = 0; i < servicesList.length; i++) {
          final service = servicesList[i];
          print('   ${i + 1}. ID: ${service['id']}, Name: ${service['name']}, Active: ${service['is_active']}');
        }
        
        // Cache the response (cache for 2 hours as categories don't change often)
        await CacheService.setCache(cacheKey, responseData, expiration: const Duration(hours: 2));
        
        return {'success': true, 'data': responseData};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('Get categories timeout: $e');
      // Try to return cached data on timeout
      final cacheKey = CacheService.getCacheKey('services/categories/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached data due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('Get categories network error: $e');
      // Try to return cached data on network error
      final cacheKey = CacheService.getCacheKey('services/categories/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached data due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Get categories error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Provider Onboarding Step 1: Location
  static Future<Map<String, dynamic>> onboardingStep1({
    required double latitude,
    required double longitude,
    required String locationString,
    String? referralCode,
  }) async {
    try {
      print('📍 Onboarding step 1: Location');
      print('   Latitude: $latitude, Longitude: $longitude');
      print('   Location string: $locationString');
      
      // Verify session exists before making request
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      
      print('   🔍 Session check before onboarding:');
      print('      is_logged_in: $isLoggedIn');
      print('      session_id exists: ${sessionId != null && sessionId.isNotEmpty}');
      if (sessionId != null && sessionId.isNotEmpty) {
        print('      session_id (first 30 chars): ${sessionId.substring(0, sessionId.length > 30 ? 30 : sessionId.length)}...');
      } else {
        print('      ⚠️ WARNING: No session ID found!');
        return {'success': false, 'error': {'message': 'Session expired. Please login again.'}};
      }
      
      // Get headers with session cookie
      final headers = await _getHeaders(includeAuth: true);
      print('   📤 Request headers:');
      headers.forEach((key, value) {
        if (key == 'Cookie') {
          print('      $key: sessionid=${value.substring(value.indexOf('=') + 1, value.length > 50 ? value.indexOf('=') + 51 : value.length)}...');
        } else {
          print('      $key: $value');
        }
      });
      
      // Round latitude and longitude to 6 decimal places (backend requirement)
      // Use toStringAsFixed(6) directly to ensure exactly 6 decimal places in the string
      final roundedLatStr = latitude.toStringAsFixed(6);
      final roundedLonStr = longitude.toStringAsFixed(6);
      
      print('   Original coordinates: lat=$latitude, lon=$longitude');
      print('   Rounded coordinates: lat=$roundedLatStr, lon=$roundedLonStr');
      
      final response = await http.post(
        Uri.parse('$baseUrl/providers/onboarding_step1/'),
        headers: headers,
        body: jsonEncode({
          'latitude': roundedLatStr,
          'longitude': roundedLonStr,
          'location_string': locationString,
          if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('   📥 Step 1 response status: ${response.statusCode}');
      print('   📥 Step 1 response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          final errorData = jsonDecode(response.body);
          print('   ❌ Step 1 error data: $errorData');
          
          // If authentication error, clear session
          if (response.statusCode == 403 || response.statusCode == 401) {
            print('   ⚠️ Authentication failed, clearing session');
            await _clearSession();
          }
          
          return {'success': false, 'error': errorData};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Step 1 timeout: $e');
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Step 1 network error: $e');
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('❌ Step 1 error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Provider Onboarding Step 2: Services
  static Future<Map<String, dynamic>> onboardingStep2({
    required List<int> serviceIds,
  }) async {
    try {
      print('Onboarding step 2: Services');
      final response = await http.post(
        Uri.parse('$baseUrl/providers/onboarding_step2/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode({
          'service_ids': serviceIds,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('Step 2 response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('Step 2 timeout: $e');
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('Step 2 network error: $e');
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Step 2 error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Provider Onboarding Step 3: Documents
  static Future<Map<String, dynamic>> onboardingStep3({
    required String name,
    required String contact,
    required String address,
    String? profilePhotoPath,
    required String panCardPath,
    required String registrationCertificatePath,
  }) async {
    try {
      print('Onboarding step 3: Documents');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/providers/onboarding_step3/'),
      );
      
      // Add headers with session cookie
      final headers = await _getHeaders(includeAuth: true);
      print('   Request headers: $headers');
      request.headers.addAll(headers);
      request.headers.remove('Content-Type'); // Let multipart set it
      
      // Ensure Cookie header is preserved for multipart requests
      final sessionId = (await SharedPreferences.getInstance()).getString('session_id');
      if (sessionId != null && sessionId.isNotEmpty) {
        request.headers['Cookie'] = 'sessionid=$sessionId';
        print('   Cookie header set: sessionid=$sessionId');
      }
      
      // Add fields
      request.fields['name'] = name;
      request.fields['contact'] = contact;
      request.fields['address'] = address;
      
      // Add files
      if (profilePhotoPath != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_photo',
          profilePhotoPath,
        ));
      }
      
      request.files.add(await http.MultipartFile.fromPath(
        'pan_card',
        panCardPath,
      ));
      
      request.files.add(await http.MultipartFile.fromPath(
        'registration_certificate',
        registrationCertificatePath,
      ));
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('File upload timed out after 60 seconds');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);
      
      print('Step 3 response status: ${response.statusCode}');
      print('Step 3 response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Step 3 error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Check provider status
  static Future<Map<String, dynamic>> getProviderStatus({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('providers/status/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached provider status');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('Checking provider status from API');
      final response = await http.get(
        Uri.parse('$baseUrl/providers/status/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('Status response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Cache the response (cache for 5 minutes)
        await CacheService.setCache(cacheKey, data, expiration: const Duration(minutes: 5));
        
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('Status check timeout: $e');
      // Try to return cached data on timeout
      final cacheKey = CacheService.getCacheKey('providers/status/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached provider status due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('Status check network error: $e');
      // Try to return cached data on network error
      final cacheKey = CacheService.getCacheKey('providers/status/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached provider status due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Status check error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Get provider profile
  static Future<Map<String, dynamic>> getProviderProfile({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('providers/my_profile/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached provider profile');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('Fetching provider profile from API');
      final response = await http.get(
        Uri.parse('$baseUrl/providers/my_profile/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('Provider profile response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Cache the response (cache for 10 minutes)
        await CacheService.setCache(cacheKey, data, expiration: const Duration(minutes: 10));
        
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('Get provider profile timeout: $e');
      // Try to return cached data on timeout
      final cacheKey = CacheService.getCacheKey('providers/my_profile/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached provider profile due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('Get provider profile network error: $e');
      // Try to return cached data on network error
      final cacheKey = CacheService.getCacheKey('providers/my_profile/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached provider profile due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Get provider profile error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Check if user is logged in by verifying session
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedInFlag = prefs.getBool('is_logged_in') ?? false;
      final sessionId = prefs.getString('session_id');
      
      print('🔍 Checking login status...');
      print('   is_logged_in flag: $isLoggedInFlag');
      print('   session_id exists: ${sessionId != null && sessionId.isNotEmpty}');
      if (sessionId != null && sessionId.isNotEmpty) {
        print('   session_id (first 20 chars): ${sessionId.substring(0, sessionId.length > 20 ? 20 : sessionId.length)}...');
      }
      
      // If we have both flag and session ID, trust it (don't require network verification on every app start)
      if (isLoggedInFlag && sessionId != null && sessionId.isNotEmpty) {
        print('✅ Session exists locally, assuming logged in');
        
        // Try to verify in background, but don't block on it
        try {
          print('🔍 Verifying session with server (non-blocking)...');
          final response = await http.get(
            Uri.parse('$baseUrl/auth/users/me/'),
            headers: await _getHeaders(includeAuth: true),
          ).timeout(const Duration(seconds: 5));
          
          print('   Response status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            // Session is valid, update user data
            try {
              final userData = jsonDecode(response.body);
              await prefs.setString('user_data', jsonEncode(userData));
              print('✅ Session verified, user data updated');
            } catch (e) {
              print('⚠️ Failed to parse user data: $e');
            }
          } else if (response.statusCode == 401 || response.statusCode == 403) {
            // Only clear session on definitive auth errors (401/403)
            print('❌ Session invalid (status: ${response.statusCode}), clearing session');
            await _clearSession();
            return false;
          } else {
            // Other errors (500, 404, etc.) - don't clear session, might be server issue
            print('⚠️ Server error (status: ${response.statusCode}), keeping session');
          }
        } catch (e) {
          // Network errors, timeouts, etc. - don't clear session
          print('⚠️ Session verification failed (network/timeout), keeping session: $e');
          print('   User can still use app - session will be verified on next API call');
        }
        
        return true;
      }
      
      print('❌ Not logged in: missing flag or session ID');
      return false;
    } catch (e) {
      print('❌ Session check error: $e');
      // On unexpected errors, check if we have a session
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id');
      final isLoggedInFlag = prefs.getBool('is_logged_in') ?? false;
      if (sessionId != null && sessionId.isNotEmpty && isLoggedInFlag) {
        print('⚠️ Error but session exists, assuming logged in');
        return true;
      }
      print('❌ No session found, user not logged in');
      return false;
    }
  }

  // Get current user data from SharedPreferences
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      
      if (userDataString != null) {
        return jsonDecode(userDataString) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Get current user info from API (refresh from server)
  static Future<Map<String, dynamic>> getCurrentUserInfo({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('auth/users/me/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached user info');
          // Also update SharedPreferences for backward compatibility
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(cachedData));
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/auth/users/me/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        
        // Update cached user data in both SharedPreferences and CacheService
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(userData));
        
        // Cache the response (cache for 10 minutes)
        await CacheService.setCache(cacheKey, userData, expiration: const Duration(minutes: 10));
        
        return {'success': true, 'data': userData};
      } else {
        // Session expired
        await _clearSession();
        return {'success': false, 'error': {'message': 'Session expired. Please login again.'}};
      }
    } on TimeoutException catch (e) {
      print('Get user info timeout: $e');
      // Try to return cached data on timeout
      final cacheKey = CacheService.getCacheKey('auth/users/me/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached user info due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your internet connection.'}};
    } on SocketException catch (e) {
      print('Get user info network error: $e');
      // Try to return cached data on network error
      final cacheKey = CacheService.getCacheKey('auth/users/me/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached user info due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Get user info error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Logout - clear session and user data
  static Future<void> logout() async {
    try {
      // Call logout endpoint if available (optional)
      // await http.post(
      //   Uri.parse('$baseUrl/auth/users/logout/'),
      //   headers: await _getHeaders(includeAuth: true),
      // );
      
      // Clear all cached data
      await CacheService.clearAllCache();
      print('🗑️ All cached data cleared');
      
      // Clear local session
      await _clearSession();
      print('User logged out successfully');
    } catch (e) {
      print('Logout error: $e');
      // Still clear cache and session even if API call fails
      try {
        await CacheService.clearAllCache();
        print('🗑️ All cached data cleared (on error)');
      } catch (cacheError) {
        print('Error clearing cache: $cacheError');
      }
      await _clearSession();
    }
  }

  // Clear session and user data from SharedPreferences
  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_id');
    await prefs.remove('user_data');
    await prefs.setBool('is_logged_in', false);
    print('Session cleared');
  }
  
  // Get reviews (optionally filtered by provider or limited count)
  static Future<Map<String, dynamic>> getReviews({int? providerId, int? limit, bool forceRefresh = false}) async {
    try {
      final params = <String, dynamic>{};
      if (providerId != null) params['provider'] = providerId;
      if (limit != null) params['limit'] = limit;
      final cacheKey = CacheService.getCacheKey('reviews/', params: params);
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached reviews${providerId != null ? " for provider: $providerId" : ""}');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('Fetching reviews${providerId != null ? " for provider: $providerId" : ""}');
      String url = '$baseUrl/reviews/';
      List<String> urlParams = [];
      if (providerId != null) {
        urlParams.add('provider=$providerId');
      }
      if (limit != null) {
        urlParams.add('limit=$limit');
      }
      if (urlParams.isNotEmpty) {
        url += '?${urlParams.join("&")}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('Reviews response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> reviewsList = [];
        if (data is List) {
          reviewsList = data;
        } else if (data is Map && data.containsKey('results')) {
          reviewsList = data['results'] as List;
        }
        
        print('✅ Loaded ${reviewsList.length} reviews');
        
        // Cache the response (cache for 30 minutes)
        await CacheService.setCache(cacheKey, reviewsList, expiration: const Duration(minutes: 30));
        
        return {'success': true, 'data': reviewsList};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('Get reviews timeout: $e');
      // Try to return cached data on timeout
      final params = <String, dynamic>{};
      if (providerId != null) params['provider'] = providerId;
      if (limit != null) params['limit'] = limit;
      final cacheKey = CacheService.getCacheKey('reviews/', params: params);
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached reviews due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('Get reviews network error: $e');
      // Try to return cached data on network error
      final params = <String, dynamic>{};
      if (providerId != null) params['provider'] = providerId;
      if (limit != null) params['limit'] = limit;
      final cacheKey = CacheService.getCacheKey('reviews/', params: params);
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached reviews due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Get reviews error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Create a review (with optimistic update support)
  static Future<Map<String, dynamic>> createReview(Map<String, dynamic> reviewData, {Function(Map<String, dynamic>)? onOptimisticUpdate, Function()? onError}) async {
    try {
      print('📝 Creating review: $reviewData');
      
      // Invalidate related caches
      await CacheService.invalidateCachePattern('reviews/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/reviews/create_review/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(reviewData),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('📥 Create review response status: ${response.statusCode}');
      print('📥 Create review response body: ${response.body}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Review created successfully');
        return {'success': true, 'data': data};
      } else {
        try {
          final errorData = jsonDecode(response.body);
          print('❌ Review creation error: $errorData');
          // Call error callback if provided
          if (onError != null) onError();
          return {'success': false, 'error': errorData};
        } catch (e) {
          if (onError != null) onError();
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Create review timeout: $e');
      if (onError != null) onError();
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Create review network error: $e');
      if (onError != null) onError();
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('💥 Create review error: $e');
      if (onError != null) onError();
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Get notifications
  static Future<Map<String, dynamic>> getNotifications({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('notifications/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached notifications');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('📬 Fetching notifications from API');
      final headers = await _getHeaders(includeAuth: true);
      print('📬 Notifications URL: $baseUrl/notifications/');
      print('📬 Headers: $headers');
      
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('📬 Notifications response status: ${response.statusCode}');
      print('📬 Notifications response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> notificationsList = [];
        if (data is List) {
          notificationsList = data;
        } else if (data is Map && data.containsKey('results')) {
          notificationsList = data['results'] as List;
        }
        
        print('✅ Loaded ${notificationsList.length} notifications');
        if (notificationsList.isNotEmpty) {
          print('📋 First notification: ${notificationsList[0]}');
        }
        
        // Cache the response (cache for 5 minutes)
        await CacheService.setCache(cacheKey, notificationsList, expiration: const Duration(minutes: 5));
        
        return {'success': true, 'data': notificationsList};
      } else {
        print('❌ Notifications error: ${response.body}');
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Get notifications timeout: $e');
      // Try to return cached data on timeout
      final cacheKey = CacheService.getCacheKey('notifications/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached notifications due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Get notifications network error: $e');
      // Try to return cached data on network error
      final cacheKey = CacheService.getCacheKey('notifications/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached notifications due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('❌ Get notifications error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Update user profile
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data, {
    File? profilePhoto,
  }) async {
    try {
      print('💾 Updating profile');
      print('   Data: $data');
      print('   Profile photo: ${profilePhoto != null ? profilePhoto.path : "none"}');
      
      // Invalidate user info and provider profile caches
      await CacheService.invalidateCachePattern('auth/users/me/');
      await CacheService.invalidateCachePattern('providers/my_profile/');
      
      // If profile photo is provided, use multipart form data
      if (profilePhoto != null) {
        final request = http.MultipartRequest(
          'PATCH',
          Uri.parse('$baseUrl/auth/users/update_profile/'),
        );
        
        // Add session cookie
        final prefs = await SharedPreferences.getInstance();
        final sessionId = prefs.getString('session_id');
        if (sessionId != null && sessionId.isNotEmpty) {
          request.headers['Cookie'] = 'sessionid=$sessionId';
          print('   Added session cookie');
        } else {
          print('⚠️ No session ID found');
          return {'success': false, 'error': {'message': 'Not authenticated. Please login again.'}};
        }
        
        // Add text fields (excluding password fields and profile_photo)
        data.forEach((key, value) {
          if (value != null && key != 'profile_photo') {
            request.fields[key] = value.toString();
            print('   Field: $key = ${key.contains('password') ? '***' : value}');
          }
        });
        
        // Add profile photo file
        try {
          final multipartFile = await http.MultipartFile.fromPath(
            'profile_photo',
            profilePhoto.path,
          );
          request.files.add(multipartFile);
          print('   Added profile photo: ${multipartFile.filename} (${multipartFile.length} bytes)');
        } catch (e) {
          print('❌ Error adding profile photo: $e');
          return {'success': false, 'error': {'message': 'Failed to read profile photo file'}};
        }
        
        print('📤 Sending multipart request...');
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Request timed out after 30 seconds');
          },
        );
        final response = await http.Response.fromStream(streamedResponse);
        
        print('📥 Profile update response status: ${response.statusCode}');
        print('📥 Profile update response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        
        if (response.statusCode == 200) {
          try {
            final userData = jsonDecode(response.body);
            print('✅ Profile updated successfully');
            
            // Update cached user data
            await prefs.setString('user_data', jsonEncode(userData));
            
            return {'success': true, 'data': userData};
          } catch (e) {
            print('❌ Error parsing response: $e');
            return {'success': false, 'error': {'message': 'Invalid response from server'}};
          }
        } else {
          // Try to parse error response
          try {
            final errorData = jsonDecode(response.body);
            print('❌ Profile update failed: $errorData');
            return {'success': false, 'error': errorData};
          } catch (e) {
            // If response is HTML (like the error page), extract a meaningful message
            if (response.body.contains('<!DOCTYPE html>')) {
              print('❌ Server returned HTML error page');
              return {'success': false, 'error': {'message': 'Server error. Please try again later or contact support.'}};
            }
            print('❌ Profile update failed with status ${response.statusCode}');
            return {'success': false, 'error': {'message': 'Failed to update profile. Status: ${response.statusCode}'}};
          }
        }
      } else {
        // No photo, use regular JSON request
        final headers = await _getHeaders(includeAuth: true);
        
        print('📤 Sending JSON request (no photo)...');
        final response = await http.patch(
          Uri.parse('$baseUrl/auth/users/update_profile/'),
          headers: headers,
          body: jsonEncode(data),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Request timed out after 30 seconds');
          },
        );
        
        print('📥 Profile update response status: ${response.statusCode}');
        print('📥 Profile update response body: ${response.body}');
        
        if (response.statusCode == 200) {
          try {
            final userData = jsonDecode(response.body);
            print('✅ Profile updated successfully');
            
            // Update cached user data
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', jsonEncode(userData));
            
            return {'success': true, 'data': userData};
          } catch (e) {
            print('❌ Error parsing response: $e');
            return {'success': false, 'error': {'message': 'Invalid response from server'}};
          }
        } else {
          try {
            final errorData = jsonDecode(response.body);
            print('❌ Profile update failed: $errorData');
            return {'success': false, 'error': errorData};
          } catch (e) {
            if (response.body.contains('<!DOCTYPE html>')) {
              print('❌ Server returned HTML error page');
              return {'success': false, 'error': {'message': 'Server error. Please try again later or contact support.'}};
            }
            print('❌ Profile update failed with status ${response.statusCode}');
            return {'success': false, 'error': {'message': 'Failed to update profile. Status: ${response.statusCode}'}};
          }
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Update profile timeout: $e');
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Update profile network error: $e');
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('❌ Update profile error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Get provider details by ID
  static Future<Map<String, dynamic>> getProviderDetails(int providerId, {bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('providers/$providerId/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached provider details for ID: $providerId');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('🔍 Fetching provider details for ID: $providerId');
      final url = '$baseUrl/providers/$providerId/';
      print('📍 Provider details URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('📥 Provider details response status: ${response.statusCode}');
      print('📥 Provider details response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Loaded provider details: ${data['name'] ?? 'Unknown'}');
        
        // Cache the response (cache for 1 hour)
        await CacheService.setCache(cacheKey, data, expiration: const Duration(hours: 1));
        
        return {'success': true, 'data': data};
      } else {
        final errorBody = response.body;
        print('❌ Provider details error: $errorBody');
        try {
          final errorData = jsonDecode(errorBody);
          return {'success': false, 'error': errorData};
        } catch (e) {
          return {'success': false, 'error': {'message': errorBody}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Get provider details timeout: $e');
      // Try to return cached data on timeout
      final cacheKey = CacheService.getCacheKey('providers/$providerId/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached provider details due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Get provider details network error: $e');
      // Try to return cached data on network error
      final cacheKey = CacheService.getCacheKey('providers/$providerId/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached provider details due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('💥 Get provider details error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Create a booking (with optimistic update support)
  static Future<Map<String, dynamic>> createBooking(Map<String, dynamic> bookingData, {Function(Map<String, dynamic>)? onOptimisticUpdate, Function()? onError}) async {
    try {
      print('📝 Creating booking...');
      print('   Booking data: $bookingData');
      
      // Invalidate bookings cache
      await CacheService.invalidateCachePattern('bookings/');
      
      final headers = await _getHeaders(includeAuth: true);
      print('   Request headers:');
      headers.forEach((key, value) {
        if (key == 'Cookie') {
          print('      $key: sessionid=${value.substring(value.indexOf('=') + 1, value.length > 50 ? value.indexOf('=') + 51 : value.length)}...');
        } else {
          print('      $key: $value');
        }
      });
      
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/'),
        headers: headers,
        body: jsonEncode(bookingData),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('📥 Create booking response status: ${response.statusCode}');
      print('📥 Create booking response body: ${response.body}');
      print('📥 Create booking response headers: ${response.headers}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Booking created successfully');
        return {'success': true, 'data': data};
      } else {
        try {
          final errorData = jsonDecode(response.body);
          print('❌ Booking creation error: $errorData');
          if (onError != null) onError();
          return {'success': false, 'error': errorData};
        } catch (e) {
          if (onError != null) onError();
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Create booking timeout: $e');
      if (onError != null) onError();
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Create booking network error: $e');
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('💥 Create booking error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Get user bookings (for customers and providers)
  static Future<Map<String, dynamic>> getUserBookings({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('bookings/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached user bookings');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('📋 Fetching user bookings from API');
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('📥 User bookings response status: ${response.statusCode}');
      print('📥 User bookings response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> bookingsList = [];
        if (data is List) {
          bookingsList = data;
        } else if (data is Map && data.containsKey('results')) {
          bookingsList = data['results'] as List;
        }
        
        print('✅ Loaded ${bookingsList.length} bookings');
        
        // Cache the response (cache for 5 minutes as bookings change frequently)
        await CacheService.setCache(cacheKey, bookingsList, expiration: const Duration(minutes: 5));
        
        return {'success': true, 'data': bookingsList};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Get user bookings timeout: $e');
      // Try to return cached data on timeout
      final cacheKey = CacheService.getCacheKey('bookings/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached bookings due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Get user bookings network error: $e');
      // Try to return cached data on network error
      final cacheKey = CacheService.getCacheKey('bookings/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached bookings due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('💥 Get user bookings error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Get provider requests (for service providers)
  static Future<Map<String, dynamic>> getProviderRequests({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('bookings/my_requests/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached provider requests');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('Fetching provider requests from API');
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/my_requests/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('Provider requests response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> requestsList = [];
        if (data is List) {
          requestsList = data;
        } else if (data is Map && data.containsKey('results')) {
          requestsList = data['results'] as List;
        }
        
        print('✅ Loaded ${requestsList.length} requests');
        
        // Cache the response (cache for 2 minutes as requests change frequently)
        await CacheService.setCache(cacheKey, requestsList, expiration: const Duration(minutes: 2));
        
        return {'success': true, 'data': requestsList};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('Get provider requests timeout: $e');
      // Try to return cached data on timeout
      final cacheKey = CacheService.getCacheKey('bookings/my_requests/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached requests due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('Get provider requests network error: $e');
      // Try to return cached data on network error
      final cacheKey = CacheService.getCacheKey('bookings/my_requests/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached requests due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Get provider requests error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Accept a booking request
  static Future<Map<String, dynamic>> startNegotiation(int bookingId) async {
    try {
      // Invalidate bookings cache
      await CacheService.invalidateCachePattern('bookings/');
      
      final headers = await _getHeaders(includeAuth: true);
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/start_negotiation/'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      final responseData = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'error': responseData};
      }
    } catch (e) {
      print('Error starting negotiation: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  static Future<Map<String, dynamic>> acceptBooking(int bookingId) async {
    try {
      print('Accepting booking: $bookingId');
      
      // Invalidate bookings cache
      await CacheService.invalidateCachePattern('bookings/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/accept/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Accept booking error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Complete a booking
  static Future<Map<String, dynamic>> completeBooking(int bookingId) async {
    try {
      print('Completing booking: $bookingId');
      
      // Invalidate bookings cache
      await CacheService.invalidateCachePattern('bookings/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/complete/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Complete booking error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Cancel a booking (with optimistic update support)
  static Future<Map<String, dynamic>> cancelBooking(int bookingId, {Function(Map<String, dynamic>)? onOptimisticUpdate, Function()? onError}) async {
    try {
      print('Cancelling booking: $bookingId');
      
      // Invalidate bookings cache
      await CacheService.invalidateCachePattern('bookings/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/cancel/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          if (onError != null) onError();
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          if (onError != null) onError();
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Cancel booking error: $e');
      if (onError != null) onError();
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Delete a booking (for removing from history) (with optimistic update support)
  static Future<Map<String, dynamic>> deleteBooking(int bookingId, {Function(Map<String, dynamic>)? onOptimisticUpdate, Function()? onError}) async {
    try {
      print('🗑️ Deleting booking: $bookingId');
      
      // Invalidate bookings cache
      await CacheService.invalidateCachePattern('bookings/');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/bookings/$bookingId/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('📥 Delete booking response status: ${response.statusCode}');
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        print('✅ Booking deleted successfully');
        return {'success': true};
      } else {
        try {
          final errorData = jsonDecode(response.body);
          print('❌ Delete booking error: $errorData');
          if (onError != null) onError();
          return {'success': false, 'error': errorData};
        } catch (e) {
          print('❌ Delete booking error (parse): ${response.body}');
          if (onError != null) onError();
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Delete booking timeout: $e');
      if (onError != null) onError();
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Delete booking network error: $e');
      if (onError != null) onError();
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('💥 Delete booking error: $e');
      if (onError != null) onError();
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Reject booking during negotiation
  static Future<Map<String, dynamic>> rejectBooking(int bookingId) async {
    try {
      print('Rejecting booking: $bookingId');
      
      // Invalidate bookings cache
      await CacheService.invalidateCachePattern('bookings/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/reject/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Reject booking error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Propose price during negotiation (both customer and provider)
  static Future<Map<String, dynamic>> proposePrice(int bookingId, double price) async {
    try {
      print('Proposing price: $price for booking: $bookingId');
      
      // Invalidate bookings cache
      await CacheService.invalidateCachePattern('bookings/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/propose_price/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode({'price': price}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Propose price error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Accept proposed price (both customer and provider)
  static Future<Map<String, dynamic>> acceptPrice(int bookingId) async {
    try {
      print('Accepting price for booking: $bookingId');
      
      // Invalidate bookings cache
      await CacheService.invalidateCachePattern('bookings/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/accept_price/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Accept price error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Get saved addresses
  static Future<Map<String, dynamic>> getSavedAddresses({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('addresses/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached saved addresses');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('📍 Fetching saved addresses from API');
      final response = await http.get(
        Uri.parse('$baseUrl/addresses/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('📥 Saved addresses response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> addressesList = [];
        if (data is List) {
          addressesList = data;
        } else if (data is Map && data.containsKey('results')) {
          addressesList = data['results'] as List;
        }
        
        print('✅ Loaded ${addressesList.length} saved addresses');
        
        // Cache the response (cache for 10 minutes)
        await CacheService.setCache(cacheKey, addressesList, expiration: const Duration(minutes: 10));
        
        return {'success': true, 'data': addressesList};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Get saved addresses timeout: $e');
      // Try to return cached data on timeout
      final cacheKey = CacheService.getCacheKey('addresses/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached addresses due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Get saved addresses network error: $e');
      // Try to return cached data on network error
      final cacheKey = CacheService.getCacheKey('addresses/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached addresses due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('💥 Get saved addresses error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Create a saved address
  static Future<Map<String, dynamic>> createSavedAddress(Map<String, dynamic> addressData) async {
    try {
      print('📝 Creating saved address: $addressData');
      
      // Invalidate addresses cache
      await CacheService.invalidateCachePattern('addresses/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/addresses/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(addressData),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('📥 Create address response status: ${response.statusCode}');
      print('📥 Create address response body: ${response.body}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Address created successfully');
        return {'success': true, 'data': data};
      } else {
        try {
          final errorData = jsonDecode(response.body);
          print('❌ Address creation error: $errorData');
          return {'success': false, 'error': errorData};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Create address timeout: $e');
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Create address network error: $e');
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('💥 Create address error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Delete a saved address
  static Future<Map<String, dynamic>> deleteSavedAddress(int addressId) async {
    try {
      print('🗑️ Deleting saved address: $addressId');
      
      // Invalidate addresses cache
      await CacheService.invalidateCachePattern('addresses/');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/addresses/$addressId/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        print('✅ Address deleted successfully');
        return {'success': true};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Delete address timeout: $e');
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('🌐 Delete address network error: $e');
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('💥 Delete address error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Get list of verified providers with filtering options
  static Future<Map<String, dynamic>> getProviders({
    int? serviceCategoryId,
    String? searchQuery,
    double? latitude,
    double? longitude,
    double? radius,
    double? minPrice,
    double? maxPrice,
    bool? availableOnly,
    String? sortBy, // 'price_low' or 'price_high'
    int? page, // Page number for pagination
    bool forceRefresh = false,
  }) async {
    try {
      // Build cache key from parameters
      final params = <String, dynamic>{
        if (serviceCategoryId != null) 'service': serviceCategoryId,
        if (searchQuery != null && searchQuery.isNotEmpty) 'search': searchQuery,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radius != null) 'radius': radius,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (availableOnly == true) 'available_only': true,
        if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
        if (page != null) 'page': page,
      };
      final cacheKey = CacheService.getCacheKey('providers/', params: params);
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached providers');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      print('Fetching providers with filters from API');
      final uri = Uri.parse('$baseUrl/providers/');
      final queryParams = <String, String>{};
      
      if (serviceCategoryId != null) {
        queryParams['service'] = serviceCategoryId.toString();
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }
      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude.toString();
        queryParams['longitude'] = longitude.toString();
        if (radius != null) {
          queryParams['radius'] = radius.toString();
        }
      }
      if (minPrice != null) {
        queryParams['min_price'] = minPrice.toString();
      }
      if (maxPrice != null) {
        queryParams['max_price'] = maxPrice.toString();
      }
      if (availableOnly == true) {
        queryParams['available_only'] = 'true';
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['sort_by'] = sortBy;
      }
      if (page != null) {
        queryParams['page'] = page.toString();
      }
      
      final url = uri.replace(queryParameters: queryParams);
      print('Fetching providers from: $url');
      
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('Providers response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Handle both list and paginated responses
        List<dynamic> providersList = [];
        if (data is List) {
          providersList = data;
        } else if (data is Map && data.containsKey('results')) {
          providersList = data['results'] as List;
        }
        
        print('✅ Loaded ${providersList.length} providers');
        
        // Cache the response (cache for 5 minutes as providers can change)
        await CacheService.setCache(cacheKey, providersList, expiration: const Duration(minutes: 5));
        
        return {'success': true, 'data': providersList};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } on TimeoutException catch (e) {
      print('Get providers timeout: $e');
      // Try to return cached data on timeout
      final params = <String, dynamic>{
        if (serviceCategoryId != null) 'service': serviceCategoryId,
        if (searchQuery != null && searchQuery.isNotEmpty) 'search': searchQuery,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radius != null) 'radius': radius,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (availableOnly == true) 'available_only': true,
        if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
        if (page != null) 'page': page,
      };
      final cacheKey = CacheService.getCacheKey('providers/', params: params);
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached providers due to timeout');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Request timed out. Please check your connection.'}};
    } on SocketException catch (e) {
      print('Get providers network error: $e');
      // Try to return cached data on network error
      final params = <String, dynamic>{
        if (serviceCategoryId != null) 'service': serviceCategoryId,
        if (searchQuery != null && searchQuery.isNotEmpty) 'search': searchQuery,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radius != null) 'radius': radius,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (availableOnly == true) 'available_only': true,
        if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
        if (page != null) 'page': page,
      };
      final cacheKey = CacheService.getCacheKey('providers/', params: params);
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached providers due to network error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': 'Network error. Please check your internet connection.'}};
    } catch (e) {
      print('Get providers error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Update provider availability schedule
  static Future<Map<String, dynamic>> updateProviderAvailability({
    String? availableFromDay,
    String? availableToDay,
    String? availableStartTime,
    String? availableEndTime,
  }) async {
    try {
      // Invalidate provider profile and providers list caches
      await CacheService.invalidateCachePattern('providers/');
      
      print('Updating provider availability schedule');
      final body = <String, dynamic>{};
      if (availableFromDay != null) {
        body['available_from_day'] = availableFromDay;
      }
      if (availableToDay != null) {
        body['available_to_day'] = availableToDay;
      }
      if (availableStartTime != null) {
        body['available_start_time'] = availableStartTime;
      }
      if (availableEndTime != null) {
        body['available_end_time'] = availableEndTime;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/providers/update_availability/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('Update availability response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Update availability error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Register FCM token for push notifications
  static Future<Map<String, dynamic>> registerFcmToken(String fcmToken) async {
    try {
      print('📱 Registering FCM token');
      print('   Token length: ${fcmToken.length}');
      print('   Token preview: ${fcmToken.substring(0, fcmToken.length > 50 ? 50 : fcmToken.length)}...');
      
      final headers = await _getHeaders(includeAuth: true);
      print('   Request URL: $baseUrl/auth/users/register_fcm_token/');
      print('   Headers: ${headers.keys}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/users/register_fcm_token/'),
        headers: headers,
        body: jsonEncode({'fcm_token': fcmToken}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('📥 Register FCM token response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ FCM token registered successfully');
        return {'success': true, 'data': data};
      } else {
        final errorBody = response.body;
        print('❌ FCM token registration failed: $errorBody');
        try {
          final errorData = jsonDecode(errorBody);
          return {'success': false, 'error': errorData};
        } catch (e) {
          return {'success': false, 'error': {'message': errorBody}};
        }
      }
    } catch (e) {
      print('❌ Register FCM token error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
  
  // Update provider price range
  static Future<Map<String, dynamic>> updateProviderPriceRange({
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      // Invalidate provider profile and providers list caches
      await CacheService.invalidateCachePattern('providers/');
      
      print('Updating provider price range: min=$minPrice, max=$maxPrice');
      final body = <String, dynamic>{};
      if (minPrice != null) {
        body['min_price'] = minPrice;
      }
      if (maxPrice != null) {
        body['max_price'] = maxPrice;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/providers/update_price_range/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('Update price range response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Update price range error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Get wallet balance
  static Future<Map<String, dynamic>> getWalletBalance({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('wallets/balance/');
      
      // Check cache first unless force refresh (cache for 2 minutes as balance changes frequently)
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached wallet balance');
          return {'success': true, 'balance': cachedData, 'fromCache': true};
        }
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/wallets/balance/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final balance = data['balance'];
        
        // Cache the balance (cache for 2 minutes)
        await CacheService.setCache(cacheKey, balance, expiration: const Duration(minutes: 2));
        
        return {'success': true, 'balance': balance};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Get wallet balance error: $e');
      // Try to return cached data on error
      final cacheKey = CacheService.getCacheKey('wallets/balance/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached wallet balance due to error');
        return {'success': true, 'balance': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Add money to wallet
  static Future<Map<String, dynamic>> addMoneyToWallet(double amount, String paymentMethod) async {
    try {
      // Invalidate wallet balance cache
      await CacheService.invalidateCachePattern('wallets/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/wallets/add_money/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode({
          'amount': amount,
          'payment_method': paymentMethod,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'balance': data['balance'], 'message': data['message']};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Add money to wallet error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Get wallet transactions
  static Future<Map<String, dynamic>> getWalletTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallets/transactions/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Get wallet transactions error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Pay for booking
  static Future<Map<String, dynamic>> payBooking(int bookingId) async {
    try {
      // Invalidate bookings and wallet caches
      await CacheService.invalidateCachePattern('bookings/');
      await CacheService.invalidateCachePattern('wallets/');
      
      final headers = await _getHeaders(includeAuth: true);
      print('💳 Paying for booking: $bookingId');
      print('💳 URL: $baseUrl/bookings/$bookingId/pay/');
      print('💳 Headers: $headers');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/pay/'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      print('💳 Payment response status: ${response.statusCode}');
      print('💳 Payment response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Payment successful: $data');
        return {'success': true, 'data': data};
      } else {
        print('❌ Payment failed: ${response.statusCode} - ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          return {'success': false, 'error': errorData};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('❌ Pay booking error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Bank Account Management (Provider only)
  static Future<Map<String, dynamic>> getBankAccounts({bool forceRefresh = false}) async {
    try {
      final cacheKey = CacheService.getCacheKey('bank-accounts/');
      
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cachedData = await CacheService.getCache(cacheKey);
        if (cachedData != null) {
          print('📦 Using cached bank accounts');
          return {'success': true, 'data': cachedData, 'fromCache': true};
        }
      }
      
      final headers = await _getHeaders(includeAuth: true);
      print('🏦 Fetching bank accounts from API: $baseUrl/bank-accounts/');
      print('🏦 Headers: $headers');
      
      final response = await http.get(
        Uri.parse('$baseUrl/bank-accounts/'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      print('🏦 Bank accounts response status: ${response.statusCode}');
      print('🏦 Bank accounts response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(response.body);
        print('🏦 Decoded response: $decodedBody');
        print('🏦 Response type: ${decodedBody.runtimeType}');
        
        // DRF ViewSet list() returns a list directly, not wrapped in 'results'
        List<dynamic> accountsList;
        if (decodedBody is List) {
          accountsList = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('results')) {
          // Handle paginated response
          accountsList = decodedBody['results'] ?? [];
        } else if (decodedBody is Map) {
          // Try to extract list from any key
          accountsList = decodedBody.values.firstWhere(
            (value) => value is List,
            orElse: () => [],
          ) as List;
        } else {
          accountsList = [];
        }
        
        print('🏦 Extracted accounts list: $accountsList');
        print('🏦 Number of accounts: ${accountsList.length}');
        
        // Cache the response (cache for 10 minutes)
        await CacheService.setCache(cacheKey, accountsList, expiration: const Duration(minutes: 10));
        
        return {'success': true, 'data': accountsList};
      } else {
        print('❌ Failed to fetch bank accounts: ${response.statusCode} - ${response.body}');
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('❌ Get bank accounts error: $e');
      // Try to return cached data on error
      final cacheKey = CacheService.getCacheKey('bank-accounts/');
      final cachedData = await CacheService.getCache(cacheKey);
      if (cachedData != null) {
        print('📦 Returning cached bank accounts due to error');
        return {'success': true, 'data': cachedData, 'fromCache': true};
      }
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  static Future<Map<String, dynamic>> addBankAccount({
    required String accountHolderName,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
    String? branchName,
    bool isPrimary = false,
  }) async {
    try {
      // Invalidate bank accounts cache
      await CacheService.invalidateCachePattern('bank-accounts/');
      
      final headers = await _getHeaders(includeAuth: true);
      final body = {
        'account_holder_name': accountHolderName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'bank_name': bankName,
        'branch_name': branchName ?? '',
        'is_primary': isPrimary,
      };
      
      print('🏦 Adding bank account: $body');
      print('🏦 URL: $baseUrl/bank-accounts/');
      print('🏦 Headers: $headers');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bank-accounts/'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      
      print('🏦 Response status: ${response.statusCode}');
      print('🏦 Response body: ${response.body}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Bank account added successfully: $data');
        return {'success': true, 'data': data};
      } else {
        print('❌ Bank account addition failed: ${response.statusCode} - ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          return {'success': false, 'error': errorData};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('❌ Add bank account error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  static Future<Map<String, dynamic>> deleteBankAccount(int accountId) async {
    try {
      // Invalidate bank accounts cache
      await CacheService.invalidateCachePattern('bank-accounts/');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/bank-accounts/$accountId/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Delete bank account error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  // Withdrawal (Provider only)
  static Future<Map<String, dynamic>> withdrawMoney(int bankAccountId, double amount) async {
    try {
      // Invalidate wallet balance cache
      await CacheService.invalidateCachePattern('wallets/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/withdrawals/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode({
          'bank_account_id': bankAccountId,
          'amount': amount,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Withdraw money error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  static Future<Map<String, dynamic>> getWithdrawals() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/withdrawals/'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          return {'success': false, 'error': jsonDecode(response.body)};
        } catch (e) {
          return {'success': false, 'error': {'message': response.body}};
        }
      }
    } catch (e) {
      print('Get withdrawals error: $e');
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }
}
