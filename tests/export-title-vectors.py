"""Native vector resources for authored title dial and five-character logotype.
No screenshots or font binaries are included in the game resources.
"""
import math,json
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'assets/title/ui';out.mkdir(parents=True,exist_ok=True)
cx,cy,r=784.8,435.4,404.7
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1152" viewBox="0 0 2560 1152"><g id="plane">','<g id="blueprint" fill="none" stroke="#0a3cb8" stroke-width="1.6" opacity="0">']
segments=[(0,cy,2560,cy),(cx,0,cx,1152),(cx-1400,cy-868,cx+1400,cy+868),(cx-700,cy+1260,cx+700,cy-1260)]
lengths=[]
for i,(x1,y1,x2,y2) in enumerate(segments):
 length=math.hypot(x2-x1,y2-y1);lengths.append(length)
 svg.append(f'<path id="bp{i+1}" d="M{x1},{y1} L{x2},{y2}" stroke-opacity=".5" stroke-dasharray="{length}" stroke-dashoffset="{length}"/>')
for i,rad in enumerate([r*1.55,r*.42],5):
 length=2*math.pi*rad;lengths.append(length)
 svg.append(f'<circle id="bp{i}" cx="{cx}" cy="{cy}" r="{rad}" stroke-opacity=".5" stroke-dasharray="{length}" stroke-dashoffset="{length}"/>')
for x,y,text in [(cx-r-96,cy-12,'90°'),(cx+14,cy+r+40,'180°'),(cx+r*1.55+16,cy-14,'R 1.55'),(1700,120,'FIG.0 — DRAFT / 草稿')]:
 svg.append(f'<text x="{x}" y="{y}" font-family="Fonts/NotoSansSC-Regular.ttf" font-size="22" letter-spacing="2.2" fill="#0a3cb8" stroke="none" opacity=".6">{text}</text>')
svg+=['</g>','<g id="ticks" stroke="#0a3cb8">']
for i in range(120):
 a=i/120*2*math.pi;major=i%10==0;r0=r+16;r1=r+(44 if major else 28)
 svg.append(f'<line x1="{cx+math.sin(a)*r0}" y1="{cy-math.cos(a)*r0}" x2="{cx+math.sin(a)*r1}" y2="{cy-math.cos(a)*r1}" stroke-width="{3 if major else 2}" opacity="{.8 if major else .55}"/>')
svg+=['</g>',f'<g id="arc"><circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#c9a25e" stroke-width="4" stroke-linecap="round" stroke-dasharray="{2*math.pi*r*50/360} {2*math.pi*r}"/><circle cx="1189.5" cy="435.4" r="7" fill="#c9a25e"/></g>','</g></svg>']
(out/'dial.svg').write_text('\n'.join(svg))
# Same installed font selected by the frozen H5 on the macOS baseline.
# Export only the authored logotype's path geometry, not reusable font software.
font=TTFont('/System/Library/Fonts/Supplemental/Songti.ttc',fontNumber=0)
glyphs=font.getGlyphSet();cmap=font.getBestCmap();scale=136/font['head'].unitsPerEm
advance=136*1.06;width=advance*5-136*.06;lineHeight=136*1.08
ascent=font['hhea'].ascent*scale;descent=-font['hhea'].descent*scale
baseline=(lineHeight-ascent-descent)/2+ascent
paths=[]
for i,ch in enumerate('反方向的猪'):
 pen=SVGPathPen(glyphs);glyphs[cmap[ord(ch)]].draw(pen)
 path=f'<path transform="translate({i*advance},{baseline}) scale({scale},{-scale})" d="{pen.getCommands()}"/>'
 paths.append(path)
svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width+10}" height="{lineHeight+10}" viewBox="0 0 {width+10} {lineHeight+10}">']
for name,fill,offset in [('shadow','#0140c4',5),('ink','#ffffff',0)]:
 svg.append(f'<g id="{name}" fill="{fill}" transform="translate({offset},{offset})"><g id="fan-{name}">{paths[0]}</g>'+''.join(paths[1:])+'</g>')
svg.append('</svg>');(out/'logotype.svg').write_text('\n'.join(svg))
(ROOT/'scripts/game/data/TitleVectorMetrics.lua').write_text('return {width='+str(width+10)+',height='+str(lineHeight+10)+',fanCenter=68,blueprintLengths={'+','.join(map(str,lengths))+'}}\n')
(ROOT/'docs/migration/title-vector-provenance.json').write_text(json.dumps({'dial':'frozen title-screen.js SVG construction','logotype':'five authored glyph outlines in Songti SC Black, matching macOS H5 font selection','fontBinaryIncluded':False,'remainingFontDifference':'Menu and dynamic labels use engine Noto Sans SC pending rendered comparison'},ensure_ascii=False,indent=2)+'\n')
print('Exported native dial (120 ticks, 6 blueprint paths, sweep) and five-glyph vector logotype.')
