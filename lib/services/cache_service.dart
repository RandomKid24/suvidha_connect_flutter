import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _cachePrefix = 'api_cache_';
  static const String _timestampPrefix = 'cache_timestamp_';
  static const Duration _defaultCacheDuration = Duration(hours: 1); // Cache for 1 hour by default
  
  // Cache data with optional expiration
  static Future<void> setCache(String key, dynamic data, {Duration? expiration}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '$_timestampPrefix$key';
      
      await prefs.setString(cacheKey, jsonEncode(data));
      final expirationTime = DateTime.now().add(expiration ?? _defaultCacheDuration);
      await prefs.setString(timestampKey, expirationTime.toIso8601String());
      
      print('💾 Cached data for key: $key (expires: $expirationTime)');
    } catch (e) {
      print('❌ Error caching data: $e');
    }
  }
  
  // Get cached data if it exists and hasn't expired
  static Future<dynamic> getCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '$_timestampPrefix$key';
      
      final cachedData = prefs.getString(cacheKey);
      final timestampStr = prefs.getString(timestampKey);
      
      if (cachedData == null || timestampStr == null) {
        print('📭 No cache found for key: $key');
        return null;
      }
      
      final expirationTime = DateTime.parse(timestampStr);
      if (DateTime.now().isAfter(expirationTime)) {
        print('⏰ Cache expired for key: $key');
        // Remove expired cache
        await prefs.remove(cacheKey);
        await prefs.remove(timestampKey);
        return null;
      }
      
      print('✅ Cache hit for key: $key');
      return jsonDecode(cachedData);
    } catch (e) {
      print('❌ Error getting cache: $e');
      return null;
    }
  }
  
  // Check if cache exists and is valid
  static Future<bool> hasValidCache(String key) async {
    final cached = await getCache(key);
    return cached != null;
  }
  
  // Remove specific cache entry
  static Future<void> removeCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final timestampKey = '$_timestampPrefix$key';
      
      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
      print('🗑️ Removed cache for key: $key');
    } catch (e) {
      print('❌ Error removing cache: $e');
    }
  }
  
  // Clear all cache
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) || key.startsWith(_timestampPrefix)) {
          await prefs.remove(key);
        }
      }
      print('🗑️ Cleared all cache');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }
  
  // Invalidate cache for a specific pattern (useful for related endpoints)
  static Future<void> invalidateCachePattern(String pattern) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) && key.contains(pattern)) {
          final cacheKey = key.replaceFirst(_cachePrefix, '');
          await removeCache(cacheKey);
        }
      }
      print('🗑️ Invalidated cache pattern: $pattern');
    } catch (e) {
      print('❌ Error invalidating cache pattern: $e');
    }
  }
  
  // Get cache key from URL and parameters
  static String getCacheKey(String endpoint, {Map<String, dynamic>? params}) {
    String key = endpoint;
    if (params != null && params.isNotEmpty) {
      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      key += '_${jsonEncode(sortedParams)}';
    }
    return key;
  }
}
