import 'package:objectbox/objectbox.dart';
import 'person.dart';

@Entity()
class FaceEmbedding {
  @Id()
  int id;

  /// 512-dimensional face embedding — one row per captured angle.
  @HnswIndex(dimensions: 512)
  @Property(type: PropertyType.floatVector)
  List<double> embedding;

  /// Which person this embedding belongs to.
  final person = ToOne<Person>();

  FaceEmbedding({
    this.id = 0,
    required this.embedding,
  });
}
