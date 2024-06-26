# Models
Macrotic has the most powerful models in macros.
* **Immutable** - All fields are final
* **Deep Equals & Hashcode** - All models have deep equals & hashcode
* **To/From Map** - All models can be converted to/from json compat maps (Map<String, dynamic>)
* **To/From Json** - All models can be converted to/from json strings
* **Mutations** - All models can be mutated with a new model with the changes you want (copyWith)
* **Iterable Mutations** - add/remove on lists instead of annoying copyWith calls for deep modifications
* **Nested Models** - Models can be nested within each other
* **Model Mirrors** - Reflective get/set all fields, methods, annotations & invoke methods
* **Minimal Boilerplate** - Just @Model() and define the field type, name & default value.

## Writing Models

Macrotic models use a few somewhat strict rules on fields & types however because of this strictness we can ensure immutability & speed.
1. All fields must have a default value
2. All fields must actually have a direct type (no dynamic, or Object or super types)
3. All fields must either be a int, double, String, bool or another Model. You can mix and match (or even nest) Lists, Sets & Maps with the following key types.
4. Map keys specifically must be ints, doubles, Strings, or bools. They cannot be another List, Map, Set or Model.
5. Recursive models are not allowed.
6. Fields cannot be null

```dart
import 'package:macrotic/macrotic.dart';

@Model()
class Person {
  // Don't worry! This is just a requirement to designate a serializable field & specify defaults
  static const String $name = "";
  static const int $age = 25;
}
```

### Fields
Then you can use it like a regular immutable model! All fields are final
```dart
Person person = Person(
    name: "John",
); // age would be 25

person.name; // John
person.age; // 25
```

### To/From Json
```dart
person.toMap(); // returns Map<String, dynamic>{"john": "John", "age": 25}
person.toJson(); // returns "{"john": "John", "age": 25}"

Person.fromMap({"age": 2}); // returns Person(name: "", age: 2)
Person.fromJson('{"name": "Joe"}') // returns Person(name: "Joe", age: 25)
```

### Mutations
Since all fields are final, you can't change them directly. You can however create a new model with the changes you want. This is the same as copyWith but with extra features.
```dart
Person mutated = person.mutate(
  name: "NewName"
);

// mutated.name == "NewName"
// mutated.age == (whatever it was before)
```

### Lists, Maps & Sets

Sets are actual sets but to/from json/map just converts them to lists and back. This is because json doesn't support sets.

```dart
import 'package:macrotic/macrotic.dart';

@Model()
class Person {
  static const String $name = "";
  static const int $age = 25;
  static const Set<String> $nicknames = {};
}
```

Mutations also have benefits for lists specifically

```dart
Person person = Person(
    name: "John",
    nicknames: {"Johnny"}
);

// Instead of doing this to append
Person mutated = person.mutate(
  nicknames: {...person.nicknames, "JohnBoy"}
);

// Just use the provided addNicknames. They do the same thing
mutated = mutated.mutate(
    addNicknames: {"JohnBoy"}
);

// You can also remove them
mutated = mutated.mutate(
  // Explicitly remove each item in list
  removeNicknames: {"Johnny"}

  // Or use a where clause to remove multiple via predicate
  removeNicknamesWhere: (nickname) => nickname.trim().isEmpty
);
```

### Nested Models
```dart
import 'package:macrotic/macrotic.dart';

@Model()
class Address {
  static const String $street = "";
  static const String $city = "";
}

@Model()
class Person {
  static const String $name = "";
  static const int $age = 25;
  
  // Since all model classes use const constructors you can easily provide defaults here
  static const Address $address = Address();
}
```

### Model Mirrors
You can use generated "reflection" to do the following things
* Get all field names and their types
* Get / Set (mutate) fields by name
* Get all annotations on each field by name
* Get all methods
* Invoke methods by name
* Get all method annotations by name

#### Example: Get a field
```dart
import 'package:macrotic/macrotic.dart';

@Model()
class Person {
  static const String $name = "";
  static const int $age = 25;
}

void doMirrors(){
  Person person = Person(
    name: "John",
  );
  
  // Use reflection to get the age
  int age = Person.mirror.field("age").get(person);
  
  // Use reflection to set the age
  Person modified = Person.mirror.field("age").set(person, age + 1);
}
```

