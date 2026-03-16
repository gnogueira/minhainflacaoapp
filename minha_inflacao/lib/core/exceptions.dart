class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class ApiException extends AppException {
  final int statusCode;
  const ApiException(super.message, {required this.statusCode});
}

class RateLimitException extends AppException {
  const RateLimitException()
      : super('Você atingiu o limite de 50 notas este mês.');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException() : super('Sessão expirada. Faça login novamente.');
}
