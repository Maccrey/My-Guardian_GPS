import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// 이미지 캐싱 서비스
///
/// 네트워크 이미지를 로컬에 저장하고 관리하는 서비스입니다.
/// 프로필 이미지 및 메시지 이미지를 로컬에 캐싱하여 데이터 사용량과 로딩 속도를 개선합니다.
class ImageCacheService extends GetxService {
  // 캐시 메타데이터 저장용 SharedPreferences 키
  static const String _profileImageMetaKey = 'profile_image_metadata';
  static const String _messageImageMetaKey = 'message_image_metadata';

  // 캐시 디렉토리 이름
  static const String _profileImageDir = 'profile_images';
  static const String _messageImageDir = 'message_images';

  // 캐시 만료 시간 (30일)
  static const Duration _cacheExpiration = Duration(days: 30);

  // 저장된 메타데이터
  final Map<String, dynamic> _profileImageMeta = {};
  final Map<String, dynamic> _messageImageMeta = {};

  // 디렉토리 경로
  late final Directory _appCacheDir;
  late final Directory _profileImagesDir;
  late final Directory _messageImagesDir;

  bool _initialized = false;

  /// 서비스 초기화
  Future<ImageCacheService> init() async {
    if (_initialized) return this;

    try {
      // 캐시 디렉토리 생성
      _appCacheDir = await getTemporaryDirectory();
      _profileImagesDir =
          Directory(path.join(_appCacheDir.path, _profileImageDir));
      _messageImagesDir =
          Directory(path.join(_appCacheDir.path, _messageImageDir));

      await _profileImagesDir.create(recursive: true);
      await _messageImagesDir.create(recursive: true);

      // 메타데이터 로드
      await _loadMetadata();

      _initialized = true;
      debugPrint('✅ 이미지 캐시 서비스 초기화 완료');
    } catch (e) {
      debugPrint('⚠️ 이미지 캐시 서비스 초기화 오류: $e');
    }

    return this;
  }

  /// 메타데이터 로드
  Future<void> _loadMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final profileMeta = prefs.getString(_profileImageMetaKey);
      if (profileMeta != null) {
        _profileImageMeta.addAll(jsonDecode(profileMeta));
      }

      final messageMeta = prefs.getString(_messageImageMetaKey);
      if (messageMeta != null) {
        _messageImageMeta.addAll(jsonDecode(messageMeta));
      }

