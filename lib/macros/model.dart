import 'dart:async';
import 'dart:convert' as c;

import 'package:collection/collection.dart';
import 'package:macros/macros.dart';

class _Context {
  List<FieldDeclaration> properties;
  ClassDeclaration? superClazz;
  List<FieldDeclaration>? superProperties;
  List<MethodDeclaration> methods;
  List<ClassDeclaration> superTree;
  List<ClassDeclaration> subclasses;
  
  _Context(this.properties, this.superClazz, this.superProperties, this.methods, this.superTree, this.subclasses);
  
  String fieldSelfRef(FieldDeclaration dec) {
    return selfReference(superTree.where((i) => i.identifier == dec.definingType).first);
  }
  
  String selfReference(ClassDeclaration dec) {
    int v = superTree.indexOf(dec);
    
    if(v == -1){
      return "idk";
    }
    
    if(v == 0){
      return "this";
    }
    
    else {
      return List.generate(v, (i) => "super").join(".");
    }
  }
}

macro class Model implements ClassDeclarationsMacro {
  final bool withFields ;
  final bool withConstructor ;
  final bool withFromMap ;
  final bool withFromJson ;
  final bool withToJson ;
  final bool withToMap ;
  final bool withMutate;
  final bool withHashCode;
  final bool withEquals ;
  final bool withToString;
  final bool withMirror;
  final bool documentation;

  const Model({
    this.documentation = true,
    this.withFields = true,
    this.withConstructor = true,
    this.withFromMap = true,
    this.withFromJson = true,
    this.withToJson = true,
    this.withToMap = true,
    this.withMutate = true,
    this.withHashCode = true,
    this.withEquals = true,
    this.withToString = true,
    this.withMirror = true
  });

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    builder.declareInLibrary(DeclarationCode.fromString(
        "import 'package:macrotic/macrotic.dart';\n"));
    List<FieldDeclaration> properties = await _validFields(clazz, builder);
    List<MethodDeclaration> methods = await _validMethods(clazz, builder);
    ClassDeclaration? superClazz = await clazz.getSuperclassDeclaration(builder);
    List<ClassDeclaration> tree = await _calculateSuperTree(clazz, builder);
    List<FieldDeclaration>? superProperties = [];
    List<ClassDeclaration> subclasses = [];
    
    for(ClassDeclaration i in tree.sublist(1)){
      superProperties.addAll(await _validFields(i, builder));
    }
    
    // TODO: This is currently unimplemented by dart at runtime?
    for(TypeDeclaration i in await builder.typesOf(clazz.library)){
      if(i is ClassDeclaration && i.superclass?.identifier == clazz.identifier){
        subclasses.add(i);
      }
    }

    _Context context = _Context(properties, superClazz, superProperties, methods, tree, subclasses);

  
    if(subclasses.isNotEmpty){
      builder.declareInType(DeclarationCode.fromString(asCode("""
      static final Map<String, ${clazz.identifier.name} Function(Map<String, dynamic>)> _subConstructors = { 
        ${subclasses.map((i) => "\"${i.identifier.name}\": (m) => ${i.identifier.name}.fromMap(m)").join(",\n          ")}  
      }; 
      """)));
    }
    
    if(withFields) await buildFields(clazz, builder, context);
    if(withConstructor) await buildConstructor(clazz, builder, context);
    if(withFromMap) await buildFromMap(clazz, builder, context);
    if(withFromJson) await buildFromJson(clazz, builder, context);
    if(withToJson) await buildToJson(clazz, builder, context);
    if(withToMap) await buildToMap(clazz, builder, context);
    if(withMutate) await buildMutate(clazz, builder, context);
    if(withHashCode) await buildHashCode(clazz, builder, context);
    if(withEquals) await buildEquals(clazz, builder, context);
    if(withToString) await buildToString(clazz, builder, context);
    if(withMirror) await buildMirror(clazz, builder, context);
    

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

  String asCode(String c) {
    List<String> s = [];
    for(String i in c.split("\n")){
      if(!documentation && i.trim().startsWith("///")){
        continue;
      }

      s.add(i);
    }

    return s.join("\n");
  }
  
  Future<List<ClassDeclaration>> _calculateSuperTree(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    List<ClassDeclaration> tree = [];
    ClassDeclaration? current = clazz;

    while(current != null){
      tree.add(current);
      current = await current.getSuperclassDeclaration(builder);
    }

    return tree;    
  }

  Future<List<FieldDeclaration>> _validFields(ClassDeclaration clazz, MemberDeclarationBuilder builder) async => (await builder.fieldsOf(clazz)).where((i) => i.hasStatic && i.hasConst && i.identifier.name.startsWith("\$")).toList();
  
  Future<List<MethodDeclaration>> _validMethods(ClassDeclaration clazz, MemberDeclarationBuilder builder) async => (await builder.methodsOf(clazz)).where((i) => !i.hasStatic).toList();
  
  Future<void> buildFields(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    List<FieldDeclaration> properties = context.properties;

    if(!properties.isEmpty){
      builder.declareInType(DeclarationCode.fromString(asCode("""
    ${properties.map((i) => "/// Defined from [${i.identifier.name}]\n    ${i.hasLate ? "late " : ""}final ${i.type.fullName} ${i.identifier.name.substring(1)};\n").join("\n    ")}""")));
    }
  }

  Future<void> buildConstructor(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    List<FieldDeclaration> properties = context.properties;

    if(properties.isEmpty){
      builder.declareInType(DeclarationCode.fromString(asCode("""
    /// The Constructor for [${clazz.identifier.name}]. You should probably define some fields.
    const ${clazz.identifier.name}();
      """)));
    } else{
      builder.declareInType(DeclarationCode.fromString(asCode("""
    /// The Constructor for [${clazz.identifier.name}]. 
    /// Null values use the default value in the \$prefixed static const fields.
    ${properties.map((i) => "/// [${i.identifier.name.substring(1)}] ${i.type.fullName}").join("\n    ")}
    const ${clazz.identifier.name}({
        ${properties.map((i) => "this.${i.identifier.name.substring(1)} = ${i.identifier.name}")
        .followedBy(context.superClazz == null ? [] : context.superProperties!.map((i) => "${i.type.fullName} ${i.identifier.name.substring(1)} = ${i.definingType.name}.${i.identifier.name}"))
        .join(",\n        ")}
    })${context.superClazz != null ? " : super(${context.superProperties!.map((i) => "${i.identifier.name.substring(1)}: ${i.identifier.name.substring(1)}").join(",\n        ")})" : ""};
    """)));
    }
  }

  Future<void> buildFromMap(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    List<FieldDeclaration> properties = context.properties;

    if(properties.isEmpty){
      builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Creates a new [${clazz.identifier.name}] object from a Map<String, dynamic>
    factory ${clazz.identifier.name}.fromMap(Map<String, dynamic> map) => ${clazz.identifier.name}();
      """)));
    } else{ 
      builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Creates a new [${clazz.identifier.name}] object from a Map<String, dynamic>
    factory ${clazz.identifier.name}.fromMap(Map<String, dynamic> map) => ${context.subclasses.isNotEmpty?"_subConstructors[map[\"_${clazz.identifier.name}Type\"] ?? \"?\"]?.call(map) ?? ":""}${clazz.identifier.name}(
        ${properties.map((i) => "${i.identifier.name.substring(1)}: map[\"${i.identifier.name.substring(1)}\"] != null ? ${_fromMap(i, builder)} : ${i.identifier.name}")
          .followedBy(context.superClazz != null ? 
            context.superProperties!.map((i) => "${i.identifier.name.substring(1)}: map[\"${i.identifier.name.substring(1)}\"] != null ? ${_fromMap(i, builder)} : ${i.definingType.name}.${i.identifier.name}")
       : [])
          .join(",\n        ")}
    );
    """)));
    }
  }

  Future<void> buildFromJson(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Converts a json string to a [${clazz.identifier.name}] object.
    factory ${clazz.identifier.name}.fromJson(String json) => ${clazz.identifier.name}.fromMap(Model.jsonDecode(json));
    """)));
  }

  Future<void> buildToJson(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Converts [${clazz.identifier.name}] object to a json string.
    String toJson({bool pretty = false}) => Model.jsonEncode(toMap(), pretty: pretty);
    """)));
  }

  Future<void> buildToMap(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    List<FieldDeclaration> properties = context.properties;
    ClassDeclaration? superClazz = context.superClazz;

    if (properties.isEmpty) {
      builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Converts this object to a Map<String, dynamic>
    Map<String, dynamic> toMap() => {};
    """)));
    } else {
      builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Converts this object to a Map<String, dynamic>
    Map<String, dynamic> toMap() => {
        ${properties.map((i) => "\"${i.identifier.name.substring(1)}\": ${_toMap(
          i, builder)}")
          .followedBy(superClazz == null ? [] : ["...super.toMap()", '"_${context.superClazz!.identifier.name}Type":"${clazz.identifier.name}"'])
          .join(",\n        ")}
    };
    """)));
    }
  }

  Future<void> buildMutate(ClassDeclaration clazz,
      MemberDeclarationBuilder builder, _Context context) async {
    List<FieldDeclaration> properties = context.properties;
    if(properties.isEmpty){
      builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Creates a new [${clazz.identifier.name}] object with the provided fields as overrides
    /// Also provides mutator methods to add,remove,removeWhere on Lists, Sets & Maps
    ${clazz.identifier.name} mutate() => ${clazz.identifier.name}();
    """)));

    }else{
      builder.declareInType(DeclarationCode.fromString(asCode("""
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
      .followedBy(context.superClazz == null ? <String>[] : <String>[
        ...context.superProperties!.map((i) => "${i.type.fullName}? ${i.identifier.name.substring(1)}"),
        ...context.superProperties!.where((i) => i.type.name == "List" || i.type.name == "Set").map((i) => "Iterable<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>? add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}"),
        ...context.superProperties!.where((i) => i.type.name == "List" || i.type.name == "Set").map((i) => "Iterable<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}"),
        ...context.superProperties!.where((i) => i.type.name == "List" || i.type.name == "Set").map((i) => "bool Function(${(i.type as NamedTypeAnnotation).typeArguments.first.fullName})? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Where"),
        ...context.superProperties!.where((i) => i.type.name == "Map").map((i) => "${i.type.fullName}? add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}"),
        ...context.superProperties!.where((i) => i.type.name == "Map").map((i) => "Iterable<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Keys"),
        ...context.superProperties!.where((i) => i.type.name == "Map").map((i) => "bool Function(${(i.type as NamedTypeAnnotation).typeArguments.first.fullName})? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}KeysWhere"),
        ...context.superProperties!.where((i) => i.type.name == "Map").map((i) => "Iterable<${(i.type as NamedTypeAnnotation).typeArguments.last.fullName}>? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Values"),
        ...context.superProperties!.where((i) => i.type.name == "Map").map((i) => "bool Function(${(i.type as NamedTypeAnnotation).typeArguments.last.fullName})? remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}ValuesWhere"),
])
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
      }).followedBy(context.superClazz == null ? [] : context.superProperties!.map((i) {
        String s = "${i.identifier.name.substring(1)} ?? this.${i.identifier.name.substring(1)}";

        if(i.type.name == "List"){
          s = "Model.modList<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>($s, add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Where)";
        } else if(i.type.name == "Set") {
          s = "Model.modSet<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}>($s, add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Where)";
        } else if(i.type.name == "Map") {
          s = "Model.modMap<${(i.type as NamedTypeAnnotation).typeArguments.first.fullName}, ${(i.type as NamedTypeAnnotation).typeArguments.last.fullName}>($s, add${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Keys, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}KeysWhere, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}Values, remove${i.identifier.name.substring(1,2).toUpperCase()}${i.identifier.name.substring(2)}ValuesWhere)";
        }

        return "${i.identifier.name.substring(1)}: $s";
      })) 
          .join(",\n        ")}
    );
    """)));
    }
  }

  Future<void> buildHashCode(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Creates the deep hash code of the ${clazz.identifier.name} object.
    @override
    int get hashCode => Model.deepHash(toMap());
    """)));
  }

  Future<void> buildEquals(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Checks deep equality of two [${clazz.identifier.name}] objects.
    @override
    bool operator ==(Object o) {
      if (identical(this, o)) return true;
      if (o is! ${clazz.identifier.name}) return false;
      return Model.deepEq(toMap(), o.toMap());
    }
    """)));
  }

  Future<void> buildToString(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Converts the [${clazz.identifier.name}] object to a map string.
    @override
    String toString() => "${clazz.identifier.name}(\${toMap()})";
    """)));
  }

  Future<void> buildMirror(ClassDeclaration clazz, MemberDeclarationBuilder builder, _Context context) async {
    List<FieldDeclaration> properties = context.properties;
    List<MethodDeclaration> methods = context.methods;

    builder.declareInType(DeclarationCode.fromString(asCode("""
    /// Offers field reflection for the [${clazz.identifier.name}] object.
    /// * Offers basic Type information
    /// * You can get & set (via mutation) fields using the [MirrorField] object.
    /// * You can obtain annotations from the [MirrorField] object.
    static final ModelMirror<${clazz.identifier.name}> mirror = ModelMirror(List.unmodifiable([
      ${properties.map((i) => "MirrorField<${clazz.identifier.name}, ${i.type.fullName}>(\"${i.identifier.name.substring(1)}\", ${i.type.fullName}, (o) => o.${i.identifier.name.substring(1)}, (o, v) => o.mutate(${i.identifier.name.substring(1)}: v), const [${i.metadata.whereType<ConstructorMetadataAnnotation>().map((m) => reconstructAnnotation(m)).join(",")}])").join(",\n      ")}
    ]), List.unmodifiable([
      ${methods.map((i) => "MirrorMethod<${clazz.identifier.name}>(\"${i.identifier.name}\", const [${i.metadata.whereType<ConstructorMetadataAnnotation>().map((m) => reconstructAnnotation(m)).join(",")}], (o, p) => o.${buildMethodCall(i)})").join(",\n      ")}
    ]));
    """)));
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
        vp = 'v as ${vt.name}';
      } else {
        vp = _fromMap(field, builder, vt, "v");
      }

      if(_isCleanType(kt.identifier.name) && _isCleanType(vt.identifier.name)){
        return switch(kt.identifier.name){
          "String" => '<String, ${vt.fullName}>{...($name as Map).map((k, v) => MapEntry("\$k", ${_fromMap(field, builder, vt, "v")}))}',
          "int" => '<int, ${vt.fullName}>{...($name as Map).map((k, v) => MapEntry(int.tryParse(k)??0, ${_fromMap(field, builder, vt, "v")}))}',
          "double" => '<double, ${vt.fullName}>{...($name as Map).map((k, v) => MapEntry(double.tryParse(k)??0.0, ${_fromMap(field, builder, vt, "v")}))}',
          "bool" => '<bool, ${vt.fullName}>{...($name as Map).map((k, v) => MapEntry("\$k" == "true", ${_fromMap(field, builder, vt, "v")}))}',
          _ => 'E R R O R',
        };
      }

      return '<${kt.name}, ${vt.fullName}>{...($name as Map).map((k, v) => MapEntry($kp, $vp))}';
    }

    return '${type.name}.fromMap($name)';
  }
}

