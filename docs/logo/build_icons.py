"""Genera todos los íconos de Cobrá (logo A · Moneda) y los copia al proyecto.

Requisitos (solo para regenerar): Chromium headless e ImageMagick (`convert`).
Uso: python3 docs/logo/build_icons.py
"""
import math, os, subprocess, tempfile, shutil, re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CHROME = os.environ.get("CHROME", "/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
P, T = "#6C63FF", "#03DAC6"

def arc(r=66, cx=128, cy=128, gap=46):
    a = math.radians(gap); x = cx + r * math.cos(a)
    return f"M{x:.1f} {cy - r*math.sin(a):.1f} A{r} {r} 0 1 0 {x:.1f} {cy + r*math.sin(a):.1f}"

def art(c="#fff", dot=T):
    return (f'<path d="{arc()}" fill="none" stroke="{c}" stroke-width="26" stroke-linecap="round"/>'
            f'<circle cx="194" cy="128" r="15" fill="{dot}"/>')

def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 256 256">{body}</svg>'

SVGS = {
  "rounded":    svg(f'<rect width="256" height="256" rx="58" fill="{P}"/>{art()}'),   # ícono con esquinas redondas
  "square":     svg(f'<rect width="256" height="256" fill="{P}"/>{art()}'),           # a sangre (iOS, maskable)
  "foreground": svg(art()),                                                           # capa frontal adaptable (transparente)
  "mono":       svg(art(dot="#fff")),                                                 # monocromo Android 13
}

def render(name, tmp):
    svg_path = os.path.join(tmp, name + ".svg"); open(svg_path, "w").write(SVGS[name])
    shot = os.path.join(tmp, name + "_raw.png"); out = os.path.join(tmp, name + ".png")
    # El viewport de headless es ~87px más bajo que la ventana: se pide más alto y se recorta.
    subprocess.run([CHROME, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                    "--default-background-color=00000000", "--window-size=1024,1111",
                    f"--screenshot={shot}", "file://" + svg_path], check=True, capture_output=True)
    subprocess.run(["convert", shot, "-crop", "1024x1024+0+0", "+repage", out], check=True)
    return out

def put(master, size, dest, flatten=False):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    cmd = ["convert", master, "-filter", "Lanczos", "-resize", f"{size}x{size}"]
    if flatten: cmd += ["-background", P, "-alpha", "remove", "-alpha", "off"]
    subprocess.run(cmd + [dest], check=True)

def main():
    tmp = tempfile.mkdtemp(); m = {n: render(n, tmp) for n in SVGS}
    res = f"{ROOT}/android/app/src/main/res"
    # Android: ícono clásico + adaptable (foreground/mono 108dp) + color de fondo
    for d, legacy, adaptive in (("mdpi",48,108),("hdpi",72,162),("xhdpi",96,216),("xxhdpi",144,324),("xxxhdpi",192,432)):
        put(m["rounded"], legacy, f"{res}/mipmap-{d}/ic_launcher.png")
        put(m["foreground"], adaptive, f"{res}/mipmap-{d}/ic_launcher_foreground.png")
        put(m["mono"], adaptive, f"{res}/mipmap-{d}/ic_launcher_monochrome.png")
    os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
    open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        '</adaptive-icon>\n')
    open(f"{res}/values/ic_launcher_background.xml", "w").write(
        f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">{P}</color>\n</resources>\n')
    # iOS: mismos tamaños que ya tiene el proyecto, sin transparencia
    ios = f"{ROOT}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for f in sorted(os.listdir(ios)):
        if f.endswith(".png"):
            w = int(subprocess.run(["identify", "-format", "%w", f"{ios}/{f}"], capture_output=True, text=True).stdout)
            put(m["square"], w, f"{ios}/{f}", flatten=True)
    # Web
    web = f"{ROOT}/web"
    put(m["rounded"], 64, f"{web}/favicon.png")
    for s in (192, 512):
        put(m["rounded"], s, f"{web}/icons/Icon-{s}.png")
        put(m["square"], s, f"{web}/icons/Icon-maskable-{s}.png", flatten=True)
    # Fuentes vectoriales del logo
    for n in ("rounded", "square", "foreground", "mono"):
        open(f"{ROOT}/docs/logo/final_{n}.svg", "w").write(SVGS[n])
    shutil.copy(m["rounded"], f"{ROOT}/docs/logo/cobra_icono_1024.png")
    shutil.rmtree(tmp); print("íconos generados")

if __name__ == "__main__":
    main()
