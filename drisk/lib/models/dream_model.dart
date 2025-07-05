import 'package:hive/hive.dart';

part 'dream_model.g.dart';

@HiveType(typeId: 0)
class Dream extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  DreamMood mood;

  @HiveField(5)
  DreamType type;

  @HiveField(6)
  double thrillLevel;

  @HiveField(7)
  double clarity;

  @HiveField(8)
  List<String> tags;

  @HiveField(9)
  bool? isFavorite;

  @HiveField(10)
  String? recurringDreamGroupId;

  // REMOVED voiceMemoPath and sketchPath fields

  Dream({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.mood,
    required this.type,
    required this.thrillLevel,
    required this.clarity,
    required this.tags,
    this.isFavorite,
    this.recurringDreamGroupId,
    // REMOVED voiceMemoPath and sketchPath from constructor
  });
}

@HiveType(typeId: 1)
enum DreamMood {
  @HiveField(0)
  nightmare,
  @HiveField(1)
  bad,
  @HiveField(2)
  neutral,
  @HiveField(3)
  good,
  @HiveField(4)
  excellent,
}

@HiveType(typeId: 2)
enum DreamType {
  @HiveField(0)
  normal,
  @HiveField(1)
  lucid,
  @HiveField(2)
  daydream,
  @HiveField(3)
  falseAwakening,
  @HiveField(4)
  recurring,
}
