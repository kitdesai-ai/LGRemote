#!/usr/bin/env python3
# Generates App Store marketing screenshots (1320 x 2868) for LG webOS Remote.
# Each slide: branded gradient + headline + the app UI inside an iPhone frame.
# App UI is recreated faithfully from the SwiftUI source at 393x852 logical pt.

import os, math, base64, cairosvg

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "screenshots")
os.makedirs(OUT, exist_ok=True)

CW, CH = 1320, 2868            # required 6.9" screenshot size
BLUE  = "#0A84FF"
GREEN = "#34C759"
TEAL  = "#36E0A0"              # brand accent (matches app icon)
ORANGE= "#FF9F0A"
RED   = "#FF453A"

# ---------- tiny svg helpers (operate in 393x852 screen space) ----------

def txt(x, y, s, text, color="#FFFFFF", weight="bold", anchor="start",
        op=1.0, family="DejaVu Sans", spacing=None, mono=False):
    fam = "DejaVu Sans Mono" if mono else family
    sp = f' letter-spacing="{spacing}"' if spacing is not None else ""
    text = text.replace("&", "&amp;")
    return (f'<text x="{x}" y="{y}" font-family="{fam}" font-size="{s}" '
            f'font-weight="{weight}" fill="{color}" fill-opacity="{op}" '
            f'text-anchor="{anchor}"{sp}>{text}</text>')

def rrect(x, y, w, h, r, fill="#FFFFFF", op=1.0, stroke=None, sop=1.0, sw=1):
    s = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" '
         f'fill="{fill}" fill-opacity="{op}"')
    if stroke:
        s += f' stroke="{stroke}" stroke-opacity="{sop}" stroke-width="{sw}"'
    return s + "/>"

def circle(cx, cy, r, fill="none", op=1.0, stroke=None, sop=1.0, sw=1):
    s = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" fill-opacity="{op}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-opacity="{sop}" stroke-width="{sw}"'
    return s + "/>"

# ---------- icon glyphs (simple, recognizable, SF-symbol inspired) ----------

def i_power(cx, cy, size, color, sw):
    k = size / 1024.0
    return (f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round">'
            f'<path d="M{cx} {cy-212*k} V {cy-62*k}"/>'
            f'<path d="M{cx-120*k} {cy-152*k} a {170*k} {170*k} 0 1 0 {240*k} 0"/></g>')

def i_chevron(cx, cy, w, direction, color, sw):
    h = w * 0.6
    if direction == "up":    p = [(cx-w/2, cy+h/2), (cx, cy-h/2), (cx+w/2, cy+h/2)]
    elif direction == "down":p = [(cx-w/2, cy-h/2), (cx, cy+h/2), (cx+w/2, cy-h/2)]
    elif direction == "left":p = [(cx+h/2, cy-w/2), (cx-h/2, cy), (cx+h/2, cy+w/2)]
    else:                    p = [(cx-h/2, cy-w/2), (cx+h/2, cy), (cx-h/2, cy+w/2)]
    pts = " ".join(f"{a:.1f},{b:.1f}" for a, b in p)
    return (f'<polyline points="{pts}" fill="none" stroke="{color}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>')

def i_speaker(cx, cy, s, color, kind):
    body = (f'<path d="M{cx-0.52*s} {cy-0.13*s} H{cx-0.34*s} L{cx-0.12*s} {cy-0.34*s} '
            f'V{cy+0.34*s} L{cx-0.34*s} {cy+0.13*s} H{cx-0.52*s} Z" fill="{color}"/>')
    sw = 0.085 * s
    g = f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round">'
    bx = cx + 0.18 * s
    if kind == "plus":
        g += (f'<path d="M{bx} {cy-0.16*s} V{cy+0.16*s}"/>'
              f'<path d="M{bx-0.16*s} {cy} H{bx+0.16*s}"/>')
    elif kind == "minus":
        g += f'<path d="M{bx-0.16*s} {cy} H{bx+0.16*s}"/>'
    elif kind == "wave":
        g += (f'<path d="M{cx+0.02*s} {cy-0.18*s} a {0.22*s} {0.22*s} 0 0 1 0 {0.36*s}"/>'
              f'<path d="M{cx+0.14*s} {cy-0.3*s} a {0.38*s} {0.38*s} 0 0 1 0 {0.6*s}"/>')
    elif kind == "slash":
        g += f'<path d="M{cx+0.0*s} {cy-0.3*s} L{cx+0.36*s} {cy+0.3*s}"/>'
    g += "</g>"
    return body + g

