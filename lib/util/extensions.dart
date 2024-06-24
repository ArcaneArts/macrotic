import 'package:macrotic/macrotic.dart';

extension XMethodDeclaration on MethodDeclaration {
  Iterable<Object> params() sync* {
    yield "(";

    if (positionalParameters.any((e) => e.isRequired)) {
      yield* positionalParameters
          .where((e) => e.isRequired)
          .expand((e) => [e.code, ","]);
    }

    if (positionalParameters.any((e) => !e.isRequired)) {
      yield "[";
      yield* positionalParameters
          .where((e) => !e.isRequired)
          .expand((e) => [e.code, ", "]);
      yield "]";
    }

    if (namedParameters.isNotEmpty) {
      yield "{";
      yield* namedParameters.expand((e) => [e.code, ","]);
      yield "}";
    }

    yield ")";
  }
}
