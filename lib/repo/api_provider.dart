// frontend-only: no network JSON parsing needed here

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:hatud_tricycle_app/common/model/common_response.dart';
import 'package:hatud_tricycle_app/common/my_const.dart';
import 'package:hatud_tricycle_app/features/loginsignup/login/model/LoginResponse.dart';

abstract class APIProvider {
  Future<Either<DioException, LoginResponse>> login({
    required String mobileCountryCode,
    required String mobile,
    required String deviceId,
    required String deviceToken,
    required String deviceName,
    required String deviceType,
  });

  Future<Either<DioException, CommonResponse>> sendOTP(
    String type,
    String userId,
  );
}

class APIProviderIml extends APIProvider {
  final String _endPoint = kAPIBaseURL;
  final Dio _dio = Dio();

  APIProviderIml() {
    _dio.options.baseUrl = _endPoint;
    _dio.interceptors.add(LogInterceptor(responseBody: false));
    _dio.options.contentType = "application/x-www-form-urlencoded";
  }

  @override
  Future<Either<DioException, LoginResponse>> login({
    required String mobileCountryCode,
    required String mobile,
    required String deviceId,
    required String deviceToken,
    required String deviceName,
    required String deviceType,
  }) async {
    // TODO: Implement real API call to login endpoint
    // This is a stub - replace with actual network call when backend is ready
    try {
      // Placeholder - this should make a real API call
      // final response = await _dio.post('/login', data: {...});
      // return Right(LoginResponse.fromJson(response.data));
      
      // For now, return error indicating API not implemented
      return Left(DioException(
        requestOptions: RequestOptions(path: '/login'),
        type: DioExceptionType.unknown,
        error: 'API endpoint not implemented',
      ));
    } on DioException catch (dioError) {
      return Left(dioError);
    }
  }

  @override
  Future<Either<DioException, CommonResponse>> sendOTP(
    String type,
    String userId,
  ) async {
    // Front-end only stub: immediate success response
    return Right(CommonResponse(status: "success"));
  }
}
