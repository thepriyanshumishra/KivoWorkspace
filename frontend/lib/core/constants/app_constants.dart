// app/core/constants/app_constants.dart
// Purpose: Application-wide constants for Kivo Workspace.
// Responsibilities: Defines app name, version, backend URL.

class AppConstants {
  AppConstants._();

  static const String appName = 'Kivo Workspace';
  static const String appVersion = '1.0.0';

  // Backend base URL — FastAPI running locally (can be updated dynamically if port 8000 is in use)
  static String backendBaseUrl = 'http://127.0.0.1:8000';

  // API endpoints
  static const String healthEndpoint = '/health';
  static const String workspacesEndpoint = '/workspaces';
}
