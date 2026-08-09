import 'dart:io';

void main(List<String> args) async {
  // Get commit count
  final result = await Process.run('git', ['rev-list', '--count', 'HEAD']);
  if (result.exitCode != 0) {
    print('Error running git command: ${result.stderr}');
    exit(1);
  }

  int commitCount = int.parse(result.stdout.toString().trim());

  // If this is running in a pre-commit hook, the commit hasn't been created yet.
  // So we add 1 to the commit count to represent the version of the incoming commit.
  if (args.contains('--pre-commit')) {
    commitCount += 1;
  }

  // Calculate version based on requirements
  // 1 commit = 0.0.1
  // 100 commits = 0.1.0
  // 101 commits = 0.1.1
  int major = commitCount ~/ 1000;
  int minor = (commitCount % 1000) ~/ 100;
  int patch = commitCount % 100;

  String newVersion = '$major.$minor.$patch';
  print('Updating version to: $newVersion (commit count: $commitCount)');

  // Update app_constants.dart
  final constantsFile = File('lib/core/constants/app_constants.dart');
  if (!await constantsFile.exists()) {
    print('Error: app_constants.dart not found.');
    exit(1);
  }

  String content = await constantsFile.readAsString();
  
  // Replace version using regex
  final versionRegex = RegExp(r"const String appVersion = '[^']+';");
  final buildNumberRegex = RegExp(r"const String appBuildNumber = '[^']+';");

  content = content.replaceAll(versionRegex, "const String appVersion = '$newVersion';");
  content = content.replaceAll(buildNumberRegex, "const String appBuildNumber = '$commitCount';");

  await constantsFile.writeAsString(content);
  print('Successfully updated app_constants.dart');
  
  if (args.contains('--pre-commit')) {
    // Stage the changed file
    await Process.run('git', ['add', 'lib/core/constants/app_constants.dart']);
  }
}