def i_rect_input(cx, cy, s, color, sw):
    o = 0.12 * s
    return (f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linejoin="round">'
            + rrect(cx-0.5*s+o, cy-0.4*s-o, 0.78*s, 0.62*s, 0.1*s, "none", 0, color, 1, sw)
            + rrect(cx-0.5*s-o, cy-0.4*s+o, 0.78*s, 0.62*s, 0.1*s, "none", 0, color, 1, sw)
            + "</g>")

def i_gear(cx, cy, s, color, holecolor, op=1.0):
    ro, ri, hole = 0.5*s, 0.36*s, 0.17*s
    pts = []
    for i in range(16):
        r = ro if i % 2 == 0 else ri
        a = i * (2*math.pi/16) - math.pi/16
        pts.append((cx + r*math.cos(a), cy + r*math.sin(a)))
    poly = " ".join(f"{a:.1f},{b:.1f}" for a, b in pts)
    return (f'<polygon points="{poly}" fill="{color}" fill-opacity="{op}"/>'
            + circle(cx, cy, hole, holecolor, 1.0))

def i_dpad(cx, cy, s, color, holecolor, op=1.0):
    arm = 0.34 * s
    return (f'<g fill="{color}" fill-opacity="{op}">'
            + rrect(cx-arm/2, cy-0.5*s, arm, s, 0.1*s, color, op)
            + rrect(cx-0.5*s, cy-arm/2, s, arm, 0.1*s, color, op)
            + "</g>" + circle(cx, cy, 0.12*s, holecolor, 1.0))

def i_tv(cx, cy, s, color, op=1.0):
    return (rrect(cx-0.5*s, cy-0.42*s, s, 0.66*s, 0.1*s, color, op)
            + rrect(cx-0.2*s, cy+0.28*s, 0.4*s, 0.07*s, 0.03*s, color, op))

def i_check_circle(cx, cy, s, color):
    p = f'<path d="M{cx-0.22*s} {cy} L{cx-0.05*s} {cy+0.17*s} L{cx+0.25*s} {cy-0.16*s}" fill="none" stroke="#FFFFFF" stroke-width="{0.1*s}" stroke-linecap="round" stroke-linejoin="round"/>'
    return circle(cx, cy, 0.5*s, color, 1.0) + p

def i_antenna(cx, cy, s, color):
    sw = 0.07 * s
    g = f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round">'
    g += (f'<path d="M{cx-0.12*s} {cy-0.18*s} a {0.2*s} {0.2*s} 0 0 0 0 {0.36*s}" transform="rotate(0)"/>')
    g += f'<path d="M{cx-0.26*s} {cy-0.3*s} a {0.36*s} {0.36*s} 0 0 0 0 {0.6*s}"/>'
    g += f'<path d="M{cx+0.12*s} {cy-0.18*s} a {0.2*s} {0.2*s} 0 0 1 0 {0.36*s}"/>'
    g += f'<path d="M{cx+0.26*s} {cy-0.3*s} a {0.36*s} {0.36*s} 0 0 1 0 {0.6*s}"/>'
    g += "</g>"
    g += circle(cx, cy, 0.1*s, color, 1.0)
    g += f'<path d="M{cx} {cy} L{cx} {cy+0.4*s}" stroke="{color}" stroke-width="{sw}" stroke-linecap="round"/>'
    return g

def i_plug(cx, cy, s, color):
    sw = 0.08 * s
    return (f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">'
            + rrect(cx-0.42*s, cy-0.22*s, 0.5*s, 0.44*s, 0.08*s, "none", 0, color, 1, sw)
            + f'<path d="M{cx+0.08*s} {cy-0.12*s} h{0.22*s}"/>'
            + f'<path d="M{cx+0.08*s} {cy+0.12*s} h{0.22*s}"/>'
            + f'<path d="M{cx+0.3*s} {cy-0.12*s} v{0.24*s}"/>'
            + "</g>")

