from pathlib import Path
import json, math, struct
OUT = Path('data/cockpit')
OUT.mkdir(parents=True, exist_ok=True)
MATS = [
 ('soft_black',[0.025,0.03,0.035,1],0.0,0.58,None,None),
 ('leather',[0.035,0.038,0.04,1],0.0,0.42,None,None),
 ('aluminium',[0.42,0.46,0.50,1],0.88,0.24,None,None),
 ('chrome',[0.70,0.74,0.78,1],0.96,0.12,None,None),
 ('piano_black',[0.010,0.012,0.015,1],0.18,0.12,None,None),
 ('display',[0.01,0.05,0.08,1],0.05,0.22,[0.01,0.22,0.50],None),
 ('gauge',[0.75,0.82,0.90,1],0.0,0.35,[0.65,0.75,0.95],None),
 ('needle',[0.90,0.03,0.02,1],0.0,0.40,[0.80,0.02,0.01],None),
 ('glass',[0.08,0.12,0.16,0.12],0.0,0.06,None,'BLEND'),
 ('warm',[0.40,0.12,0.02,1],0.0,0.50,[0.55,0.10,0.015],None),
 ('stitch',[0.24,0.25,0.27,1],0.0,0.65,None,None),
]
MAT={n:i for i,(n,*_) in enumerate(MATS)}
def rot(axis, a):
    x,y,z=axis; L=(x*x+y*y+z*z)**.5 or 1; x/=L;y/=L;z/=L
    c=math.cos(a);s=math.sin(a);C=1-c
    return ((c+x*x*C,x*y*C-z*s,x*z*C+y*s),(y*x*C+z*s,c+y*y*C,y*z*C-x*s),(z*x*C-y*s,z*y*C+x*s,c+z*z*C))
def mv(R,p): return (R[0][0]*p[0]+R[0][1]*p[1]+R[0][2]*p[2],R[1][0]*p[0]+R[1][1]*p[1]+R[1][2]*p[2],R[2][0]*p[0]+R[2][1]*p[1]+R[2][2]*p[2])
class G:
    def __init__(self): self.pr=[]
    def add(self, v,n,idx,mat): self.pr.append((v,n,idx,MAT[mat]))
    def box(self,c,s,mat,axis=(0,0,1),ang=0):
        x,y,z=c; w,h,d=s
        v=[(-w/2,-h/2,-d/2),(w/2,-h/2,-d/2),(w/2,h/2,-d/2),(-w/2,h/2,-d/2),(-w/2,-h/2,d/2),(w/2,-h/2,d/2),(w/2,h/2,d/2),(-w/2,h/2,d/2)]
        R=rot(axis,ang) if ang else None
        v=[mv(R,p) if R else p for p in v]; v=[(a+x,b+y,c0+z) for a,b,c0 in v]
        faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(1,2,6,5),(0,4,7,3)]
        ns=[(0,0,-1),(0,0,1),(0,-1,0),(0,1,0),(1,0,0),(-1,0,0)]
        vv=[];nn=[];ii=[]
        for fi,f in enumerate(faces):
            base=len(vv); normal=mv(R,ns[fi]) if R else ns[fi]
            vv += [v[j] for j in f]; nn += [normal]*4; ii += [base,base+1,base+2,base,base+2,base+3]
        self.add(vv,nn,ii,mat)
    def cyl(self,c,r,h,mat,axis=(0,0,1),seg=24):
        x,y,z=c
        ax=axis; L=(sum(q*q for q in ax))**.5 or 1; ax=tuple(q/L for q in ax); dot=max(-1,min(1,ax[2]))
        if dot>.99999: R=None
        elif dot<-.99999: R=rot((1,0,0),math.pi)
        else: R=rot((-ax[1],ax[0],0),math.acos(dot))
        vv=[];nn=[];ii=[]
        for i in range(seg):
            a0=2*math.pi*i/seg;a1=2*math.pi*(i+1)/seg
            p=[(r*math.cos(a0),r*math.sin(a0),-h/2),(r*math.cos(a1),r*math.sin(a1),-h/2),(r*math.cos(a1),r*math.sin(a1),h/2),(r*math.cos(a0),r*math.sin(a0),h/2)]
            norm=(math.cos((a0+a1)/2),math.sin((a0+a1)/2),0)
            if R: p=[mv(R,q) for q in p]; norm=mv(R,norm)
            p=[(a+x,b+y,c0+z) for a,b,c0 in p]; base=len(vv);vv+=p;nn+=[norm]*4;ii += [base,base+1,base+2,base,base+2,base+3]
        for zz,norm,rev in [(-h/2,(0,0,-1),True),(h/2,(0,0,1),False)]:
            center=(0,0,zz); n0=norm
            if R: center=mv(R,center); n0=mv(R,n0)
            center=(center[0]+x,center[1]+y,center[2]+z)
            for i in range(seg):
                a0=2*math.pi*i/seg;a1=2*math.pi*(i+1)/seg
                p0=(r*math.cos(a0),r*math.sin(a0),zz);p1=(r*math.cos(a1),r*math.sin(a1),zz)
                if R:p0=mv(R,p0);p1=mv(R,p1)
                p0=(p0[0]+x,p0[1]+y,p0[2]+z);p1=(p1[0]+x,p1[1]+y,p1[2]+z)
                base=len(vv); vv += [center,p1,p0] if rev else [center,p0,p1]; nn += [n0]*3; ii += [base,base+1,base+2]
        self.add(vv,nn,ii,mat)
    def torus(self,c,R0,r,mat,major=32,minor=8):
        x,y,z=c; vv=[];nn=[];ii=[]
        for i in range(major):
            A=2*math.pi*i/major
            for j in range(minor):
                B=2*math.pi*j/minor
                nx=math.cos(A)*math.cos(B); ny=math.sin(A)*math.cos(B); nz=math.sin(B)
                vv.append((x+(R0+r*math.cos(B))*math.cos(A),y+(R0+r*math.cos(B))*math.sin(A),z+r*math.sin(B)))
                nn.append((nx,ny,nz))
        for i in range(major):
            ni=(i+1)%major
            for j in range(minor):
                nj=(j+1)%minor
                a=i*minor+j;b=ni*minor+j;c0=ni*minor+nj;d=i*minor+nj
                ii += [a,b,c0,a,c0,d]
        self.add(vv,nn,ii,mat)
