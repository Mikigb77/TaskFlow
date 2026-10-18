"""WebKit renders of every public page for the UX web loop's reviewers: Safari's engine, on Windows.

WSL here can't run Playwright's WebKit (its libraries aren't packaged for this Linux), so this runs
on Windows with Playwright for Python, in its own folder outside the repos (set up 2026-10-18):

    C:\\Users\\mikig\\.taskflow-tools\\webkit\\venv\\Scripts\\python.exe -X utf8 .claude/ux-web/webkit_renders.py

The website's production build must be served on http://localhost:3000 from WSL (`npm run start`),
as for the Chromium renders. Output: ../TaskFlowWeb/artifacts/ux-web/webkit/, with INDEX.md.
It's Playwright's WebKit on Windows: close to Safari's engine, but not Safari on an iPhone.
"""
import os
import sys
import time
from datetime import datetime
from pathlib import Path

TOOLS = Path.home() / ".taskflow-tools" / "webkit"
os.environ.setdefault("PLAYWRIGHT_BROWSERS_PATH", str(TOOLS / "browsers"))
from playwright.sync_api import Error, sync_playwright  # noqa: E402

BASE = os.environ.get("UX_WEB_BASE", "http://localhost:3000").rstrip("/")
OUT = Path(__file__).resolve().parents[3] / "TaskFlowWeb" / "artifacts" / "ux-web" / "webkit"
PAGES = [
    ("home", "en", "/"),
    *[(page, language, f"/{page}/" if language == "en" else f"/{language}/{page}/")
      for page in ("privacy", "terms", "legal", "delete-account") for language in ("en", "es", "ca")],
    ("not-found", "en", "/ux-renders-missing-page/"),
]
FOLD_LINE = """(y) => {
  const line = document.createElement('div');
  line.setAttribute('data-ux-fold', '');
  line.style.cssText = `position:absolute;left:0;right:0;top:${y}px;height:2px;` +
    'background:#ff00ff;z-index:2147483647;pointer-events:none';
  document.body.appendChild(line);
}"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rows, problems = [], []
    started = time.monotonic()
    with sync_playwright() as p:
        browser = p.webkit.launch()
        try:
            devices = {
                "mobile": dict(p.devices["iPhone 13"]),
                "desktop": {"viewport": {"width": 1440, "height": 1000}, "device_scale_factor": 1},
            }
            for device, options in devices.items():
                for theme in ("light", "dark"):
                    context = browser.new_context(**options, color_scheme=theme)
                    for page_name, language, path in PAGES:
                        page = context.new_page()
                        errors = []
                        page.on("pageerror", lambda error, errors=errors: errors.append(str(error)[:200]))
                        page.on("console", lambda message, errors=errors: errors.append(message.text[:200])
                                if message.type == "error" else None)
                        try:
                            response = page.goto(BASE + path, wait_until="networkidle", timeout=30000)
                            page.evaluate("document.fonts.ready")
                            stem = f"{page_name}.{language}.{device}.{theme}"
                            page.screenshot(path=str(OUT / f"{stem}.fold.png"))
                            height = page.viewport_size["height"]
                            page.evaluate(FOLD_LINE, height)
                            # 1 px per CSS px, as the Chromium full renders; 3x would pass 32,767 px on long pages.
                            page.screenshot(path=str(OUT / f"{stem}.full.png"), full_page=True, scale="css")
                            rows.append((stem, path, response.status if response else "?", errors))
                        except Error as error:
                            problems.append(f"{page_name} {language} {device} {theme}: {str(error)[:200]}")
                        finally:
                            page.close()
                    context.close()
        finally:
            browser.close()
    seconds = time.monotonic() - started
    lines = [
        "# WebKit renders",
        "",
        f"Written by `.claude/ux-web/webkit_renders.py` on {datetime.now():%Y-%m-%d %H:%M}, from {BASE}, in {seconds:.0f} s.",
        "",
        "- **Engine:** Playwright's WebKit on Windows. It's close to Safari's engine, but it isn't Safari on an "
        "iPhone; fonts and form controls can still differ there.",
        "- **mobile:** Playwright's iPhone 13 profile (390 × 664 at 3×, touch). **desktop:** 1440 × 1000 at 1×.",
        "- **fold** is the first viewport, at device scale. **full** is the whole page at 1 px per CSS px, with a magenta line where the first viewport ends.",
        "- Compare them with the Chromium renders in the folder above. A difference is a WebKit finding.",
        "",
        "| Render | URL | Status | Console or page errors |",
        "|---|---|---|---|",
    ]
    for stem, path, status, errors in rows:
        lines.append(f"| `{stem}.fold.png`, `.full.png` | `{path}` | {status} | {'; '.join(errors) or 'none'} |")
    if problems:
        lines += ["", "## Not rendered", *[f"- {problem}" for problem in problems]]
    (OUT / "INDEX.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(rows) * 2} PNGs in {seconds:.0f} s; {len(problems)} not rendered; index at {OUT / 'INDEX.md'}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
