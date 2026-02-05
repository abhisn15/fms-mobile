class VersionResponse {
  final bool success;
  final VersionData? data;
  final String? error;

  VersionResponse({
    required this.success,
    this.data,
    this.error,
  });

  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      success: json['success'] ?? false,
      data: json['data'] != null ? VersionData.fromJson(json['data']) : null,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data?.toJson(),
      'error': error,
    };
  }
}

class VersionData {
  final String version;
  final int versionCode;
  final String platform;
  final String releaseNotes;
  final bool forceUpdate;
  final String minimumVersion;
  final String updateUrl;
  final String timestamp;

  VersionData({
    required this.version,
    required this.versionCode,
    required this.platform,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.minimumVersion,
    required this.updateUrl,
    required this.timestamp,
  });

  factory VersionData.fromJson(Map<String, dynamic> json) {
    return VersionData(
      version: json['version'] ?? '',
      versionCode: json['versionCode'] ?? 0,
      platform: json['platform'] ?? 'android',
      releaseNotes: json['releaseNotes'] ?? '',
      forceUpdate: json['forceUpdate'] ?? false,
      minimumVersion: json['minimumVersion'] ?? '',
      updateUrl: json['updateUrl'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'versionCode': versionCode,
      'platform': platform,
      'releaseNotes': releaseNotes,
      'forceUpdate': forceUpdate,
      'minimumVersion': minimumVersion,
      'updateUrl': updateUrl,
      'timestamp': timestamp,
    };
  }

  // Helper methods
  bool isUpdateAvailable(String currentVersion) {
    return _compareVersions(version, currentVersion) > 0;
  }

  bool isUpdateRequired(String currentVersion) {
    return forceUpdate || _compareVersions(minimumVersion, currentVersion) > 0;
  }

  // Simple version comparison (major.minor.patch)
  int _compareVersions(String version1, String version2) {
    List<int> v1Parts = version1.split('.').map(int.parse).toList();
    List<int> v2Parts = version2.split('.').map(int.parse).toList();

    // Pad shorter version with zeros
    while (v1Parts.length < v2Parts.length) {
      v1Parts.add(0);
    }
    while (v2Parts.length < v1Parts.length) {
      v2Parts.add(0);
    }

    for (int i = 0; i < v1Parts.length; i++) {
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }
    return 0; // versions are equal
  }
}
