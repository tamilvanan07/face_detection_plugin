import 'package:objectbox/objectbox.dart';
import 'face_embedding.dart';

@Entity()
class Person {
  @Id()
  int id;

  @Index()
  String name;

  int age;

  int createdAt;

  /// All captured angle embeddings for this person.
  @Backlink('person')
  final embeddings = ToMany<FaceEmbedding>();

  Person({
    this.id = 0,
    required this.name,
    required this.age,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;
}
