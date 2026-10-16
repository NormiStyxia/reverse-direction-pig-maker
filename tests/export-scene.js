// Build-time serializer of frozen Three meshes; never loaded by native runtime.
import * as THREE from 'three';
export function serialize(roots,handles) {
  const geometries=[],materials=[],textures=[],nodes=[];
  const gm=new Map(),mm=new Map(),tm=new Map(),nm=new Map();
  function texture(t){
    if(!t)return 0;if(tm.has(t))return tm.get(t);
    const id=textures.length+1;tm.set(t,id);
    const im=t.image,c=document.createElement('canvas');c.width=im.width;c.height=im.height;
    const ctx=c.getContext('2d');
    if(im.data){
      if(!(im.data instanceof Uint8Array))throw Error('Unsupported texture buffer '+im.data.constructor.name);
      const channels=im.data.length/im.width/im.height,bytes=new Uint8ClampedArray(im.width*im.height*4);
      for(let i=0;i<im.width*im.height;i++)for(let j=0;j<4;j++)bytes[i*4+j]=j<channels?im.data[i*channels+j]:(j===3?255:im.data[i*channels]);
      ctx.putImageData(new ImageData(bytes,im.width,im.height),0,0);
    }else ctx.drawImage(im,0,0);
    textures.push({id,width:im.width,height:im.height,png:c.toDataURL('image/png').split(',')[1],
      source:im.src?new URL(im.src).pathname:null,colorSpace:t.colorSpace,flipY:t.flipY,repeat:t.repeat.toArray(),offset:t.offset.toArray(),
      center:t.center.toArray(),rotation:t.rotation,wrapS:t.wrapS,wrapT:t.wrapT,minFilter:t.minFilter,magFilter:t.magFilter});
    return id;
  }
  function material(m){
    if(mm.has(m))return mm.get(m);const id=materials.length+1;mm.set(m,id);
    materials.push({id,type:m.type,color:m.color?.toArray()||[1,1,1],emissive:m.emissive?.toArray()||[0,0,0],emissiveIntensity:m.emissiveIntensity||0,
      opacity:m.opacity,alphaTest:m.alphaTest,transparent:m.transparent,depthWrite:m.depthWrite,depthTest:m.depthTest,colorWrite:m.colorWrite,
      side:m.side,blending:m.blending,fog:m.fog,map:texture(m.map),alphaMap:texture(m.alphaMap),emissiveMap:texture(m.emissiveMap),gradientMap:texture(m.gradientMap),
      programKey:m.customProgramCacheKey(),customShader:m.onBeforeCompile.toString()});return id;
  }
  function geometry(g){
    if(gm.has(g))return gm.get(g);const id=geometries.length+1;gm.set(g,id);
    const attrs={};for(const [name,a]of Object.entries(g.attributes)){
      if(!['position','normal','uv','color'].includes(name))throw Error('Unexpected geometry attribute '+name);
      const getters=['getX','getY','getZ','getW'];
      const array=a.isInterleavedBufferAttribute
        ? Array.from({length:a.count*a.itemSize},(_,i)=>a[getters[i%a.itemSize]](Math.floor(i/a.itemSize)))
        : Array.from(a.array);
      attrs[name]={size:a.itemSize,array};
    }
    geometries.push({id,type:g.type,attributes:attrs,index:g.index?Array.from(g.index.array):null,groups:g.groups,drawRange:{start:g.drawRange.start,count:Number.isFinite(g.drawRange.count)?g.drawRange.count:null}});return id;
  }
  function visit(o,parent){
    const id=nodes.length+1;nm.set(o,id);
    const n={id,parent,name:o.name,type:o.type,position:o.position.toArray(),quaternion:o.quaternion.toArray(),scale:o.scale.toArray(),visible:o.visible,
      castShadow:o.castShadow,receiveShadow:o.receiveShadow,renderOrder:o.renderOrder,sourceLayers:o.layers.mask};nodes.push(n);
    if(o.geometry)n.geometry=geometry(o.geometry);
    if(o.material)n.materials=(Array.isArray(o.material)?o.material:[o.material]).map(material);
    if(o.isLight)n.light={type:o.type,color:o.color.toArray(),intensity:o.intensity,distance:o.distance,decay:o.decay};
    if(o.isInstancedMesh){
      const matrix=new THREE.Matrix4(),p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3(),c=new THREE.Color();
      n.instances=[];
      for(let i=0;i<o.count;i++){o.getMatrixAt(i,matrix);matrix.decompose(p,q,s);if(o.instanceColor)o.getColorAt(i,c);n.instances.push({matrix:matrix.toArray(),position:p.toArray(),quaternion:q.toArray(),scale:s.toArray(),color:c.toArray()});}
    }
    for(const child of o.children)visit(child,id);
  }

  for(const root of roots)visit(root,0);
  return {nodes,geometries,materials,textures,handles:handles(nm,mm)};
}
