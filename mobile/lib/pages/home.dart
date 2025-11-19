import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

// Thư viện gemini, mic, get giờ giấc và icon
import 'package:speech_to_text/speech_to_text.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// Thư viện .env
import 'package:flutter_dotenv/flutter_dotenv.dart';

//lấy api
final String geminiApiKey = dotenv.env['GEMINI_API_KEY']!;
final String openWeatherApiKey = dotenv.env['OPENWEATHER_API_KEY']!;
final String ngrokBaseUrl = dotenv.env['NGROK_BASE_URL']!;
// -------------------------------------------------

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  CameraController? cameraController;

  final String _serverUrl = "$ngrokBaseUrl/upload";
  final String _ocrUrl = "$ngrokBaseUrl/ocr";

  FlutterTts flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  GenerativeModel? _geminiModel;

  //trạng thái
  bool _isListening = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _setupCameraController();
    _setupTts();
    _initializeSpeech();
    _initializeGemini();

    Future.delayed(const Duration(milliseconds: 500), () {
      _speak("Xin chào! Nhấn vào nút mic ở dưới để ra lệnh nhé.");
    });
  }

  void _initializeGemini() {
    _geminiModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: geminiApiKey,
    );
  }

  void _initializeSpeech() async {
    try {
      await _speechToText.initialize(
        onError: (error) => print("Lỗi STT: $error"),
        onStatus: (status) => print("Trạng thái STT: $status"),
      );
    } catch (e) {
      print("Không thể khởi tạo STT: $e");
    }
  }

  Future<void> _setupTts() async {
    await flutterTts.setLanguage("vi-VN");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.5);
  }

  //thiết lập cam
  Future<void> _setupCameraController() async {
    List<CameraDescription> cameras = await availableCameras();
    if (cameras.isEmpty) return;

    cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await cameraController!.initialize();
    } catch (e) {
      print("Lỗi khởi tạo camera: $e");
    }
    if (mounted) setState(() {});
  }

  // Hàm Đọc text
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    final Completer<void> completer = Completer<void>();
    flutterTts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    flutterTts.setErrorHandler((msg) {
      if (!completer.isCompleted) completer.completeError(msg);
    });
    await flutterTts.speak(text);
    return completer.future;
  }

  // Hàm Kích hoạt mic
  void _startListening() async {
    if (_isProcessing || _isListening) return;

    bool available = await _speechToText.initialize();
    if (!available) {
      print("STT không khả dụng.");
      return;
    }

    setState(() => _isListening = true);

    await _speak("Tôi đang nghe...");

    if (mounted && _isListening) {
      _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            setState(() => _isListening = false);
            _speechToText.stop();
            print("Người dùng nói: ${result.recognizedWords}");
            if (result.recognizedWords.isNotEmpty) {
              _sendToGemini(result.recognizedWords);
            }
          }
        },
        localeId: "vi-VN",
      );
    }
  }

  // Hàm Gửi lệnh đến Gemini để phân tích intent
  Future<void> _sendToGemini(String userText) async {
    if (_geminiModel == null) {
      print("Gemini chưa sẵn sàng");
      return;
    }

    setState(() => _isProcessing = true);
    await _speak("Đang xử lý yêu cầu của bạn...");

    final prompt =
        """
      Bạn là một trợ lý AI cho người khiếm thị.
      Nhiệm vụ của bạn là phân loại yêu cầu của người dùng và CHỈ trả lời bằng một đối tượng JSON.
      
      Các "intent" (ý định) có thể có là:
      1. "describe_scene": Người dùng muốn mô tả những gì trước mặt họ. (ví dụ: "có gì trước mặt tôi", "mô tả xung quanh")
      2. "read_text": Người dùng muốn đọc văn bản. (ví dụ: "đọc tờ giấy này")
      3. "get_current_time": Người dùng muốn biết ngày/giờ hiện tại. (ví dụ: "mấy giờ rồi", "hôm nay ngày mấy")
      4. "get_weather": Người dùng muốn biết thời tiết. Bạn PHẢI trích xuất "location" (địa điểm).
      5. "general_question": Người dùng hỏi một câu hỏi kiến thức chung, TĨNH mà bạn biết.
      6. "get_help": Người dùng cần hướng dẫn sử dụng. (ví dụ: "làm sao để dùng?", "hướng dẫn tôi", "tôi không biết dùng", "trợ giúp")

      Định dạng JSON trả về PHẢI là:
      {
        "intent": "tên_intent",
        "response_tts": "câu_phản_hồi_ngắn_nếu_cần",
        "data": { "key": "value" } // (Chỉ dùng cho get_weather)
      }

      Ví dụ:
      - Nếu người dùng nói: "Trước mặt tôi có gì vậy?"
        Bạn trả về: {"intent": "describe_scene", "response_tts": "Hãy hướng điện thoại về phía bạn muốn nhận dạng nhé.", "data": {}}
      - Nếu người dùng nói: "Đọc cho tôi tờ giấy này."
        Bạn trả về: {"intent": "read_text", "response_tts": "Hãy đưa điện thoại vào văn bản bạn muốn biết.", "data": {}}
      - Nếu người dùng nói: "Mấy giờ rồi?"
        Bạn trả về: {"intent": "get_current_time", "response_tts": "Đang lấy thông tin giờ...", "data": {}}
      - Nếu người dùng nói: "Thời tiết ở Thành phố Hồ Chí Minh hôm nay?"
        Bạn trả về: {"intent": "get_weather", "response_tts": "Đang lấy thông tin thời tiết...", "data": {"location": "Ho Chi Minh City"}}
      - Nếu người dùng nói: "Thủ đô của Việt Nam là gì?"
        Bạn trả về: {"intent": "general_question", "response_tts": "Thủ đô của Việt Nam là Hà Nội.", "data": {}}
      - Nếu người dùng nói: "Làm sao để dùng ứng dụng này?" hoặc "Hướng dẫn tôi."
        Bạn trả về: {"intent": "get_help", "response_tts": "Tôi sẽ giúp bạn nhận biết thế giới. Bạn có thể nhấn nút mic và ra lệnh. Ví dụ, bạn muốn biết 'trước mặt bạn có gì', hay đọc giúp bạn một văn bản nào đó, hay bạn muốn biết thời tiết hôm nay như nào hay giờ giấc ra sao tôi điều có thể giúp bạn", "data": {}}
      - Nếu người dùng nói: "Thời tiết hôm nay thế nào?"
        Bạn trả về: {"intent": "general_question", "response_tts": "Bạn muốn biết thời tiết ở đâu ạ?", "data": {}}

      Yêu cầu của người dùng là: "$userText"
    """;

    try {
      final response = await _geminiModel!.generateContent([
        Content.text(prompt),
      ]);
      String geminiText = response.text ?? "";
      print("Gemini response (Raw): $geminiText");

      final RegExp jsonRegex = RegExp(r'(\{[\s\S]*\})');
      final Match? match = jsonRegex.firstMatch(geminiText);

      if (match == null || match.group(0) == null) {
        throw Exception(
          "Không tìm thấy JSON hợp lệ trong phản hồi của Gemini.",
        );
      }

      final String cleanJson = match.group(0)!;
      print("Gemini response (Cleaned JSON): $cleanJson");

      final Map<String, dynamic> responseData = jsonDecode(cleanJson);
      final String intent = responseData['intent'];
      final String ttsResponse = responseData['response_tts'];
      final Map<String, dynamic> data = responseData['data'] ?? {};

      await _handleGeminiResponse(intent, ttsResponse, data);
    } catch (e) {
      print("Lỗi khi gọi Gemini hoặc phân tích JSON: $e");
      await _speak("Tôi xin lỗi, đã có lỗi xảy ra khi xử lý yêu cầu.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Hàm xử lý phản hồi
  Future<void> _handleGeminiResponse(
    String intent,
    String ttsResponse,
    Map<String, dynamic> data,
  ) async {
    // 1. Luôn đọc phản hồi của Gemini
    await _speak(ttsResponse);

    // 2. Thực hiện hành động dựa trên intent
    switch (intent) {
      case 'describe_scene':
        await _triggerImageCaptioning();

      case 'read_text':
        await _triggerOCR();

      case 'get_current_time':
        await _speakCurrentTime();

      case 'get_weather':
        final String? location = data['location'];
        if (location != null && location.isNotEmpty) {
          await _triggerWeatherReport(location);
        } else {
          await _speak("Bạn chưa nói rõ địa điểm.");
        }
      case 'get_help':
      case 'general_question':
      default:
        break;
    }
  }

  // hàm lấy ngày giờ
  Future<void> _speakCurrentTime() async {
    await initializeDateFormatting('vi_VN', null);
    DateTime now = DateTime.now();
    String timeString = DateFormat('k \'giờ\' m \'phút\'', 'vi_VN').format(now);
    String dateString = DateFormat(
      'EEEE, \'ngày\' d \'tháng\' M \'năm\' y',
      'vi_VN',
    ).format(now);

    await _speak("Bây giờ là $timeString, $dateString.");
  }

  // hàm lấy thông tin thời tiết
  Future<void> _triggerWeatherReport(String location) async {
    setState(() => _isProcessing = true);
    try {
      String url =
          'https://api.openweathermap.org/data/2.5/weather?q=$location&appid=$openWeatherApiKey&units=metric&lang=vi';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        String description = data['weather'][0]['description'];
        double temp = data['main']['temp'];
        double feelsLike = data['main']['feels_like'];
        String city = data['name'];
        int tempInt = temp.round();
        int feelsLikeInt = feelsLike.round();

        String weatherString =
            "Thời tiết tại $city hiện tại: $description, $tempInt độ. Cảm giác như $feelsLikeInt độ.";
        print("Thời tiết: $weatherString");
        await _speak(weatherString);
      } else {
        await _speak("Tôi không tìm thấy thông tin thời tiết cho $location.");
      }
    } catch (e) {
      print("Lỗi khi lấy thời tiết: $e");
      await _speak("Đã có lỗi xảy ra khi lấy thông tin thời tiết.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // hàm chụp ảnh và nhận caption
  Future<void> _triggerImageCaptioning() async {
    setState(() => _isProcessing = true);
    try {
      if (cameraController == null || !cameraController!.value.isInitialized) {
        print("Camera chưa sẵn sàng");
        await _speak("Camera chưa sẵn sàng, vui lòng thử lại.");
        return;
      }
      print("Đang chụp ảnh cho Caption...");
      XFile imageFile = await cameraController!.takePicture();
      Uint8List imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      print("Đang gửi ảnh lên server (Caption)...");
      final String? vietnameseText = await _sendImageToServer(base64Image);

      if (vietnameseText != null && vietnameseText.isNotEmpty) {
        print("Đang đọc text (Caption): $vietnameseText");
        await _speak(vietnameseText);
      } else {
        await _speak("Tôi không nhận dạng được gì trong ảnh.");
      }
    } catch (e) {
      print("Lỗi khi chụp và gửi ảnh (Caption): $e");
      await _speak("Đã có lỗi xảy ra khi nhận dạng ảnh.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // hàm chụp ảnh và nhận text từ ảnh
  Future<void> _triggerOCR() async {
    setState(() => _isProcessing = true);
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (cameraController == null || !cameraController!.value.isInitialized) {
        print("Camera chưa sẵn sàng");
        await _speak("Camera chưa sẵn sàng, vui lòng thử lại.");
        return;
      }
      print("Đang chụp ảnh cho OCR...");
      XFile imageFile = await cameraController!.takePicture();
      Uint8List imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      print("Đang gửi ảnh lên server (OCR)...");
      final String? ocrText = await _sendImageToOCR(base64Image);

      if (ocrText != null && ocrText.isNotEmpty) {
        print("Đang đọc text (OCR): $ocrText");
        await _speak("Văn bản đọc được là: $ocrText");
      } else {
        await _speak("Tôi không đọc được chữ nào trong ảnh.");
      }
    } catch (e) {
      print("Lỗi khi chụp và gửi ảnh (OCR): $e");
      await _speak("Đã có lỗi xảy ra khi đọc chữ.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Gửi ảnh lên server (Backend) - CHO CAPTION
  Future<String?> _sendImageToServer(String base64Image) async {
    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'image_base64': base64Image,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        final String? vietnameseText = data['vietnamese_text'];
        return vietnameseText;
      } else {
        print("Lỗi (Caption): Server phản hồi ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Lỗi khi gửi request (Caption): $e");
      return null;
    }
  }

  // Gửi ảnh lên server (Backend) - CHO OCR
  Future<String?> _sendImageToOCR(String base64Image) async {
    try {
      final response = await http.post(
        Uri.parse(_ocrUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'image_base64': base64Image,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        final String? ocrText = data['ocr_text'];
        return ocrText;
      } else {
        print("Lỗi (OCR): Server phản hồi ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Lỗi khi gửi request (OCR): $e");
      return null;
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (cameraController == null ||
        cameraController?.value.isInitialized == false) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: MediaQuery.sizeOf(context).height * 0.70,
                width: MediaQuery.sizeOf(context).width * 0.90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey, width: 10),
                ),
                clipBehavior: Clip.hardEdge,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: CameraPreview(cameraController!),
                ),
              ),

              // Nút Mic
              GestureDetector(
                onTap: (_isProcessing || _isListening) ? null : _startListening,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    color: _isListening
                        ? Colors.red.shade700
                        : (_isProcessing
                              ? Colors.grey
                              : Colors.lightBlueAccent.withAlpha(
                                  (255 * 0.8).round(),
                                )),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.lightBlueAccent.withAlpha(
                          (255 * 0.6).round(),
                        ),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(
                            _isListening ? Icons.pause : Icons.mic,
                            color: Colors.white,
                            size: 45,
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
}
