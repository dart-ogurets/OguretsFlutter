part of ogurets_flutter;

// this is taken from the gherkin package and then modified. https://github.com/jonsamwell/dart_gherkin

enum DriverPlatform { android, ios }

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

  static RegExp _usageRegex = RegExp(r"Usage: flutter run \[arguments\]",
      caseSensitive: false, multiLine: false);

  static RegExp _errorRegex =
      RegExp(r"Gradle build aborted", caseSensitive: false, multiLine: false);

  static RegExp _finished =
      RegExp(r"Application (.*)\.", caseSensitive: false, multiLine: false);

  static RegExp _androidPlatform =
      RegExp(r"Gradle", caseSensitive: true, multiLine: false);

  Process? _runningProcess;
  late Stream<String> _processStdoutStream;
  late Stream<String> _processStderrStream;
  List<StreamSubscription> _openSubscriptions = <StreamSubscription>[];
  final String _appTarget;
  final String _workingDirectory;
  String? deviceId;
  String? flavour;
  String observatoryPort;
  String additionalArguments;
  Duration timeout = Duration(
      seconds: int.parse(
          Platform.environment['OGURETS_FLUTTER_START_TIMEOUT'] ?? '60'));
  late final List<String> cmdLine;
  DriverPlatform _platform = DriverPlatform.ios;

  FlutterRunProcessHandler(this._appTarget, this._workingDirectory,
      {this.flavour,
      this.deviceId,
      this.observatoryPort = '8888',
      this.additionalArguments = ''
      }) {
    _log.info("Waiting for up to ${timeout.inSeconds}s for build and start");
  }

  DriverPlatform get platform => _platform;

  /// builds the command line arguments for flutter run and calls startApp()
  Future<void> run() async {
    cmdLine = [
      "run",
      "--target=$_appTarget",
      "--observatory-port",
      observatoryPort
    ];
    String? flav = this.flavour;
    if (flav is String) {
      cmdLine.addAll(["--flavor", flav]);
    }

    String? devId = this.deviceId;
    if (devId != null) {
      cmdLine.addAll(["-d", devId]);
    }

    if (additionalArguments != null) {
      cmdLine.addAll(_splitArgs(additionalArguments));
    }

    await startApp();
  }

  /// Calls flutter run with any additional arguments. Do not await anything that is not a critical error, or the tests
  /// will not execute because it will wait for the process to exit.
  Future startApp() async {
    _log.info("flutter ${cmdLine.join(' ')}");

    Process _runningProcess = await Process.start("flutter", cmdLine,
        workingDirectory: _workingDirectory, runInShell: true);
    this._runningProcess = _runningProcess;
    _processStdoutStream =
        _runningProcess.stdout.transform(utf8.decoder).asBroadcastStream();
    _processStderrStream =
        _runningProcess.stderr.transform(utf8.decoder).asBroadcastStream();

    _openSubscriptions.add(_processStdoutStream.listen((data) {
      stdout.writeln(">> " + data);
    }));
    _openSubscriptions.add(_processStderrStream.listen((events) async {
      stderr
          .writeln(">> ${FAIL_COLOUR}Flutter run error: $events$RESET_COLOUR");
      // Get the exit code of flutter run and stop if there is an error so we don't have to wait for the timeout
      exit(await _runningProcess.exitCode);
    }));
  }

  // attempts to restart the running app
  Future restart() async {
    Process? _runningProcess = this._runningProcess;
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

  /// close the running app
  Future<int> terminate() async {
    print("closing app.");
    int exitCode = -1;
    _ensureRunningProcess();
    Process? _runningProcess = this._runningProcess;
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

  /// wait for a specific message to appear in the console
  Future<String> waitForConsoleMessage(
      RegExp search, String timeoutException, String failMessage) {
    _ensureRunningProcess();
    final completer = Completer<String>();
    StreamSubscription? stdoutSub;
    StreamSubscription? stderrSub;

    Timer? timer;

    stderrSub = _processStderrStream.listen((logLine) {
      if (_errorRegex.hasMatch(logLine)) {
        timer?.cancel();
        stdoutSub?.cancel();
        stderrSub?.cancel();
        if (!completer.isCompleted) {
          stderr.writeln(failMessage);
          completer.completeError(Exception("unknown startup failure"));
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
          completer.complete(search.firstMatch(logLine)?.group(1));
        }
      } else if (_noConnectedDeviceRegex.hasMatch(logLine)) {
        timer?.cancel();
        stdoutSub?.cancel();
        stderrSub?.cancel();
        if (!completer.isCompleted) {
          stderr.writeln(failMessage);
          completer
              .completeError(Exception("no device running to test against"));
        }
      } else if (_usageRegex.hasMatch(logLine)) {
        timer?.cancel();
        stdoutSub?.cancel();
        stderrSub?.cancel();
        if (!completer.isCompleted) {
          stderr.writeln(
              "${FAIL_COLOUR}Incorrect parameters for flutter run. Please check the command line above and resolve any issues.$RESET_COLOUR");
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

  /// wait for the debugger uri - appears after flutter run has started
  Future<String> waitForObservatoryDebuggerUri() {
    return waitForConsoleMessage(
        _observatoryDebuggerUriRegex,
        "Timeout while wait for observatory debugger uri",
        "${FAIL_COLOUR}No connected devices found to run app on and tests against$RESET_COLOUR");
  }

  /// make sure flutter run is executing - _runningProcess is set by startApp()
  void _ensureRunningProcess() {
    if (_runningProcess == null) {
      throw Exception(
          "FlutterRunProcessHandler: flutter run process is not active");
    }
  }

  /// port of translateCommandline https://commons.apache.org/proper/commons-exec/apidocs/src-html/org/apache/commons/exec/CommandLine.html
  List<String> _splitArgs(String line) {
    line = line.trimLeft();

    var args = <String>[];

    int pos = -1;
    StringBuffer current = StringBuffer();
    const int normal = 0;
    const int inSingleQuote = 1;
    const int inDoubleQuote = 2;
    int state = normal;
    bool lastQuoted = false;

    while (pos < line.length - 1) {
      var next = line[pos + 1];

      switch (state) {
        case inSingleQuote:
          if (next == '\'') {
            lastQuoted = true;
            state = normal;
          } else {
            current.write(next);
          }
          break;
        case inDoubleQuote:
          if (next == '\"') {
            lastQuoted = true;
            state = normal;
          } else {
            current.write(next);
          }
          break;
        default:
          if (next == '\'') {
            state = inSingleQuote;
          } else if (next == '\"') {
            state = inDoubleQuote;
          } else if (next == ' ') {
            if (lastQuoted || current.isNotEmpty) {
              args.add(current.toString());
              current.clear();
            }
          } else {
            current.write(next);
          }
          lastQuoted = false;
          break;
      }

      pos++;
    }

    if (lastQuoted || current.isNotEmpty) {
      args.add(current.toString());
    }

    return args;
  }
}