#### Example: Increment all ints
```dart
import 'package:macrotic/macrotic.dart';

@Model()
class Person {
  static const String $name = "";
  static const int $age = 25;
}

void doMirrors(){
  Person person = Person(
    name: "John",
  );
  
  // Use reflection to increment all ints by 1
  for(MirrorField<Person, int> i in Person.mirror.fields.whereType<MirrorField<Person, int>>()){
    // Calling set returns a modified copy of the model
    person = i.set(person, i.get(person) + 1);
  }
}
```

#### Example: Get annotation properties to auto increment
```dart
import 'package:macrotic/macrotic.dart';

class AutoIncrement {
  final int amount;
  
  const AutoIncrement(this.amount);
}

@Model()
class Person {
  @AutoIncrement(4)
  static const String $name = "";
  static const int $age = 25;
}

void doMirrors(){
  Person person = Person(
    name: "John",
  );
  
  // Use reflection to increment all ints by 1
  for(MirrorField<Person, int> i in Person.mirror.fields.whereType<MirrorField<Person, int>>()
    // Filter for the annotation
    .where((i) => i.annotations.any((i) => i is AutoIncrement))){
    
    // Get the annotation and increment amount
    int amount = i.annotation<AutoIncrement>().amount;
    
    // Increment!
    person = i.set(person, i.get(person) + annotation.amount);
  }
}
```

#### Example: Invoke Method
```dart
import 'package:macrotic/macrotic.dart';

class OnBirthday{
  const OnBirthday();
}

@Model()
class Person {
  static const String $name = "";
  static const int $age = 25;
  
  @OnBirthday()
  void itsMyBirthday(){
    print("HAPPY BIRTHDAY");
  }
}

void doMirrors(){
  Person person = Person();
  
  // Use reflection to increment all ints by 1
  for(MirrorMethod<Person> i in Person.mirror.methods  
  // Filter for the annotation
      .where((i) => i.annotations.any((i) => i is OnBirthday))) {
    i(person);
    
    // Method calls only support required POSITIONAL args like so
    i(person, [1, "two", 3.5]); // This will throw an error because the method doesn't have any args
  }
}
```

## What is Generated?

```dart
import 'package:macrotic/macrotic.dart';

@Model()
class Person {
  static const String $name = "";
  static const int $age = 0;
  static const double $height = 0.0;
  static const bool $isMarried = false;
  static const List<String> $nicknames = const [];

  @SomeAnnotation("Some information here")
  static const Map<int, List<Set<String>>> $nonsense = const {};

  @SomeAnnotation("A Annotated Value")
  void aMethod(int value){
    // def
  }
}
```

