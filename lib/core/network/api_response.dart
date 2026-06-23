import 'api_exception.dart';

abstract final class ApiResponse {
  static T parseData<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> data) fromJson,
  ) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(messageKey: 'common_error', statusCode: 0);
    }
    return fromJson(data);
  }

  static List<T> parseList<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromJson,
  ) {
    final data = json['data'];
    if (data is! List<dynamic>) {
      throw ApiException(messageKey: 'common_error', statusCode: 0);
    }
    return data
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
