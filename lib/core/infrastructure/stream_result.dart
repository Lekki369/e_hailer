import 'package:fpdart/fpdart.dart';
import '../domain/failures/app_failure.dart';

Stream<Either<AppFailure, T>> streamResult<T>(Stream<T> source) async* {
  try {
    await for (final value in source) {
      yield right(value);
    }
  } catch (_) {
    yield left(
      const ServerFailure(
        message: 'Could not load updates. Check your connection and retry.',
      ),
    );
  }
}
