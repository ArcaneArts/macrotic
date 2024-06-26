import 'package:macrotic/macros/model.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

@Model()
class InnerTestModel {
  static const String $aString = "";
  static const int $anInt = 0;
  static const double $aDouble = 0.0;
  static const bool $aBool = false;
}

@Model()
class TestModel {
  static const String $aString = "";
  static const int $anInt = 0;
  static const double $aDouble = 0.0;
  static const bool $aBool = false;
  static const List<String> $aStringList = const [];
  static const List<int> $anIntList = const [];
  static const List<double> $aDoubleList = const [];
  static const List<bool> $aBoolList = const [];
  static const Set<String> $aStringSet = const {};
  static const Set<int> $anIntSet = const {};
  static const Set<double> $aDoubleSet = const {};
  static const Set<bool> $aBoolSet = const {};
  static const Map<String, String> $aStringMap = const {};
  static const Map<String, int> $aIntMap = const {};
  static const Map<String, double> $aDoubleMap = const {};
  static const Map<String, bool> $aBoolMap = const {};
  static const Map<int, String> $anIntStringMap = const {};
  static const Map<double, String> $anIntIntMap = const {};
  static const Map<bool, String> $anIntDoubleMap = const {};
  static const Map<String, List<String>> $aStringListMap = const {};
  static const Map<String, List<int>> $anIntListMap = const {};
  static const Map<String, List<double>> $aDoubleListMap = const {};
  static const Map<String, List<bool>> $aBoolListMap = const {};
  static const Map<String, Set<String>> $aStringSetMap = const {};
  static const Map<String, Set<int>> $anIntSetMap = const {};
  static const Map<String, Set<double>> $aDoubleSetMap = const {};
  static const Map<String, Set<bool>> $aBoolSetMap = const {};
  static const InnerTestModel $anInnerTestModel = const InnerTestModel();
  static const List<InnerTestModel> $anInnerTestModelList = const [];
  static const Set<InnerTestModel> $anInnerTestModelSet = const {};
  static const Map<String, InnerTestModel> $anInnerTestModelMap = const {};
  static const Map<double, List<InnerTestModel>> $anInnerTestModelListMap =
      const {};
}

void main() {
  test("Basic Retention Default Constructor", () {
    TestModel m = TestModel();
    expect(m.toJson(), TestModel.fromJson(m.toJson()));
  });
}
