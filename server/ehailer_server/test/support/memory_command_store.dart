import 'dart:async';
import 'dart:convert';
import 'package:ehailer_server/src/core/domain/command_store.dart';
import 'package:ehailer_server/src/core/domain/operation_failure.dart';

/// Rollback-capable transaction double; enforces Firestore's read-before-write rule.
class MemoryCommandStore implements CommandStore {
  Map<String, Json> documents = {};
  Future<void> _tail = Future.value();
  @override
  Future<T> transaction<T>(
    Future<T> Function(CommandTransaction) action,
  ) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      final copy = {
        for (final e in documents.entries)
          e.key: Json.from(jsonDecode(jsonEncode(e.value)) as Map),
      };
      final result = await action(_Transaction(copy));
      documents = copy;
      return result;
    } finally {
      done.complete();
    }
  }
}

class _Transaction implements CommandTransaction {
  final Map<String, Json> documents;
  bool written = false;
  _Transaction(this.documents);
  @override
  Future<Json?> get(String path) async {
    if (written) throw StateError('Read after write: $path');
    return documents[path] == null
        ? null
        : Json.from(jsonDecode(jsonEncode(documents[path])) as Map);
  }

  @override
  void create(String path, Json value) {
    if (documents.containsKey(path)) throw StateError('Already exists: $path');
    set(path, value);
  }

  @override
  void set(String path, Json value) {
    written = true;
    documents[path] = Json.from(value);
  }

  @override
  void update(String path, Json value) {
    if (!documents.containsKey(path)) throw StateError('Missing: $path');
    set(path, {...documents[path]!, ...value});
  }

  @override
  void delete(String path) {
    written = true;
    documents.remove(path);
  }
}