      debugPrint('✅ 이미지 캐시 메타데이터 로드 완료');
    } catch (e) {
      debugPrint('⚠️ 이미지 캐시 메타데이터 로드 오류: $e');
    }
  }

  /// 메타데이터 저장
  Future<void> _saveMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
          _profileImageMetaKey, jsonEncode(_profileImageMeta));
      await prefs.setString(
          _messageImageMetaKey, jsonEncode(_messageImageMeta));
    } catch (e) {
      debugPrint('⚠️ 이미지 캐시 메타데이터 저장 오류: $e');
    }
  }

  /// URL에서 파일 이름 생성 (해시 기반)
  String _getFileNameFromUrl(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString() + path.extension(url).toLowerCase();
  }

  /// 프로필 이미지 캐싱
  ///
  /// [url] 이미지 URL
  /// [uid] 사용자 ID
  /// [forceUpdate] 강제 업데이트 여부
  /// [uploadDate] 업로드 날짜
  Future<String?> cacheProfileImage(
    String url,
    String uid, {
    bool forceUpdate = false,
    DateTime? uploadDate,
  }) async {
    if (!_initialized) await init();

    try {
      final now = DateTime.now();
      final fileName = '${uid}_profile.jpg';
      final filePath = path.join(_profileImagesDir.path, fileName);
      final file = File(filePath);

      // 메타데이터 확인
      final metadata = _profileImageMeta[uid];
      final lastUpdated =
          metadata != null ? DateTime.parse(metadata['lastUpdated']) : null;
      final cachedUrl = metadata != null ? metadata['url'] as String : null;
      final cachedUploadDate =
          metadata != null && metadata['uploadDate'] != null
              ? DateTime.parse(metadata['uploadDate'])
              : null;

      // 강제 업데이트 요청이면 무조건 새로 다운로드
      if (forceUpdate) {
        debugPrint('🔄 프로필 이미지 강제 업데이트: $uid');
        // 새 이미지 다운로드 및 저장
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);

          // 메타데이터 업데이트
          _profileImageMeta[uid] = {
            'url': url,
            'lastUpdated': now.toIso8601String(),
            'filePath': filePath,
            'uploadDate':
                uploadDate?.toIso8601String() ?? now.toIso8601String(),
          };

          await _saveMetadata();
          debugPrint('✅ 프로필 이미지 강제 업데이트 완료: $uid');
          return filePath;
        } else {
          debugPrint('⚠️ 프로필 이미지 다운로드 실패: ${response.statusCode}');
          return null;
        }
      }

      // 파일이 존재하고 URL이 동일하고 강제 업데이트가 아니고
      // 캐시가 만료되지 않았고 업로드 날짜가 동일한 경우 캐시 파일 반환
      if (!forceUpdate &&
          await file.exists() &&
          cachedUrl == url &&
          (now.difference(lastUpdated!) < _cacheExpiration) &&
          (uploadDate == null ||
              cachedUploadDate == null ||
              uploadDate.isAtSameMomentAs(cachedUploadDate))) {
        debugPrint('✅ 프로필 이미지 캐시 사용: $uid');
        return filePath;
      }

      // 이미지 다운로드 및 저장
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);

        // 메타데이터 업데이트
        _profileImageMeta[uid] = {
          'url': url,
          'lastUpdated': now.toIso8601String(),
          'filePath': filePath,
          'uploadDate': uploadDate?.toIso8601String() ?? now.toIso8601String(),
        };

        await _saveMetadata();

        debugPrint('✅ 프로필 이미지 다운로드 및 캐싱 완료: $uid');
        return filePath;
      } else {
        debugPrint('⚠️ 프로필 이미지 다운로드 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ 프로필 이미지 캐싱 오류: $e');
      return null;
    }
  }

  /// 메시지 이미지 캐싱
  ///
  /// [url] 이미지 URL
  /// [messageId] 메시지 ID
  /// [forceUpdate] 강제 업데이트 여부
  Future<String?> cacheMessageImage(String url, String messageId,
      {bool forceUpdate = false}) async {
    if (!_initialized) await init();

    try {
      final now = DateTime.now();
      final fileName = '${messageId}_${_getFileNameFromUrl(url)}';
      final filePath = path.join(_messageImagesDir.path, fileName);
      final file = File(filePath);

      // 메타데이터 확인
      final metadata = _messageImageMeta[messageId];
      final lastUpdated =
          metadata != null ? DateTime.parse(metadata['lastUpdated']) : null;
      final cachedUrl = metadata != null ? metadata['url'] as String : null;

      // 파일이 존재하고 URL이 동일하고 강제 업데이트가 아니고
      // 캐시가 만료되지 않은 경우 캐시 파일 반환
      if (!forceUpdate &&
          await file.exists() &&
          cachedUrl == url &&
          (lastUpdated != null &&
              now.difference(lastUpdated) < _cacheExpiration)) {
        debugPrint('✅ 메시지 이미지 캐시 사용: $messageId');
        return filePath;
      }

      // 이미지 다운로드 및 저장
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);

        // 메타데이터 업데이트
        _messageImageMeta[messageId] = {
          'url': url,
          'lastUpdated': now.toIso8601String(),
          'filePath': filePath,
        };

        await _saveMetadata();

        debugPrint('✅ 메시지 이미지 다운로드 및 캐싱 완료: $messageId');
        return filePath;
      } else {
        debugPrint('⚠️ 메시지 이미지 다운로드 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ 메시지 이미지 캐싱 오류: $e');
      return null;
    }
  }

  /// 프로필 이미지 파일 경로 가져오기
  String? getProfileImagePath(String uid) {
    final metadata = _profileImageMeta[uid];
    if (metadata == null) return null;

    final filePath = metadata['filePath'] as String?;
    if (filePath == null) return null;

    final file = File(filePath);
    if (!file.existsSync()) return null;

    return filePath;
  }

  /// 메시지 이미지 파일 경로 가져오기
  String? getMessageImagePath(String messageId) {
    final metadata = _messageImageMeta[messageId];
    if (metadata == null) return null;

    final filePath = metadata['filePath'] as String?;
    if (filePath == null) return null;

    final file = File(filePath);
    if (!file.existsSync()) return null;

    return filePath;
  }

  /// 캐시 정리 (만료된 캐시 삭제)
  Future<void> cleanupCache() async {
    if (!_initialized) await init();

    try {
      final now = DateTime.now();

      // 프로필 이미지 캐시 정리
      final profileKeysToRemove = <String>[];

      _profileImageMeta.forEach((uid, metadata) {
        final lastUpdated = DateTime.parse(metadata['lastUpdated']);
        if (now.difference(lastUpdated) > _cacheExpiration) {
          final filePath = metadata['filePath'] as String?;
          if (filePath != null) {
            final file = File(filePath);
            if (file.existsSync()) {
              file.deleteSync();
            }
          }
          profileKeysToRemove.add(uid);
        }
      });

      for (final key in profileKeysToRemove) {
        _profileImageMeta.remove(key);
      }

      // 메시지 이미지 캐시 정리
      final messageKeysToRemove = <String>[];

      _messageImageMeta.forEach((messageId, metadata) {
        final lastUpdated = DateTime.parse(metadata['lastUpdated']);
        if (now.difference(lastUpdated) > _cacheExpiration) {
          final filePath = metadata['filePath'] as String?;
          if (filePath != null) {
            final file = File(filePath);
            if (file.existsSync()) {
              file.deleteSync();
            }
          }
          messageKeysToRemove.add(messageId);
        }
      });

      for (final key in messageKeysToRemove) {
        _messageImageMeta.remove(key);
      }

      await _saveMetadata();

      debugPrint(
          '✅ 이미지 캐시 정리 완료: 프로필 ${profileKeysToRemove.length}개, 메시지 ${messageKeysToRemove.length}개 삭제');
    } catch (e) {
      debugPrint('⚠️ 이미지 캐시 정리 오류: $e');
    }
  }

  /// 전체 캐시 삭제
  Future<void> clearAllCache() async {
    if (!_initialized) await init();

    try {
      // 프로필 이미지 디렉토리 삭제 후 재생성
      if (await _profileImagesDir.exists()) {
        await _profileImagesDir.delete(recursive: true);
        await _profileImagesDir.create(recursive: true);
      }

      // 메시지 이미지 디렉토리 삭제 후 재생성
      if (await _messageImagesDir.exists()) {
        await _messageImagesDir.delete(recursive: true);
        await _messageImagesDir.create(recursive: true);
      }

      // 메타데이터 초기화
      _profileImageMeta.clear();
      _messageImageMeta.clear();
      await _saveMetadata();

      debugPrint('✅ 전체 이미지 캐시 삭제 완료');
    } catch (e) {
      debugPrint('⚠️ 전체 이미지 캐시 삭제 오류: $e');
    }
  }
}
