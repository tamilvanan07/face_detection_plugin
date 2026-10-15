import 'dart:math';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'face_embedding.dart';
import 'person.dart';
import '../objectbox.g.dart';

class FaceRecognitionResult {
  final double similarityScore;
  final Person record;

  FaceRecognitionResult({
    required this.similarityScore,
    required this.record,
  });
}

class ObjectBoxVectorStore {
  late final Store store;
  late final Box<Person> personBox;
  late final Box<FaceEmbedding> embeddingBox;

  ObjectBoxVectorStore._create(this.store) {
    personBox = store.box<Person>();
    embeddingBox = store.box<FaceEmbedding>();
  }

  static Future<ObjectBoxVectorStore> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    // v2 — renamed from 'objectbox_example_face_db' to force a clean store
    // after the schema change from FaceRecord to Person + FaceEmbedding.
    final storeDir = p.join(docsDir.path, 'objectbox_face_db_v2');
    final store = await openStore(directory: storeDir);
    return ObjectBoxVectorStore._create(store);
  }

  /// Register a person with one or more face embeddings (one per captured angle).
  ///
  /// Each embedding is stored as a separate [FaceEmbedding] row linked to the
  /// [Person] — this lets the HNSW index search across all angles independently.
  int addPerson({
    required String name,
    required int age,
    required List<List<double>> embeddings,
  }) {
    assert(embeddings.isNotEmpty, 'At least one embedding is required');

    final person = Person(name: name, age: age);
    final personId = personBox.put(person);

    final rows = embeddings
        .map((vec) => FaceEmbedding(embedding: vec)..person.targetId = personId)
        .toList();
    embeddingBox.putMany(rows);

    return personId;
  }

  /// Find the closest registered person to [queryEmbedding] by checking every
  /// stored embedding row and taking the best cosine similarity across all
  /// angles of all persons.
  FaceRecognitionResult? findNearestFace(
    List<double> queryEmbedding, {
    double threshold = 0.75,
  }) {
    final allEmbeddings = embeddingBox.getAll();
    if (allEmbeddings.isEmpty) return null;

    FaceEmbedding? bestRow;
    double highestSimilarity = -1.0;

    for (final row in allEmbeddings) {
      if (row.embedding.length != queryEmbedding.length) continue;
      final sim = cosineSimilarity(queryEmbedding, row.embedding);
      if (sim > highestSimilarity) {
        highestSimilarity = sim;
        bestRow = row;
      }
    }

    if (bestRow == null || highestSimilarity < threshold) return null;

    // Load the linked Person (attach store so the ToOne lazy-loads).
    bestRow.person.attach(store);
    final person = bestRow.person.target;
    if (person == null) return null;

    return FaceRecognitionResult(
      similarityScore: highestSimilarity,
      record: person,
    );
  }

  /// Cosine similarity between two equal-length vectors.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// All registered persons (for the home screen list).
  List<Person> getAllPersons() => personBox.getAll();

  /// Number of stored embeddings for a person (shows how many angles captured).
  int embeddingCountForPerson(int personId) {
    return embeddingBox
        .query(FaceEmbedding_.person.equals(personId))
        .build()
        .count();
  }

  /// Delete a person and all their embeddings.
  void removePerson(int personId) {
    embeddingBox
        .query(FaceEmbedding_.person.equals(personId))
        .build()
        .remove();
    personBox.remove(personId);
  }

  /// Wipe everything.
  void clearAll() {
    embeddingBox.removeAll();
    personBox.removeAll();
  }

  void close() => store.close();
}
