
import googletrans
from googletrans import Translator


def translate_txt(text)->str:
    translator = Translator()
    result = translator.translate(text, src='en', dest='vi')
    return result.text