import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for checking app updates via GitHub Releases API.
class UpdateService {
  /// GitHub API URL for latest release.
  /// Replace YOUR_USERNAME with your actual GitHub username.
  static const String _releaseUrl =
      'https://api.github.com/repos/XU-QiYi/ai-hub/releases/latest';

  /// Compare two semantic version strings (without "v" prefix).
  /// Returns true if [latest] is newer than [current].
  static bool isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.tryParse).toList();
    final latestParts = latest.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final c = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
      final l = (i < latestParts.length ? latestParts[i] : 0) ?? 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Check GitHub for a newer version.
  ///
  /// Returns a map with `latestVersion`, `downloadUrl`, `releaseNotes`
  /// if an update is available, otherwise `null`.
  Future<Map<String, dynamic>?> checkForUpdate(String currentVersion) async {
    try {
      final response = await http.get(
        Uri.parse(_releaseUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final latestVersion = tagName.replaceFirst('v', '');

      if (!isNewerVersion(currentVersion, latestVersion)) return null;

      final assets = json['assets'] as List<dynamic>? ?? [];
      String downloadUrl = '';
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? '';
          break;
        }
      }

      final releaseNotes = json['body'] as String? ?? '';

      return {
        'latestVersion': latestVersion,
        'downloadUrl': downloadUrl,
        'releaseNotes': releaseNotes,
      };
    } catch (_) {
      return null;
    }
  }
}
