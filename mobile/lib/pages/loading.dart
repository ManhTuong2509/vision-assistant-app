import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  final String head = dotenv.env['NGROK_BASE_URL']!;
  late Future<String> _dataFuture;

  // SỬA 1: Thêm biến này để theo dõi
  bool _navigationScheduled = false;

  Future<void> loadModel() async {
    Response res = await get(Uri.parse("$head/"));
    print("Model loaded: ${res.body}");
  }

  Future<String> translate() async {
    Response res = await get(
      Uri.parse("$head/eng_to_vi/We will be your eyes."),
    );
    print(res.body);
    return res.body;
  }

  Future<String> _loadDataSequentially() async {
    print("Bắt đầu tải Model...");
    await loadModel();
    print("Tải Model xong.");

    print("Bắt đầu dịch...");
    String result = await translate();
    print("Dịch xong.");

    return result;
  }

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadDataSequentially();
  }

  // hàm điều hướng riêng
  void _navigateToHome() {
    // Nó sẽ thay thế màn hình Loading bằng màn hình Home
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<String>(
        future: _dataFuture,
        builder: (context, snapshot) {
          // TRƯỜNG HỢP 1: Đang tải
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Đang tải dữ liệu..."),
                ],
              ),
            );
          }

          // TRƯỜNG HỢP 2: Bị lỗi
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Đã xảy ra lỗi: ${snapshot.error}",
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          // TRƯỜNG HỢP 3: Tải xong (thành công)
          if (snapshot.connectionState == ConnectionState.done) {
            // SỬA 3: Chỉ lên lịch MỘT LẦN
            if (!_navigationScheduled) {
              _navigationScheduled = true; // Đánh dấu đã lên lịch
              // Hẹn giờ 3 giây rồi mới gọi hàm điều hướng
              Future.delayed(Duration(seconds: 3), () {
                // Kiểm tra xem widget còn trên cây widget không
                if (mounted) {
                  _navigateToHome();
                }
              });
            }

            // Luôn hiển thị UI "Tải xong" trong 3 giây đó
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 50),
                  SizedBox(height: 20),
                  Text("Tải xong!"),
                  SizedBox(height: 10),
                  Text("Kết quả: ${snapshot.data}"),
                ],
              ),
            );
          }

          // Trường hợp khác
          return Container();
        },
      ),
    );
  }
}
