import os
import time
import requests
import RPi.GPIO as GPIO
from newspaper import Article
from openai import OpenAI
from elevenlabs import ElevenLabs, play
from luma.core.interface.serial import i2c
from luma.oled.device import ssd1306
from PIL import Image, ImageDraw, ImageFont
import multiprocessing

# ====== API KEYS ======
NEWS_API_KEY = "API_KEY"
OPENAI_API_KEY = "API_KEY"
ELEVENLABS_API_KEY = "API_KEY"
VOICE_ID = "ID"

CATEGORY = "general"
COUNTRY = "us"
PAGE_SIZE = 5

# ====== OLED DISPLAY SETUP ======
serial = i2c(port=1, address=0x3C)
device = ssd1306(serial, width=128, height=64)
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size=12)

def wrap_text(text, max_chars=20):
    words = text.split()
    lines = []
    current = ""
    for w in words:
        if len((current + " " + w).strip()) <= max_chars:
            current = f"{current} {w}".strip()
        else:
            lines.append(current)
            current = w
    if current:
        lines.append(current)
    return lines

def show_text(text, duration=None):
    lines = wrap_text(text)
    image = Image.new("1", device.size)
    draw = ImageDraw.Draw(image)
    draw.rectangle(device.bounding_box, outline=0, fill=0)
    for idx, line in enumerate(lines[:5]):
        draw.text((0, idx * 13), line, font=font, fill=255)
    device.display(image)
    if duration:
        time.sleep(duration)

# ====== BUTTON SETUP ======
BUTTON_WHITE = 17  # increment / next
BUTTON_BLUE = 27   # confirm / select / quit

GPIO.setmode(GPIO.BCM)
GPIO.setup(BUTTON_WHITE, GPIO.IN, pull_up_down=GPIO.PUD_UP)
GPIO.setup(BUTTON_BLUE, GPIO.IN, pull_up_down=GPIO.PUD_UP)

def wait_release(pin):
    while GPIO.input(pin) == GPIO.LOW:
        time.sleep(0.05)

# ====== ELEVEN LABS SETUP ======
elevenlabs = ElevenLabs(api_key=ELEVENLABS_API_KEY)

def tts_playback(audio):
    try:
        play(audio)
    except Exception as e:
        print(f"TTS playback error: {e}")

def speak_interruptible(text):
    audio = elevenlabs.text_to_speech.convert(
        text=text,
        voice_id=VOICE_ID,
        model_id="eleven_multilingual_v2",
        output_format="mp3_44100_128"
    )
    p = multiprocessing.Process(target=tts_playback, args=(audio,))
    p.start()

    while p.is_alive():
        if GPIO.input(BUTTON_BLUE) == GPIO.LOW:
            # Wait for button release to avoid multiple triggers
            while GPIO.input(BUTTON_BLUE) == GPIO.LOW:
                time.sleep(0.05)
            print("Stopping playback")
            p.terminate()  # kill playback immediately
            break
        time.sleep(0.1)
    p.join()

# ====== AGE INPUT VIA BUTTONS ======
def get_age():
    age = 0
    show_text(f"Set your age:\n{age}")
    confirmed = False
    while not confirmed:
        if GPIO.input(BUTTON_WHITE) == GPIO.LOW:
            wait_release(BUTTON_WHITE)
            age += 1
            if age > 99:  # reasonable upper bound
                age = 0
            show_text(f"Set your age:\n{age}")
        if GPIO.input(BUTTON_BLUE) == GPIO.LOW:
            wait_release(BUTTON_BLUE)
            confirmed = True
        time.sleep(0.1)
    return age if age > 0 else 12  # fallback if age 0

# ====== MAIN LOGIC ======
def main():
    show_text("Fetching news...", 2)
    resp = requests.get("https://newsapi.org/v2/top-headlines", params={
        "country": COUNTRY,
        "category": CATEGORY,
        "apiKey": NEWS_API_KEY,
        "pageSize": PAGE_SIZE
    })
    articles = resp.json().get("articles", [])
    saved = []
    for art in articles:
        try:
            a = Article(art.get("url", ""))
            a.download()
            a.parse()
            saved.append({"title": a.title, "content": a.text})
        except Exception as e:
            print(f"Article parse error: {e}")

    age = get_age()
    speak_interruptible(f"Summarizing news for a {age} year old.")
    show_text(f"Summarizing...\nAge: {age}", 2)

    client = OpenAI(api_key=OPENAI_API_KEY)
    summaries = []
    for art in saved:
        prompt = f"Summarize for a {age}-year-old in a fun and exciting way:\n\n{art['content']}"
        try:
            res = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}]
            )
            summary = res.choices[0].message.content.strip()
            # Limit summary length for faster TTS
            if len(summary) > 1000:
                summary = summary[:1000] + "..."
            summaries.append({
                "title": art["title"],
                "content": summary
            })
        except Exception as e:
            print(f"Summarization error: {e}")

    idx, running = 0, True
    show_text("White: Next\nBlue: Read/Quit", 2)

    while running:
        story = summaries[idx]
        show_text(f"Story {idx+1}:\n{story['title']}")
        time.sleep(0.1)
        if GPIO.input(BUTTON_WHITE) == GPIO.LOW:
            wait_release(BUTTON_WHITE)
            idx = (idx + 1) % len(summaries)
        elif GPIO.input(BUTTON_BLUE) == GPIO.LOW:
            wait_release(BUTTON_BLUE)
            show_text("Reading...\nPlease wait", 2)
            speak_interruptible(story["title"])
            speak_interruptible(story["content"])
            show_text("Blue: Quit\nWhite: Next", 2)
            waiting = True
            while waiting:
                if GPIO.input(BUTTON_WHITE) == GPIO.LOW:
                    wait_release(BUTTON_WHITE)
                    idx = (idx + 1) % len(summaries)
                    waiting = False
                elif GPIO.input(BUTTON_BLUE) == GPIO.LOW:
                    wait_release(BUTTON_BLUE)
                    running = False
                    waiting = False
                time.sleep(0.1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("Exiting...")
    finally:
        GPIO.cleanup()
        device.clear()