class MirrorField<O, T>{
  final String name;
  final Type type;
  final T Function(O instance) get;
  final O Function(O instance, T value) set;
  final List<Object> annotations;

  const MirrorField(this.name, this.type, this.get, this.set, this.annotations);

  T annotation<T>() => annotations.whereType<T>().first;
}

class MirrorMethod<O> {
  final String name;
  final List<Object> annotations;
  final dynamic Function(O, List<dynamic>) caller;

  const MirrorMethod(this.name, this.annotations, this.caller);

  dynamic call(O instance, [List<dynamic> params = const []]) => caller(instance, params);

  T annotation<T>() => annotations.whereType<T>().first;
}

class ModelMirror<O>{
  final List<MirrorField<O, dynamic>> fields;
  final List<MirrorMethod<O>> methods;

  const ModelMirror(this.fields, this.methods);

  MirrorField field(String name) => fields.firstWhere((i) => i.name == name);

  MirrorMethod method(String name) => methods.firstWhere((i) => i.name == name);
}

extension XClassDeclaration on ClassDeclaration {
  Future<ClassDeclaration?> getSuperclassDeclaration(MemberDeclarationBuilder builder) async {
      if(superclass == null){
        return null;
      }
      
      return builder.typeDeclarationOf(superclass!.identifier).then((value) => value is ClassDeclaration ? value : null);
  }
}

extension XTypeAnnotation on TypeAnnotation{
  String get name => (this as NamedTypeAnnotation).identifier.name;

  String get fullName => (this as NamedTypeAnnotation).typeArguments.isEmpty ? name : "$name<${(this as NamedTypeAnnotation).typeArguments.map((i) => i.fullName).join(", ")}>";
}