Generates this
```dart
augment library 'package:macrotic/macrotic.dart';

import 'package:macrotic/macrotic.dart';

augment class Person {
    /// Defined from [$name]
    final String name;

    /// Defined from [$age]
    final int age;

    /// Defined from [$height]
    final double height;

    /// Defined from [$isMarried]
    final bool isMarried;

    /// Defined from [$nicknames]
    final List<String> nicknames;

    /// Defined from [$nonsense]
    final Map<int, List<Set<String>>> nonsense;

    /// The Constructor for [Person]. 
    /// Null values use the default value in the $prefixed static const fields.
    /// [name] String
    /// [age] int
    /// [height] double
    /// [isMarried] bool
    /// [nicknames] List<String>
    /// [nonsense] Map<int, List<Set<String>>>
    const Person({
        this.name = $name,
        this.age = $age,
        this.height = $height,
        this.isMarried = $isMarried,
        this.nicknames = $nicknames,
        this.nonsense = $nonsense
    });
    
    /// Creates a new [Person] object from a Map<String, dynamic>
    factory Person.fromMap(Map<String, dynamic> map) => Person(
        name: map["name"] != null ? "${map["name"]}" : $name,
        age: map["age"] != null ? map["age"] as int : $age,
        height: map["height"] != null ? map["height"] as double : $height,
        isMarried: map["isMarried"] != null ? map["isMarried"] as bool : $isMarried,
        nicknames: map["nicknames"] != null ? [...(map["nicknames"] as List).whereType<String>()] : $nicknames,
        nonsense: map["nonsense"] != null ? <int, List<Set<String>>>{...(map["nonsense"] as Map).map((k, v) => MapEntry(int.parse(k), [...(v as List).map((i) => {...(i as List).whereType<String>()})]))} : $nonsense
    );
    
    /// Converts a json string to a [Person] object.
    factory Person.fromJson(String json) => Person.fromMap(Model.jsonDecode(json));
    
    /// Converts [Person] object to a json string.
    String toJson({bool pretty = false}) => Model.jsonEncode(toMap(), pretty: pretty);
    
    /// Converts this object to a Map<String, dynamic>
    Map<String, dynamic> toMap() => {
      "name": name,
      "age": age,
      "height": height,
      "isMarried": isMarried,
      "nicknames": [...nicknames],
      "nonsense": <String, dynamic>{...nonsense.map((k, v) => MapEntry("$k", [...v.map((i) => [...i])]))}
    };
    
    /// Creates a new [Person] object with the provided fields as overrides
    /// Also provides mutator methods to add,remove,removeWhere on Lists, Sets & Maps
    /// ### [name]
    /// ### [age]
    /// ### [height]
    /// ### [isMarried]
    /// ### [nicknames]
    /// * add [addNicknames]
    /// * remove [removeNicknames]
    /// * removeWhere [removeNicknamesWhere]
    /// ### [nonsense]
    /// * add [addNonsense]
    /// * removeKeys [removeNonsenseKeys]
    /// * removeKeysWhere [removeNonsenseKeysWhere]
    /// * removeValues [removeNonsenseValues]
    /// * removeValuesWhere [removeNonsenseValuesWhere]
    Person mutate({
      String? name,
      int? age,
      double? height,
      bool? isMarried,
      List<String>? nicknames,
      Map<int, List<Set<String>>>? nonsense,
      Iterable<String>? addNicknames,
      Iterable<String>? removeNicknames,
      bool Function(String)? removeNicknamesWhere,
      Map<int, List<Set<String>>>? addNonsense,
      Iterable<int>? removeNonsenseKeys,
      bool Function(int)? removeNonsenseKeysWhere,
      Iterable<List<Set<String>>>? removeNonsenseValues,
      bool Function(List<Set<String>>)? removeNonsenseValuesWhere
    }) => Person(
        name: name ?? this.name,
        age: age ?? this.age,
        height: height ?? this.height,
        isMarried: isMarried ?? this.isMarried,
        nicknames: Model.modList<String>(nicknames ?? this.nicknames, addNicknames, removeNicknames, removeNicknamesWhere),
        nonsense: Model.modMap<int, List<Set<String>>>(nonsense ?? this.nonsense, addNonsense, removeNonsenseKeys, removeNonsenseKeysWhere, removeNonsenseValues, removeNonsenseValuesWhere)
    );
    
    /// Creates the deep hash code of the Person object.
    @override
    int get hashCode => Model.deepHash(toMap());
    
    /// Checks deep equality of two [Person] objects.
    @override
    bool operator ==(Object o) {
      if (identical(this, o)) return true;
      if (o is! Person) return false;
      return Model.deepEq(toMap(), o.toMap());
    }
    
    /// Converts the [Person] object to a map string.
    @override
    String toString() => "Person(${toMap()})";
    
    /// Offers field reflection for the [Person] object.
    /// * Offers basic Type information
    /// * You can get & set (via mutation) fields using the [MirrorField] object.
    /// * You can obtain annotations from the [MirrorField] object.
    static final ModelMirror<Person> mirror = ModelMirror(List.unmodifiable([
      MirrorField<Person, String>("name", String, (o) => o.name, (o, v) => o.mutate(name: v), const []),
      MirrorField<Person, int>("age", int, (o) => o.age, (o, v) => o.mutate(age: v), const []),
      MirrorField<Person, double>("height", double, (o) => o.height, (o, v) => o.mutate(height: v), const []),
      MirrorField<Person, bool>("isMarried", bool, (o) => o.isMarried, (o, v) => o.mutate(isMarried: v), const []),
      MirrorField<Person, List<String>>("nicknames", List<String>, (o) => o.nicknames, (o, v) => o.mutate(nicknames: v), const []),
      MirrorField<Person, Map<int, List<Set<String>>>>("nonsense", Map<int, List<Set<String>>>, (o) => o.nonsense, (o, v) => o.mutate(nonsense: v), const [SomeAnnotation("Some information here")])
    ]), List.unmodifiable([
      MirrorMethod<Person>("aMethod", const [SomeAnnotation("A Annotated Value")], (o, p) => o.aMethod(p[0]))
    ]));
}
```