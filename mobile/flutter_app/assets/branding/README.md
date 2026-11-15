# Sanqi logo

The unpadded `sanqi-logo.svg` is the canonical logo used by the Flutter app and
repository README. Cream (#f5e6c8) and brown (#a06b3b) squares and piece colors
match `sanqi-render`. The characters use LXGW WenKai Medium outlines for a
gentle calligraphic style. The characters are paths, not text: no Chinese font is
needed on the device. `sanqi-logo.png` is a 1024-pixel export for sharing.

`sanqi-app-icon.svg` and its opaque RGB PNG export add a cream safe margin so
rounded launcher masks preserve all four fields. Android density-specific icons,
iPhone/iPad/App Store icons, and native launch images are generated from these
same sources. The operating system supplies the final app-icon corner mask.

Regenerate from the repository root on Debian with Python fontTools, Inkscape,
ImageMagick, and LXGW WenKai Medium version 1.530 from the
[official release](https://github.com/lxgw/LxgwWenKai/releases/tag/v1.530):

```bash
python3 tools/generate_branding.py /path/to/LXGWWenKai-Medium.ttf
```

The outlined characters derive from LXGW WenKai. See `FONT-LICENSE.txt`
for the attribution and SIL Open Font License 1.1, also bundled with the Flutter app.
