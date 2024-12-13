import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';

// Base repository interface that all repositories should implement
// Uses Either type from dartz for functional error handling
abstract class BaseRepository<T> {
  // Core operations that most repositories will need
  Future<Either<Failure, T>> get(String id);
  Future<Either<Failure, List<T>>> getAll();
  Future<Either<Failure, T>> create(T entity);
  Future<Either<Failure, T>> update(T entity);
  Future<Either<Failure, bool>> delete(String id);
}
