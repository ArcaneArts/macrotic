import 'dart:async';

import 'package:macrotic/macrotic.dart';
import 'package:macrotic/util/extensions.dart';

macro class Cached implements MethodDeclarationsMacro {
  const Cached();
  
  @override
  FutureOr<void> buildDeclarationsForMethod(MethodDeclaration method, MemberDeclarationBuilder builder) {
    builder.declareInType(DeclarationCode.fromParts([
      "/// The cached response of [${method.identifier.name}Cached] if it had a response last time.\n"
      "  ",
      if(method.hasStatic)
      "static ",
      method.returnType.code, 
      "${method.returnType.isNullable?"":"?"} ",
      "_${method.identifier.name}CacheResult",
      ";"
    ]));

    builder.declareInType(DeclarationCode.fromParts([
      "  ",
      if(method.hasStatic)
      "static ",
      method.returnType.code, 
      " ${method.identifier.name}Cached",
      ...method.params(),
      " => ${method.identifier.name}();"
    ]));
  }
}
