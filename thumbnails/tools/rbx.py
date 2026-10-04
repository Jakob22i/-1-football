import struct, lz4.block, zstandard
def deint(b, n, sz):
    return [b[i::n] for i in range(0)]
def read_chunks(path):
    d=open(path,'rb').read()
    p=32; ch=[]
    while p<len(d):
        name=d[p:p+4]; cl,ul,_=struct.unpack('<III',d[p+4:p+16]); p+=16
        if name==b'END\0': break
        if cl>0:
            raw=d[p:p+cl]; p+=cl
            if raw[:4]==b'\x28\xb5\x2f\xfd': data=zstandard.ZstdDecompressor().decompress(raw,max_output_size=ul)
            else: data=lz4.block.decompress(raw,uncompressed_size=ul)
        else:
            data=d[p:p+ul]; p+=ul
        ch.append((name,data))
    return ch
def rd_str(b,p):
    n=struct.unpack_from('<I',b,p)[0]; return b[p+4:p+4+n].decode('utf8','replace'),p+4+n
def deint_arr(b,p,n,sz):
    out=bytearray(n*sz)
    for i in range(sz):
        out[i::sz]=b[p+i*n:p+(i+1)*n]
    return bytes(out)
def unzig(v): return (v>>1)^-(v&1)
def read_i32s(b,p,n,acc=False):
    raw=deint_arr(b,p,n,4)
    vals=[unzig(x) for x in struct.unpack('>%dI'%n,raw)]
    if acc:
        s=0
        for i in range(n): s+=vals[i]; vals[i]=s
    return vals
def read_f32s(b,p,n):
    raw=deint_arr(b,p,n,4)
    out=[]
    for x in struct.unpack('>%dI'%n,raw):
        x=((x>>1)|((x&1)<<31))&0xffffffff
        out.append(struct.unpack('<f',struct.pack('<I',x))[0])
    return out
def parse(path):
    ch=read_chunks(path)
    classes={}; props={}; parent={}
    for name,b in ch:
        if name==b'INST':
            cid=struct.unpack_from('<I',b,0)[0]; cn,p=rd_str(b,4); fmt=b[p]; p+=1
            n=struct.unpack_from('<I',b,p)[0]; p+=4
            ids=read_i32s(b,p,n,True)
            classes[cid]=(cn,ids)
        elif name==b'PROP':
            cid=struct.unpack_from('<I',b,0)[0]; pn,p=rd_str(b,4); t=b[p]; p+=1
            cn,ids=classes[cid]; n=len(ids)
            v=None
            if t==1:
                v=[]
                for i in range(n):
                    s,p=rd_str(b,p); v.append(s)
            elif t==2: v=[bool(x) for x in b[p:p+n]]
            elif t==3: v=read_i32s(b,p,n)
            elif t==4: v=read_f32s(b,p,n)
            elif t==5:
                raw=deint_arr(b,p,n,8); v=list(struct.unpack('<%dd'%n,raw[:0]+bytes(raw))) if False else None
            elif t==0xc:  # Color3
                v=list(zip(read_f32s(b,p,n),read_f32s(b,p+4*n,n),read_f32s(b,p+8*n,n)))
            elif t==0xd: # Vector2
                v=list(zip(read_f32s(b,p,n),read_f32s(b,p+4*n,n)))
            elif t==0xe: # Vector3
                v=list(zip(read_f32s(b,p,n),read_f32s(b,p+4*n,n),read_f32s(b,p+8*n,n)))
            elif t==0x10: #CFrame
                v=[]
                rots=[]
                for i in range(n):
                    rid=b[p]; p+=1
                    if rid==0:
                        r=struct.unpack_from('<9f',b,p); p+=36
                    else: r=('id',rid)
                    rots.append(r)
                xs=read_f32s(b,p,n); ys=read_f32s(b,p+4*n,n); zs=read_f32s(b,p+8*n,n)
                v=list(zip(rots,zip(xs,ys,zs)))
            elif t==0x12: # Enum
                v=read_i32s(b,p,n) if False else [unzig(0)]  # placeholder
                raw=deint_arr(b,p,n,4); v=list(struct.unpack('>%dI'%n,raw))
            elif t==0x13: # Ref
                v=read_i32s(b,p,n,True)
            elif t==0xb:
                raw=deint_arr(b,p,n,4); v=list(struct.unpack('>%dI'%n,raw))
            elif t==0x1a:
                v=list(zip(b[p:p+n],b[p+n:p+2*n],b[p+2*n:p+3*n]))
            elif t==0x1c:
                raw=deint_arr(b,p,n,4); v=list(struct.unpack('>%dI'%n,raw))
            props[(cid,pn)]=(t,v)
        elif name==b'PRNT':
            p=1; n=struct.unpack_from('<I',b,p)[0]; p+=4
            ch_=read_i32s(b,p,n,True); par=read_i32s(b,p+4*n,n,True)
            parent=dict(zip(ch_,par))
    return classes,props,parent
