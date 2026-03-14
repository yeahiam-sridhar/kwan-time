import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kwan_time/core/constants/api_routes.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// HTTP Client Service
/// Singleton Dio instance with interceptors for authentication, error handling
/// ═══════════════════════════════════════════════════════════════════════════

/// Riverpod provider for HTTP client
final httpClientProvider = Provider<HttpClient>((ref) => HttpClient());

/// HTTP Client wrapper around Dio
class HttpClient {
  HttpClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiRoutes.defaultApiBase,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );

    // Add interceptors
    _dio.interceptors.add(LoggingInterceptor());
    _dio.interceptors.add(AuthInterceptor());
    _dio.interceptors.add(ErrorInterceptor());
  }
  late final Dio _dio;

  /// GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } catch (e) {
      rethrow;
    }
  }

  /// POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } catch (e) {
      rethrow;
    }
  }

  /// PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } catch (e) {
      rethrow;
    }
  }

  /// PATCH request
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } catch (e) {
      rethrow;
    }
  }

  /// DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } catch (e) {
      rethrow;
    }
  }

  /// Download file
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
  }) =>
      _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
      );

  /// Set authorization token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear authorization token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Update base URL
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  /// Get the underlying Dio instance (for advanced usage)
  Dio get dio => _dio;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// INTERCEPTORS
/// ═══════════════════════════════════════════════════════════════════════════

/// Logging interceptor for debugging
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('📤 HTTP Request: ${options.method} ${options.path}');
    print('   Headers: ${options.headers}');
    if (options.data != null) {
      print('   Data: ${options.data}');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('📥 HTTP Response: ${response.statusCode} ${response.requestOptions.path}');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('❌ HTTP Error: ${err.type} ${err.requestOptions.path}');
    print('   Message: ${err.message}');
    super.onError(err, handler);
  }
}

/// Authentication interceptor for token injection
class AuthInterceptor extends Interceptor {
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_token != null && !options.path.contains('/public/')) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    super.onRequest(options, handler);
  }
}

/// Error interceptor for centralized error handling
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle specific error types
    switch (err.type) {
      case DioExceptionType.badResponse:
        // Server responded with error status
        final statusCode = err.response?.statusCode;
        final message = err.response?.data['error'] ?? 'Request failed';
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: 'Server Error ($statusCode): $message',
          type: err.type,
          response: err.response,
        ));
        break;

      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: 'Connection timeout',
          type: err.type,
        ));
        break;

      case DioExceptionType.cancel:
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: 'Request cancelled',
          type: err.type,
        ));
        break;

      default:
        handler.next(err);
    }
  }
}
