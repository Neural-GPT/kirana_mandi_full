import '../remote/api_client.dart';

class ApkBuildTriggerResult {
  final bool triggered;
  final String message;
  final String? actionsUrl;
  ApkBuildTriggerResult({required this.triggered, required this.message, this.actionsUrl});

  factory ApkBuildTriggerResult.fromJson(Map<String, dynamic> json) => ApkBuildTriggerResult(
        triggered: json['triggered'] as bool,
        message: json['message'] as String,
        actionsUrl: json['actions_url'] as String?,
      );
}

class ApkStatus {
  final String status; // "not_built_yet" | "ready"
  final String? downloadUrl;
  final DateTime? builtAt;
  final String? applicationId;
  ApkStatus({required this.status, this.downloadUrl, this.builtAt, this.applicationId});

  bool get isReady => status == 'ready' && downloadUrl != null;

  factory ApkStatus.fromJson(Map<String, dynamic> json) => ApkStatus(
        status: json['status'] as String,
        downloadUrl: json['download_url'] as String?,
        builtAt: json['built_at'] == null ? null : DateTime.parse(json['built_at'] as String),
        applicationId: json['application_id'] as String?,
      );
}

/// Backend-only: this is real CI orchestration (kicks off a GitHub
/// Actions build), which has no meaningful offline/SQLite equivalent --
/// see main.dart, which only wires this up when EnvConfig.useRemoteApi
/// is true. AppDeploymentScreen hides the "Generate My App" section
/// entirely when it's unavailable (e.g. an offline demo build).
abstract class DeploymentRepository {
  Future<ApkBuildTriggerResult> generateApk(String shopId);
  Future<ApkStatus> getApkStatus(String shopId);
}

class HttpDeploymentRepository implements DeploymentRepository {
  final ApiClient _client;
  HttpDeploymentRepository(this._client);

  @override
  Future<ApkBuildTriggerResult> generateApk(String shopId) async {
    final json = await _client.post('/shops/$shopId/generate-apk');
    return ApkBuildTriggerResult.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<ApkStatus> getApkStatus(String shopId) async {
    final json = await _client.get('/shops/$shopId/apk-status');
    return ApkStatus.fromJson(json as Map<String, dynamic>);
  }
}
