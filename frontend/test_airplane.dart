import 'package:airplane_mode_checker/airplane_mode_checker.dart';

void main() async {
  final status = await AirplaneModeChecker.checkAirplaneMode();
  print(status);
}
