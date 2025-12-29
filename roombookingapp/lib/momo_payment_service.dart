import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MoMoPaymentService {
  // Sandbox credentials - Thay thế bằng thông tin sandbox của bạn từ https://developers.momo.vn
  // Để lấy sandbox credentials:
  // 1. Đăng ký tài khoản tại https://developers.momo.vn
  // 2. Tạo app và lấy Partner Code, Access Key, Secret Key
  // 3. Cập nhật các giá trị bên dưới
  static const String partnerCode = 'MOMO';
  static const String accessKey = 'F8BBA842ECF85';
  static const String secretKey = 'K951B6PE1waDMi640xX08PD3vg6EkVlz';
  static const String apiEndpoint = 'https://test-payment.momo.vn/v2/gateway/api/create';
  static const String returnUrl = 'roombookingapp://payment-success';
  static const String notifyUrl = 'roombookingapp://payment-notify';
  static const String requestType = 'captureWallet';
  
  // Method channel để giao tiếp với native Android
  static const MethodChannel _channel = MethodChannel('com.example.roombookingapp/momo');

  /// Tạo payment request và mở MoMo app
  static Future<Map<String, dynamic>> createPaymentRequest({
    required int amount,
    required String orderId,
    required String orderInfo,
    required String extraData,
  }) async {
    try {
      // Tạo raw signature
      final rawSignature = 'accessKey=$accessKey&amount=$amount&extraData=$extraData&ipnUrl=$notifyUrl&orderId=$orderId&orderInfo=$orderInfo&partnerCode=$partnerCode&redirectUrl=$returnUrl&requestId=$orderId&requestType=$requestType';

      // Tạo HMAC SHA256 signature
      final signature = _generateSignature(rawSignature);

      // Tạo request body
      final requestBody = {
        'partnerCode': partnerCode,
        'partnerName': 'Test',
        'storeId': 'MomoTestStore',
        'requestId': orderId,
        'amount': amount,
        'orderId': orderId,
        'orderInfo': orderInfo,
        'redirectUrl': returnUrl,
        'ipnUrl': notifyUrl,
        'lang': 'vi',
        'extraData': extraData,
        'requestType': requestType,
        'signature': signature,
      };

      // Gửi request đến MoMo API
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['resultCode'] == 0) {
          // Lấy payment URL từ response
          // URL này đã chứa đầy đủ thông tin thanh toán:
          // - Số tiền (amount)
          // - Mô tả đơn hàng (orderInfo)
          // - Mã đơn hàng (orderId)
          // Khi mở trong app MoMo, nó sẽ tự động hiển thị tất cả thông tin này
          final payUrl = responseData['payUrl'];
          
          // Mở MoMo app với payment URL
          try {
            if (Platform.isAndroid) {
              // Trên Android, sử dụng MethodChannel để mở app MoMo trực tiếp
              try {
                final opened = await _channel.invokeMethod<bool>('openMoMoApp', {
                  'url': payUrl,
                });
                
                if (opened == true) {
                  // App MoMo đã được mở với URL thanh toán
                  // URL này sẽ hiển thị đầy đủ thông tin: số tiền, mô tả đơn hàng trong app MoMo
                  return {
                    'success': true,
                    'payUrl': payUrl,
                    'orderId': orderId,
                  };
                } else {
                  // App MoMo chưa được cài đặt, đã mở Play Store
                  return {
                    'success': false,
                    'error': 'Ứng dụng MoMo chưa được cài đặt. Vui lòng cài đặt MoMo từ Play Store.',
                    'payUrl': payUrl,
                    'orderId': orderId,
                  };
                }
              } catch (e) {
                // Nếu MethodChannel không hoạt động, fallback về url_launcher
                debugPrint('MethodChannel error: $e');
                final uri = Uri.parse(payUrl);
                final launched = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                
                if (launched) {
                  return {
                    'success': true,
                    'payUrl': payUrl,
                    'orderId': orderId,
                  };
                } else {
                  return {
                    'success': false,
                    'error': 'Không thể mở ứng dụng MoMo. Vui lòng kiểm tra lại.',
                    'payUrl': payUrl,
                  };
                }
              }
            } else {
              // iOS hoặc platform khác
              final uri = Uri.parse(payUrl);
              final launched = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              
              if (launched) {
                return {
                  'success': true,
                  'payUrl': payUrl,
                  'orderId': orderId,
                };
              } else {
                return {
                  'success': false,
                  'error': 'Không thể mở ứng dụng MoMo. Vui lòng kiểm tra lại.',
                  'payUrl': payUrl,
                };
              }
            }
          } catch (e) {
            // Nếu không thể mở URL, vẫn trả về payUrl để user có thể copy
            return {
              'success': false,
              'error': 'Không thể mở ứng dụng MoMo tự động. Vui lòng mở link sau trong trình duyệt: $payUrl',
              'payUrl': payUrl,
              'orderId': orderId,
            };
          }
        } else {
          return {
            'success': false,
            'error': responseData['message'] ?? 'Lỗi khi tạo yêu cầu thanh toán',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Lỗi kết nối đến MoMo: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Lỗi: ${e.toString()}',
      };
    }
  }

  /// Tạo HMAC SHA256 signature
  static String _generateSignature(String rawSignature) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(rawSignature);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  /// Kiểm tra kết quả thanh toán từ callback
  static Map<String, dynamic> verifyPaymentResult(Map<String, dynamic> result) {
    try {
      final orderId = result['orderId'] as String?;
      final resultCode = result['resultCode'] as int?;
      final amount = result['amount'] as int?;
      final signature = result['signature'] as String?;

      if (orderId == null || resultCode == null || amount == null || signature == null) {
        return {
          'success': false,
          'error': 'Thiếu thông tin thanh toán',
        };
      }

      // Tạo raw signature để verify
      final rawSignature = 'accessKey=$accessKey&amount=$amount&extraData=${result['extraData'] ?? ''}&message=${result['message'] ?? ''}&orderId=$orderId&orderInfo=${result['orderInfo'] ?? ''}&orderType=${result['orderType'] ?? ''}&partnerCode=$partnerCode&payType=${result['payType'] ?? ''}&requestId=${result['requestId'] ?? ''}&responseTime=${result['responseTime'] ?? ''}&resultCode=$resultCode&transId=${result['transId'] ?? ''}';
      
      final expectedSignature = _generateSignature(rawSignature);

      if (signature == expectedSignature) {
        if (resultCode == 0) {
          return {
            'success': true,
            'orderId': orderId,
            'amount': amount,
            'transId': result['transId'],
          };
        } else {
          return {
            'success': false,
            'error': result['message'] ?? 'Thanh toán thất bại',
            'resultCode': resultCode,
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Chữ ký không hợp lệ',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Lỗi xác thực: ${e.toString()}',
      };
    }
  }
}

