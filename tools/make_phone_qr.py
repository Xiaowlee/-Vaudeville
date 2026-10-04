"""Offline QR version 3-L, byte mode. No packages or network calls.
Usage: python tools/make_phone_qr.py URL
After changing URL, update the URL label in UI/phone_pairing.tscn too.
"""
import sys
from pathlib import Path
url=sys.argv[1] if len(sys.argv)>1 else 'https://192.168.0.61:3000/stage'
payload=url.encode('utf-8')
if len(payload)>53: raise SystemExit('URL too long for this small QR generator (53 bytes maximum).')
def mul(a,b):
    out=0
    while b:
        if b&1: out^=a
        b>>=1; a<<=1
        if a&256: a^=0x11d
    return out
bits='0100'+format(len(payload),'08b')+''.join(format(x,'08b') for x in payload)
bits+='0'*min(4,440-len(bits));bits+='0'*((-len(bits))%8)
data=[int(bits[i:i+8],2) for i in range(0,len(bits),8)]
while len(data)<55: data.append(0xec if (len(data)-len(bits)//8)%2==0 else 0x11)
gen=[1];root=1
for _ in range(15):
    nxt=[0]*(len(gen)+1)
    for j,c in enumerate(gen): nxt[j]^=c; nxt[j+1]^=mul(c,root)
    gen=nxt;root=mul(root,2)
work=data+[0]*15
for i in range(55):
    factor=work[i]
    for j,c in enumerate(gen): work[i+j]^=mul(c,factor)
words=data+work[-15:]
# Independently check every Reed-Solomon root.
root=1
for _ in range(15):
    v=0
    for c in words: v=mul(v,root)^c
    assert v==0
    root=mul(root,2)
n=29;m=[[False]*n for _ in range(n)];reserved=[[False]*n for _ in range(n)]
def put(x,y,v):
    if 0<=x<n and 0<=y<n: m[y][x]=bool(v);reserved[y][x]=True
for i in range(n): put(6,i,i%2==0);put(i,6,i%2==0)
for cx,cy in [(3,3),(25,3),(3,25)]:
    for dy in range(-4,5):
        for dx in range(-4,5):
            d=max(abs(dx),abs(dy));put(cx+dx,cy+dy,d!=2 and d!=4)
for dy in range(-2,3):
    for dx in range(-2,3): put(22+dx,22+dy,max(abs(dx),abs(dy))!=1)
# Error-correction level L (01), mask 0; BCH format code with mandated XOR mask.
v=8;rem=v
for _ in range(10): rem=(rem<<1)^((rem>>9)*0x537)
f=((v<<10)|rem)^0x5412
assert f==0x77c4
for i in range(6): put(8,i,(f>>i)&1)
put(8,7,(f>>6)&1);put(8,8,(f>>7)&1);put(7,8,(f>>8)&1)
for i in range(9,15): put(14-i,8,(f>>i)&1)
for i in range(8): put(n-1-i,8,(f>>i)&1)
for i in range(8,15): put(8,n-15+i,(f>>i)&1)
put(8,n-8,True)
stream=''.join(format(c,'08b') for c in words);coords=[]
x=n-1;up=True
while x>=1:
    if x==6:x=5
    for y in (range(n-1,-1,-1) if up else range(n)):
        for xx in [x,x-1]:
            if not reserved[y][xx]:coords.append((xx,y))
    up=not up;x-=2
assert len(coords)==567
for i,(x,y) in enumerate(coords):m[y][x]=(i<len(stream) and stream[i]=='1')^((x+y)%2==0)
read=''.join(str(int(m[y][x]^((x+y)%2==0))) for x,y in coords)
assert read[:560]==stream and read[560:]=='0000000'
assert bytes(int(read[i:i+8],2) for i in range(12,12+8*len(payload),8))==payload
path=''.join(f'M{x+4},{y+4}h1v1h-1z' for y in range(n) for x in range(n) if m[y][x])
svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="296" height="296" viewBox="0 0 37 37"><rect width="37" height="37" fill="white"/><path d="{path}" fill="black"/></svg>'
output=Path(__file__).resolve().parents[1]/'UI/phone_companion_qr.svg'
output.write_text(svg,encoding='utf-8')
print('QR generated and codeword-checked offline:',url)
