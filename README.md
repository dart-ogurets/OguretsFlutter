# ogurets_flutter

*ogurets* is a Gherkin + Cucumber implementation in Dart, focused on making your life writing tests as easy as possible,
with the minimum of boilerplate fuss. *ogurets_flutter* is a flutter extension to ogurets which adds support for:

- Running against an existing running application (as long as you know the observatory port)
- Starting the application for you and controlling it to ensure it is allowed to Restart and set its state back
to the beginning without having to quit and rerun the application
- Terminating the application (or not) on completion
- Allowing you to set a default for restarts or no-restarts and use Gherkin tags to control behaviour.

## installing

in your `dev_dependencies` section in your `pubspec.yaml` include:

`  ogurets_flutter: ^1.2.1`

or whichever is the higher version you see on this page.

## environment variables

If you wish to control the flutter run via your own command line build, then the important environment variables are
the same as ogurets but with the extension of:

- OGURETS_FLUTTER_FLAVOUR - this passes "--flavor ${OGURETS_FLUTTER_FLAVOUR}" to flutter run. Not the International
English spelling.
- OGURETS_FLUTTER_DEVICE_ID - this passes "-d ${OGURETS_FLUTTER_DEVICE_ID}" to flutter run letting you specify a device
to run on.
- OGURETS_ADDITIONAL_ARGUMENTS - lets you specify any arguments you wish. Arguments in quotes are broken up
correctly.
- OGURETS_FLUTTER_START_TIMEOUT - lets you override the default 60 second timeout to wait for the application to start. 

## notes

*ogurets flutter* cannot be used from the command line tool `flutter driver` because it needs to know what 
the observatory port is. If you wish to include it in your test runs, just use Dart itself and run your 
_test.dart runner, it will start your main app and control it.

If you wish to use the `flutter driver` command line tool, use *ogurets* directly and just enable the driver in
an instance of your own to make it available to your steps. 

The other reason you may not need to use this mechanism is if you want to keep your app
running while you are writing your test, in which case start it with `flutter run`, take note of the Observatory
Port and set it in an environment variable: `VM_SERVICE_URL`. If *ogurets_flutter* sees that when it starts, it will
simply use it, but restart functionality will be turned off. Only use this when testing scenario by scenario and
you are writing and changing code and restarting the app yourself or where the state isn't important.
 
### Screenshots

*ogurets_flutter* can take screenshots for you - if you tag your test with XX and ensure the environment variable
SCREENSHOT_DIR has been set, then we will take screenshots after every step and once the scenario ends.

### Debugging

If you wish to run and debug your Flutter app as a separate process from your Ogurets run, you need to follow the 
below steps:

- create a new run profile that points to your "main" used in your Flutter Driver tests. Then add in the Additional
Arguments to this run configuration `--observatory-port 8888` (or chose some other port).
- start the application and look for the line when the build spits out: `Observatory URL on this device: http://127.0.0.1/XXXX`,
e.g. ![Observatory URL](images/observatory_url.png)
- open your test run configuration and you will see a field called Observatory URL - paste this link in there. If this
is in place when the IDE runs, it will not attempt to run the Flutter app, simply connect to it. From the command line,
this is done using the environment variable `VM_SERVICE_URL`.

At this point you can now operate in normal Flutter development mode, changing code, adding widget tags, debug points
and so forth, and re-running your tests again and again as necessary.

## authors

- _Irina Southwell (nee Капрельянц Ирина)_, Principal Engineer (https://www.linkedin.com/in/irina-southwell-9727a422/)
- _Richard Vowles_, Software Developer (https://www.linkedin.com/in/richard-vowles-72035193/)

We also thank Jon Samwell of _Flutter Gherkin_ for his idea (and core code) for managing the run of the the application.
 

