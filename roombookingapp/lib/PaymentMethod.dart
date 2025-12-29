import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  bool _showQRCode = false; // Track if QR code is shown
  String? _paymentHistoryId; // Track payment history ID for monitoring
  StreamSubscription<DocumentSnapshot>? _paymentSubscription; // Monitor payment status
  bool _paymentSuccessDialogShown = false; // Prevent multiple dialogs

  String _formatPrice(int price) {
    return '${(price / 1000).toStringAsFixed(0)}k VNĐ';
  }

  void _showQRCodeScreen() {
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

    setState(() {
      _showQRCode = true;
    });
  }

  Future<void> _confirmPayment() async {
    // Show confirmation dialog
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

  void _startPaymentMonitoring(String paymentHistoryId) {
    // Cancel existing subscription if any
    _paymentSubscription?.cancel();
    _paymentSuccessDialogShown = false;
    
    // Monitor payment status
    _paymentSubscription = _firestore
        .collection('PaymentHistory')
        .doc(paymentHistoryId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || _paymentSuccessDialogShown) return;
      
      if (snapshot.exists) {
        final data = snapshot.data();
        final status = data?['status'] as String?;
        
        // Check if payment is confirmed
        if (status == 'confirmed' || status == 'success') {
          _paymentSuccessDialogShown = true;
          _paymentSubscription?.cancel();
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

  Future<void> _processPayment() async {

    try {
      final now = DateTime.now();
      final checkInDate = now;
      final checkOutDate = now.add(Duration(days: widget.numberOfDays));

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

      // 3. Tạo PaymentHistory với status 'pending'
      final paymentHistoryRef = await _firestore
          .collection('PaymentHistory')
          .add({
        'paymentMethod': _selectedPaymentMethod,
        'amount': widget.totalPrice,
        'status': 'pending', // Initial status
        'createdAt': FieldValue.serverTimestamp(),
      });

      final paymentHistoryId = paymentHistoryRef.id;
      
      // Start monitoring payment status
      _paymentHistoryId = paymentHistoryId;
      _startPaymentMonitoring(paymentHistoryId);

      // 4. Tạo PayRoom_Detail
      await _firestore.collection('PayRoom_Detail').add({
        'DeteID': bookingDetailId,
        'PaymentDeteID': paymentHistoryId,
        'Paid': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Tạo History trong Users/{email}/History
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
            'paymentMethod': _selectedPaymentMethod,
            'amount': widget.totalPrice,
            'roomId': widget.roomId,
            'hotelId': widget.hotelId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // 6. Cập nhật trạng thái phòng thành "booked"
      await _firestore
          .collection('Hotels')
          .doc(widget.hotelId)
          .collection('Rooms')
          .doc(widget.roomDocId)
          .update({
        'roomstatus': 'booked',
      });

      // 7. Cập nhật trạng thái thanh toán thành 'confirmed'
      // Điều này sẽ trigger StreamBuilder và hiển thị dialog thành công
      await _firestore
          .collection('PaymentHistory')
          .doc(paymentHistoryId)
          .update({
        'status': 'confirmed',
      });

      // Thành công - Dialog sẽ được hiển thị tự động bởi _startPaymentMonitoring
      // Không cần hiển thị SnackBar ở đây nữa vì đã có dialog
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
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'MoMo',
                'lib/assets/images/momo/logo512.webp',
                'momo',
              ),

              const SizedBox(height: 32),

              // Show QR Code or Payment Button
              if (!_showQRCode)
                // Initial button to show QR code
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _showQRCodeScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Hiển thị QR code thanh toán',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                // QR Code Display Section
                Column(
                  children: [
                    const SizedBox(height: 24),
                    // Confirm Payment Button
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
                    const SizedBox(height: 12),

                    // Back button
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showQRCode = false;
                        });
                      },
                      child: const Text(
                        'Quay lại',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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

