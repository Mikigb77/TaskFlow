"""Build reproducible PCM fixtures; all input is synthetic, offline Windows TTS."""
import array
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave

target = Path(sys.argv[1]).resolve()
assets = target / "assets"
assets.mkdir(parents=True, exist_ok=True)
cases = json.loads(Path(__file__).with_name("cases.json").read_text(encoding="utf-8"))
for case in cases:
    samples = array.array("h", [0] * 4000)  # 250 ms lead-in.
    for index, text in enumerate(case["segments"]):
        with wave.open(str(target / f'{case["id"]}-{index}.wav'), "rb") as wav:
            assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 16000)
            part = array.array("h", wav.readframes(wav.getnframes()))
        if sys.byteorder != "little":
            part.byteswap()
        if index:
            samples.extend([0] * (case.get("pause_ms", 0) * 16))
        samples.extend(part)
    if "noise_snr_db" in case:
        # RMS over the original signal, deterministic white noise, fixed 12 dB SNR.
        rms = math.sqrt(sum(value * value for value in samples) / len(samples))
        sigma = rms / (10 ** (case["noise_snr_db"] / 20))
        rng = random.Random(case["id"])
        samples = array.array("h", (max(-32768, min(32767, round(value + rng.gauss(0, sigma)))) for value in samples))
    samples.extend([0] * 32000)  # Two seconds of trailing silence for normal endpointing.
    case["expected_words"] = " ".join(case["segments"])
    case["audio_duration_ms"] = len(samples) * 1000 // 16000
    if sys.byteorder != "little":
        samples.byteswap()
    raw = samples.tobytes()
    case["pcm_sha256"] = hashlib.sha256(raw).hexdigest()
    (assets / f'{case["id"]}.pcm').write_bytes(raw)
(assets / "cases.json").write_text(json.dumps(cases, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Prepared {len(cases)} synthetic PCM cases.")
