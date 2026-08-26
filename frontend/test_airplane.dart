import 'package:airplane_mode_checker/airplane_mode_checker.dart';

void main() async {
  final status = await AirplaneModeChecker.instance.checkAirplaneMode();
  print(status);
}
