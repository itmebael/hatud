class CommonResponse {
  final CommonError? error;
  final String status;

  CommonResponse({required this.status, this.error});
}

class CommonError {
  final String? name;
  final String? message;
  final int? code;

  CommonError({this.name, this.message, this.code});

  factory CommonError.fromJson(Map<String, dynamic> json) {
    return CommonError(
      name: json['name'] as String?,
      message: json['message'] as String?,
      code: json['code'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['message'] = message;
    data['code'] = code;
    return data;
  }
}
