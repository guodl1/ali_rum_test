import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class PaymentService {
  static const MethodChannel _channel = MethodChannel('com.example.tts_app/payment');
  final Dio _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

  /// Initiate Alipay payment
  /// [amount] Payment amount
  /// [subject] Order title
  /// [userId] User ID
  Future<Map<String, dynamic>> payWithAlipay({
    required String amount,
    required String subject,
    required int userId,
  }) async {
    try {
      // 1. Get order string from server
      final response = await _dio.post('/payment/alipay/order', data: {
        'amount': amount,
        'subject': subject,
        'user_id': userId,
      });

      if (response.data['success'] == true) {
        final orderString = response.data['orderString'];
        
        // 2. Call native Alipay SDK
        final Map<dynamic, dynamic> result = await _channel.invokeMethod('alipay', {
          'orderString': orderString,
        });

        // 3. Parse result (Simple check, server callback is the source of truth)
        final resultStatus = result['resultStatus'];
        if (resultStatus == '9000') {
          return {'success': true, 'message': 'Payment successful'};
        } else if (resultStatus == '8000') {
          return {'success': true, 'message': 'Payment processing'};
        } else if (resultStatus == '4000') {
          return {'success': false, 'message': 'Payment failed'};
        } else if (resultStatus == '6001') {
          return {'success': false, 'message': 'Payment cancelled'};
        } else {
          return {'success': false, 'message': 'Payment error: $resultStatus'};
        }
      } else {
        return {'success': false, 'message': response.data['error'] ?? 'Failed to get order'};
      }
    } catch (e) {
      print('Alipay error: $e');
      return {'success': false, 'message': 'Payment exception: $e'};
    }
  }
}
