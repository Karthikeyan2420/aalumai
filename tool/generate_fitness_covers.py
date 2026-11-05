"""Download real fitness cover photos into assets/images/fitness."""
from __future__ import annotations

import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets" / "images" / "fitness"

# Wikimedia Commons — direct file URLs (not /thumb/… sizes).
URLS: dict[str, str] = {
    "cover_arm_shoulder_dumbbell.png": "https://upload.wikimedia.org/wikipedia/commons/6/6f/Biceps_curl_2.jpg",
    "cover_back_chest_dumbbell.png": "https://upload.wikimedia.org/wikipedia/commons/8/8e/Bench_press_1.jpg",
    "cover_abs_dumbbell.png": "https://upload.wikimedia.org/wikipedia/commons/1/1e/Abdominal_exercise.jpg",
    "cover_leg_dumbbell.png": "https://upload.wikimedia.org/wikipedia/commons/5/53/Squat_%28exercise%29.jpg",
    "cover_arm_shoulder_bodyweight.png": "https://upload.wikimedia.org/wikipedia/commons/c/c5/Push-up.jpg",
    "cover_back_chest_bodyweight.png": "https://upload.wikimedia.org/wikipedia/commons/a/ae/Pull-up_bar.jpg",
    "cover_abs_bodyweight.png": "https://upload.wikimedia.org/wikipedia/commons/4/4e/Sit-up.jpg",
    "cover_leg_bodyweight.png": "https://upload.wikimedia.org/wikipedia/commons/5/5a/Lunges.jpg",
    "cover_cardio_bodyweight.png": "https://upload.wikimedia.org/wikipedia/commons/8/82/Running_woman.jpg",
    "cover_warmup_bodyweight.png": "https://upload.wikimedia.org/wikipedia/commons/a/a3/Stretching.jpg",
    "focus_body_male.png": "https://upload.wikimedia.org/wikipedia/commons/6/6f/Biceps_curl_2.jpg",
    "focus_body_female.png": "https://upload.wikimedia.org/wikipedia/commons/8/82/Running_woman.jpg",
}


def fetch(url: str, dest: Path) -> None:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (compatible; OneAppFitness/1.0)",
            "Accept": "image/*,*/*",
        },
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        data = resp.read()
    dest.write_bytes(data)
    print(f"OK {dest.name} ({len(data)} bytes)")


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    failed = []
    for name, url in URLS.items():
        dest = ROOT / name
        try:
            fetch(url, dest)
        except Exception as e:
            failed.append((name, str(e)))
            print(f"FAIL {name}: {e}")
    if failed:
        raise SystemExit(f"{len(failed)} downloads failed")


if __name__ == "__main__":
    main()
