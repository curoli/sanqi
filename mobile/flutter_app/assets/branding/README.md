# Sanqi logo

The unpadded `sanqi-logo.svg` is the canonical logo used by the Flutter app and
repository README. The characters are paths, not text: no Chinese font is
needed on the device. `sanqi-logo.png` is a 1024-pixel export for sharing.

`sanqi-app-icon.svg` and its opaque RGB PNG export add a white safe margin so
rounded launcher masks preserve all four fields. Android density-specific icons,
iPhone/iPad/App Store icons, and native launch images are generated from these
same sources. The operating system supplies the final app-icon corner mask.

Regenerate from the repository root on Debian with Python fontTools, Inkscape,
ImageMagick, and the `fonts-droid-fallback` font package installed:

```bash
python3 tools/generate_branding.py /usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf
```

The outlined characters derive from Droid Sans Fallback. See `FONT-LICENSE.txt`
for the attribution and Apache 2.0 license, also bundled with the Flutter app.