def i_house(cx, cy, s, color):
    return (f'<path d="M{cx} {cy-0.45*s} L{cx+0.45*s} {cy-0.02*s} L{cx+0.32*s} {cy-0.02*s} '
            f'L{cx+0.32*s} {cy+0.42*s} L{cx-0.32*s} {cy+0.42*s} L{cx-0.32*s} {cy-0.02*s} '
            f'L{cx-0.45*s} {cy-0.02*s} Z" fill="{color}"/>')

def i_back(cx, cy, s, color):
    sw = 0.09 * s
    return (f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">'
            f'<path d="M{cx+0.32*s} {cy+0.28*s} a {0.3*s} {0.3*s} 0 1 0 -{0.3*s} -{0.3*s} L{cx-0.34*s} {cy-0.02*s}"/>'
            f'<polyline points="{cx-0.34*s:.1f},{cy-0.24*s:.1f} {cx-0.34*s:.1f},{cy-0.02*s:.1f} {cx-0.12*s:.1f},{cy-0.02*s:.1f}"/>'
            f'</g>')

def i_refresh(cx, cy, s, color):
    sw = 0.13 * s
    return (f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">'
            f'<path d="M{cx+0.45*s} {cy-0.05*s} a {0.45*s} {0.45*s} 0 1 1 -0.13*s -{0.32*s}"/>'
            f'<polyline points="{cx+0.18*s:.1f},{cy-0.45*s:.1f} {cx+0.45*s:.1f},{cy-0.4*s:.1f} {cx+0.4*s:.1f},{cy-0.12*s:.1f}"/>'
            f'</g>')

def i_pencil(cx, cy, s, color):
    sw = 0.1 * s
    return (f'<g fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">'
            f'<path d="M{cx-0.35*s} {cy+0.35*s} L{cx+0.25*s} {cy-0.25*s} L{cx+0.38*s} {cy-0.12*s} L{cx-0.22*s} {cy+0.48*s} Z" transform="translate(0,-0.06)"/>'
            f'<path d="M{cx-0.4*s} {cy+0.42*s} h{0.7*s}"/></g>')

# ---------- iOS status bar (drawn in screen space) ----------

def status_bar(dark=True):
    c = "#FFFFFF"
    g = txt(28, 34, 17, "9:41", c, "bold")
    # right cluster: signal bars, wifi, battery
    bx = 300
    bars = ""
    for i in range(4):
        h = 5 + i*3
        bars += rrect(bx + i*7, 30 - h, 4.5, h, 1.2, c, 1.0)
    wifi = (f'<g fill="none" stroke="{c}" stroke-width="2.2" stroke-linecap="round">'
            f'<path d="M333 22 a 9 9 0 0 1 14 0"/><path d="M336 26 a 5 5 0 0 1 8 0"/></g>'
            + circle(340, 30, 1.4, c, 1.0))
    batt = (rrect(353, 22, 22, 11, 3, "none", 0, c, 0.5, 1.4)
            + rrect(355, 24, 16, 7, 1.5, c, 1.0)
            + rrect(376, 25, 1.8, 5, 1, c, 0.6))
    return g + bars + wifi + batt

def nav_bar(title):
    return (status_bar()
            + txt(196.5, 78, 17, title, "#FFFFFF", "bold", "middle")
            + txt(369, 78, 16, "Done", BLUE, "bold", "end"))

def drag_indicator():
    return rrect(196.5-18, 12, 36, 5, 2.5, "#FFFFFF", 0.3)

# ---------- screens (each returns inner svg for 0..393 x 0..852) ----------