def materials():
    out=[]
    for name,base,metal,rough,em,alpha in MATS:
        m={'name':name,'pbrMetallicRoughness':{'baseColorFactor':base,'metallicFactor':metal,'roughnessFactor':rough}}
        if em: m['emissiveFactor']=em
        if alpha: m['alphaMode']=alpha; m['doubleSided']=True
        out.append(m)
    return out
def write_glb(path,g):
    buf=bytearray(); bvs=[]; acc=[]; prim=[]
    def align():
        while len(buf)%4:buf.append(0)
    def pack_accessor(vals,typ,component,target=None):
        align(); off=len(buf)
        if component==5126:
            flat=[q for v in vals for q in v] if isinstance(vals[0],tuple) else vals
            buf.extend(struct.pack('<'+'f'*len(flat),*flat))
        elif component==5125:
            flat=vals; buf.extend(struct.pack('<'+'I'*len(flat),*flat))
        ln=len(buf)-off; bv={'buffer':0,'byteOffset':off,'byteLength':ln}
        if target: bv['target']=target
        bvi=len(bvs);bvs.append(bv)
        a={'bufferView':bvi,'componentType':component,'count':len(vals),'type':typ}
        if typ=='VEC3' and component==5126:
            a['min']=[min(v[k] for v in vals) for k in range(3)];a['max']=[max(v[k] for v in vals) for k in range(3)]
        ai=len(acc);acc.append(a);return ai
    for v,n,idx,mi in g.pr:
        pa=pack_accessor(v,'VEC3',5126,34962);na=pack_accessor(n,'VEC3',5126,34962);ia=pack_accessor(idx,'SCALAR',5125,34963)
        prim.append({'attributes':{'POSITION':pa,'NORMAL':na},'indices':ia,'material':mi})
    doc={'asset':{'version':'2.0','generator':'UkhtaDrive CI cockpit generator'},'buffers':[{'byteLength':len(buf)}],'bufferViews':bvs,'accessors':acc,'materials':materials(),'meshes':[{'primitives':prim}],'nodes':[{'mesh':0}],'scenes':[{'nodes':[0]}],'scene':0}
    js=json.dumps(doc,separators=(',',':')).encode(); js += b' ' * ((4-len(js)%4)%4); align(); binary=bytes(buf); binary+=b'\0'*((4-len(binary)%4)%4)
    total=12+8+len(js)+8+len(binary)
    with open(path,'wb') as f:
        f.write(struct.pack('<4sII',b'glTF',2,total));f.write(struct.pack('<I4s',len(js),b'JSON'));f.write(js);f.write(struct.pack('<I4s',len(binary),b'BIN\0'));f.write(binary)
