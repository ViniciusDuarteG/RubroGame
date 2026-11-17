#!/usr/bin/env python3
"""Original tiny diffuse textures; deterministic offline generation, no downloaded art."""
from pathlib import Path
import random, math
from PIL import Image, ImageDraw, ImageFilter
out=Path(__file__).resolve().parents[1]/'assets'/'textures';out.mkdir(parents=True,exist_ok=True)
r=random.Random(2005)
for name in ['ground','concrete','metal','fabric','asphalt','camo']:
 n=128;im=Image.new('RGB',(n,n));p=im.load()
 for y in range(n):
  for x in range(n):
   v=205+r.randint(-18,18)
   if name=='ground': v=180+int(15*math.sin(x*.11)*math.cos(y*.13))+r.randint(-24,24)
   if name=='concrete': v=206+r.randint(-14,14)+(12 if y%32==0 else 0)
   if name=='metal': v=188+int(28*math.cos(x*math.pi/8))+r.randint(-8,8)
   if name=='fabric': v=203+r.randint(-12,12)+(12 if (x+y)%4==0 else 0)
   if name=='asphalt': v=160+r.randint(-40,40)
   p[x,y]=(v,v,v)
 d=ImageDraw.Draw(im)
 if name=='ground':
  for i in range(150):
   x=r.randrange(n);y=r.randrange(n);d.line((x,y,x+2,y+1),fill=(135,137,127),width=1)
 if name=='metal':
  for x in [4,124]:
   for y in [5,64,123]:d.ellipse((x-1,y-1,x+1,y+1),fill=(90,90,85))
 if name=='concrete':
  for _ in range(5):
   x=r.randrange(n);y=r.randrange(n);d.line((x,y,x+6,y+13,x+4,y+23),fill=(170,173,162),width=1)
 if name=='camo':
  for i in range(65):
   x=r.randrange(n);y=r.randrange(n);a=r.randrange(5,18);b=r.randrange(4,13)
   c=r.choice([(95,109,87),(152,157,119),(205,199,156),(65,85,71)])
   d.polygon([(x-a,y),(x-a//2,y-b),(x+a,y-b//2),(x+a//2,y+b),(x,y+b//2)],fill=c)
 im.save(out/(name+'.png'))
print(out)
