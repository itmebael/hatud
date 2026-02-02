import 'package:hatud_tricycle_app/common/model/common_response.dart';

class LoginResponse extends CommonResponse {
  final Payload? payload;

  /*Error error;
  String status;*/

  LoginResponse({CommonError? error, this.payload, String status = "success"})
      : super(status: status, error: error);

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      error: json['error'] != null ? CommonError.fromJson(json['error']) : null,
      payload:
          json['payload'] != null ? Payload.fromJson(json['payload']) : null,
      status: (json['status'] ?? 'success') as String,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (error != null) data['error'] = error!.toJson();
    if (payload != null) data['payload'] = payload!.toJson();
    data['status'] = status;
    return data;
  }
}

class Payload {
  final String? passengerId;
  final String? name;
  final String? email;
  final String? mobile;
  final String? profilePicture;
  final int? credits;
  final String? accessToken;

  const Payload({
    this.passengerId,
    this.name,
    this.email,
    this.mobile,
    this.profilePicture,
    this.credits,
    this.accessToken,
  });

  factory Payload.fromJson(Map<String, dynamic> json) {
    return Payload(
      passengerId: json['passenger_id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      mobile: json['mobile'] as String?,
      profilePicture: json['profile_picture'] as String?,
      credits: json['credits'] as int?,
      accessToken: json['access_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['passenger_id'] = passengerId;
    data['name'] = name;
    data['email'] = email;
    data['mobile'] = mobile;
    data['profile_picture'] = profilePicture;
    data['credits'] = credits;
    data['access_token'] = accessToken;
    return data;
  }
}

/*class Error {
  String name;
  String message;
  int code;

  Error({this.name, this.message, this.code});

  Error.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    message = json['message'];
    code = json['code'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['message'] = this.message;
    data['code'] = this.code;
    return data;
  }
}*/
