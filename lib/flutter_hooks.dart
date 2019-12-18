part of ogurets_flutter;

class FlutterHooks {
  final FlutterOgurets world;

  FlutterHooks(this.world);

  // this enables overriding the default
  @Before(tag: 'FlutterRestart', order: -100)
  void restartTheFlutterApp() {
    world.resetOverride(true);
  }

  // this enables overriding the default
  @Before(tag: 'NoFlutterRestart', order: -100)
  void dontRestartTheFlutterApp() {
    world.resetOverride(false);
  }

  @After(tag: 'AndroidQuit', order: 999)
  void androidQuit() async {
    if (world.isAndroid) {
      await world.quit();
    }
  }

  // this won't do anything if the app wasn't started by us, the default
  // is not to restart or the NoFlutterRestart tag has been added
  @Before(order: -99)
  Future attemptRestart() async {
    if (world.started) {
      print("restarting app");
      await world.restart();
    }
    
    world.started = true;
  }

  @BeforeStep(tag: 'FlutterScreenshot')
  void beforeStepScreenshot(ScenarioStatus instanceScenario) async {
    await takescreenshot(instanceScenario);
  }

  @After(tag: 'FlutterScreenshot')
  void afterScenarioScreenshot(ScenarioStatus instanceScenario) async {
    await takescreenshot(instanceScenario);
  }

  Future takescreenshot(ScenarioStatus instanceScenario) async {
    String dir = Platform.environment['SCREENSHOT_DIR'];
    if (dir != null) {
      // ensure directory exists
      await Directory(dir).create(recursive: true);
      // filename is scenario name + timestamp
      String filename = dir + "/" + instanceScenario.scenario.name + "-" + DateTime.now().millisecondsSinceEpoch.toString() + ".jpg";
      final bytes = await world.driver.screenshot();
      await File(filename).writeAsBytes(bytes, flush: true);
    }
  }

}
