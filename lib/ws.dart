import 'package:macrotic/macros/model.dart';
import 'package:macrotic/macrotic.dart';

@Model()
class A {
  static const int $a = -1;
  static const String $b = "Hello";
}

void go() {
  A().toJson();
}
