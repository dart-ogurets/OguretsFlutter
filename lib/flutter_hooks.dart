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
    await world.restart();
  }
}
