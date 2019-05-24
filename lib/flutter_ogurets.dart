part of ogurets_flutter;

final Logger _log = new Logger('ogurets_flutter');

/// This just follows the traditional world pattern
class FlutterOgurets {
  String _port;
  FlutterDriver _driver;
  FlutterRunProcessHandler _handler;
  bool _leaveRunning = false;
  bool _resetByDefault = true;
  bool _resetOverride;
  bool _canReset = false;
  String _targetApp;
  String _workingDirectory = '.';
  int _waitDelayAfterRestartInMilliseconds = 2000;

  FlutterDriver get driver => _driver;

  @BeforeRun(order: -999999)
  void init() async {
    if (_driver != null) {
      return;
    }

    if (Platform.environment['VM_SERVICE_URL'] != null) {
      _port = Platform.environment['VM_SERVICE_URL'];
    } else {
      var runApp = _targetApp;
      // run the app and get its port no. This also allows restart to work.
      if (runApp == null) {
        var app = Platform.environment['OGURETS_FLUTTER_APP'] ?? Platform.script.toFilePath();
        // standard integration tests (the only type that will use Flutter World)
        // use X_test.dart (test runner) and X.dart (app runner)
        if (app.endsWith("_test.dart")) {
          runApp = app.substring(0, app.length - "_test.dart".length) + ".dart";
        }
      }

      if (runApp == null) {
        throw Exception("Cannot determine how to run or connect to the application.");
      }

      _log.info("Waiting for application to start and expose port.");
      await _run(runApp);

      _canReset = true;
    }

    _driver = await FlutterDriver.connect(dartVmServiceUrl: _port);
  }

  void leaveRunning(bool l) {
    this._leaveRunning = l;
  }

  void waitDelayAfterRestartInMilliseconds(int ms) {
    _waitDelayAfterRestartInMilliseconds = ms;
  }

  void resetByDefault(bool defaultReset) {
    _resetByDefault = defaultReset;
  }

  // override for just this scenario
  void resetOverride(bool override) {
    _resetOverride = override;
  }

  void targetApp(String target) {
    this._targetApp = target;
  }

  void workingDirectory(String wDir) {
    this._workingDirectory = _workingDirectory;
  }

  Future _run(String runApp) async {
    _handler = FlutterRunProcessHandler(runApp, Platform.environment['OGURETS_FLUTTER_WORKDIR'] ?? '.');
    await _handler.run();
    _port = await _handler.waitForObservatoryDebuggerUri();
    _log.info("application started, exposed observatory port $_port");
  }

  Future restart() async {
    if (_handler == null || !_canReset) {
      return null;
    }

    // check if we have a reset override and it is set to false
    if (_resetOverride != null && !_resetOverride) {
      _resetOverride = null;
      return null;
    }

    if (!_resetByDefault && _resetOverride != null && _resetOverride) {
      _resetOverride = null; // we have been overridden to force a reset
    }

    // if we have an open driver, close it as a restart will kill it
    if (_driver != null) {
      await _driver.close();
    }

    // now hit "R" on the currently running app
    _log.info("Waiting for restart of driver");
    await _handler.restart();
    var c = Completer();

    // now wait for 2 seconds and then reconnect - not waiting causes it to fail
    Timer(Duration(milliseconds: _waitDelayAfterRestartInMilliseconds), () {
      FlutterDriver.connect(dartVmServiceUrl: _port).then((_d) {
        this._driver = _d;
        c.complete();
      }).catchError((e, s) => c.completeError(e, s));
    });

    return c.future;
  }

  Future quitAndStart() async {
    // if we have an open driver, close it as a restart will kill it
    if (_driver != null) {
      await _driver.close();
    }

    // now hit "R" on the currently running app
    await _handler.terminate();
    var c = Completer();

    // now wait for 2 seconds and then reconnect - not waiting causes it to fail
    Timer(Duration(milliseconds: _waitDelayAfterRestartInMilliseconds), () {
      FlutterDriver.connect(dartVmServiceUrl: _port).then((_d) {
        this._driver = _d;
        c.complete();
      }).catchError((e, s) => c.completeError(e, s));
    });

    return c.future;
  }

  void dispose() async {
    await close();
  }

  @AfterRun(order: 999999)
  Future close() async {
    if (_driver != null) {
      _log.info("Closing flutter driver");
      await _driver.close();
      _driver = null;
    }

    if (_handler != null && !_leaveRunning) {
      _log.info("Waiting for run application to close...");
      await _handler.terminate();
      _handler = null;
    }
  }
}