def screen_main():
    s = ['<rect x="0" y="0" width="393" height="852" fill="#000000"/>']
    s.append(status_bar())
    # top bar
    s.append(txt(24, 100, 27, "LG webOS Remote", "#FFFFFF", "bold"))
    s.append(circle(30, 120, 4, GREEN, 1.0))
    s.append(txt(42, 125, 13, "Connected", GREEN, "bold"))
    # power button (connected -> red)
    pcx, pcy = 196.5, 250
    s.append(circle(pcx, pcy, 44, RED, 0.14))
    s.append(circle(pcx, pcy, 44, "none", 1.0, RED, 0.6, 2))
    s.append(i_power(pcx, pcy, 60, RED, 5.5))
    # control pills
    top = 330
    def pill(px, label, value, top_icon, bot_icon):
        out = [rrect(px, top, 120, 188, 24, "#FFFFFF", 0.05, "#FFFFFF", 0.08, 1)]
        cxp = px + 60
        out.append(top_icon(cxp, top + 36))
        out.append(txt(cxp, top + 72 + 18, 11, label, "#FFFFFF", "bold", "middle", 0.35, spacing=2))
        if value is not None:
            out.append(txt(cxp, top + 72 + 40, 18, value, "#FFFFFF", "bold", "middle", 0.8, mono=True))
        out.append(bot_icon(cxp, top + 188 - 36))
        return "".join(out)
    s.append(pill(60.5, "VOL", "14",
                  lambda x, y: i_speaker(x, y, 26, "#FFFFFF", "plus"),
                  lambda x, y: i_speaker(x, y, 26, "#FFFFFF", "minus")))
    s.append(pill(212.5, "CH", None,
                  lambda x, y: i_chevron(x, y, 22, "up", "#FFFFFF", 4),
                  lambda x, y: i_chevron(x, y, 22, "down", "#FFFFFF", 4)))
    # input button
    iy = 548
    s.append(rrect(24, iy, 345, 56, 16, "#FFFFFF", 0.05, "#FFFFFF", 0.08, 1))
    s.append(i_rect_input(52, iy + 28, 26, "#FFFFFF", 2.4))
    s.append(txt(76, iy + 35, 16, "Input", "#FFFFFF", "bold"))
    s.append(txt(330, iy + 34, 14, "Live TV", "#FFFFFF", "bold", "end", 0.4))
    s.append(i_chevron(352, iy + 28, 9, "right", "#FFFFFF", 2.6))
    # mute button
    my = 628
    mw = 150
    s.append(rrect(196.5 - mw/2, my, mw, 48, 24, "#FFFFFF", 0.05, "#FFFFFF", 0.08, 1))
    s.append(i_speaker(196.5 - 38, my + 24, 22, "#FFFFFF", "wave"))
    s.append(txt(196.5 + 6, my + 30, 15, "Mute", "#FFFFFF", "bold", "middle", 0.6))
    # FABs
    fy = 760
    s.append(circle(54, fy, 26, "#FFFFFF", 0.06, "#FFFFFF", 0.15, 1))
    s.append(i_dpad(54, fy, 24, "#FFFFFF", "#0a0a0a", 0.85))
    s.append(circle(339, fy, 26, "#FFFFFF", 0.06, "#FFFFFF", 0.15, 1))
    s.append(i_gear(339, fy, 24, "#FFFFFF", "#0a0a0a", 0.85))
    return "".join(s)

def screen_onboarding():
    s = ['<rect x="0" y="0" width="393" height="852" fill="#000000"/>']
    s.append(status_bar())
    s.append(i_tv(196.5, 300, 70, "#FFFFFF", 0.16))
    s.append(txt(196.5, 410, 24, "No TV Connected", "#FFFFFF", "bold", "middle"))
    s.append(txt(196.5, 452, 15, "Set up your LG TV to get started.", "#FFFFFF", "normal", "middle", 0.45))
    s.append(txt(196.5, 476, 15, "Make sure it's on and connected to", "#FFFFFF", "normal", "middle", 0.45))
    s.append(txt(196.5, 500, 15, "the same network.", "#FFFFFF", "normal", "middle", 0.45))
    s.append(rrect(32, 712, 329, 56, 16, BLUE, 1.0))
    s.append(txt(196.5, 747, 17, "Get Started", "#FFFFFF", "bold", "middle"))
    return "".join(s)

