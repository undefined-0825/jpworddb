import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionUpdateInfo {
  final String previousVersion;
  final String currentVersion;
  final Uri? reinstallUri;

  const VersionUpdateInfo({
    required this.previousVersion,
    required this.currentVersion,
    required this.reinstallUri,
  });
}

class VersionUpdateService {
  static const String _prefsKeyLastSeenVersion = 'last_seen_app_version';
  static const String _appStoreSearchTerm = 'コトノハ';
  static const String _iosAppStoreId = '';

  static Future<VersionUpdateInfo?> detectVersionUpgrade() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    final prefs = await SharedPreferences.getInstance();
    final previousVersion = prefs.getString(_prefsKeyLastSeenVersion);
    await prefs.setString(_prefsKeyLastSeenVersion, currentVersion);

    if (previousVersion == null || previousVersion == currentVersion) {
      return null;
    }

    return VersionUpdateInfo(
      previousVersion: previousVersion,
      currentVersion: currentVersion,
      reinstallUri: _buildReinstallUri(packageInfo.packageName),
    );
  }

  static Uri? _buildReinstallUri(String packageName) {
    if (Platform.isAndroid) {
      return Uri.parse('market://details?id=$packageName');
    }
    if (Platform.isIOS) {
      if (_iosAppStoreId.isNotEmpty) {
        return Uri.parse('itms-apps://apps.apple.com/app/id$_iosAppStoreId');
      }
      return Uri.https('apps.apple.com', '/jp/search', {
        'term': _appStoreSearchTerm,
      });
    }
    return null;
  }

  static Future<bool> openReinstallPage({
    required String packageName,
    required Uri? reinstallUri,
  }) async {
    Future<bool> tryLaunchExternal(Uri uri) async {
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }

    if (reinstallUri != null) {
      final opened = await tryLaunchExternal(reinstallUri);
      if (opened) return true;
    }

    if (Platform.isAndroid) {
      final webFallback = Uri.parse(
        'https://play.google.com/store/apps/details?id=$packageName',
      );
      final opened = await tryLaunchExternal(webFallback);
      if (opened) return true;

      // Last fallback for environments where external mode is rejected.
      try {
        return await launchUrl(webFallback);
      } catch (_) {
        return false;
      }
    }

    if (Platform.isIOS && _iosAppStoreId.isNotEmpty) {
      final webFallback = Uri.parse(
        'https://apps.apple.com/app/id$_iosAppStoreId',
      );
      return tryLaunchExternal(webFallback);
    }

    if (Platform.isIOS) {
      final webFallback = Uri.https('apps.apple.com', '/jp/search', {
        'term': _appStoreSearchTerm,
      });
      return tryLaunchExternal(webFallback);
    }

    return false;
  }
}
