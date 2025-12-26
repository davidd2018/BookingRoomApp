import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Khởi tạo dữ liệu địa điểm vào Firebase collection 'Locations'
/// Chạy hàm này một lần để tạo dữ liệu ban đầu
Future<void> initializeLocations() async {
  try {
    // Kiểm tra Firebase đã được khởi tạo chưa
    try {
      Firebase.app();
    } catch (e) {
      print('Lỗi: Firebase chưa được khởi tạo');
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // Dữ liệu các địa điểm
    final locations = [
      {
        'name': 'TpHCM',
        'description':
            'Thành phố Hồ Chí Minh là thành phố lớn nhất Việt Nam, trung tâm kinh tế, văn hóa và du lịch của cả nước. Nơi đây có nhiều điểm tham quan nổi tiếng như Dinh Độc Lập, Nhà thờ Đức Bà, Chợ Bến Thành và các khu vui chơi giải trí hiện đại.',
      },
      {
        'name': 'Hà Nội',
        'description':
            'Hà Nội là thủ đô của Việt Nam, nơi hội tụ văn hóa nghìn năm văn hiến. Thành phố có nhiều di tích lịch sử như Văn Miếu - Quốc Tử Giám, Hồ Hoàn Kiếm, Phố cổ Hà Nội và các bảo tàng văn hóa đặc sắc.',
      },
      {
        'name': 'Nha Trang',
        'description':
            'Nha Trang là thành phố biển xinh đẹp với những bãi biển trong xanh, cát trắng mịn. Nơi đây nổi tiếng với các hoạt động lặn biển, tham quan đảo và các resort sang trọng. Thành phố còn có nhiều điểm tham quan như Tháp Bà Ponagar, Viện Hải dương học.',
      },
      {
        'name': 'Đà Lạt',
        'description':
            'Đà Lạt là thành phố cao nguyên với khí hậu mát mẻ quanh năm, được mệnh danh là "thành phố ngàn hoa". Nơi đây có nhiều điểm tham quan như Hồ Xuân Hương, Thung lũng Tình Yêu, Đồi Cù, các vườn hoa và đồn điền cà phê đẹp mắt.',
      },
      {
        'name': 'Vũng Tàu',
        'description':
            'Vũng Tàu là thành phố biển gần Sài Gòn, nổi tiếng với những bãi biển đẹp và các món hải sản tươi ngon. Thành phố có nhiều điểm tham quan như Tượng Chúa Kitô Vua, Bãi Sau, Bãi Trước, Chùa Linh Sơn và các khu vui chơi giải trí ven biển.',
      },
    ];

    // Kiểm tra xem collection đã có dữ liệu chưa
    final existingLocations = await firestore.collection('Locations').get();

    if (existingLocations.docs.isNotEmpty) {
      print('Collection Locations đã có dữ liệu. Bỏ qua việc khởi tạo.');
      return;
    }

    // Thêm từng địa điểm vào Firestore
    for (final location in locations) {
      await firestore.collection('Locations').add({
        'name': location['name'],
        'description': location['description'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Đã thêm địa điểm: ${location['name']}');
    }

    print('Khởi tạo dữ liệu địa điểm thành công!');
  } catch (e) {
    print('Lỗi khi khởi tạo dữ liệu địa điểm: $e');
  }
}

