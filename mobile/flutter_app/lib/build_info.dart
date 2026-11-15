/// Values recorded when Flutter compiles the application, never at app launch.
class AppBuildInfo {
  const AppBuildInfo({
    this.date = const String.fromEnvironment('SANQI_BUILD_DATE'),
    this.commit = const String.fromEnvironment('SANQI_GIT_COMMIT'),
  });

  final String date;
  final String commit;
}
