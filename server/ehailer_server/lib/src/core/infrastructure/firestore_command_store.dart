import 'package:google_cloud_firestore/google_cloud_firestore.dart' as firebase;
import '../domain/command_store.dart';
import '../domain/operation_failure.dart';

class FirestoreCommandStore implements CommandStore {
  final firebase.Firestore firestore;
  FirestoreCommandStore(this.firestore);
  @override
  Future<T> transaction<T>(
    Future<T> Function(CommandTransaction transaction) action,
  ) => firestore.runTransaction(
    (transaction) => action(_FirestoreTransaction(firestore, transaction)),
  );
}

class _FirestoreTransaction implements CommandTransaction {
  final firebase.Firestore firestore;
  final firebase.Transaction transaction;
  _FirestoreTransaction(this.firestore, this.transaction);
  @override
  Future<Json?> get(String path) async =>
      (await transaction.get(firestore.doc(path))).data();
  @override
  void create(String path, Json value) =>
      transaction.create(firestore.doc(path), value);
  @override
  void set(String path, Json value) =>
      transaction.set(firestore.doc(path), value);
  @override
  void update(String path, Json value) =>
      transaction.update(firestore.doc(path), value);
  @override
  void delete(String path) => transaction.delete(firestore.doc(path));
}
