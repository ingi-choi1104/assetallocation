class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError});
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.originalError});
}

class ParseException extends AppException {
  const ParseException(super.message, {super.code, super.originalError});
}

class ApiKeyMissingException extends AppException {
  const ApiKeyMissingException(String apiName)
      : super('$apiName API 키가 설정되지 않았습니다');
}

class RateLimitException extends AppException {
  const RateLimitException(String service)
      : super('$service 요청 한도를 초과했습니다. 잠시 후 다시 시도하세요',
            code: '429');
}
