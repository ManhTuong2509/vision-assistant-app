import asyncio
import os
import edge_tts
from playsound import playsound

async def speak(text, voice="vi-VN-HoaiMyNeural", out="audio/tmp.mp3"):
    tts = edge_tts.Communicate(text, voice=voice)
    await tts.save(out)
    playsound(out)
    os.remove("audio/tmp.mp3")

async def speak_vietnamese(txt):
    await speak(txt)
