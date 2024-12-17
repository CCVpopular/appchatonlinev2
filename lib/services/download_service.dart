import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  static Future<void> initialize() async {
    await FlutterDownloader.initialize(
      debug: true,
      ignoreSsl: true
    );
  }

  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidVersion = int.parse(await _getAndroidVersion());
      
      if (androidVersion >= 33) { // Android 13 and above
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        final audio = await Permission.audio.request();
        final files = await Permission.manageExternalStorage.request();
        
        return photos.isGranted && 
               videos.isGranted && 
               audio.isGranted &&
               files.isGranted;
      } else if (androidVersion >= 30) { // Android 11 and 12
        final storage = await Permission.storage.request();
        final manageStorage = await Permission.manageExternalStorage.request();
        
        return storage.isGranted && manageStorage.isGranted;
      } else { // Android 10 and below
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true; // For iOS or other platforms
  }

  static Future<String> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        String release = Platform.operatingSystemVersion;
        // Extract SDK version from strings like "13" or "SDK 33" or "Android 13"
        RegExp regExp = RegExp(r'(\d+)');
        Match? match = regExp.firstMatch(release);
        if (match != null && match.group(1) != null) {
          return match.group(1)!;
        }
        // Fallback for newer Android versions
        if (release.toLowerCase().contains('tiramisu')) return '13';
        if (release.toLowerCase().contains('vanillaicecream')) return '14';
        return '33'; // Default to Android 13 if we can't determine version
      }
    } catch (e) {
      print('Error parsing Android version: $e');
    }
    return '33'; // Default fallback version
  }

  static Future<String> getDownloadPath() async {
    late Directory directory;
    
    if (Platform.isAndroid) {
      final androidVersion = int.parse(await _getAndroidVersion());
      
      if (androidVersion >= 30) { // Android 11 and above
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    
    final downloadPath = '${directory.path}/ChatApp';
    await Directory(downloadPath).create(recursive: true);
    return downloadPath;
  }

  static Future<String?> downloadFile({
    required String url,
    required String fileName,
    bool isImage = false,
  }) async {
    try {
      final granted = await requestStoragePermission();
      if (!granted) {
        throw Exception('Storage permission denied');
      }

      final savePath = await getDownloadPath();
      final subDir = isImage ? 'Images' : 'Files';
      final fullPath = '$savePath/$subDir';
      
      await Directory(fullPath).create(recursive: true);

      // Modify Google Drive URL to get direct download link
      String downloadUrl = url;
      if (url.contains('drive.google.com')) {
        // Extract file ID from Google Drive URL
        final RegExp regExp = RegExp(r'/d/([^/]+)');
        final Match? match = regExp.firstMatch(url);
        if (match != null && match.groupCount >= 1) {
          final String fileId = match.group(1)!;
          downloadUrl = 'https://drive.google.com/uc?export=download&id=$fileId';
        }
      }

      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: fullPath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
        allowCellular: true,
        requiresStorageNotLow: false,
      );

      return taskId;
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }

  static Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }

  static Future<void> retryDownload(String taskId) async {
    await FlutterDownloader.retry(taskId: taskId);
  }
}