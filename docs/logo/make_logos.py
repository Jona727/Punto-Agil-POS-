"""Genera las propuestas de logo de Cobrá (SVG). Colores de la app."""
P="#6C63FF"   # violeta principal de la app
T="#03DAC6"   # turquesa secundario
INK="#1E1B4B" # texto oscuro

def arc(r, cx=128, cy=128, gap=42):
    import math
    a=math.radians(gap)
    x=cx+r*math.cos(a); y1=cy-r*math.sin(a); y2=cy+r*math.sin(a)
    return f"M{x:.1f} {y1:.1f} A{r} {r} 0 1 0 {x:.1f} {y2:.1f}"

def icon_a():  # Moneda: C blanca + punto turquesa (el "pago")
    return f'''<rect width="256" height="256" rx="58" fill="{P}"/>
<path d="{arc(66,gap=46)}" fill="none" stroke="#fff" stroke-width="26" stroke-linecap="round"/>
<circle cx="194" cy="128" r="15" fill="{T}"/>'''

def icon_b():  # C con check de cobro adentro
    return f'''<rect width="256" height="256" rx="58" fill="{P}"/>
<path d="{arc(74,gap=50)}" fill="none" stroke="#fff" stroke-width="24" stroke-linecap="round"/>
<path d="M104 131 L124 151 L160 105" fill="none" stroke="{T}" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>'''

def icon_c():  # Ticket con check
    teeth="L164 208 L152 196 L140 208 L128 196 L116 208 L104 196 L92 208 L80 196"
    return f'''<rect width="256" height="256" rx="58" fill="{P}"/>
<path d="M80 52 H176 V196 {teeth} Z" fill="#fff"/>
<rect x="98" y="80" width="60" height="10" rx="5" fill="{P}" opacity=".28"/>
<rect x="98" y="102" width="44" height="10" rx="5" fill="{P}" opacity=".28"/>
<rect x="98" y="124" width="52" height="10" rx="5" fill="{P}" opacity=".28"/>
<circle cx="178" cy="176" r="38" fill="{T}" stroke="{P}" stroke-width="10"/>
<path d="M162 177 L174 189 L196 163" fill="none" stroke="#fff" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>'''

def icon_d():  # C + rayo (ágil)
    return f'''<rect width="256" height="256" rx="58" fill="{P}"/>
<path d="{arc(72,gap=48)}" fill="none" stroke="#fff" stroke-width="24" stroke-linecap="round"/>
<path d="M140 84 L108 136 H128 L116 172 L154 118 H133 Z" fill="{T}" stroke="{T}" stroke-width="6" stroke-linejoin="round"/>'''

def word(x,y,size,color=INK):
    return f'<text x="{x}" y="{y}" font-family="Poppins, Montserrat, \'Segoe UI\', \'DejaVu Sans\', Arial, sans-serif" font-weight="800" font-size="{size}" fill="{color}" letter-spacing="-1">Cobr<tspan fill="{T}">á</tspan></text>'

CARDS=[("A","Moneda","Una “C” abierta como moneda, con el punto turquesa del pago.",icon_a),
       ("B","Check","La “C” guarda el tilde de cobro confirmado. Transmite “listo, cobrado”.",icon_b),
       ("C","Ticket","El ticket del punto de venta con el sello de pago. Muy literal y claro.",icon_c),
       ("D","Rayo","La “C” con un rayo: rapidez (“Ágil”). Más enérgico y moderno.",icon_d)]

W,H=1240,980
out=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
 f'<rect width="{W}" height="{H}" fill="#F4F3FF"/>',
 f'<text x="40" y="58" font-family="\'DejaVu Sans\', Arial, sans-serif" font-weight="700" font-size="28" fill="{INK}">Cobrá · 4 direcciones de logo</text>',
 f'<text x="40" y="88" font-family="\'DejaVu Sans\', Arial, sans-serif" font-size="16" fill="#6B6B8A">Colores de la app: violeta {P} y turquesa {T}. Abajo de cada una: como se ve chico (ícono del celular) y con el nombre.</text>']
for i,(k,name,desc,fn) in enumerate(CARDS):
    cx=40+(i%2)*600; cy=120+(i//2)*430
    out.append(f'<g transform="translate({cx},{cy})"><rect width="560" height="400" rx="24" fill="#fff" stroke="#E4E2FF"/>')
    out.append(f'<g transform="translate(28,28) scale(.78)">{fn()}</g>')
    out.append(f'<text x="260" y="70" font-family="\'DejaVu Sans\', Arial, sans-serif" font-weight="700" font-size="26" fill="{INK}">{k} · {name}</text>')
    # descripción en hasta 3 líneas (cada palabra va a la línea actual o a la siguiente)
    lines=[""]
    for w in desc.split():
        if len(lines[-1])+len(w)+1>30 and lines[-1]: lines.append("")
        lines[-1]+=w+" "
    for j,l in enumerate(lines[:3]):
        out.append(f'<text x="260" y="{104+j*21}" font-family="\'DejaVu Sans\', Arial, sans-serif" font-size="15" fill="#6B6B8A">{l.strip()}</text>')
    # tamaños chicos (ícono de celular)
    out.append(f'<g transform="translate(260,172) scale(.25)">{fn()}</g>')
    out.append(f'<g transform="translate(340,172) scale(.16)">{fn()}</g>')
    out.append(f'<text x="395" y="212" font-family="\'DejaVu Sans\', Arial, sans-serif" font-size="12" fill="#9A98B5">tamaño real</text>')
    # lockup horizontal
    out.append(f'<g transform="translate(28,262)"><g transform="scale(.34)">{fn()}</g>{word(96,60,50)}</g>')
    # sobre fondo oscuro
    out.append(f'<rect x="318" y="262" width="214" height="96" rx="16" fill="{INK}"/>')
    out.append(f'<g transform="translate(334,282) scale(.26)">{fn()}</g>{word(402,330,34,"#fff")}')
    out.append('</g>')
out.append('</svg>')
open('propuestas.svg','w').write("\n".join(out))
for k,name,_,fn in CARDS:
    open(f'icono_{k.lower()}_{name.lower()}.svg','w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 256 256">{fn()}</svg>')
print("ok")
