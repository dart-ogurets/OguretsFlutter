part of ogurets_flutter;

// this is taken from the gherkin package and then modified. https://github.com/jonsamwell/dart_gherkin

enum DriverPlatform {
  android, ios
}

class FlutterRunProcessHandler {
  static const String FAIL_COLOUR = "\u001b[33;31m"; // red
  static const String RESET_COLOUR = "\u001b[33;0m";

  static RegExp _observatoryDebuggerUriRegex = RegExp(
      r"observatory debugger .*[:]? (http[s]?:.*\/).*",
      caseSensitive: false,
      multiLine: false);

  static RegExp _restartedApplicationSuccess = RegExp(
      r"Restarted application (.*)ms.",
      caseSensitive: false,
      multiLine: false);

  static RegExp _noConnectedDeviceRegex =
  RegExp(r"no connected device", caseSensitive: false, multiLine: false);

  static RegExp _usageRegex =
  RegExp(r"Usage: flutter run \[arguments\]", caseSensitive: false, multiLine: false);

  static RegExp _errorRegex =
  RegExp(r"Gradle build aborted", caseSensitive: false, multiLine: false);

  static RegExp _finished =
  RegExp(r"Application (.*)\.", caseSensitive: false, multiLine: false);

  static RegExp _androidPlatform =
  RegExp(r"Gradle", caseSensitive: true, multiLine: false);

  Process _runningProcess;
  Stream<String> _processStdoutStream;
  Stream<String> _processStderrStream;
  List<StreamSubscription> _openSubscriptions = <StreamSubscription>[];
  final String _appTarget;
  final String _workingDirectory;
  String deviceId;
  String flavour;
  String observatoryPort = '8888';
  String additionalArguments;
  Duration timeout;
  List<String> cmdLine;
  DriverPlatform _platform = DriverPlatform.ios;

  FlutterRunProcessHandler(this._appTarget, this._workingDirectory, {this.flavour, this.deviceId, this.observatoryPort, this.additionalArguments}) {

    timeout = Duration(seconds: int.parse(Platform.environment['OGURETS_FLUTTER_START_TIMEOUT'] ?? '60'));
    _log.info("Waiting for up to ${timeout.inSeconds}s for build and start");
  }

  DriverPlatform get platform => _platform;

  Future<void> run() async {
    cmdLine = ["run", "--target=$_appTarget", "--observatory-port", observatoryPort];

    if (flavour != null) {
      cmdLine.addAll(["--flavor", flavour]);
    }

    if (deviceId != null) {
      cmdLine.addAll(["-d", deviceId]);
    }

    if (additionalArguments != null) {
      cmdLine.addAll(split(additionalArguments));
    }

    await startApp();
  }

  Future startApp() async {
    _log.info("flutter ${cmdLine.join(' ')}");

    _runningProcess = await Process.start("flutter",
        cmdLine,
        workingDirectory: _workingDirectory, runInShell: true);
    _processStdoutStream =
        _runningProcess.stdout.transform(utf8.decoder).asBroadcastStream();
    _processStderrStream =
        _runningProcess.stderr.transform(utf8.decoder).asBroadcastStream();

    _openSubscriptions.add(_processStdoutStream.listen((data) {
      stdout.writeln(">> " + data);
    }));
    _openSubscriptions.add(_processStderrStream.listen((events) {
      stderr.writeln(
          ">> ${FAIL_COLOUR}Flutter run error: ${events}$RESET_COLOUR");
    }));
  }

  // attempts to restart the running app
  Future restart() async {
    if (_runningProcess != null) {
      _runningProcess.stdin.write("R");
      return waitForConsoleMessage(
          _restartedApplicationSuccess,
          "Timeout waiting for app restart",
          "${FAIL_COLOUR}No connected devices found to run app on and tests against$RESET_COLOUR");
    } else {
      return startApp();
    }
  }

  Future<int> terminate() async {
    print("closing app.");
    int exitCode = -1;
    _ensureRunningProcess();
    if (_runningProcess != null) {
      _runningProcess.stdin.write("q");
      await waitForConsoleMessage(_finished, "Application not finished!!!", "");
      _openSubscriptions.forEach((s) => s.cancel());
      _openSubscriptions.clear();
      exitCode = await _runningProcess.exitCode;
      _runningProcess = null;
    }

    return exitCode;
  }

  //
  Future<String> waitForConsoleMessage(
      RegExp search, String timeoutException, String failMessage) {

    _ensureRunningProcess();
    final completer = Completer<String>();
    StreamSubscription stdoutSub;
    StreamSubscription stderrSub;

    Timer timer;

    stderrSub = _processStderrStream.listen((logLine) {
      if (_errorRegex.hasMatch(logLine)) {
        timer?.cancel();
        stdoutSub?.cancel();
        stderrSub?.cancel();
        if (!completer.isCompleted) {
          stderr.writeln(failMessage);
          completer.completeError(
              Exception("unknown startup failure"));
        }
      }
    });

    stdoutSub = _processStdoutStream.listen((logLine) {
      if (_androidPlatform.hasMatch(logLine)) {
        _platform = DriverPlatform.android;
      }

      if (search.hasMatch(logLine)) {
        timer?.cancel();
        stdoutSub?.cancel();
        stderrSub?.cancel();
        if (!completer.isCompleted) {
          completer.complete(search.firstMatch(logLine).group(1));
        }
      } else if (_noConnectedDeviceRegex.hasMatch(logLine)) {
        timer?.cancel();
        stdoutSub?.cancel();
        stderrSub?.cancel();
        if (!completer.isCompleted) {
          stderr.writeln(failMessage);
          completer.completeError(
              Exception("no device running to test against"));
        }
      } else if (_usageRegex.hasMatch(logLine)) {
        timer?.cancel();
        stdoutSub?.cancel();
        stderrSub?.cancel();
        if (!completer.isCompleted) {
          stderr.writeln("${FAIL_COLOUR}Incorrect parameters for flutter run. Please check the command line above and resolve any issues.$RESET_COLOUR");
          completer.completeError(
              Exception("incorrect parameters for flutter run."));
        }
      }
    }, cancelOnError: true);

    timer = Timer(timeout, () {
      stdoutSub?.cancel();
      stderrSub?.cancel();
      if (!completer.isCompleted) {
        stderr.writeln("timed out");
        completer.completeError(Exception("timed out"));
      }
    });

    return completer.future;
  }

  Future<String> waitForObservatoryDebuggerUri() {
    return waitForConsoleMessage(
        _observatoryDebuggerUriRegex,
        "Timeout while wait for observatory debugger uri",
        "${FAIL_COLOUR}No connected devices found to run app on and tests against$RESET_COLOUR");
  }

  void _ensureRunningProcess() {
    if (_runningProcess == null) {
      throw Exception(
          "FlutterRunProcessHandler: flutter run process is not active");
    }
  }
}
