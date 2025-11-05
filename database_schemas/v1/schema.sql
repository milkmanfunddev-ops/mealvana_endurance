Unhandled exception:
FileSystemException: Cannot open file, path = 'database_schemas/v1/' (OS Error: Is a directory, errno = 21)
#0      _checkForErrorResponse (dart:io/common.dart:58:9)
#1      _File.open.<anonymous closure> (dart:io/file_impl.dart:442:7)
<asynchronous suspension>
#2      _File.writeAsBytes.<anonymous closure> (dart:io/file_impl.dart:732:34)
<asynchronous suspension>
#3      WriteVersions.run (package:drift_dev/src/cli/commands/schema/steps.dart:49:5)
<asynchronous suspension>
#4      CommandRunner.runCommand (package:args/command_runner.dart:212:13)
<asynchronous suspension>
#5      DriftDevCli.run (package:drift_dev/src/cli/cli.dart:70:5)
<asynchronous suspension>
#6      run (package:drift_dev/src/cli/cli.dart:20:12)
<asynchronous suspension>
#7      main (file:///Users/leemartin/.pub-cache/hosted/pub.dev/drift_dev-2.28.3/bin/drift_dev.dart:7:5)
<asynchronous suspension>
