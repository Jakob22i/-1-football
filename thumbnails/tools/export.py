import collections, json
from rbx import *
TBL={2:(1,0,0,0,1,0,0,0,1),3:(1,0,0,0,0,-1,0,1,0),5:(1,0,0,0,-1,0,0,0,-1),6:(1,0,0,0,0,1,0,-1,0),
7:(0,1,0,1,0,0,0,0,-1),9:(0,0,1,1,0,0,0,1,0),0xa:(0,-1,0,1,0,0,0,0,1),0xc:(0,0,-1,1,0,0,0,-1,0),
0xd:(0,1,0,0,0,1,1,0,0),0xe:(0,0,-1,0,1,0,1,0,0),0x10:(0,-1,0,0,0,-1,1,0,0),0x11:(0,0,1,0,-1,0,1,0,0),
0x14:(-1,0,0,0,1,0,0,0,-1),0x15:(-1,0,0,0,0,1,0,1,0),0x17:(-1,0,0,0,-1,0,0,0,1),0x18:(-1,0,0,0,0,-1,0,-1,0),
0x19:(0,1,0,-1,0,0,0,0,1),0x1b:(0,0,-1,-1,0,0,0,1,0),0x1c:(0,-1,0,-1,0,0,0,0,-1),0x1e:(0,0,1,-1,0,0,0,-1,0),
0x1f:(0,1,0,0,0,-1,-1,0,0),0x20:(0,0,1,0,1,0,-1,0,0),0x22:(0,-1,0,0,0,1,-1,0,0),0x23:(0,0,-1,0,-1,0,-1,0,0)}
f='/root/.claude/uploads/68bac485-aa9b-58fa-9136-959e989c4159/79c911ca-horrorgame_7.rbxl'
classes,props,parent=parse(f)
inst={}
for cid,(cn,ids) in classes.items():
    nm=props.get((cid,'Name'))
    for i,r in enumerate(ids): inst[r]=dict(cls=cn,name=nm[1][i] if nm else '?',cid=cid,idx=i)
def P(r,pn,default=None):
    i=inst[r]; v=props.get((i['cid'],pn))
    return v[1][i['idx']] if v and v[1] is not None else default
kids=collections.defaultdict(list)
for c,p in parent.items(): kids[p].append(c)
def path(r):
    out=[]
    while r in inst:
        out.append(inst[r]['name']); r=parent.get(r,-1)
    return '/'.join(reversed(out))
parts=[]
for r,i in inst.items():
    if i['cls'] not in('Part','SpawnLocation'): continue
    rot,pos=P(r,'CFrame')
    R=list(TBL[rot[1]]) if rot[0]=='id' else list(rot)
    mesh=None
    for k in kids[r]:
        if inst[k]['cls']=='SpecialMesh': mesh=P(k,'MeshType')
    lights=[dict(b=P(k,'Brightness',1),c=P(k,'Color',(1,1,1)),rng=P(k,'Range',8)) for k in kids[r] if inst[k]['cls']=='PointLight']
    parts.append(dict(path=path(r),cf=[*pos,*R],size=P(r,'size',(1,1,1)),color=P(r,'Color3uint8',(163,162,165)),mat=P(r,'Material',256),shape=P(r,'shape',1),tr=P(r,'Transparency',0),ref=P(r,'Reflectance',0),mesh=mesh,lights=lights))
json.dump(parts,open('parts.json','w'))
# summaries
def bbox(ps):
    import numpy as np
    pts=np.array([p['cf'][:3] for p in ps]); return pts.min(0).round(1).tolist(),pts.max(0).round(1).tolist()
for pre in ('ServerStorage/Monster','ReplicatedStorage/Assets/MonsterJumpscare','Workspace/Lobby','ServerStorage/Key'):
    ps=[p for p in parts if p['path'].startswith(pre)]
    print(pre,len(ps),bbox(ps))
    c=collections.Counter('/'.join(p['path'].split('/')[len(pre.split('/')):][:1]) for p in ps); print(' ',c.most_common(8))
