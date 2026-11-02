import 'operation_failure.dart';

abstract interface class CommandStore {
  Future<T> transaction<T>(
    Future<T> Function(CommandTransaction transaction) action,
  );
}

abstract interface class CommandTransaction {
  Future<Json?> get(String path);
  void create(String path, Json value);
  void set(String path, Json value);
  void update(String path, Json value);
  void delete(String path);
}
