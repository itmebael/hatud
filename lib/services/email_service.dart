import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  // EmailJS Configuration
  static const String _serviceId = 'service_snrql7t';
  static const String _publicKey = 'ysZGZB86KPFg8orKa';
  static const String _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  
  // Template IDs
  static const String _verifiedTemplateId = 'VERIFIED_Email';
  static const String _rejectedTemplateId = 'REJECTED_EMAIL';

  /// Send verification approved email to driver
  static Future<bool> sendVerificationApprovedEmail({
    required String driverName,
    required String driverEmail,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _verifiedTemplateId,
          'user_id': _publicKey,
          'template_params': {
            'name': driverName,
            'to_email': driverEmail,
            'subject': 'BPLO Verification Approved',
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Verification approved email sent successfully to $driverEmail');
        return true;
      } else {
        print('Failed to send email. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending verification approved email: $e');
      return false;
    }
  }

  /// Send verification rejected email to driver
  static Future<bool> sendVerificationRejectedEmail({
    required String driverName,
    required String driverEmail,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _rejectedTemplateId,
          'user_id': _publicKey,
          'template_params': {
            'name': driverName,
            'to_email': driverEmail,
            'subject': 'BPLO Verification Rejected',
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Verification rejected email sent successfully to $driverEmail');
        return true;
      } else {
        print('Failed to send email. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending verification rejected email: $e');
      return false;
    }
  }
}










