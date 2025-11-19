from fastapi import FastAPI,Query
from model.load_model import load_model_processing,img_to_text
from trans.eng_to_vi import translate_txt
from text_to_audio.vi_to_audio import speak_vietnamese
from model.llm_api.chatbot_api import translate_and_make_context_powerfull
from pydantic import BaseModel
import base64
import io
from PIL import Image
import numpy as np
import easyocr
import os 
from datetime import datetime 
app = FastAPI()

DEBUG_IMAGE_DIR = "debug_images"
os.makedirs(DEBUG_IMAGE_DIR, exist_ok=True)
print(f"--- Ảnh debug sẽ được lưu tại thư mục: {os.path.abspath(DEBUG_IMAGE_DIR)} ---")

app.state.isLoadModel = True

@app.get("/")
async def load_model():
    if app.state.isLoadModel:

        print("Đang tải model sinh caption...")
        app.state.processor, app.state.model = load_model_processing()
        print("Đã tải xong model sinh caption")

        print("Đang tải model OCR...")
        app.state.ocr_reader = easyocr.Reader(['vi', 'en'])
        print("Đã tải xong model OCR")
        app.state.isLoadModel = False
    return "Đã Load Thành Công"


## xóa model
@app.get("/remove_cache")
async def remove_cache():
    del app.state.processor
    del app.state.model
    del app.state.ocr_reader
    app.state.isLoadModel = True
    return "Đã xóa cache"

## test mô hình dịch, google dịch
@app.get("/eng_to_vi/{txt}")
async def eng_to_vi(txt):
    txt_vi = translate_txt(txt)
    return txt_vi




class ImagePayload(BaseModel):
    image_base64: str
    timestamp: str | None = None  # Nhận cả timestamp 
## hàm chính để gửi request
@app.post("/upload")
async def process_image_from_base64(payload: ImagePayload):
    
    # 1. Lấy chuỗi base64 từ payload
    base64_string = payload.image_base64
    
    # 2. Decode Base64 thành bytes
    try:
        image_bytes = base64.b64decode(base64_string)
    except Exception as e:
        print(f"Lỗi decode base64: {e}")
        return {"error": "Base64 không hợp lệ"}

    # 3. Đọc bytes vào stream trong bộ nhớ
    image_stream = io.BytesIO(image_bytes)

    # 4. Mở stream bằng PIL để có `raw_image`
    try:
        
        raw_image = Image.open(image_stream).convert('RGB')
    except Exception as e:
        print(f"Lỗi mở ảnh từ stream: {e}")
        return {"error": "Không thể đọc dữ liệu ảnh"}
    
    #5. gọi hàm xử lý sinh caption
    txt = img_to_text(raw_image, app.state.model, app.state.processor)
    print(f"Đã xử lý ảnh, text: {txt}")

    # 6. dịch
    txt_vi = translate_and_make_context_powerfull(txt)
    
    # 7. trả về kết quả json
    return {
        "original_text": txt,
        "vietnamese_text": txt_vi
    }


@app.post("/ocr")
async def process_ocr_from_base64(payload: ImagePayload):
    base64_string = payload.image_base64
    try:
        image_bytes = base64.b64decode(base64_string)
    except Exception as e:
        print(f"Lỗi decode base64: {e}")
        return {"error": "Base64 không hợp lệ"}
    image_stream = io.BytesIO(image_bytes)
    try:
        raw_image = Image.open(image_stream).convert("RGB")
    except Exception as e:
        print(f"Lỗi mở ảnh từ stream: {e}")
        return {"error":"Không thể đọc dữ liệu ảnh"}
    image_np = np.array(raw_image)
    ocr_results = app.state.ocr_reader.readtext(image_np, detail=0)
    full_text = " ".join(ocr_results)
    print(f"Đã xử lý ảnh (OCR), text: {full_text}")
    return{
        "ocr_text":full_text
    }

## test gemini
@app.get("/enrich_context/{context}")
async def enrich_context(context):
    txt_vi = translate_and_make_context_powerfull(context)
    return txt_vi

## test mô hình đọc
@app.get("/text_to_audio/{vitxt}")
async def text_to_audio(vitxt):
    await speak_vietnamese(vitxt)
    return {"status" :"đọc thành công"}