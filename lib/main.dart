import 'package:macrotic/macro/json.dart';
import 'package:macrotic/macro/test.dart';

void main() {
  print("Hello!");
}

class SomeUtility {
  @Cached()
  Future<String> getThing() async {
    await Future.delayed(Duration(seconds: 4));
    return "response from network";
  }
}
