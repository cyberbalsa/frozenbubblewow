#!/usr/bin/env python3
"""Build one-bit WoW mask atlases for the reveals in Frozen Bubble's CStuff.xs."""
import argparse
import subprocess
import tempfile
import math
from pathlib import Path
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def pow2(n):
    return 1 << (n - 1).bit_length()


def write_blp(path, mask):
    """BC1 with white endpoints. Index zero is white, index three transparent."""
    w, h = mask.size
    stride = (w + 7) // 8
    bits = mask.tobytes()
    # Each group of four mask pixels becomes one row of a BC1 block.
    nibble = [sum(3 << (i * 2) for i in range(4) if not (n & (8 >> i))) for n in range(16)]
    high = bytes(nibble[b >> 4] for b in range(256))
    low = bytes(nibble[b & 15] for b in range(256))
    blocks = bytearray(b'\xff\xff\xff\xff\x00\x00\x00\x00' * (w * h // 16))
    for row in range(4):
        rows = b''.join(bits[y*stride:(y+1)*stride] for y in range(row, h, 4))
        if w == 4:
            blocks[4+row::8] = rows.translate(high)
        else:
            blocks[4+row::16] = rows.translate(high)
            blocks[12+row::16] = rows.translate(low)
    header = struct.pack('<4sI4B2I', b'BLP2', 1, 2, 1, 0, 0, w, h)
    header += struct.pack('<16I', 1172, *([0]*15)) + struct.pack('<16I', len(blocks), *([0]*15))
    path.write_bytes(header + bytes(1024) + blocks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('upstream', type=Path)
    args = parser.parse_args()
    media = ROOT / 'FrozenBubble' / 'Media'
    dest = media / 'Reveals'
    dest.mkdir(exist_ok=True)
    specs = []

    def store(name, rank, steps):
        w,h = rank.size
        columns = min(steps, 2048//w)
        capacity = columns * min(math.ceil(steps/columns), 2048//h)
        sheets = []
        for first in range(0,steps,capacity):
            n = min(steps-first,capacity)
            sw,sh = max(4,pow2(min(n,columns)*w)),max(4,pow2(math.ceil(n/columns)*h))
            atlas = Image.new('1',(sw,sh))
            for i in range(n):
                frame = rank.point([255 if v<=first+i else 0 for v in range(256)], '1')
                atlas.paste(frame,(i%columns*w,i//columns*h))
            write_blp(dest / f'{name}-{len(sheets)+1}.blp',atlas)
            sheets.append(f'{{{sw},{sh}}}')
        specs.append(f'    ["{name}"]={{w={w},h={h},steps={steps},cols={columns},capacity={capacity},sheets={{{",".join(sheets)}}}}},')

    build=tempfile.TemporaryDirectory()
    scratch=Path(build.name)
    code=(args.upstream/'lib/Games/FrozenBubble/CStuff.xs').read_text()
    (scratch/'transitions.inc').write_text(code[code.index('void copy_line('):code.index('void shrink_(')])
    exe=scratch/'reference'
    subprocess.run(['cc','-std=gnu99','-O2','-I',str(scratch),str(ROOT/'tools/transition_surface.c'),'-lm','-o',str(exe)],check=True)

    def native(effect,plate=None):
        data=plate.tobytes() if plate is not None else None
        raw=subprocess.run([str(exe),effect,str(args.upstream/'share')],input=data,stdout=subprocess.PIPE,check=True).stdout
        return Image.frombytes('L',(640,480),raw[1:]),raw[0]

    for effect in ('horizontal','vertical','bars','squares','circle-out','circle-in','plasma','points'):
        rank,steps=native(effect)
        size={'horizontal':(1,480),'vertical':(640,1),'bars':(16,40),'squares':(20,15)}.get(effect,rank.size)
        small=rank.resize(size,Image.Resampling.NEAREST)
        assert small.resize(rank.size,Image.Resampling.NEAREST).tobytes()==rank.tobytes()
        store(effect,small,steps)

    def brightness(name,plate):
        screen=Image.new('RGB',(640,480)); screen.paste(plate.convert('RGB'))
        if plate.mode=='RGBA':
            w,h=plate.size
            cut=Image.new('1',(max(4,pow2(w)),max(4,pow2(h))),1)
            cut.paste(plate.getchannel('A').point([255]*255+[0],'1'),(0,0))
            write_blp(dest/(name+'-cut.blp'),cut)
        for order in ('dark','light'):
            rank,steps=native(order,screen)
            store(name+'-'+order,rank.crop((0,0,*plate.size)),steps)

    for layout in ('solo','versus','arena'):
        from_sheet=Image.open(media/f'{layout}-background.tga').convert('RGB')
        scale=from_sheet.width//1024
        plate=from_sheet.crop((0,0,640*scale,480*scale)).resize((640,480),Image.Resampling.LANCZOS)
        brightness(layout,plate)
    for prefix,size in [('',32),('mini-',16)]:
        for family in ('bubble','bubble-symbol'):
            for i in range(1,9):
                name=f'{prefix}{family}{i}'
                plate=Image.open(media/(name+'.tga')).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
                brightness(name,plate)
    for name,w,h in [('compressor',252,51),('next-rim',39,39),('mini-rim',20,20),
                     ('training-clock',96,75),('progress-green',7,7),('progress-red',7,7)]:
        brightness(name,Image.open(media/(name+'.tga')).crop((0,0,w,h)))
    # The first strip is SDLPango's opening time, centered in its 96px field.
    # Composite it before calculating luminance, as print_ does on the clock.
    lettering=Image.open(media/'hud-lettering.tga').convert('RGBA')
    clock=Image.open(media/'training-clock.tga').convert('RGBA')
    clock.alpha_composite(lettering.crop((0,0,96,24)),(0,25))
    clock.save(media/'opening-training-clock.tga')
    brightness('opening-training-clock',clock.crop((0,0,96,75)))
    # All used glyphs fit within the desktop's 480px capture height.
    assert lettering.getchannel('A').getbbox()[3]<=480
    brightness('hud-lettering',lettering.crop((0,0,lettering.width,480)))
    names=Image.open(media/'name-lettering.tga').convert('RGBA')
    cut=names.getchannel('A').point([255]*255+[0],'1')
    write_blp(dest/'name-lettering-cut.blp',cut)
    for name,gray in [('name-shadow',0),('name-lettering',255)]:
        for order in ('dark','light'):
            rank,steps=native(order,Image.new('RGB',(640,480),(gray,)*3))
            assert rank.getextrema()[0]==rank.getextrema()[1]
            store(name+'-'+order,rank.crop((0,0,1,1)),steps)
    build.cleanup()
    meta=ROOT/'FrozenBubble'/'RevealData.lua'
    meta.write_text('-- Generated by tools/import_transitions.py.\nlocal _,FB=...\nFB.RevealData={\n'+'\n'.join(specs)+'\n}\n')


if __name__=='__main__':
    main()
