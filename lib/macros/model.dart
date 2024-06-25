import 'dart:async';
import 'dart:convert' as c;

import 'package:collection/collection.dart';
import 'package:macros/macros.dart';


class ModelField<O, T>{
  final String name;
  final Type type;
  final T Function(O instance) get;
  final O Function(O instance, T value) set;
  final List<Object> annotations;
  
  const ModelField(this.name, this.type, this.get, this.set, this.annotations);
  
  T annotation<T>() => annotations.whereType<T>().first;
}

class ModelMethod<O> {
  final String name;
  final List<Object> annotations;
  final dynamic Function(O, List<dynamic>) caller;
  
  const ModelMethod(this.name, this.annotations, this.caller);
  
  dynamic call(O instance, List<dynamic> params) => caller(instance, params);
  
  T annotation<T>() => annotations.whereType<T>().first;
}

class ModelMirror<O>{
  final List<ModelField<O, dynamic>> fields;
  final List<ModelMethod<O>> methods;
  
  const ModelMirror(this.fields, this.methods); 
  
  ModelField field(String name) => fields.firstWhere((i) => i.name == name);
  
  ModelMethod method(String name) => methods.firstWhere((i) => i.name == name);
}

macro class Model implements ClassDeclarationsMacro {
  const Model();
  
  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    builder.declareInLibrary(DeclarationCode.fromString(
        "import 'package:macrotic/macrotic.dart';\n"));

    await buildFields(clazz, builder);
    await buildConstructor(clazz, builder);
    await buildFromMap(clazz, builder);
    await buildFromJson(clazz, builder);
    await buildToJson(clazz, builder);
    await buildToMap(clazz, builder);
    await buildMutate(clazz, builder);
    await buildHashCode(clazz, builder);
    await buildEquals(clazz, builder);
    await buildToString(clazz, builder);
    await buildMirror(clazz, builder);
  }
  
  static bool deepEq(Object? e1, Object? e2) => const DeepCollectionEquality().equals(e1, e2);
  
  static int deepHash(Object? e1) => const DeepCollectionEquality().hash(e1);
  
  static String jsonEncode(Map<String, dynamic> map, {bool pretty = false}) => 
      pretty ? 
      const c.JsonEncoder.withIndent("  ").convert(map)
      : c.jsonEncode(map);
  
  static Map<String, dynamic> jsonDecode(String json) => c.jsonDecode(json);
  
  static List<T> modList<T>(List<T> initial, Iterable<T>? add, Iterable<T>? remove, bool Function(T)? where){
    if(add != null || remove != null || where != null){
      List<T> copy = initial.toList();
      
      if(add != null){
        copy.addAll(add);
      }
      
      if(remove != null){
        for(T item in remove){
          copy.remove(item);
        }
      }
      
      if(where != null){
        copy.removeWhere(where);
      }
      
      return copy;
    }
    
    return initial;
  }
  
  static Set<T> modSet<T>(Set<T> initial, Iterable<T>? add, Iterable<T>? remove, bool Function(T)? where){
    if(add != null || remove != null || where != null){
      Set<T> copy = initial.toSet();
      
      if(add != null){
        copy.addAll(add);
      }
      
      if(remove != null){
        for(T item in remove){
          copy.remove(item);
        }
      }
      
      if(where != null){
        copy.removeWhere(where);
      }
      
      return copy;
    }
    
    return initial;
  }
  
  static Map<K,V> modMap<K,V>(Map<K,V> initial, Map<K,V>? add, Iterable<K>? removeKeys, bool Function(K)? whereKeys, Iterable<V>? removeValues, bool Function(V)? whereValues){
    if(add != null || removeKeys != null || whereKeys != null || removeValues != null || whereValues != null){
      Map<K,V> copy = initial;
      
      if(add != null){
        copy.addAll(add);
      }
      
      if(removeKeys != null){
        for(K key in removeKeys){
          copy.remove(key);
        }
      }
      
      if(whereKeys != null){
        copy.removeWhere((k, v) => whereKeys(k));
      }
      
      if(removeValues != null){
        for(V value in removeValues){
          copy.removeWhere((k, v) => v == value);
        }
      }
      
      if(whereValues != null){
        copy.removeWhere((k, v) => whereValues(v));
      }
      
      return copy;
    }
    
    return initial;
  }

  Future<List<FieldDeclaration>> validFields(ClassDeclaration clazz, MemberDeclarationBuilder builder) async => (await builder.fieldsOf(clazz)).where((i) => i.hasStatic && i.hasConst && i.identifier.name.startsWith("\$")).toList();
  Future<List<MethodDeclaration>> validMethods(ClassDeclaration clazz, MemberDeclarationBuilder builder) async => (await builder.methodsOf(clazz)).where((i) => !i.hasStatic).toList();
  
  Future<void> buildFields(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    List<FieldDeclaration> properties = await validFields(clazz, builder);
    
    if(!properties.isEmpty){
      builder.declareInType(DeclarationCode.fromString("""
    ${properties.map((i) => "/// Defined from [${i.identifier.name}]\n    ${i.hasLate ? "late " : ""}final ${i.type.fullName} ${i.identifier.name.substring(1)};\n").join("\n    ")}"""));
    }
  }

  Future<void> buildConstructor(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    List<FieldDeclaration> properties = await validFields(clazz, builder);

    if(properties.isEmpty){
      builder.declareInType(DeclarationCode.fromString("""
    /// The Constructor for [${clazz.identifier.name}]. You should probably define some fields.
    const ${clazz.identifier.name}();
      """));
    } else{
      builder.declareInType(DeclarationCode.fromString("""
    /// The Constructor for [${clazz.identifier.name}]. 
    /// Null values use the default value in the \$prefixed static const fields.
    ${properties.map((i) => "/// [${i.identifier.name.substring(1)}] ${i.type.fullName}").join("\n    ")}
    const ${clazz.identifier.name}({
       ${properties.map((i) => "${!i.type.isNullable && !i.hasInitializer?"required " : ""} this.${i.identifier.name.substring(1)}${i.hasInitializer ? " = ${i.identifier.name}" : ""}").join(",\n       ")}
    });
    """));
    }
  }

  Future<void> buildFromMap(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    List<FieldDeclaration> properties = await validFields(clazz, builder);

    if(properties.isEmpty){
      builder.declareInType(DeclarationCode.fromString("""
    // Creates a new [${clazz.identifier.name}] object from a Map<String, dynamic>
    factory ${clazz.identifier.name}.fromMap(Map<String, dynamic> map) => ${clazz.identifier.name}();
      """));
    } else{
      builder.declareInType(DeclarationCode.fromString("""
    // Creates a new [${clazz.identifier.name}] object from a Map<String, dynamic>
    factory ${clazz.identifier.name}.fromMap(Map<String, dynamic> map) => ${clazz.identifier.name}(
        ${properties.map((i) => "${i.identifier.name.substring(1)}: map[\"${i.identifier.name.substring(1)}\"] != null ? ${_fromMap(i, builder)} : ${i.identifier.name}").join(",\n        ")}
    );
    """));
    }
  }

  Future<void> buildFromJson(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    builder.declareInType(DeclarationCode.fromString("""
    // Converts a json string to a [${clazz.identifier.name}] object.
    factory ${clazz.identifier.name}.fromJson(String json) => ${clazz.identifier.name}.fromMap(Model.jsonDecode(json));
    """));
  }

  Future<void> buildToJson(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    builder.declareInType(DeclarationCode.fromString("""
    /// Converts [${clazz.identifier.name}] object to a json string.
    String toJson({bool pretty = false}) => Model.jsonEncode(toMap(), pretty: pretty);
    """));
  }

  Future<void> buildToMap(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    List<FieldDeclaration> properties = await validFields(clazz, builder);

    if (properties.isEmpty) {
      builder.declareInType(DeclarationCode.fromString("""
    // Converts this object to a Map<String, dynamic>
    Map<String, dynamic> toMap() => {};
    """));
    } else {
      builder.declareInType(DeclarationCode.fromString("""
    // Converts this object to a Map<String, dynamic>
    Map<String, dynamic> toMap() => {
      ${properties.map((i) => "\"${i.identifier.name.substring(1)}\": ${_toMap(
          i, builder)}").join(",\n      ")}
    };
    """));
    }
  }

    Future<void> buildMutate(ClassDeclaration clazz,
        MemberDeclarationBuilder builder) async {
      List<FieldDeclaration> properties = await validFields(clazz, builder);
      if(properties.isEmpty){
        builder.declareInType(DeclarationCode.fromString("""
    /// Creates a new [${clazz.identifier.name}] object with the provided fields as overrides
    /// Also provides mutator methods to add,remove,removeWhere on Lists, Sets & Maps
    ${clazz.identifier.name} mutate() => ${clazz.identifier.name}();
    """));

      }else{
        builder.declareInType(DeclarationCode.fromString("""
    /// Creates a new [${clazz.identifier.name}] object with the provided fields as overrides
    /// Also provides mutator methods to add,remove,removeWhere on Lists, Sets & Maps
    ${properties.map((i) {
          String s =  "/// ### [${i.identifier.name.substring(1)}]";

          if(i.type.name == "List"){
            s += "\n    /// * add [add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}]";
            s += "\n    /// * remove [remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}]";
            s += "\n    /// * removeWhere [remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Where]";
          } else if(i.type.name == "Set") {
            s += "\n    /// * add [add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}]";
            s += "\n    /// * remove [remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}]";
            s += "\n    /// * removeWhere [remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Where]";
          } else if(i.type.name == "Map") {
            s += "\n    /// * add [add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}]";
            s += "\n    /// * removeKeys [remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Keys]";
            s += "\n    /// * removeKeysWhere [remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}KeysWhere]";
            s += "\n    /// * removeValues [remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Values]";
            s += "\n    /// * removeValuesWhere [remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}ValuesWhere]";
          }

          return s;
        }).join("\n    ")}
    ${clazz.identifier.name} mutate({
      ${properties.map((i) => "${i.type.fullName}? ${i.identifier.name.substring(1)}")

            .followedBy(properties.where((i) => i.type.name == "List" || i.type.name == "Set").map((i) => "Iterable<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>? add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}"))
            .followedBy(properties.where((i) => i.type.name == "List" || i.type.name == "Set").map((i) => "Iterable<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}"))
            .followedBy(properties.where((i) => i.type.name == "List" || i.type.name == "Set").map((i) => "bool Function(${(i.type as NamedTypeAnnotation).typeArguments.first.fullName})? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Where"))
            .followedBy(properties.where((i) => i.type.name == "Map").map((i) => "${i.type.fullName}? add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}"))
            .followedBy(properties.where((i) => i.type.name == "Map").map((i) => "Iterable<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Keys"))
            .followedBy(properties.where((i) => i.type.name == "Map").map((i) => "bool Function(${(i.type as NamedTypeAnnotation).typeArguments.first.fullName})? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}KeysWhere"))
            .followedBy(properties.where((i) => i.type.name == "Map").map((i) => "Iterable<${(i.type as NamedTypeAnnotation).typeArguments.last.fullName}>? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Values"))
            .followedBy(properties.where((i) => i.type.name == "Map").map((i) => "bool Function(${(i.type as NamedTypeAnnotation).typeArguments.last.fullName})? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}ValuesWhere"))

            .join(",\n      ")}
    }) => ${clazz.identifier.name}(
        ${properties.map((i) {
          String s = "${i.identifier.name.substring(1)} ?? this.${i.identifier.name.substring(1)}";

          if(i.type.name == "List"){
            s = "Model.modList<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>($s, add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Where)";
          } else if(i.type.name == "Set") {
            s = "Model.modSet<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>($s, add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Where)";
          } else if(i.type.name == "Map") {
            s = "Model.modMap<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}, ${(i.type as NamedTypeAnnotation).typeArguments.last.fullName}>($s, add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Keys, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}KeysWhere, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Values, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}ValuesWhere)";
          }

          return "${i.identifier.name.substring(1)}: $s";
        })
            .join(",\n        ")}
    );
    """)); 
      }
  }

  Future<void> buildHashCode(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    builder.declareInType(DeclarationCode.fromString("""
    /// Creates the deep hash code of the ${clazz.identifier.name} object.
    @override
    int get hashCode => Model.deepHash(toMap());
    """));
  }

  Future<void> buildEquals(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    builder.declareInType(DeclarationCode.fromString("""
    /// Checks deep equality of two [${clazz.identifier.name}] objects.
    @override
    bool operator ==(Object o) {
      if (identical(this, o)) return true;
      if (o is! ${clazz.identifier.name}) return false;
      return Model.deepEq(toMap(), o.toMap());
    }
    """));
  }

  Future<void> buildToString(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    builder.declareInType(DeclarationCode.fromString("""
    /// Converts the [${clazz.identifier.name}] object to a map string.
    @override
    String toString() => "${clazz.identifier.name}(\${toMap()})";
    """));
  }

  Future<void> buildMirror(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    List<FieldDeclaration> properties = await validFields(clazz, builder);
    List<MethodDeclaration> methods = await validMethods(clazz, builder);

    builder.declareInType(DeclarationCode.fromString("""
    /// Offers field reflection for the [${clazz.identifier.name}] object.
    /// * Offers basic Type information
    /// * You can get & set (via mutation) fields using the [ModelField] object.
    /// * You can obtain annotations from the [ModelField] object.
    static final ModelMirror<${clazz.identifier.name}> mirror = ModelMirror(List.unmodifiable([
      ${properties.map((i) => "ModelField<${clazz.identifier.name}, ${i.type.fullName}>(\"${i.identifier.name.substring(1)}\", ${i.type.fullName}, (o) => o.${i.identifier.name.substring(1)}, (o, v) => o.mutate(${i.identifier.name.substring(1)}: v), const [${i.metadata.whereType<ConstructorMetadataAnnotation>().map((m) => reconstructAnnotation(m)).join(",")}])").join(",\n      ")}
    ]), List.unmodifiable([
      ${methods.map((i) => "ModelMethod<${clazz.identifier.name}>(\"${i.identifier.name}\", const [${i.metadata.whereType<ConstructorMetadataAnnotation>().map((m) => reconstructAnnotation(m)).join(",")}], (o, p) => o.${buildMethodCall(i)})").join(",\n      ")}
    ]));
    """));
  }
  
  String buildMethodCall(MethodDeclaration m){
    return "${m.identifier.name}(${m.positionalParameters.mapIndexed((i, d) => "p[$i]").join(", ")})";
  }
  
  String reconstructAnnotation(ConstructorMetadataAnnotation a){
    List<String> s = [];
    
    for(ExpressionCode i in a.positionalArguments){
      s.add(i.parts.join(""));
    }
    
    for(MapEntry<String, ExpressionCode> i in a.namedArguments.entries){
     s.add("${i.key}: ${i.value.parts.join("")}");
    }
    
    return "${a.type.name}${a.constructor.name == "" ? "" : ".${a.constructor.name}"}(${s.join(", ")})";
  }
  
  bool _isCleanType(String id) => id == "String" || id == "int" || id == "double" || id == "bool";

  String _equals(FieldDeclaration field, MemberDeclarationBuilder builder, [NamedTypeAnnotation? nta, String? ref]){
    NamedTypeAnnotation type = nta??field.type as NamedTypeAnnotation;
    String id = type.identifier.name;
    String name = ref??field.identifier.name.substring(1);

    if(_isCleanType(id)){
      return "$name == o.$name";
    }

    if(id == "List" || id == "Set"){
      Function deepEq = const DeepCollectionEquality().equals;
      
      if(_isCleanType(type.typeArguments.first.name)){
        return "[...$name]";
      }

      return "[...$name.map((i) => ${_toMap(field, builder, type.typeArguments.first as NamedTypeAnnotation, "i")})]";
    }

    if(id == "Map"){
      NamedTypeAnnotation kt = type.typeArguments.first as NamedTypeAnnotation;
      NamedTypeAnnotation vt = type.typeArguments.last as NamedTypeAnnotation;

      if(!_isCleanType(kt.identifier.name)){
        builder.report(Diagnostic(DiagnosticMessage("Map Keys can only be String, int, double or bool", target: field.asDiagnosticTarget), Severity.error));
        return '"E R R O R"';
      }

      if(_isCleanType(vt.identifier.name)){
        if(kt.identifier.name == "String") {
          return "<String, dynamic>{...$name}";
        }

        return "<String, dynamic>{...$name.map((k, v) => MapEntry(\"\$k\", v))}";
      }

      if(kt.identifier.name == "String"){
        return "<String, dynamic>{...$name.map((k, v) => MapEntry(k, ${_toMap(field, builder, vt, "v")}))}";
      }

      return "<String, dynamic>{...$name.map((k, v) => MapEntry(\"\$k\", ${_toMap(field, builder, vt, "v")}))}";
    }

    return "$name.toMap()";
  }
  
  String _toMap(FieldDeclaration field, MemberDeclarationBuilder builder, [NamedTypeAnnotation? nta, String? ref]){
    NamedTypeAnnotation type = nta??field.type as NamedTypeAnnotation;
    String id = type.identifier.name;
    String name = ref??field.identifier.name.substring(1);

    if(_isCleanType(id)){
      return name;
    }

    if(id == "List" || id == "Set"){
      if(_isCleanType(type.typeArguments.first.name)){
        return "[...$name]"; 
      }

      return "[...$name.map((i) => ${_toMap(field, builder, type.typeArguments.first as NamedTypeAnnotation, "i")})]";
    }

    if(id == "Map"){
      NamedTypeAnnotation kt = type.typeArguments.first as NamedTypeAnnotation;
      NamedTypeAnnotation vt = type.typeArguments.last as NamedTypeAnnotation;

      if(!_isCleanType(kt.identifier.name)){
        builder.report(Diagnostic(DiagnosticMessage("Map Keys can only be String, int, double or bool", target: field.asDiagnosticTarget), Severity.error));
        return '"E R R O R"';
      }

      if(_isCleanType(vt.identifier.name)){
        if(kt.identifier.name == "String") {
          return "<String, dynamic>{...$name}";
        }

        return "<String, dynamic>{...$name.map((k, v) => MapEntry(\"\$k\", v))}";
      }

      if(kt.identifier.name == "String"){
        return "<String, dynamic>{...$name.map((k, v) => MapEntry(k, ${_toMap(field, builder, vt, "v")}))}";
      }

      return "<String, dynamic>{...$name.map((k, v) => MapEntry(\"\$k\", ${_toMap(field, builder, vt, "v")}))}";
    }

    return "$name.toMap()";
  }


  String _fromMap(FieldDeclaration field, MemberDeclarationBuilder builder, [NamedTypeAnnotation? nta, String? ref]){
    NamedTypeAnnotation type = nta??field.type as NamedTypeAnnotation;
    String id = type.identifier.name;
    String name = ref??'map["${field.identifier.name.substring(1)}"]';

    if(_isCleanType(id)){
      if(id == "String"){
        if(name.contains(".") || name.contains("\"") || name.contains("[")){


          return '"\${$name}\"';
        }
        
        return '"\$$name"';
      }
      
      return '$name as ${type.name}';
    }

    if(id == "List"){
      if(_isCleanType(type.typeArguments.first.name)){
        return '[...($name as List).whereType<${type.typeArguments.first.name}>()]';
      }

      return '[...($name as List).map((i) => ${_fromMap(field, builder, type.typeArguments.first as NamedTypeAnnotation, "i")})]';
    }

    if(id == "Set"){
      if(_isCleanType(type.typeArguments.first.name)){
        return '{...($name as List).whereType<${type.typeArguments.first.name}>()}';
      }

      return '{...($name as List).map((i) => ${_fromMap(field, builder, type.typeArguments.first as NamedTypeAnnotation, "i")})}';
    }
    
    if(id == "Map"){
      NamedTypeAnnotation kt = type.typeArguments.first as NamedTypeAnnotation;
      NamedTypeAnnotation vt = type.typeArguments.last as NamedTypeAnnotation;

      String kp = switch(kt.identifier.name){
        "String" => '"\$k"',
        "int" => 'int.parse(k)',
        "double" => 'double.parse(k)',
        "bool" => '"\$k" == "true',
        _ => 'E R R O R',
      };
      String vp = "wyt";
      
      if(_isCleanType(vt.identifier.name)){
        vp = 'k as ${vt.name}';
      } else {
        vp = _fromMap(field, builder, vt, "k");
      }
      
      if(_isCleanType(kt.identifier.name) && _isCleanType(vt.identifier.name)){
        return switch(kt.identifier.name){
          "String" => '<String, ${vt.identifier.name}>{...($name as Map).map((k, v) => MapEntry("\$k", ${_fromMap(field, builder, vt, "v")}))}',
          "int" => '<int, ${vt.identifier.name}>{...($name as Map).map((k, v) => MapEntry(int.tryParse(k)??0, ${_fromMap(field, builder, vt, "v")}))}',
          "double" => '<double, ${vt.identifier.name}>{...($name as Map).map((k, v) => MapEntry(double.tryParse(k)??0.0, ${_fromMap(field, builder, vt, "v")}))}',
          "bool" => '<bool, ${vt.identifier.name}>{...($name as Map).map((k, v) => MapEntry("\$k" == "true", ${_fromMap(field, builder, vt, "v")}))}',
           _ => 'E R R O R',
        };
      }
      
      return '<${kt.name}, ${vt.name}>{...($name as Map).map((k, v) => MapEntry($kp, $vp))}';
    } 
    
    return '${type.name}.fromMap($name)';
  }
}
  

class Field {
  final bool ignore;
  final String? name;
  
   const Field(
    {this.ignore = false, this.name}
       );   
}

extension XTypeAnnotation on TypeAnnotation{
  String get name => (this as NamedTypeAnnotation).identifier.name;
  
  String get fullName => (this as NamedTypeAnnotation).typeArguments.isEmpty ? name : "$name<${(this as NamedTypeAnnotation).typeArguments.map((i) => i.fullName).join(", ")}>";
}