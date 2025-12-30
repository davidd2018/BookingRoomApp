import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class PayPalPaymentService {
  // PayPal Sandbox credentials
  static const String clientId = 'AXFcFS5Omgre7X658w0i6ExtahqHByEINev_bYtcp-HHqW-SJ7SIqJ_CdpH6STvbRKQLgpFJYCePrJLh';
  static const String secretKey = 'EJcZfmPybxCbxTKBUquzdejXawVV2kH22M87ideTH-BdLjPiettsc39-fdWoJYSF6H9AZYoZ_QuBex-z';
  
  // PayPal Sandbox endpoints
  static const String baseUrl = 'https://api.sandbox.paypal.com';
  static const String tokenUrl = '$baseUrl/v1/oauth2/token';
  static const String ordersUrl = '$baseUrl/v2/checkout/orders';
  
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Lấy access token từ PayPal
  static Future<String?> _getAccessToken() async {
    try {
      // Kiểm tra nếu token còn hiệu lực
      if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }

      // Tạo Basic Auth header
      final credentials = base64Encode(utf8.encode('$clientId:$secretKey'));
      
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Accept': 'application/json',
          'Accept-Language': 'en_US',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $credentials',
        },
        body: 'grant_type=client_credentials',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60)); // Trừ 60s để đảm bảo an toàn
        return _accessToken;
      } else {
        debugPrint('PayPal token error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('PayPal token exception: $e');
      return null;
    }
  }

  /// Tạo PayPal order
  static Future<Map<String, dynamic>> createPaymentRequest({
    required int amount,
    required String orderId,
    required String orderInfo,
    required String extraData,
  }) async {
    try {
      // Lấy access token
      final token = await _getAccessToken();
      if (token == null) {
        return {
          'success': false,
          'error': 'Không thể lấy access token từ PayPal',
        };
      }

      // Chuyển đổi amount từ VNĐ sang USD (PayPal sử dụng USD)
      // Giả sử 1 USD = 24,000 VNĐ (có thể điều chỉnh)
      final amountInUsd = (amount / 24000).toStringAsFixed(2);

      // Tạo PayPal order
      final orderData = {
        'intent': 'CAPTURE',
        'purchase_units': [
          {
            'reference_id': orderId,
            'description': orderInfo,
            'amount': {
              'currency_code': 'USD',
              'value': amountInUsd,
            },
          }
        ],
        'application_context': {
          'brand_name': 'Room Booking App',
          'landing_page': 'NO_PREFERENCE',
          'user_action': 'PAY_NOW',
          'return_url': 'roombookingapp://payment-success',
          'cancel_url': 'roombookingapp://payment-cancel',
        },
      };

      final response = await http.post(
        Uri.parse(ordersUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'PayPal-Request-Id': orderId,
        },
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final orderId = responseData['id'];
        final links = responseData['links'] as List;
        
        // Tìm approval URL
        String? approvalUrl;
        for (var link in links) {
          if (link['rel'] == 'approve') {
            approvalUrl = link['href'];
            break;
          }
        }

        if (approvalUrl != null) {
          // Mở PayPal checkout trong browser
          try {
            final uri = Uri.parse(approvalUrl);
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );

            if (launched) {
              return {
                'success': true,
                'orderId': orderId,
                'payUrl': approvalUrl,
                'paypalOrderId': orderId,
              };
            } else {
              return {
                'success': false,
                'error': 'Không thể mở PayPal checkout. Vui lòng thử lại.',
                'payUrl': approvalUrl,
                'paypalOrderId': orderId,
              };
            }
          } catch (e) {
            return {
              'success': false,
              'error': 'Lỗi khi mở PayPal: ${e.toString()}',
              'payUrl': approvalUrl,
              'paypalOrderId': orderId,
            };
          }
        } else {
          return {
            'success': false,
            'error': 'Không tìm thấy approval URL từ PayPal',
          };
        }
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Lỗi khi tạo PayPal order: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Lỗi: ${e.toString()}',
      };
    }
  }

  /// Capture PayPal payment (sau khi user approve)
  static Future<Map<String, dynamic>> capturePayment(String paypalOrderId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        return {
          'success': false,
          'error': 'Không thể lấy access token từ PayPal',
        };
      }

      final response = await http.post(
        Uri.parse('$ordersUrl/$paypalOrderId/capture'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final status = responseData['status'];
        
        if (status == 'COMPLETED') {
          return {
            'success': true,
            'orderId': paypalOrderId,
            'status': status,
          };
        } else {
          return {
            'success': false,
            'error': 'Trạng thái thanh toán: $status',
            'status': status,
          };
        }
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Lỗi khi capture payment: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Lỗi: ${e.toString()}',
      };
    }
  }

  /// Lấy thông tin order từ PayPal
  static Future<Map<String, dynamic>> getOrderDetails(String paypalOrderId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        return {
          'success': false,
          'error': 'Không thể lấy access token từ PayPal',
        };
      }

      final response = await http.get(
        Uri.parse('$ordersUrl/$paypalOrderId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'order': responseData,
        };
      } else {
        return {
          'success': false,
          'error': 'Lỗi khi lấy thông tin order: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Lỗi: ${e.toString()}',
      };
    }
  }
}

