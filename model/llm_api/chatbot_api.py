import os
from dotenv import load_dotenv
import google.generativeai as genai

# Nạp file .env
load_dotenv()

# Lấy API key
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model_gem = genai.GenerativeModel("gemini-2.0-flash")


def translate_and_make_context_powerfull(text):
    prompt = f"""
    bạn là một người phiên dịch viên từ tiếng anh sang tiếng việt, mục đích làm cho câu mà bạn dịch trông giống con người. 
    bạn hãy dịch đoạn text tiếng anh, trong phần bạn trả về hãy thêm từ "trước mặt bạn", dưới đây là ví dụ:
    câu gốc : a man is walking a dog.
    bạn trả về : trước mặt bạn là người đàn ông đang dắt chó đi dạo.

    nếu câu gốc trống, bạn trả về "tôi không biết"

    giờ đến lượt bạn:
    câu gốc: {text}
    bạn trả về : 
    """
    response = model_gem.generate_content(prompt)
    return response.text
