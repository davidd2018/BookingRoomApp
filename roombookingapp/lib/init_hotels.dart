import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Khởi tạo dữ liệu Hotels và Rooms vào Firebase
/// Chạy hàm này một lần để tạo dữ liệu ban đầu
Future<void> initializeHotelsAndRooms() async {
  try {
    // Kiểm tra Firebase đã được khởi tạo chưa
    try {
      Firebase.app();
    } catch (e) {
      print('Lỗi: Firebase chưa được khởi tạo');
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // Kiểm tra xem collection Hotels đã có dữ liệu chưa
    final existingHotels = await firestore.collection('Hotels').limit(1).get();

    if (existingHotels.docs.isNotEmpty) {
      print('Collection Hotels đã có dữ liệu. Bỏ qua việc khởi tạo.');
      return;
    }

    // Map dữ liệu Hotels và Rooms cho từng địa điểm
    // Format: LocationName -> List of Hotels -> List of Rooms
    final hotelsData = {
      'TpHCM': [
        {
          'name': 'Caravelle Sài Gòn',
          'status': 'Còn phòng',
          'address': '19 Công Trường Lam Sơn, Bến Nghé, Quận 1, TP. Hồ Chí Minh',
          'rooms': [
            {
              'roomCode': 'CAR-101',
              'price': 2500000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/caravelle_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'CAR-102',
              'price': 3000000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/caravelle_102.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'CAR-201',
              'price': 3500000,
              'maxGuest': 4,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/caravelle_201.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'La Vela Saigon',
          'status': 'Còn phòng',
          'address': '198 Nguyễn Thị Minh Khai, Phường 6, Quận 3, TP. Hồ Chí Minh',
          'rooms': [
            {
              'roomCode': 'VEL-101',
              'price': 2000000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/lavela_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'VEL-102',
              'price': 2500000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/lavela_102.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'VEL-301',
              'price': 4000000,
              'maxGuest': 4,
              'roomStatus': 'booked',
              // TODO: Chèn ảnh phòng vào lib/assets/images/lavela_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'Mai House Saigon',
          'status': 'Còn phòng',
          'address': '157 Nam Kỳ Khởi Nghĩa, Phường Võ Thị Sáu, Quận 3, TP. Hồ Chí Minh',
          'rooms': [
            {
              'roomCode': 'MAI-101',
              'price': 1800000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/maihouse_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'MAI-201',
              'price': 2200000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/maihouse_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'MAI-301',
              'price': 2800000,
              'maxGuest': 4,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/maihouse_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
      ],
      'Vũng Tàu': [
        {
          'name': 'Vias Hotel',
          'status': 'Còn phòng',
          'address': '18 Trần Phú, Phường 1, Thành phố Vũng Tàu, Bà Rịa - Vũng Tàu',
          'rooms': [
            {
              'roomCode': 'VIA-101',
              'price': 1500000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/vias_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'VIA-102',
              'price': 1800000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/vias_102.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'VIA-201',
              'price': 2200000,
              'maxGuest': 4,
              'roomStatus': 'booked',
              // TODO: Chèn ảnh phòng vào lib/assets/images/vias_201.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'The Imperial Hotel',
          'status': 'Còn phòng',
          'address': '159 Thùy Vân, Phường Thắng Tam, Thành phố Vũng Tàu, Bà Rịa - Vũng Tàu',
          'rooms': [
            {
              'roomCode': 'IMP-101',
              'price': 2000000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/imperial_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'IMP-201',
              'price': 2500000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/imperial_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'IMP-301',
              'price': 3000000,
              'maxGuest': 4,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/imperial_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'La Casa Boutique',
          'status': 'Còn phòng',
          'address': '98 Hạ Long, Phường 2, Thành phố Vũng Tàu, Bà Rịa - Vũng Tàu',
          'rooms': [
            {
              'roomCode': 'CAS-101',
              'price': 1200000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/lacasa_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'CAS-102',
              'price': 1500000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/lacasa_102.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'CAS-201',
              'price': 1800000,
              'maxGuest': 3,
              'roomStatus': 'booked',
              // TODO: Chèn ảnh phòng vào lib/assets/images/lacasa_201.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
      ],
      'Đà Lạt': [
        {
          'name': 'Hôtel Colline',
          'status': 'Còn phòng',
          'address': '10 Trần Phú, Phường 3, Thành phố Đà Lạt, Lâm Đồng',
          'rooms': [
            {
              'roomCode': 'COL-101',
              'price': 1800000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/colline_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'COL-201',
              'price': 2200000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/colline_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'COL-301',
              'price': 2800000,
              'maxGuest': 4,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/colline_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'Swiss-Belresort Tuyền Lâm',
          'status': 'Còn phòng',
          'address': 'Km 4, Đường Tuyền Lâm, Phường 11, Thành phố Đà Lạt, Lâm Đồng',
          'rooms': [
            {
              'roomCode': 'SWI-101',
              'price': 2500000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/swiss_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'SWI-201',
              'price': 3000000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/swiss_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'SWI-301',
              'price': 3500000,
              'maxGuest': 4,
              'roomStatus': 'booked',
              // TODO: Chèn ảnh phòng vào lib/assets/images/swiss_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'Terracotta Hotel',
          'status': 'Còn phòng',
          'address': '18 Trần Hưng Đạo, Phường 10, Thành phố Đà Lạt, Lâm Đồng',
          'rooms': [
            {
              'roomCode': 'TER-101',
              'price': 2000000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/terracotta_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'TER-201',
              'price': 2400000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/terracotta_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'TER-301',
              'price': 3000000,
              'maxGuest': 4,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/terracotta_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
      ],
      'Hà Nội': [
        {
          'name': 'JW Marriott Hanoi',
          'status': 'Còn phòng',
          'address': '8 Đỗ Đức Dục, Mễ Trì, Nam Từ Liêm, Hà Nội',
          'rooms': [
            {
              'roomCode': 'JWM-101',
              'price': 3500000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/jwmarriott_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'JWM-201',
              'price': 4000000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/jwmarriott_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'JWM-301',
              'price': 5000000,
              'maxGuest': 4,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/jwmarriott_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'Sofitel Legend Metropole',
          'status': 'Còn phòng',
          'address': '15 Ngô Quyền, Hoàn Kiếm, Hà Nội',
          'rooms': [
            {
              'roomCode': 'SOF-101',
              'price': 4000000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/sofitel_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'SOF-201',
              'price': 4500000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/sofitel_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'SOF-301',
              'price': 5500000,
              'maxGuest': 4,
              'roomStatus': 'booked',
              // TODO: Chèn ảnh phòng vào lib/assets/images/sofitel_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'Lotte Hotel Hanoi',
          'status': 'Còn phòng',
          'address': '54 Liễu Giai, Cống Vị, Ba Đình, Hà Nội',
          'rooms': [
            {
              'roomCode': 'LOT-101',
              'price': 3000000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/lotte_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'LOT-201',
              'price': 3500000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/lotte_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'LOT-301',
              'price': 4200000,
              'maxGuest': 4,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/lotte_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
      ],
      'Nha Trang': [
        {
          'name': 'Sunrise Beach Hotel',
          'status': 'Còn phòng',
          'address': '12-14 Trần Phú, Lộc Thọ, Nha Trang, Khánh Hòa',
          'rooms': [
            {
              'roomCode': 'SUN-101',
              'price': 2000000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/sunrise_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'SUN-201',
              'price': 2500000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/sunrise_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'SUN-301',
              'price': 3000000,
              'maxGuest': 4,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/sunrise_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'Sheraton Nha Trang',
          'status': 'Còn phòng',
          'address': '26-28 Trần Phú, Lộc Thọ, Nha Trang, Khánh Hòa',
          'rooms': [
            {
              'roomCode': 'SHE-101',
              'price': 3000000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/sheraton_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'SHE-201',
              'price': 3500000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/sheraton_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'SHE-301',
              'price': 4000000,
              'maxGuest': 4,
              'roomStatus': 'booked',
              // TODO: Chèn ảnh phòng vào lib/assets/images/sheraton_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
        {
          'name': 'Mường Thanh Grand',
          'status': 'Còn phòng',
          'address': '50 Trần Phú, Lộc Thọ, Nha Trang, Khánh Hòa',
          'rooms': [
            {
              'roomCode': 'MUO-101',
              'price': 1800000,
              'maxGuest': 2,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/muongthanh_101.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'MUO-201',
              'price': 2200000,
              'maxGuest': 3,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/muongthanh_201.jpg
              'imgurl': 'images/download.jpg',
            },
            {
              'roomCode': 'MUO-301',
              'price': 2800000,
              'maxGuest': 4,
              'roomStatus': 'available',
              // TODO: Chèn ảnh phòng vào lib/assets/images/muongthanh_301.jpg
              'imgurl': 'images/download.jpg',
            },
          ],
        },
      ],
    };

    // Thêm từng Hotel và Rooms vào Firestore
    for (final locationEntry in hotelsData.entries) {
      final locationName = locationEntry.key;
      final hotels = locationEntry.value;

      for (final hotelData in hotels) {
        // Tạo Hotel document
        final hotelDocRef = await firestore.collection('Hotels').add({
          'Name': hotelData['name'],
          'Status': hotelData['status'],
          'Address': hotelData['address'],
          'LocationName': locationName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('Đã thêm khách sạn: ${hotelData['name']} tại $locationName');

        // Thêm Rooms như subcollection của Hotel
        final rooms = hotelData['rooms'] as List;
        for (final roomData in rooms) {
          await hotelDocRef.collection('Rooms').add({
            'RoomID': roomData['roomCode'],
            'price': roomData['price'],
            'maxGuest': roomData['maxGuest'],
            'roomstatus': roomData['roomStatus'],
            'imgurl': roomData['imgurl'],
            'createdAt': FieldValue.serverTimestamp(),
          });
          print(
              '  Đã thêm phòng: ${roomData['roomCode']} - ${hotelData['name']}');
        }
      }
    }

    print('Khởi tạo dữ liệu Hotels và Rooms thành công!');
  } catch (e) {
    print('Lỗi khi khởi tạo dữ liệu Hotels và Rooms: $e');
  }
}

