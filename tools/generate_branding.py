from pathlib import Path
import json
import subprocess
import sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont


root = Path(__file__).resolve().parents[1]
assets = root / "mobile/flutter_app/assets/branding"
assets.mkdir(parents=True, exist_ok=True)
font = TTFont(sys.argv[1])
glyphs = font.getGlyphSet()


def character(value, center_x, center_y, fill):
    glyph = glyphs[font.getBestCmap()[ord(value)]]
    bounds = BoundsPen(glyphs)
    glyph.draw(bounds)
    left, bottom, right, top = bounds.bounds
    scale = min(216 / (right - left), 216 / (top - bottom))
    pen = SVGPathPen(glyphs)
    glyph.draw(pen)
    offset_x = center_x - scale * (left + right) / 2
    offset_y = center_y + scale * (bottom + top) / 2
    return f'<path fill="{fill}" transform="translate({offset_x} {offset_y}) scale({scale} {-scale})" d="{pen.getCommands()}"/>'


board = (
    '<defs><clipPath id="board"><rect x="12" y="12" width="488" height="488" rx="24"/></clipPath></defs>'
    '<g clip-path="url(#board)">'
    '<path fill="#f5e6c8" d="M12 12h488v488H12z"/>'
    '<path fill="#a06b3b" d="M256 12h244v244H256zM12 256h244v244H12z"/>'
    + character("三", 134, 134, "#1f1f1f")
    + character("棋", 378, 134, "#fffdf7")
    + '<circle cx="134" cy="378" r="72" fill="#fffdf7"/>'
    '<circle cx="134" cy="378" r="61" fill="none" stroke="#56452f" stroke-width="3"/>'
    '<circle cx="378" cy="378" r="72" fill="#1f1f1f"/>'
    '<circle cx="378" cy="378" r="61" fill="none" stroke="#f2eadb" stroke-width="3"/>'
    '</g><rect x="12" y="12" width="488" height="488" rx="24" fill="none" stroke="#56452f" stroke-width="8"/>'
)
logo = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><title>Sanqi: 三棋 and two game pieces on four alternating squares</title>{board}</svg>\n'
(assets / "sanqi-logo.svg").write_text(logo)
icon = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="#f5e6c8"/><g transform="translate(84 84) scale(0.671875)">{board}</g></svg>\n'
(assets / "sanqi-app-icon.svg").write_text(icon)


def export(source, output, size):
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "inkscape", str(source), "--export-type=png",
        f"--export-filename={output}", f"--export-width={size}",
        f"--export-height={size}",
    ], check=True, stdout=subprocess.DEVNULL)
    if source.name == "sanqi-app-icon.svg":
        subprocess.run(["magick", str(output), "-alpha", "off", f"PNG24:{output}"], check=True)


export(assets / "sanqi-logo.svg", assets / "sanqi-logo.png", 1024)
export(assets / "sanqi-app-icon.svg", assets / "sanqi-app-icon.png", 1024)
for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    export(assets / "sanqi-app-icon.svg", root / f"mobile/flutter_app/android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)
    export(assets / "sanqi-logo.svg", root / f"mobile/flutter_app/android/app/src/main/res/mipmap-{density}/launch_logo.png", size * 3)
catalog = root / "mobile/flutter_app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
for entry in json.loads((catalog / "Contents.json").read_text())["images"]:
    size = round(float(entry["size"].split("x")[0]) * float(entry["scale"].removesuffix("x")))
    export(assets / "sanqi-app-icon.svg", catalog / entry["filename"], size)
launch = root / "mobile/flutter_app/ios/Runner/Assets.xcassets/LaunchImage.imageset"
for suffix, size in [("", 168), ("@2x", 336), ("@3x", 504)]:
    export(assets / "sanqi-logo.svg", launch / f"LaunchImage{suffix}.png", size)
