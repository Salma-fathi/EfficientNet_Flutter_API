import '../error/failure.dart';

class Result<T> {
  final T? data;
  final Failure? failure;

  bool get isSuccess => failure == null;

  const Result._({this.data, this.failure});

  factory Result.success(T data) => Result._(data: data);

  factory Result.failure(Failure failure) => Result._(failure: failure);
}
