#!/usr/bin/env python3
"""Generate praise + game-instruction voice clips via ElevenLabs TTS.

Usage:
  ELEVENLABS_API_KEY=... python3 tools/gen_praise_instructions.py --list-voices
  ELEVENLABS_API_KEY=... python3 tools/gen_praise_instructions.py \
      --voice-uk <voice_id> --voice-en <voice_id> [--only uk|en] [--dry-run]

Writes MP3s straight into assets/audio_mp3/ with the exact filenames
AudioService expects (praise_{uk|en}_1..5.mp3, instr_{uk|en}_{gameId}.mp3).
Re-running overwrites. Files are mono MP3 like the rest of the card audio.
"""
import argparse
import json
import os
import sys
import urllib.request

API = "https://api.elevenlabs.io/v1"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio_mp3")

PRAISE = {
    "uk": ["Молодець!", "Так!", "Ура!", "Супер!", "Вау!"],
    "en": ["Great job!", "Yes!", "Hooray!", "Awesome!", "Wow!"],
}

INSTRUCTIONS = {
    "uk": {
        "guess": "Слухай і знайди картку!",
        "memory": "Знайди однакові картки!",
        "bubbles": "Лопай бульбашки!",
        "odd_one_out": "Знайди зайву картку!",
        "opposites": "Знайди протилежне!",
        "repeat": "Повтори за мною!",
        "coloring": "Проведи пальчиком по картинці!",
    },
    "en": {
        "guess": "Listen and find the card!",
        "memory": "Find the matching cards!",
        "bubbles": "Pop the bubbles!",
        "odd_one_out": "Find the odd one out!",
        "opposites": "Find the opposite!",
        "repeat": "Repeat after me!",
        "coloring": "Trace the picture with your finger!",
    },
}

# eleven_multilingual_v2 handles Ukrainian well; v3 not needed for short bursts.
MODEL = "eleven_multilingual_v2"
VOICE_SETTINGS = {
    "stability": 0.45,          # a bit lively — these are praise bursts
    "similarity_boost": 0.85,
    "style": 0.35,
    "use_speaker_boost": True,
}


def key() -> str:
    k = os.environ.get("ELEVENLABS_API_KEY")
    if not k:
        sys.exit("Set ELEVENLABS_API_KEY")
    return k


def req(path, payload=None):
    r = urllib.request.Request(API + path,
                               data=json.dumps(payload).encode() if payload else None,
                               method="POST" if payload else "GET")
    r.add_header("xi-api-key", key())
    if payload:
        r.add_header("Content-Type", "application/json")
    return urllib.request.urlopen(r, timeout=120)


def list_voices():
    with req("/voices") as resp:
        for v in json.load(resp)["voices"]:
            labels = ", ".join(f"{k}={val}" for k, val in (v.get("labels") or {}).items())
            print(f"{v['voice_id']}  {v['name']}  [{labels}]")


def tts(voice_id: str, text: str, out_path: str, dry: bool):
    print(f"{'DRY ' if dry else ''}{os.path.basename(out_path)}  ←  {text!r}")
    if dry:
        return
    payload = {
        "text": text,
        "model_id": MODEL,
        "voice_settings": VOICE_SETTINGS,
        "output_format": "mp3_22050_32",
    }
    with req(f"/text-to-speech/{voice_id}?output_format=mp3_22050_32", payload) as resp:
        with open(out_path, "wb") as f:
            f.write(resp.read())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list-voices", action="store_true")
    ap.add_argument("--voice-uk")
    ap.add_argument("--voice-en")
    ap.add_argument("--only", choices=["uk", "en"])
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.list_voices:
        list_voices()
        return

    voices = {"uk": args.voice_uk, "en": args.voice_en}
    langs = [args.only] if args.only else ["uk", "en"]
    os.makedirs(OUT_DIR, exist_ok=True)

    for lang in langs:
        vid = voices[lang]
        if not vid:
            sys.exit(f"--voice-{lang} is required for lang '{lang}'")
        for i, text in enumerate(PRAISE[lang], start=1):
            tts(vid, text, os.path.join(OUT_DIR, f"praise_{lang}_{i}.mp3"), args.dry_run)
        for game_id, text in INSTRUCTIONS[lang].items():
            tts(vid, text, os.path.join(OUT_DIR, f"instr_{lang}_{game_id}.mp3"), args.dry_run)
    print("done")


if __name__ == "__main__":
    main()
