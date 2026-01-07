import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'paypal_payment_service.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String userEmail;
  final String hotelId;
  final String roomId;
  final int numberOfDays;
  final int numberOfRooms;
  final int totalPrice;
  final String roomDocId; // Document ID của room trong Firestore

  const PaymentMethodScreen({
    super.key,
    required this.userEmail,
    required this.hotelId,
    required this.roomId,
    required this.numberOfDays,
    required this.numberOfRooms,
    required this.totalPrice,
    required this.roomDocId,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  String? _paymentHistoryId; // Track payment history ID for monitoring
  StreamSubscription<DocumentSnapshot>? _paymentSubscription; // Monitor payment status
  bool _paymentSuccessDialogShown = false; // Prevent multiple dialogs
  String? _paymentStatus; // Track current payment status
  String? _paypalOrderId; // Track PayPal order ID

  @override
  void initState() {
    super.initState();
    // Kiểm tra nếu có paymentHistoryId đang pending, tiếp tục monitor
    _checkPendingPayments();
  }

  Future<void> _checkPendingPayments() async {
    // Kiểm tra các payment đang pending của user này
    try {
      // Sử dụng query đơn giản hơn để tránh lỗi index
      final pendingPayments = await _firestore
          .collection('PaymentHistory')
          .where('status', isEqualTo: 'pending')
          .where('userEmail', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      if (pendingPayments.docs.isNotEmpty) {
        final paymentDoc = pendingPayments.docs.first;
        _paymentHistoryId = paymentDoc.id;
        final paymentData = paymentDoc.data() as Map<String, dynamic>?;
        _paymentStatus = paymentData?['status'] as String?;
        _paypalOrderId = paymentData?['paypalOrderId'] as String?;
        _startPaymentMonitoring(paymentDoc.id);
      }
    } catch (e) {
      // Chỉ log lỗi, không hiển thị cho user vì đây là background check
      debugPrint('Error checking pending payments: $e');
      // Nếu có lỗi index, bỏ qua việc check pending payments
    }
  }

  String _formatPrice(int price) {
    return '${(price / 1000).toStringAsFixed(0)}k VNĐ';
  }


  Future<void> _confirmPayment() async {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn phương thức thanh toán'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Nếu chọn PayPal, gọi PayPal Payment API
    if (_selectedPaymentMethod == 'paypal') {
      await _processPayPalPayment();
      return;
    }

    // Các phương thức thanh toán khác (giữ nguyên logic cũ)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận thanh toán'),
          content: const Text(
            'Bạn đã quét QR code và thanh toán thành công chưa?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Chưa'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Đã thanh toán'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _processPayment();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _manualConfirmPayment() async {
    if (_paymentHistoryId == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Lấy thông tin PaymentHistory để lấy paypalOrderId
      final paymentDoc = await _firestore
          .collection('PaymentHistory')
          .doc(_paymentHistoryId)
          .get();

      if (!paymentDoc.exists) {
        throw Exception('Không tìm thấy thông tin thanh toán');
      }

      final paymentData = paymentDoc.data() as Map<String, dynamic>?;
      final paypalOrderId = paymentData?['paypalOrderId'] as String?;

      if (paypalOrderId == null || paypalOrderId.isEmpty) {
        throw Exception('Không tìm thấy PayPal Order ID. Vui lòng thử lại từ đầu.');
      }

      // Kiểm tra trạng thái order từ PayPal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang kiểm tra trạng thái thanh toán với PayPal...'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Lấy thông tin order từ PayPal
      final orderDetails = await PayPalPaymentService.getOrderDetails(paypalOrderId);

      if (!orderDetails['success']) {
        throw Exception(
          'Không thể kiểm tra trạng thái thanh toán: ${orderDetails['error'] ?? 'Lỗi không xác định'}',
        );
      }

      final order = orderDetails['order'] as Map<String, dynamic>?;
      final orderStatus = order?['status'] as String?;

      // Kiểm tra nếu order đã được approve
      if (orderStatus != 'APPROVED' && orderStatus != 'COMPLETED') {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Thanh toán chưa hoàn tất'),
                  ],
                ),
                content: Text(
                  'PayPal order hiện tại có trạng thái: $orderStatus\n\n'
                  'Vui lòng hoàn tất thanh toán trên PayPal trước khi xác nhận.\n\n'
                  'Nếu bạn đã thanh toán, vui lòng đợi vài giây để hệ thống cập nhật.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // Nếu order đã APPROVED nhưng chưa COMPLETED, cần capture payment
      if (orderStatus == 'APPROVED') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đang xác nhận thanh toán với PayPal...'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Capture payment từ PayPal
        final captureResult = await PayPalPaymentService.capturePayment(paypalOrderId);

        if (!captureResult['success']) {
          throw Exception(
            'Không thể xác nhận thanh toán với PayPal: ${captureResult['error'] ?? 'Lỗi không xác định'}\n\n'
            'Vui lòng đảm bảo bạn đã hoàn tất thanh toán trên PayPal.',
          );
        }

        final captureStatus = captureResult['status'] as String?;
        if (captureStatus != 'COMPLETED') {
          throw Exception(
            'Thanh toán chưa được hoàn tất. Trạng thái: $captureStatus\n\n'
            'Vui lòng hoàn tất thanh toán trên PayPal trước khi xác nhận.',
          );
        }
      }

      // Nếu đến đây, thanh toán đã được xác nhận thành công từ PayPal
      // Cập nhật trạng thái thanh toán thành 'confirmed'
      await _firestore
          .collection('PaymentHistory')
          .doc(_paymentHistoryId)
          .update({
        'status': 'confirmed',
        'paypalVerified': true, // Đánh dấu đã được xác minh từ PayPal
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận thanh toán thành công! Đang tạo booking...'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Payment monitoring sẽ tự động tạo booking khi phát hiện status = 'confirmed'
      // Không cần gọi _processPayment() ở đây vì monitoring sẽ xử lý
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Lỗi xác nhận thanh toán'),
                ],
              ),
              content: Text(
                e.toString().replaceAll('Exception: ', ''),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _processPayPalPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Tạo orderId duy nhất
      final orderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';
      final orderInfo = 'Thanh toán đặt phòng ${widget.roomId} - ${widget.numberOfRooms} phòng x ${widget.numberOfDays} ngày';
      final extraData = '';

      // Gọi PayPal Payment API
      final result = await PayPalPaymentService.createPaymentRequest(
        amount: widget.totalPrice,
        orderId: orderId,
        orderInfo: orderInfo,
        extraData: extraData,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      if (result['success'] == true) {
        try {
          // Tạo PaymentHistory với status 'pending' và lưu thông tin booking
          final paymentHistoryRef = await _firestore
              .collection('PaymentHistory')
              .add({
            'paymentMethod': 'paypal',
            'amount': widget.totalPrice,
            'status': 'pending',
            'orderId': orderId,
            'paypalOrderId': result['paypalOrderId'],
            'bookingCreated': false,
            'userEmail': widget.userEmail,
            'hotelId': widget.hotelId,
            'roomId': widget.roomId,
            'roomDocId': widget.roomDocId,
            'numberOfDays': widget.numberOfDays,
            'numberOfRooms': widget.numberOfRooms,
            'createdAt': FieldValue.serverTimestamp(),
          });

          final paymentHistoryId = paymentHistoryRef.id;
          _paymentHistoryId = paymentHistoryId;
          _paymentStatus = 'pending';
          _paypalOrderId = result['paypalOrderId'];
          _startPaymentMonitoring(paymentHistoryId);

          // Hiển thị thông báo chờ thanh toán
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã mở PayPal checkout. Vui lòng hoàn tất thanh toán.'),
                backgroundColor: Colors.blue,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          }

          // Lưu paymentHistoryId để xử lý callback
          // Note: Trong thực tế, bạn cần xử lý deep link callback từ PayPal
          // và cập nhật status trong Firestore khi thanh toán thành công
        } catch (e) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Lỗi lưu thông tin'),
                    ],
                  ),
                  content: Text('Không thể lưu thông tin thanh toán: ${e.toString()}'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng'),
                    ),
                  ],
                );
              },
            );
          }
        }
      } else {
        if (mounted) {
          final errorMessage = result['error'] ?? 'Lỗi khi tạo yêu cầu thanh toán';
          // Hiển thị dialog lỗi thay vì SnackBar để user dễ đọc hơn
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Lỗi thanh toán'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(errorMessage),
                    if (result['payUrl'] != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Bạn có thể thử mở link sau trong trình duyệt:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        result['payUrl'],
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        // Hiển thị dialog lỗi thay vì SnackBar
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Lỗi thanh toán'),
                ],
              ),
              content: Text(
                'Lỗi thanh toán PayPal: ${e.toString()}\n\n'
                'Vui lòng thử lại sau hoặc liên hệ hỗ trợ.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _startPaymentMonitoring(String paymentHistoryId) {
    // Cancel existing subscription if any
    _paymentSubscription?.cancel();
    _paymentSuccessDialogShown = false;
    
    // Monitor payment status
    _paymentSubscription = _firestore
        .collection('PaymentHistory')
        .doc(paymentHistoryId)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted || _paymentSuccessDialogShown) return;
      
      if (snapshot.exists) {
        final data = snapshot.data();
        final status = data?['status'] as String?;
        
        // Update payment status in state
        if (mounted) {
          setState(() {
            _paymentStatus = status;
          });
        }
        
        // Check if payment is confirmed
        if (status == 'confirmed' || status == 'success') {
          _paymentSuccessDialogShown = true;
          _paymentSubscription?.cancel();
          
          // Kiểm tra xem đã tạo booking chưa
          final bookingCreated = data?['bookingCreated'] as bool? ?? false;
          
          if (!bookingCreated) {
            // Tạo booking nếu chưa tạo - truyền paymentHistoryId để sử dụng PaymentHistory đã có
            try {
              await _processPayment(existingPaymentHistoryId: paymentHistoryId);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi khi tạo booking: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          }
          
          // Delay slightly to ensure all data is saved
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showPaymentSuccessDialog();
            }
          });
        }
      }
    });
  }

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Thanh toán thành công!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hệ thống đã xác nhận thanh toán thành công.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đã đặt ${widget.numberOfRooms} phòng trong ${widget.numberOfDays} ngày.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Thanh toán thành công! Đã đặt ${widget.numberOfRooms} phòng trong ${widget.numberOfDays} ngày',
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processPayment({String? existingPaymentHistoryId}) async {
    try {
      final now = DateTime.now();
      final checkInDate = now;
      final checkOutDate = now.add(Duration(days: widget.numberOfDays));

      String paymentHistoryId;
      String? orderId;
      String? paypalOrderId;
      String paymentMethod = _selectedPaymentMethod ?? 'unknown';

      // Nếu đã có PaymentHistory (từ PayPal), sử dụng nó
      if (existingPaymentHistoryId != null) {
        paymentHistoryId = existingPaymentHistoryId;
        // Lấy thông tin từ PaymentHistory hiện có
        final paymentDoc = await _firestore
            .collection('PaymentHistory')
            .doc(paymentHistoryId)
            .get();
        if (paymentDoc.exists) {
          final paymentData = paymentDoc.data() as Map<String, dynamic>?;
          orderId = paymentData?['orderId'] as String?;
          paypalOrderId = paymentData?['paypalOrderId'] as String?;
          paymentMethod = paymentData?['paymentMethod'] as String? ?? paymentMethod;
        }
      } else {
        // Tạo PaymentHistory mới cho các phương thức thanh toán khác
        // Lưu ý: Với các phương thức thanh toán không phải PayPal, 
        // chúng ta xử lý ngay nên không cần monitoring
        orderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';
        final paymentHistoryRef = await _firestore
            .collection('PaymentHistory')
            .add({
          'paymentMethod': paymentMethod,
          'amount': widget.totalPrice,
          'status': 'confirmed', // Đã xác nhận ngay vì user đã confirm
          'orderId': orderId,
          'userEmail': widget.userEmail,
          'hotelId': widget.hotelId,
          'roomId': widget.roomId,
          'roomDocId': widget.roomDocId,
          'numberOfDays': widget.numberOfDays,
          'numberOfRooms': widget.numberOfRooms,
          'bookingCreated': true, // Đánh dấu sẽ được tạo ngay
          'createdAt': FieldValue.serverTimestamp(),
        });
        paymentHistoryId = paymentHistoryRef.id;
        _paymentHistoryId = paymentHistoryId;
        // Không gọi _startPaymentMonitoring() vì đã xử lý xong
      }

      // 1. Tạo BookingDetail trong Rooms/{hotelId}/Rooms/{roomDocId}/BookingDetail
      final bookingDetailRef = await _firestore
          .collection('Hotels')
          .doc(widget.hotelId)
          .collection('Rooms')
          .doc(widget.roomDocId)
          .collection('BookingDetail')
          .add({
        'DeteID': '', // Will be updated after creation
        'price': widget.totalPrice,
        'status': 'Đã thanh toán',
        'Email': widget.userEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update DeteID with the document ID
      await bookingDetailRef.update({
        'DeteID': bookingDetailRef.id,
      });

      final bookingDetailId = bookingDetailRef.id;

      // 2. Tạo BookingRoom
      await _firestore.collection('BookingRoom').add({
        'Email': widget.userEmail,
        'RoomID': widget.roomId,
        'BookDates': Timestamp.fromDate(now),
        'checkinDates': Timestamp.fromDate(checkInDate),
        'checkOutDates': Timestamp.fromDate(checkOutDate),
        'numberOfDays': widget.numberOfDays,
        'numberOfRooms': widget.numberOfRooms,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Cập nhật PaymentHistory với thông tin đầy đủ và status 'confirmed'
      await _firestore
          .collection('PaymentHistory')
          .doc(paymentHistoryId)
          .update({
        'status': 'confirmed',
        'bookingCreated': true,
        'userEmail': widget.userEmail,
        'hotelId': widget.hotelId,
        'roomId': widget.roomId,
        'roomDocId': widget.roomDocId,
        'numberOfDays': widget.numberOfDays,
        'numberOfRooms': widget.numberOfRooms,
      });

      // 4. Tạo OrderHistory - Lưu thông tin đặt phòng với userEmail
      await _firestore.collection('OrderHistory').add({
        'userEmail': widget.userEmail.toLowerCase(),
        'paymentHistoryId': paymentHistoryId,
        'bookingDetailId': bookingDetailId,
        'orderId': orderId ?? 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
        'paypalOrderId': paypalOrderId,
        'paymentMethod': paymentMethod,
        'amount': widget.totalPrice,
        'status': 'confirmed',
        'hotelId': widget.hotelId,
        'roomId': widget.roomId,
        'roomDocId': widget.roomDocId,
        'numberOfDays': widget.numberOfDays,
        'numberOfRooms': widget.numberOfRooms,
        'checkInDate': Timestamp.fromDate(checkInDate),
        'checkOutDate': Timestamp.fromDate(checkOutDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Tạo PayRoom_Detail
      await _firestore.collection('PayRoom_Detail').add({
        'DeteID': bookingDetailId,
        'PaymentDeteID': paymentHistoryId,
        'Paid': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6. Tạo History trong Users/{email}/History
      await _firestore
          .collection('Users')
          .where('email', isEqualTo: widget.userEmail.toLowerCase())
          .get()
          .then((querySnapshot) {
        if (querySnapshot.docs.isNotEmpty) {
          final userDocId = querySnapshot.docs.first.id;
          _firestore
              .collection('Users')
              .doc(userDocId)
              .collection('History')
              .add({
            'PaymentDeteID': paymentHistoryId,
            'DeteID': bookingDetailId,
            'Date of payment': Timestamp.fromDate(now),
            'paymentMethod': paymentMethod,
            'amount': widget.totalPrice,
            'roomId': widget.roomId,
            'hotelId': widget.hotelId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // 7. Cập nhật trạng thái phòng thành "booked"
      await _firestore
          .collection('Hotels')
          .doc(widget.hotelId)
          .collection('Rooms')
          .doc(widget.roomDocId)
          .update({
        'roomstatus': 'booked',
      });

      // Thành công - Dialog sẽ được hiển thị tự động bởi _startPaymentMonitoring
    } catch (e) {
      _paymentSubscription?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi thanh toán: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap trong Builder để catch lỗi build-time
    return Builder(
      builder: (context) {
        try {
          return _buildPaymentScreen(context);
        } catch (e, stackTrace) {
          // Hiển thị error screen nếu có lỗi
          return Scaffold(
            appBar: AppBar(
              title: const Text('Lỗi'),
              backgroundColor: Colors.red,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Đã xảy ra lỗi khi tải màn hình',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Quay lại'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildPaymentScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Phương thức thanh toán',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1E3A8A),
              Colors.white,
            ],
            stops: const [0.0, 0.15],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin đặt phòng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Phòng', widget.roomId),
                    const SizedBox(height: 8),
                    _buildInfoRow('Số ngày', '${widget.numberOfDays} ngày'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Số phòng', '${widget.numberOfRooms} phòng'),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng tiền',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          _formatPrice(widget.totalPrice),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Payment Methods
              const Text(
                'Chọn phương thức thanh toán',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              _buildPaymentOption(
                'PayPal',
                'lib/assets/images/paypal/paypal-3384015_640 (1).webp',
                'paypal',
              ),

              const SizedBox(height: 32),

              // Payment Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Thanh toán',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              // Hiển thị nút xác nhận thanh toán thủ công nếu có payment đang pending
              // Chỉ hiển thị khi: có paymentHistoryId, đã chọn PayPal, status là 'pending', và có paypalOrderId
              if (_paymentHistoryId != null && 
                  _selectedPaymentMethod == 'paypal' && 
                  _paymentStatus == 'pending' &&
                  _paypalOrderId != null &&
                  _paypalOrderId!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _manualConfirmPayment,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Đã thanh toán trên PayPal - Xác nhận',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    super.dispose();
  }

  Widget _buildPaymentOption(
    String title,
    String qrImagePath,
    String paymentMethod,
  ) {
    final isSelected = _selectedPaymentMethod == paymentMethod;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = paymentMethod;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1E3A8A)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF1E3A8A).withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Radio button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E3A8A)
                      : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Payment method name
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF1E3A8A)
                      : Colors.black87,
                ),
              ),
            ),
            // QR Code preview
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                qrImagePath,
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.qr_code,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