def screen_dpad():
    s = ['<rect x="0" y="0" width="393" height="852" fill="#000000"/>']
    s.append(drag_indicator())
    s.append(nav_bar("Navigate"))
    cx, cy = 196.5, 360
    s.append(circle(cx, cy, 110, "#FFFFFF", 0.04, "#FFFFFF", 0.08, 1))
    s.append(i_chevron(cx, cy - 76, 22, "up", "#FFFFFF", 4))
    s.append(i_chevron(cx, cy + 76, 22, "down", "#FFFFFF", 4))
    s.append(i_chevron(cx - 76, cy, 22, "left", "#FFFFFF", 4))
    s.append(i_chevron(cx + 76, cy, 22, "right", "#FFFFFF", 4))
    s.append(circle(cx, cy, 36, "#FFFFFF", 0.08, "#FFFFFF", 0.12, 1))
    s.append(txt(cx, cy + 6, 16, "OK", "#FFFFFF", "bold", "middle", 0.7))
    # pills row
    py = 540
    labels = [("Back", i_back), ("Settings", i_gear), ("Home", i_house)]
    widths = [104, 128, 108]
    gap = 16
    total = sum(widths) + gap*2
    x = (393 - total) / 2
    for (label, icon), w in zip(labels, widths):
        s.append(rrect(x, py, w, 40, 20, "#FFFFFF", 0.05, "#FFFFFF", 0.08, 1))
        if label == "Settings":
            s.append(i_gear(x + 22, py + 20, 15, "#FFFFFF", "#0a0a0a", 0.5))
        else:
            s.append(f'<g fill-opacity="0.5">{icon(x + 22, py + 20, 15, "#FFFFFF")}</g>')
        s.append(txt(x + 38, py + 25, 14, label, "#FFFFFF", "bold", "start", 0.5))
        x += w + gap
    return "".join(s)

def _list_row(y, icon_fn, title, subtitle, selected, sub_color="#FFFFFF", sub_op=0.35, mono_sub=False, sub_dot=None):
    out = []
    bg_op = 0.08 if selected else 0.04
    st = BLUE if selected else "#FFFFFF"
    st_op = 0.3 if selected else 0.06
    out.append(rrect(24, y, 345, 64, 14, BLUE if selected else "#FFFFFF",
                     0.08 if selected else 0.04, st, st_op, 1))
    icbg = BLUE if selected else "#FFFFFF"
    icop = 0.2 if selected else 0.06
    out.append(rrect(38, y + 14, 36, 36, 10, icbg, icop))
    out.append(icon_fn(56, y + 32))
    out.append(txt(90, y + 28, 16, title, "#FFFFFF", "bold"))
    if sub_dot is not None:
        out.append(circle(94, y + 44, 3, sub_dot, 1.0))
        out.append(txt(104, y + 48, 12, subtitle, "#FFFFFF", "bold", "start", 0.35))
    else:
        out.append(txt(90, y + 48, 13, subtitle, sub_color, "bold", "start", sub_op, mono=mono_sub))
    if selected:
        out.append(i_check_circle(351, y + 32, 22, BLUE))
    return "".join(out)

def screen_discovery():
    s = ['<rect x="0" y="0" width="393" height="852" fill="#000000"/>']
    s.append(nav_bar("Settings"))
    # section header
    s.append(txt(24, 138, 13, "DISCOVERED TVS", "#FFFFFF", "bold", "start", 0.5, spacing=1.5))
    s.append(i_refresh(355, 132, 15, BLUE))
    # rows
    s.append(_list_row(160, lambda x, y: i_tv(x, y, 22, BLUE, 1.0),
                       "LG OLED55 C3", "192.168.1.42", True, mono_sub=True))
    s.append(_list_row(236, lambda x, y: i_tv(x, y, 22, "#FFFFFF", 0.5),
                       "LG webOS TV", "192.168.1.77", False, mono_sub=True))
    # connection section
    s.append(txt(24, 360, 13, "TV CONNECTION", "#FFFFFF", "bold", "start", 0.5, spacing=1.5))
    s.append(rrect(24, 378, 345, 132, 16, "#FFFFFF", 0.05, "#FFFFFF", 0.08, 1))
    s.append(i_antenna(48, 412, 18, "#FFFFFF"))
    s.append(txt(74, 404, 11, "IP ADDRESS", "#FFFFFF", "bold", "start", 0.4, spacing=1))
    s.append(txt(74, 426, 16, "192.168.1.42", "#FFFFFF", "bold", "start", 1.0, mono=True))
    s.append(f'<rect x="40" y="444" width="313" height="1" fill="#FFFFFF" fill-opacity="0.1"/>')
    s.append(i_antenna(48, 478, 18, "#FFFFFF"))
    s.append(txt(74, 470, 11, "MAC ADDRESS", "#FFFFFF", "bold", "start", 0.4, spacing=1))
    s.append(txt(74, 492, 16, "A1:B2:C3:D4:E5:F6", "#FFFFFF", "bold", "start", 1.0, mono=True))
    # tips
    s.append(txt(24, 560, 13, "TIPS", "#FFFFFF", "bold", "start", 0.5, spacing=1.5))
    s.append(rrect(24, 578, 345, 110, 16, "#FFFFFF", 0.03, "#FFFFFF", 0.06, 1))
    for idx, (n, line) in enumerate([("1", "Keep your phone and TV on the"),
                                     ("2", "Enable Turn on via Wi-Fi for")]):
        ry = 604 + idx*44
        s.append(circle(46, ry + 6, 11, "#FFFFFF", 0.08))
        s.append(txt(46, ry + 11, 12, n, "#FFFFFF", "bold", "middle", 0.3))
        s.append(txt(66, ry + 4, 14, line, "#FFFFFF", "normal", "start", 0.6))
        s.append(txt(66, ry + 24, 14, "same network." if idx == 0 else "Wake-on-LAN.",
                     "#FFFFFF", "normal", "start", 0.6))
    return "".join(s)

