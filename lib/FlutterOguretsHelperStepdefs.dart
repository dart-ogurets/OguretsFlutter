import 'dart:io';

import 'package:image/image.dart';
import 'package:ogurets/ogurets.dart';

import 'ogurets_flutter.dart';

class FlutterOguretsHelperStepdefs {
  final FlutterOgurets _world;
  final FlutterOguretsScreenshotHelperState _state;

  FlutterOguretsHelperStepdefs(this._world, this._state);

  @And(r'I take a screenshot called {string}')
  void takeNamedScreenshot(String shotname) async {
    var dir = Platform.environment['SCREENSHOT_DIR'];
    var platformName = Platform.environment['SCREENSHOT_PLATFORM'];
    if (dir != null) {
      String fullDir = platformName != null ? '$dir/$platformName' : dir;
      // ensure directory exists
      await Directory(fullDir).create(recursive: true);
      // filename is scenario name + timestamp
      String filename = "$fullDir/$shotname.jpg";
      final bytes = await _world!.driver!.screenshot();

      if (_state.maxWidth != null || _state.maxHeight != null) {
        Image src = decodeImage(bytes);
        Image copy =
            copyResize(src, width: _state.maxWidth, height: _state.maxHeight);
        await File(filename).writeAsBytes(encodeJpg(copy), flush: true);
      } else {
        await File(filename).writeAsBytes(bytes, flush: true);
      }
    }
  }

  @And(r'I set the maximum screenshot height to {int}')
  void maxHeight(int height) {
    _state.maxHeight = height;
  }

  @And(r'I set the maximum screenshot width to {int}')
  void maxWidth(int width) {
    _state.maxWidth = width;
  }
}

class FlutterOguretsScreenshotHelperState {
  int? maxWidth;
  int? maxHeight;
}