def build_static():
    g=G(); S='soft_black'; A='aluminium'; P='piano_black'; D='display'; Gg='gauge'; Gl='glass'; Wm='warm'; L='leather'; C='chrome'; St='stitch'
    for c,s in [((-.68,1.18,-1.04),(.78,.24,.46)),((.08,1.18,-1.05),(.76,.23,.47)),((.78,1.18,-1.04),(.62,.22,.46))]:g.box(c,s,S)
    g.box((-.38,1.37,-1.00),(.72,.14,.22),P,(1,0,0),-.08);g.box((.39,1.34,-1.01),(.55,.11,.21),P)
    g.box((0,1.08,-.80),(2.18,.035,.05),A)
    g.box((.45,1.48,-.94),(.56,.31,.055),P);g.box((.45,1.48,-.905),(.49,.24,.015),D);g.box((.45,1.48,-.895),(.49,.24,.006),Gl)
    for k in range(3):g.box((.45,1.535-k*.06,-.884),(.30-k*.04,.012,.006),Gg)
    for x in [-.72,-.64,-.56,-.48,.70,.78,.86,.94]:g.box((x,1.18,-.79),(.018,.085,.02),P)
    g.box((.45,1.22,-.82),(.52,.12,.08),P)
    for i in range(7):g.box((.24+i*.07,1.22,-.774),(.04,.03,.012),A)
    for gx in [-.49,-.18]:
        g.cyl((gx,1.38,-.855),.17,.035,A,(0,0,1),28);g.cyl((gx,1.38,-.833),.148,.018,P,(0,0,1),28)
        g.torus((gx,1.38,-.81),.132,.008,C,32,6)
        for i in range(12):
            a=math.radians(220-i*20);g.box((gx+math.cos(a)*.112,1.38+math.sin(a)*.112,-.795),(.010,.026,.008),Gg,(0,0,1),a-math.pi/2)
    g.box((.18,.77,-.38),(.48,.23,1.16),L,(1,0,0),.07);g.box((.18,.90,-.39),(.41,.03,1.02),A);g.box((.18,.95,-.14),(.20,.09,.30),P)
    g.box((.18,1.05,-.22),(.08,.23,.10),L,(1,0,0),-.15);g.cyl((.34,.96,.03),.055,.025,A,(0,1,0),24)
    for x in [-1.03,1.03]:g.box((x,1.01,-.18),(.16,.62,1.55),L)
    for x in [-.94,.94]:g.box((x,1.27,-.31),(.06,.045,.82),A)
    g.box((-.99,1.64,-.69),(.12,.90,.13),S,(0,0,1),-.12);g.box((.99,1.64,-.69),(.12,.90,.13),S,(0,0,1),.12);g.box((0,2.01,-.50),(2.0,.12,.30),S)
    g.box((.05,1.78,-.58),(.42,.16,.08),P);g.box((.05,1.78,-.535),(.35,.10,.012),Gl);g.box((.05,1.89,-.55),(.04,.15,.04),S)
    for x in [-1.15,1.15]:g.box((x,1.40,-.50),(.26,.14,.20),P)
    g.box((0,.84,-2.08),(1.90,.13,1.64),A,(1,0,0),-.025)
    g.box((-.73,.50,.15),(.42,.62,.46),L);g.box((.87,.50,.15),(.44,.62,.46),L)
    g.box((0.0,1.065,-.76),(1.9,.012,.012),Wm)
    for x in [-.92,.92]:g.box((x,.93,-.18),(.02,.02,.70),St)
    return g
def build_wheel():
    g=G();L='leather';A='aluminium';C='chrome';P='piano_black';Gg='gauge'
    g.torus((0,0,0),.205,.030,L,40,10);g.torus((0,0,-.030),.163,.008,A,36,6)
    g.box((0,-.105,-.018),(.055,.15,.055),A);g.box((-.095,-.030,-.018),(.155,.050,.055),A,(0,0,1),-.38);g.box((.095,-.030,-.018),(.155,.050,.055),A,(0,0,1),.38)
    g.cyl((0,-.005,-.010),.083,.075,P,(0,0,1),32);g.cyl((0,-.005,-.054),.061,.010,A,(0,0,1),28)
    for i in range(4):g.torus((-.048+i*.032,-.005,-.063),.026,.0035,C,20,5)
    g.box((-.105,.020,-.057),(.095,.052,.016),P,(0,0,1),-.25);g.box((.105,.020,-.057),(.095,.052,.016),P,(0,0,1),.25)
    g.box((-.218,0,.040),(.032,.125,.024),A,(0,0,1),-.15);g.box((.218,0,.040),(.032,.125,.024),A,(0,0,1),.15)
    for x in [-.13,-.09,.09,.13]:g.box((x,.055,-.070),(.018,.012,.009),Gg)
    return g
write_glb(OUT/'cockpit_static.glb', build_static())
write_glb(OUT/'steering.glb', build_wheel())
print('generated', OUT/'cockpit_static.glb', OUT/'steering.glb')
