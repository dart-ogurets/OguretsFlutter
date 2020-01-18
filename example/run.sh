#!/bin/sh
flutter emulators --launch apple_ios_simulator
echo ios emulator launched
echo running e2e tests
export CUCUMBER_FOLDER=test_driver/features
export OGURETS_FLUTTER_START_TIMEOUT=120
dart --enable-asserts --enable-vm-service:59546 test_driver/ogurets_flutter_test.dart
