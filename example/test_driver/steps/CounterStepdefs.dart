

import 'package:example/widget_keys.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:ogurets/ogurets.dart';
import 'package:ogurets_flutter/ogurets_flutter.dart';

class CounterStepdefs {
  final FlutterOgurets _world;

  CounterStepdefs(this._world);

  @Then(r'the counter is {int}')
  void theCounterIs(int counter) async {
    String text = await _world.driver.getText(find.byValueKey(WidgetKeys.valueKey), timeout: Duration(seconds: 1));
    assert(counter.toString() == text, 'The value of the counter was $text but should be $counter');
  }

  @When(r'I press the button {int} times')
  void iPressTheButtonTimes(int count) async {
    for(var counter = 0; counter < count; counter ++) {
      await _world.driver.tap(find.byValueKey(WidgetKeys.addButtonKey), timeout: Duration(seconds: 1));
    }
  }
}