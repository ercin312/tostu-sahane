/// Temel use-case sözleşmesi (Clean Architecture domain katmanı).
abstract class UseCase<T, Params> {
  const UseCase();

  Future<T> call(Params params);
}

class NoParams {
  const NoParams();
}
