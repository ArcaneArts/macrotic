import 'package:macrotic/macrotic.dart';

@Model()
class A {
  static const int $a = -1;
}

@Model()
class B extends A {
  static const int $b = -1;
}

void main() {
  B p = B(
    a: 1,
    b: 2,
  );

  print(p.toJson(pretty: true));
}
