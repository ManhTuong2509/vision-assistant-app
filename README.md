# 0. Clone github này

    git clone https://github.com/thainguyen3250/ComputerVisionProj
    
    git push origin main

# 1. Tạo Môi Trường Ảo
1. tải python bản từ 3.8.xx đến 3.12.xx, sau đó add vào PATH
2. tạo môi trường ảo bằng lệnh (xx là phiên bản, vd python 3.12.9 thì là 3.12):


        py -3.xx -m venv venv

3. nhập



        /venv/Scripts/activate 



để vào môi trường ảo

4. tải các thư viện bổ trợ:
   

        pip install -r requirements.txt
   

    
lưu ý, trong file requirements.txt, bạn hãy điều chỉnh lại phiên bản torch cho hợp với GPU, nếu không có thì tải bản cpu, tuy nhiên xử lý ảnh hơi chậm
# 2. Cài Flutter
1. Cài đặt Flutter (Client)
Phần này hướng dẫn cài đặt Flutter SDK để chạy ứng dụng di động.

Tải và Cài đặt Flutter SDK:

Truy cập trang chủ của Flutter và làm theo hướng dẫn cài đặt chi tiết cho hệ điều hành của bạn (Windows, macOS, hoặc Linux):

https://flutter.dev/docs/get-started/install

2. Kiểm tra Cài đặt:

Sau khi cài đặt, chạy lệnh sau trong terminal để kiểm tra xem có thiếu công cụ nào không (VS Code):
    
    flutter doctor

3. Cài JDK

tải jdk23 tại đây: https://download.oracle.com/java/23/archive/jdk-23.0.2_windows-x64_bin.zip

Giải nén file trên vào 1 thư mục nào đó

vào environment, tạo variable mới tên JAVA_HOME, nhét đường dẫn file jdk đã giải nén vào và lưu lại

# 3. Tải ngrok

1. Tạo Tài khoản:

Truy cập https://ngrok.com/ và đăng ký một tài khoản (miễn phí).

2. Tải về và Cài đặt:

Tải về file thực thi Ngrok từ trang dashboard sau khi đăng nhập (có thể tìm và tải trong Microsoft Store).

Giải nén file và đặt nó ở một vị trí dễ truy cập.(khỏi cần nếu tải trên Ms Store)

3. Kết nối Tài khoản:

Trên trang dashboard Ngrok, sao chép "Authtoken" của bạn.

Chạy lệnh sau trong terminal để liên kết Ngrok với tài khoản của bạn:

    ngrok config add-authtoken <YOUR_AUTH_TOKEN_HERE>

# 4. Chạy Ứng Dụng

Bước 1: Chạy Server FastAPI
Mở Terminal 1 và kích hoạt môi trường ảo (nếu bạn đã tạo).

    #(Kích hoạt môi trường ảo nếu cần)
    #.\venv\Scripts\activate
       
    #Chạy server tại port 8000
    uvicorn main:app --host 0.0.0.0 --port 8000
    Lưu ý: Giữ terminal này luôn chạy. Server của bạn hiện đang lắng nghe tại http://localhost:8000.
Bước 2: Chạy Ngrok
vào 1 terminal khác, nhập :

    ngrok http 8000

lúc này nếu thành công thì terminal trả về :

    Session Status                online
    Account                       Your Name (Plan: Free)
    Forwarding                    https://[tên ngẫu nhiên].ngrok-free.app -> http://localhost:8000
    
Trong ví dụ này, địa chỉ bạn cần là: https://[tên ngẫu nhiên].ngrok-free.app    


vào thư mục mobile -> lib -> pages -> home sửa: _serverUrl = "https://[tên ngẫu nhiên].ngrok-free.app/upload"

mobile -> lib -> home -> loading sửa: final String head = "https://[tên ngẫu nhiên].ngrok-free.app"

Bước 3: Cắm điện thoại (Android) vào -> vào file mobile/lib/main.dart -> nhấn nút debug để flutter nạp ứng dụng lên android

xong bước này thì có thể rút dây kết nối giữa điện thoại và máy tính và không cần cắm nữa

# 5 Lưu Ý

khi đã làm xong các bước trên thì chỉ cần chạy server (FastAPI), vào ứng dụng trên điện thoại là chạy được bình thường