def screen_inputs():
    s = ['<rect x="0" y="0" width="393" height="852" fill="#000000"/>']
    s.append(drag_indicator())
    s.append(nav_bar("Switch Input"))
    rows = [
        (lambda x, y: i_antenna(x, y, 20, "#FFFFFF"), "Live TV", "Connected", True, GREEN),
        (lambda x, y: i_plug(x, y, 20, "#FFFFFF"), "HDMI 1 — Apple TV", "Connected", False, GREEN),
        (lambda x, y: i_plug(x, y, 20, "#FFFFFF"), "HDMI 2 — PlayStation", "Connected", False, GREEN),
        (lambda x, y: i_plug(x, y, 20, "#FFFFFF"), "HDMI 3", "Not connected", False, "#8A8A8E"),
    ]
    y = 120
    for icon_fn, title, sub, sel, dot in rows:
        s.append(_list_row(y, icon_fn, title, sub, sel, sub_dot=dot))
        y += 76
    return "".join(s)

# ---------- compose marketing slide ----------

def _png_data_uri(path):
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("ascii")
    return "data:image/png;base64," + b64


def compose(filename, headline, subtitle, screen_svg=None, glow=TEAL,
            screen_image=None, draw_island=None):
    """Render one marketing slide.

    Pass either screen_svg (synthetic UI) or screen_image (path to a real PNG
    capture, e.g. a 1320x2868 simulator screenshot). The chosen screen is placed
    inside the iPhone frame with the headline/gradient flair.
    """
    use_image = screen_image is not None
    if draw_island is None:
        # synthetic screens draw their own status bar but no island; real
        # screenshots already include the top of the device, so skip it there.
        draw_island = not use_image

    # phone geometry on the 1320x2868 canvas
    SW, SH = 864, int(864 * 852 / 393)         # screen px
    FP = 30                                      # frame bezel
    FW, FH = SW + 2*FP, SH + 2*FP
    FX = (CW - FW) // 2
    FY = 770
    SX, SY = FX + FP, FY + FP

    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" '
               f'xmlns:xlink="http://www.w3.org/1999/xlink" '
               f'width="{CW}" height="{CH}" viewBox="0 0 {CW} {CH}">')
    svg.append('<defs>')
    svg.append('<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
               '<stop offset="0" stop-color="#0c1320"/>'
               '<stop offset="0.55" stop-color="#0a0e16"/>'
               '<stop offset="1" stop-color="#070a10"/></linearGradient>')
    svg.append(f'<radialGradient id="glow" cx="0.5" cy="0.32" r="0.6">'
               f'<stop offset="0" stop-color="{glow}" stop-opacity="0.22"/>'
               f'<stop offset="1" stop-color="{glow}" stop-opacity="0"/></radialGradient>')
    svg.append('<linearGradient id="frame" x1="0" y1="0" x2="1" y2="1">'
               '<stop offset="0" stop-color="#2b313c"/>'
               '<stop offset="0.5" stop-color="#161a22"/>'
               '<stop offset="1" stop-color="#2b313c"/></linearGradient>')
    svg.append(f'<clipPath id="screenclip"><rect x="{SX}" y="{SY}" width="{SW}" height="{SH}" rx="86" ry="86"/></clipPath>')
    svg.append('</defs>')

    svg.append(f'<rect width="{CW}" height="{CH}" fill="url(#bg)"/>')
    svg.append(f'<rect width="{CW}" height="{CH}" fill="url(#glow)"/>')

    # headline: each line is one color (wrap whole line in *..* for accent),
    # centered with text-anchor=middle so spacing is exact.
    hy = 360
    fs = 104
    for line in headline:
        accent = line.startswith("*") and line.endswith("*")
        text = line.strip("*")
        color = TEAL if accent else "#FFFFFF"
        svg.append(f'<text x="{CW/2}" y="{hy}" font-family="DejaVu Sans" '
                   f'font-size="{fs}" font-weight="bold" fill="{color}" '
                   f'text-anchor="middle">{text}</text>')
        hy += 124
    if subtitle:
        svg.append(f'<text x="{CW/2}" y="{hy+6}" font-family="DejaVu Sans" font-size="46" '
                   f'font-weight="normal" fill="#FFFFFF" fill-opacity="0.5" '
                   f'text-anchor="middle">{subtitle}</text>')

    # soft shadow under phone
    svg.append(f'<ellipse cx="{CW/2}" cy="{FY+FH+30}" rx="{FW*0.46}" ry="46" fill="#000000" fill-opacity="0.45"/>')

    # phone frame
    svg.append(rrect(FX-6, FY-6, FW+12, FH+12, 122, "#000000", 0.6))
    svg.append(f'<rect x="{FX}" y="{FY}" width="{FW}" height="{FH}" rx="116" ry="116" fill="url(#frame)"/>')
    svg.append(rrect(FX+8, FY+8, FW-16, FH-16, 108, "#000000", 1.0))

    # screen content, clipped to rounded rect
    svg.append(f'<g clip-path="url(#screenclip)">')
    if use_image:
        # real screenshot fills the screen area (slice = fill, cropping overflow)
        svg.append(f'<image x="{SX}" y="{SY}" width="{SW}" height="{SH}" '
                   f'preserveAspectRatio="xMidYMid slice" '
                   f'xlink:href="{_png_data_uri(screen_image)}"/>')
    else:
        # synthetic UI: nested svg scaled from 393x852
        svg.append(f'<svg x="{SX}" y="{SY}" width="{SW}" height="{SH}" viewBox="0 0 393 852" preserveAspectRatio="xMidYMid slice">')
        svg.append(screen_svg)
        svg.append('</svg>')
    svg.append('</g>')

    # dynamic island
    if draw_island:
        isl_w, isl_h = 250, 74
        svg.append(rrect(CW/2 - isl_w/2, SY + 30, isl_w, isl_h, isl_h/2, "#000000", 1.0))

    svg.append('</svg>')
    data = "".join(svg)

    png = os.path.join(OUT, filename)
    cairosvg.svg2png(bytestring=data.encode(), write_to=png,
                     output_width=CW, output_height=CH)
    print("wrote", png)

