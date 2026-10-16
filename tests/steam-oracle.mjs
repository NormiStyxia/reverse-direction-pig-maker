// Execute the real frozen buildHotFood including its pre-steam RNG consumers.
// Geometry uses Three; paint/label materials are inert only for model validation.
import fs from 'node:fs';
import * as THREE from '../reference/h5-source/vendor/three.module.js';
const props=fs.readFileSync('reference/h5-source/src/store-props.js','utf8');
const art=fs.readFileSync('reference/h5-source/src/art.js','utf8');
const rng=new Function(art.slice(art.indexOf('export function rng'),art.indexOf('function makeCanvas')).replace('export ', '')+';return rng;')();
let calls=0;const counted=seed=>{const r=rng(seed);return ()=>{calls++;return r()}};
const body=props.slice(props.indexOf('export function buildHotFood')).replace('export ', '').replace('lights: [warm, warm2],','parts, lights: [warm, warm2],');
const build=new Function('THREE','rng','toon','paintSurface','label','paintDot',body+';return buildHotFood;')(THREE,counted,()=>new THREE.MeshBasicMaterial(),()=>null,()=>new THREE.MeshBasicMaterial(),()=>null);
const parent=new THREE.Group(),food=build(parent),steam=parent.children.find(x=>x.isPoints);
const initialRandomCalls=calls;
const steps=JSON.parse(fs.readFileSync(0,'utf8'));
const snapshots=steps.map(s=>{food.update(s.dt,s.time,{steam:s.amount});return {size:steam.material.size,parts:food.parts.map(p=>({...p})),pos:Array.from(steam.geometry.attributes.position.array),col:Array.from(steam.geometry.attributes.color.array)}});
console.log(JSON.stringify({initialRandomCalls,finalRandomCalls:calls,snapshots}));
