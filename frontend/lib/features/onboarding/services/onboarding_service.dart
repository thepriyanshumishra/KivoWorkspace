// features/onboarding/services/onboarding_service.dart
// Purpose: Handles platform check, dependency downloading, extraction, hardware config, and backend spawning.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../../../core/constants/app_constants.dart';

class OnboardingService {
  final http.Client _client;
  bool _isSpawning = false;

  OnboardingService({http.Client? client}) : _client = client ?? http.Client();

  /// Retrieve system specifications dynamically via system commands.
  Future<Map<String, String>> checkSystemSpecs() async {
    final Map<String, String> specs = {};
    specs['os'] = Platform.operatingSystem;
    specs['cores'] = Platform.numberOfProcessors.toString();

    // 1. Get Architecture
    String arch = 'unknown';
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final res = await Process.run('uname', ['-m']);
        arch = res.stdout.toString().trim();
      } else if (Platform.isWindows) {
        arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'x64';
      }
    } catch (_) {}
    specs['arch'] = arch;

    // 2. Get RAM in GB
    double ramGb = 8.0; // Fallback default
    try {
      if (Platform.isMacOS) {
        final res = await Process.run('sysctl', ['-n', 'hw.memsize']);
        final bytes = int.tryParse(res.stdout.toString().trim()) ?? 0;
        if (bytes > 0) ramGb = bytes / (1024 * 1024 * 1024);
      } else if (Platform.isLinux) {
        final res = await Process.run('free', ['-g']);
        // Parse the first number in the Mem: row
        final lines = res.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.startsWith('Mem:')) {
            final parts = line.split(RegExp(r'\s+'));
            ramGb = double.tryParse(parts[1]) ?? ramGb;
            break;
          }
        }
      } else if (Platform.isWindows) {
        final res = await Process.run('wmic', ['ComputerSystem', 'get', 'TotalPhysicalMemory']);
        final lines = res.stdout.toString().split('\n');
        if (lines.length > 1) {
          final bytes = int.tryParse(lines[1].trim()) ?? 0;
          if (bytes > 0) ramGb = bytes / (1024 * 1024 * 1024);
        }
      }
    } catch (_) {}
    specs['ram'] = '${ramGb.toStringAsFixed(1)} GB';
    specs['ramValue'] = ramGb.toString();

    // 3. Get Disk Free Space in GB
    double freeDiskGb = 20.0;
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final res = await Process.run('df', ['-k', '/']);
        final lines = res.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          // Column index 3 is free space in KB (usually)
          if (parts.length > 3) {
            final kb = int.tryParse(parts[3]) ?? 0;
            if (kb > 0) freeDiskGb = kb / (1024 * 1024);
          }
        }
      } else if (Platform.isWindows) {
        final res = await Process.run('wmic', ['logicaldisk', 'where', 'DeviceID="C:"', 'get', 'FreeSpace']);
        final lines = res.stdout.toString().split('\n');
        if (lines.length > 1) {
          final bytes = int.tryParse(lines[1].trim()) ?? 0;
          if (bytes > 0) freeDiskGb = bytes / (1024 * 1024 * 1024);
        }
      }
    } catch (_) {}
    specs['disk'] = '${freeDiskGb.toStringAsFixed(1)} GB Free';
    specs['diskValue'] = freeDiskGb.toString();

    // 4. Detect GPU Hardware Acceleration
    bool hasAcceleration = false;
    try {
      if (Platform.isMacOS) {
        // All Apple Silicon macs have metal acceleration
        hasAcceleration = arch == 'arm64';
      } else {
        // Check for Nvidia CUDA
        final res = await Process.run('nvidia-smi', []);
        hasAcceleration = res.exitCode == 0;
      }
    } catch (_) {}
    specs['gpu'] = hasAcceleration ? 'Hardware Accelerated (GPU/Metal)' : 'CPU Only';
    specs['gpuValue'] = hasAcceleration.toString();

    return specs;
  }

  /// Check which local dependencies are already installed on the system.
  Future<Map<String, dynamic>> checkDependencies() async {
    final Map<String, dynamic> result = {};
    final isWindows = Platform.isWindows;

    // Define explicit common search paths for GUI apps (which do not inherit interactive shell PATH variables)
    final List<String> searchDirs = [];
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';

    if (Platform.isMacOS) {
      searchDirs.addAll([
        '/usr/local/bin',
        '/opt/homebrew/bin',
        '/usr/bin',
        '/bin',
        path.join(home, '.local', 'bin'),
        path.join(home, '.kivo_workspace', 'bin'),
      ]);
    } else if (Platform.isLinux) {
      searchDirs.addAll([
        '/usr/bin',
        '/usr/local/bin',
        '/bin',
        path.join(home, '.local', 'bin'),
        path.join(home, '.kivo_workspace', 'bin'),
      ]);
    } else if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? path.join(home, 'AppData', 'Local');
      searchDirs.addAll([
        path.join(home, '.kivo_workspace', 'bin'),
        path.join(localAppData, 'Programs', 'Python', 'Python310'),
        path.join(localAppData, 'Programs', 'Python', 'Python311'),
        path.join(localAppData, 'Programs', 'Python', 'Python312'),
        'C:\\Program Files\\FFmpeg\\bin',
        'C:\\ffmpeg\\bin',
        'C:\\Program Files\\Tesseract-OCR',
        'C:\\Program Files (x86)\\Tesseract-OCR',
      ]);
    }

    bool lookupBinary(String binaryName) {
      // 1. Try PATH resolution first
      try {
        final checkCmd = isWindows ? 'where' : 'which';
        final res = Process.runSync(checkCmd, [binaryName]);
        if (res.exitCode == 0) return true;
      } catch (_) {}

      // 2. Fallback to explicit common search directories
      for (final dir in searchDirs) {
        final file = File(path.join(dir, isWindows ? '$binaryName.exe' : binaryName));
        if (file.existsSync()) return true;
      }
      return false;
    }

    // 1. Check FFmpeg
    result['ffmpeg'] = lookupBinary('ffmpeg');

    // 2. Check Tesseract
    result['tesseract'] = lookupBinary('tesseract');

    // 3. Check Python
    result['python'] = lookupBinary(isWindows ? 'python' : 'python3');

    // 4. Check Embedding Engine (Alibaba GTE)
    bool embeddingOk = false;
    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
      final hfDir = Directory(path.join(home, '.cache', 'huggingface', 'hub', 'models--Alibaba-NLP--gte-multilingual-base'));
      final torchDir = Directory(path.join(home, '.cache', 'torch', 'sentence_transformers', 'Alibaba-NLP_gte-multilingual-base'));
      embeddingOk = await hfDir.exists() || await torchDir.exists();
    } catch (_) {}
    result['embedding'] = embeddingOk;

    // 5. Check Ollama Pulled Models
    final List<String> installedOllama = [];
    bool ollamaRunning = false;
    try {
      final res = await _client.get(Uri.parse('http://localhost:11434/api/tags')).timeout(const Duration(seconds: 1));
      if (res.statusCode == 200) {
        ollamaRunning = true;
        final Map<String, dynamic> data = json.decode(res.body);
        if (data.containsKey('models')) {
          for (final model in data['models']) {
            if (model.containsKey('name')) {
              installedOllama.add(model['name'] as String);
            }
          }
        }
      }
    } catch (_) {}
    result['ollamaModels'] = installedOllama;
    result['ollamaRunning'] = ollamaRunning;
    result['ollamaInstalled'] = ollamaRunning || lookupOllamaBinary();

    return result;
  }

  /// Check internet connectivity.
  Future<bool> checkInternetConnection() async {
    try {
      final res = await _client.get(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Find a free port starting from a default port.
  Future<int> _findFreePort(int startPort) async {
    int port = startPort;
    while (port < startPort + 100) {
      try {
        final socket = await ServerSocket.bind('127.0.0.1', port);
        await socket.close();
        return port;
      } catch (_) {
        port++;
      }
    }
    return startPort;
  }

  Directory? _getBundleBinDir() {
    try {
      final exeFile = File(Platform.resolvedExecutable);
      final exeDir = exeFile.parent;
      
      if (Platform.isMacOS) {
        // macOS: KivoWorkspace.app/Contents/MacOS/kivo_workspace
        // Resources: KivoWorkspace.app/Contents/Resources/bin/
        final resourcesBin = Directory(path.join(exeDir.parent.path, 'Resources', 'bin'));
        if (resourcesBin.existsSync()) {
          return resourcesBin;
        }
      } else {
        // Windows/Linux: executable_dir/bin/
        final siblingBin = Directory(path.join(exeDir.path, 'bin'));
        if (siblingBin.existsSync()) {
          return siblingBin;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Spawns the python backend subprocess with environment configuration.
  Future<Process?> spawnBackendProcess({required String defaultModel}) async {
    if (_isSpawning) {
      debugPrint("Backend spawn already in progress. Skipping duplicate call.");
      return null;
    }
    _isSpawning = true;
    try {
      final port = await _findFreePort(8000);
      AppConstants.backendBaseUrl = 'http://127.0.0.1:$port';

      final Map<String, String> env = Map.from(Platform.environment);
      final separator = Platform.isWindows ? ';' : ':';
      env['OLLAMA_DEFAULT_MODEL'] = defaultModel;
      env['PORT'] = port.toString();

      // Find where backend executable is located
      final backendExeName = Platform.isWindows ? 'kivo_backend.exe' : 'kivo_backend';
      File? backendFile;

      // 1. Check bundled folder first (production build)
      final bundleDir = _getBundleBinDir();
      if (bundleDir != null) {
        final f = File(path.join(bundleDir.path, backendExeName));
        if (f.existsSync()) {
          backendFile = f;
        }
      }

      // 2. Check local AppData folder (~/.kivo_workspace/bin) (user downloaded update or similar)
      if (backendFile == null) {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
        final binDir = Directory('$home/.kivo_workspace/bin');
        final f = File(path.join(binDir.path, backendExeName));
        if (f.existsSync()) {
          backendFile = f;
        }
      }

      // Hardware specific environments
      final specs = await checkSystemSpecs();
      if (specs['os'] == 'macos' && specs['arch'] == 'arm64') {
        env['OMP_NUM_THREADS'] = '1';
        env['MKL_NUM_THREADS'] = '1';
        env['OPENBLAS_NUM_THREADS'] = '1';
        env['VECLIB_MAXIMUM_THREADS'] = '1';
        env['NUMEXPR_NUM_THREADS'] = '1';
        env['DEVICE'] = 'mps';
      } else if (specs['gpuValue'] == 'true') {
        env['DEVICE'] = 'cuda';
      } else {
        env['DEVICE'] = 'cpu';
      }

      if (backendFile != null) {
        // We found a compiled backend binary!
        // Inject its parent directory to PATH env so it can locate sibling ffmpeg and tesseract
        env['PATH'] = '${backendFile.parent.path}$separator${env['PATH'] ?? ''}';
        
        final process = await Process.start(
          backendFile.path, 
          ['--port', port.toString()], 
          environment: env,
        );
        _isSpawning = false;
        return process;
      } else {
        // Fallback for development: run python main.py reload
        // Try to locate backend dir relative to project root
        final devBackendDir = Directory('../backend');
        if (await devBackendDir.exists()) {
          // Add default development bin path for dependencies if they exist
          final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
          final binDir = Directory('$home/.kivo_workspace/bin');
          env['PATH'] = '${binDir.path}$separator${env['PATH'] ?? ''}';
          
          final pythonCmd = Platform.isWindows ? 'python' : 'python3';
          final venvPython = Platform.isWindows 
              ? '${devBackendDir.path}/venv/Scripts/python.exe'
              : '${devBackendDir.path}/venv/bin/python';
          
          final execPath = await File(venvPython).exists() ? venvPython : pythonCmd;
          final process = await Process.start(
            execPath, 
            ['-m', 'uvicorn', 'main:app', '--port', port.toString()], 
            workingDirectory: devBackendDir.path,
            environment: env,
          );
          _isSpawning = false;
          return process;
        }
      }
    } catch (_) {}
    _isSpawning = false;
    return null;
  }

  /// Pulls a model via Ollama API and yields the pulling progress (0.0 to 1.0).
  Stream<double> pullOllamaModel(String modelId, {String? ollamaUrl}) async* {
    final client = http.Client();
    try {
      final url = '${ollamaUrl ?? "http://localhost:11434"}/api/pull';
      final request = http.Request('POST', Uri.parse(url));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'name': modelId});

      final response = await client.send(request);
      if (response.statusCode == 200) {
        final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
        await for (final line in stream) {
          if (line.trim().isEmpty) continue;
          try {
            final Map<String, dynamic> data = json.decode(line);
            if (data.containsKey('completed') && data.containsKey('total')) {
              final completed = data['completed'] as int;
              final total = data['total'] as int;
              if (total > 0) {
                yield completed / total;
              }
            }
          } catch (_) {}
        }
      } else {
        throw Exception('Failed to pull model from Ollama: Status ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Deletes a model from local Ollama installation via API.
  Future<void> deleteOllamaModel(String modelId, {String? ollamaUrl}) async {
    final url = '${ollamaUrl ?? "http://localhost:11434"}/api/delete';
    final response = await _client.delete(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': modelId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete model from Ollama: Status ${response.statusCode}');
    }
  }

  /// Check if the ollama executable is present on the host system.
  bool lookupOllamaBinary() {
    // 1. Try PATH resolution first
    try {
      final checkCmd = Platform.isWindows ? 'where' : 'which';
      final res = Process.runSync(checkCmd, ['ollama']);
      if (res.exitCode == 0) return true;
    } catch (_) {}

    // 2. Check common paths
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    final searchDirs = <String>[];
    if (Platform.isMacOS) {
      searchDirs.addAll([
        '/usr/local/bin',
        '/opt/homebrew/bin',
        '/usr/bin',
        '/bin',
        '/Applications/Ollama.app/Contents/Resources',
      ]);
    } else if (Platform.isLinux) {
      searchDirs.addAll([
        '/usr/bin',
        '/usr/local/bin',
        '/bin',
      ]);
    } else if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? path.join(home, 'AppData', 'Local');
      searchDirs.addAll([
        path.join(localAppData, 'Programs', 'Ollama'),
      ]);
    }
    
    final binaryName = Platform.isWindows ? 'ollama.exe' : 'ollama';
    for (final dir in searchDirs) {
      final file = File(path.join(dir, binaryName));
      if (file.existsSync()) return true;
    }
    return false;
  }

  /// Downloads and installs Ollama using official scripts/commands.
  Future<bool> installOllama() async {
    try {
      ProcessResult res;
      if (Platform.isWindows) {
        // Powershell command: irm https://ollama.com/install.ps1 | iex
        res = await Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          'irm https://ollama.com/install.ps1 | iex'
        ]);
      } else {
        // Bash command: curl -fsSL https://ollama.com/install.sh | sh
        res = await Process.run('sh', [
          '-c',
          'curl -fsSL https://ollama.com/install.sh | sh'
        ]);
      }
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Attempts to launch/start the Ollama service programmatically (headless, no GUI).
  Future<void> startOllamaService() async {
    try {
      if (Platform.isMacOS) {
        // Use 'ollama serve' directly — avoids opening the Ollama.app GUI window
        await Process.start('ollama', ['serve'], mode: ProcessStartMode.detached);
      } else if (Platform.isWindows) {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
        final localAppData = Platform.environment['LOCALAPPDATA'] ?? path.join(home, 'AppData', 'Local');
        final ollamaPath = path.join(localAppData, 'Programs', 'Ollama', 'ollama.exe');
        if (File(ollamaPath).existsSync()) {
          await Process.start(ollamaPath, ['serve'], mode: ProcessStartMode.detached);
        } else {
          await Process.start('ollama', ['serve'], mode: ProcessStartMode.detached);
        }
      } else if (Platform.isLinux) {
        final res = await Process.run('systemctl', ['--user', 'start', 'ollama']);
        if (res.exitCode != 0) {
          await Process.start('ollama', ['serve'], mode: ProcessStartMode.detached);
        }
      }
    } catch (_) {}
  }

  /// Checks if the backend is responsive via health endpoint.
  Future<bool> isBackendHealthy() async {
    try {
      final res = await _client.get(Uri.parse('${AppConstants.backendBaseUrl}/health')).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
