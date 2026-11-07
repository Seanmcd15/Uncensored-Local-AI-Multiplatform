import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Manages wake lock (screen stays on) and Android foreground service
/// to prevent the OS from killing downloads and inference.
class WakelockService extends GetxService {
  static const modelOwner = 'model';
  static const localApiOwner = 'local-api';

  static String downloadOwner(String filename) => 'download:$filename';

  final isWakeLockActive = false.obs;
  final Set<String> _activeOwners = {};
  Future<void> _platformOperation = Future.value();

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  bool get hasActiveOwners => _activeOwners.isNotEmpty;
  bool isHeldBy(String owner) => _activeOwners.contains(owner);

  Future<void> _queuePlatformOperation(
    Future<void> Function() operation,
  ) {
    final next = _platformOperation.then((_) => operation());
    _platformOperation = next.catchError((_) {});
    return next;
  }

  Future<WakelockService> init() async {
    if (_isMobile) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'portable_ai_foreground',
          channelName: 'Uncensored Local AI',
          channelDescription: 'Keeps downloads and AI inference running',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      
      // Request notification permission for Android 13+
      await FlutterForegroundTask.requestNotificationPermission();
    }
    return this;
  }

  /// Enable wake lock + foreground service for model download.
  Future<void> enableForDownload({
    required String owner,
    String modelName = 'model',
  }) async {
    _activeOwners.add(owner);
    if (!_isMobile) return;

    await _queuePlatformOperation(() async {
      if (!_activeOwners.contains(owner)) return;
      try {
        await WakelockPlus.enable();
        isWakeLockActive.value = true;

        await FlutterForegroundTask.startService(
          notificationTitle: 'Downloading $modelName',
          notificationText: 'Download in progress — keep the app open',
          serviceId: 100,
        );
      } catch (e) {
        debugPrint('WakelockService.enableForDownload error: $e');
      }
    });
  }

  /// Update the foreground notification with download progress.
  Future<void> updateDownloadProgress({
    required String modelName,
    required double progress,
    String? speedText,
  }) async {
    if (!_isMobile) return;

    try {
      final pct = (progress * 100).toInt();
      final speed = speedText != null ? ' • $speedText' : '';
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Downloading $modelName — $pct%',
        notificationText: 'Download in progress$speed',
      );
    } catch (_) {}
  }

  /// Enable wake lock + foreground service for AI inference.
  Future<void> enableForInference({
    required String owner,
    String modelName = 'AI model',
  }) async {
    _activeOwners.add(owner);
    if (!_isMobile) return;

    await _queuePlatformOperation(() async {
      if (!_activeOwners.contains(owner)) return;
      try {
        await WakelockPlus.enable();
        isWakeLockActive.value = true;

        await FlutterForegroundTask.startService(
          notificationTitle: 'AI Model Active',
          notificationText: '$modelName is loaded and ready',
          serviceId: 101,
        );
      } catch (e) {
        debugPrint('WakelockService.enableForInference error: $e');
      }
    });
  }

  /// Release an owner and stop the foreground service when none remain.
  Future<void> release({required String owner}) async {
    _activeOwners.remove(owner);
    if (!_isMobile) return;

    await _queuePlatformOperation(() async {
      if (_activeOwners.isNotEmpty) return;
      try {
        await WakelockPlus.disable();
        isWakeLockActive.value = false;
      } catch (_) {}

      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
    });
  }

  @override
  void onClose() {
    _activeOwners.clear();
    if (_isMobile) {
      unawaited(
        _queuePlatformOperation(() async {
          try {
            await WakelockPlus.disable();
            isWakeLockActive.value = false;
          } catch (_) {}
          try {
            await FlutterForegroundTask.stopService();
          } catch (_) {}
        }),
      );
    }
    super.onClose();
  }
}
