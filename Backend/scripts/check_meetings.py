"""Check meeting notes on real recordings against the real models (MN-32), one transcription model or several.

Each recording is cut as the app cuts it (pieces of 5 minutes, Ogg Opus, mono 16 kHz, about 24 kbps), each
piece is transcribed with the server's own prompt by each model named, and the half-hour and final notes are
written as the server writes them. For each recording and model it writes a Markdown report with the
transcript, the notes, the time taken and the audio's approximate cost, so the models can be compared side by
side. Nothing is sent to the app or stored on the server; the reports and pieces stay in --out, which Git
ignores. It makes real, paid Vertex calls with the ADC from scripts/login-vertex.ps1; needs ffmpeg.

Run from Backend/ with its virtualenv:
    .venv/Scripts/python.exe -X utf8 scripts/check_meetings.py [--models gemini-3.5-flash-lite,gemini-3.5-transcribe]
        [--language es] [--out .meeting-checks] recording.m4a [...]
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from types import SimpleNamespace

BACKEND = Path(__file__).resolve().parents[1]
env_file = BACKEND / ".env"
if env_file.exists():
    for line in env_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))
os.environ["DJANGO_SECRET_KEY"] = "local-check-only"
os.environ.setdefault("AI_VERTEX_PROJECT", "taskflow-511107")
adc = BACKEND / ".credentials" / "gcloud" / "application_default_credentials.json"
if adc.exists():
    os.environ.setdefault("GOOGLE_APPLICATION_CREDENTIALS", str(adc))
os.environ["DJANGO_SETTINGS_MODULE"] = "config.test_settings"
sys.path.insert(0, str(BACKEND))
import django  # noqa: E402

django.setup()
from django.test import override_settings  # noqa: E402

from core import meetings  # noqa: E402

PIECE_SECONDS = 300
CHAPTER_PIECES = 6
# US$ per minute of audio in (Vertex list prices checked on 2026-11-03 and 2026-11-06): Flash-Lite reads
# 32 audio tokens a second at $0.30 per million; Transcribe is billed per minute.
AUDIO_PRICE_PER_MINUTE = {"gemini-3.5-flash-lite": 32 * 60 * 0.30 / 1e6, "gemini-3.5-transcribe": 0.005}


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of",
                          "default=noprint_wrappers=1:nokey=1", str(path)], capture_output=True, text=True, check=True)
    return float(out.stdout.strip())


def cut(path, folder):
    """The recording as the app sends it: 5-minute pieces of Ogg Opus, mono, 16 kHz, about 24 kbps."""
    total = duration(path)
    pieces = []
    for index, start in enumerate(range(0, int(total) + 1, PIECE_SECONDS)):
        length = min(PIECE_SECONDS, total - start)
        if length < 1:
            break
        target = folder / f"piece-{index:03d}.ogg"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(start), "-t", str(length), "-i", str(path),
                        "-ac", "1", "-ar", "16000", "-c:a", "libopus", "-b:a", "24k", str(target)], check=True)
        pieces.append(SimpleNamespace(index=index, offset_seconds=start, duration_seconds=length, path=target))
    return pieces


def transcribe(pieces, model, language):
    out, context = [], None
    with override_settings(AI_MEETING_AUDIO_MODEL=model):
        for piece in pieces:
            text = meetings.transcribe_piece(piece.path.read_bytes(), "audio/ogg", context=context, language=language)
            out.append(SimpleNamespace(index=piece.index, offset_seconds=piece.offset_seconds,
                                       duration_seconds=piece.duration_seconds, text=text))
            context = meetings.last_sentence(text) or context
            print(f"  {model}: piece {piece.index} ({len(text.split())} words)", flush=True)
    return out


def notes(pieces):
    chapters = []
    for start in range(0, len(pieces), CHAPTER_PIECES):
        part = pieces[start:start + CHAPTER_PIECES]
        if not any(piece.text.strip() for piece in part):
            continue
        written = meetings.write_chapter_notes(part)
        first, last = part[0], part[-1]
        chapters.append(SimpleNamespace(start_minute=round(first.offset_seconds / 60),
                                        end_minute=round((last.offset_seconds + last.duration_seconds) / 60),
                                        title=written.title, notes=written.notes))
    return chapters, meetings.write_final_notes(pieces, chapters)


def report(name, model, pieces, chapters, final, seconds, minutes):
    price = AUDIO_PRICE_PER_MINUTE.get(model)
    lines = [f"# {name} · {model}", "",
             f"- Length: {minutes:.1f} min, {len(pieces)} pieces",
             f"- Time to transcribe and write the notes: {seconds:.0f} s",
             f"- Audio cost: about US${price * minutes:.3f}" if price else "- Audio cost: unknown model price",
             "", "## Notes", "", f"**{final.title}**", "", final.summary, "", "### Tasks", ""]
    for task in final.tasks:
        extra = " · ".join(filter(None, [task.who, task.when, "sure" if task.sure else "maybe"]))
        lines.append(f"- {task.title} ({extra})")
        lines += [f"    - {step}" for step in task.steps]
    lines += ["", "### Decisions", ""] + [f"- {d}" for d in final.decisions]
    lines += ["", "### Open questions", ""] + [f"- {q}" for q in final.open_questions]
    lines += ["", "### Half hours", ""]
    for chapter in chapters:
        lines += [f"**{chapter.start_minute}–{chapter.end_minute} min · {chapter.title}**", "", chapter.notes, ""]
    lines += ["## Transcript", "", meetings.transcript_of(pieces), ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("recordings", nargs="+", type=Path)
    parser.add_argument("--models", default="gemini-3.5-flash-lite,gemini-3.5-transcribe")
    parser.add_argument("--language", default="", help="the app's language hint (BCP-47), as the app sends it")
    parser.add_argument("--out", type=Path, default=BACKEND / ".meeting-checks")
    args = parser.parse_args()
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        sys.exit("ffmpeg and ffprobe are needed to cut the recordings.")
    args.out.mkdir(parents=True, exist_ok=True)
    for recording in args.recordings:
        with tempfile.TemporaryDirectory() as folder:
            print(f"{recording.name}: cutting", flush=True)
            cut_pieces = cut(recording, Path(folder))
            minutes = sum(piece.duration_seconds for piece in cut_pieces) / 60
            for model in [m.strip() for m in args.models.split(",") if m.strip()]:
                began = time.monotonic()
                pieces = transcribe(cut_pieces, model, args.language or None)
                chapters, final = notes(pieces)
                text = report(recording.name, model, pieces, chapters, final, time.monotonic() - began, minutes)
                target = args.out / f"{recording.stem}.{model}.md"
                target.write_text(text, encoding="utf-8")
                print(f"  wrote {target}", flush=True)


if __name__ == "__main__":
    main()
