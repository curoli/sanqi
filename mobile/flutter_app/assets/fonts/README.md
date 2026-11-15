# Bundled skin fonts

Unmodified files from [Google Fonts](https://github.com/google/fonts), pinned to
revision `cc39c4c2c304bc368c9b7c311ea2bcc6013299fe`. Each font's original SIL Open
Font License 1.1 and copyright notice is in `licenses/`. These files are bundled
for offline use; the application does not download fonts at runtime. The skin
chooser's Font licenses button exposes the licenses through Flutter's registry.

| Local file | Upstream directory/file | SHA-256 |
| --- | --- | --- |
| Inter.ttf | ofl/inter/Inter[opsz,wght].ttf | 29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031 |
| Lora.ttf | ofl/lora/Lora[wght].ttf | 822a6621ccbe8d97d20ac88c1c41f5615c9c2c202eaa75f272cd452aac6475a7 |
| Nunito.ttf | ofl/nunito/Nunito[wght].ttf | bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207 |
| SpaceMono.ttf | ofl/spacemono/SpaceMono-Regular.ttf | 95837e182baeeada83368f7748db28357f0a1b75c6b84ff7065b5edf933c8e18 |
| NotoSansArabic.ttf | ofl/notosansarabic/NotoSansArabic[wdth,wght].ttf | 63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e |
| NotoNaskhArabic.ttf | ofl/notonaskharabic/NotoNaskhArabic[wght].ttf | 67b5a525a661b607971fbd3f96a81b89d3a768e74534fca84f18ac97e6fab72f |

Lora skins use Noto Naskh Arabic as their Arabic fallback; the other families use
Noto Sans Arabic. Other scripts, including Chinese, fall back to the device's
fonts. Board labels and the outlined branding logo do not use these skin fonts.