# ---------- slides ----------
# screen factory is a function so the synthetic UI is only built when needed.
# To use a REAL screenshot for any slide, drop a PNG with the same filename into
# screenshots/raw/ (e.g. screenshots/raw/01-remote.png) and rerun — it will be
# framed with the same headline/gradient instead of the drawn UI.

SLIDES = [
    ("01-remote.png",    ["Your remote,", "*reimagined.*"],
     "Power, volume, channels — all in one tap.", screen_main,      TEAL),
    ("02-input.png",     ["Switch inputs", "*in one tap.*"],
     "HDMI, Live TV, and everything else.",        screen_inputs,   "#6EA8FF"),
    ("03-dpad.png",      ["Navigate without", "*looking down.*"],
     "A full D-pad for every app and menu.",       screen_dpad,     TEAL),
    ("04-discovery.png", ["Finds your TV", "*automatically.*"],
     "No IP addresses. No fuss. Just tap.",         screen_discovery, "#6EA8FF"),
]
# Note: screen_onboarding() (the "No TV Connected" screen) is still defined above
# and can be re-added here if wanted, but is intentionally not shipped as a slide.

RAW = os.path.join(OUT, "raw")

for fname, headline, subtitle, screen_fn, glow in SLIDES:
    raw_path = os.path.join(RAW, fname)
    if os.path.exists(raw_path):
        compose(fname, headline, subtitle, glow=glow, screen_image=raw_path)
        print("   ^ framed real screenshot from raw/" + fname)
    else:
        compose(fname, headline, subtitle, screen_svg=screen_fn(), glow=glow)

print("done")
