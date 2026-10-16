import fs from 'node:fs';import vm from 'node:vm';
const source=fs.readFileSync('reference/h5-source/src/save.js','utf8').replaceAll('export ','');
const fixtures=[];
for(const unavailable of [false,true]){
 const data=new Map(),scope={localStorage:{getItem:k=>{if(unavailable)throw Error('unavailable');return data.get(k)||null},setItem:(k,v)=>{if(unavailable)throw Error('unavailable');data.set(k,v)}}};
 vm.createContext(scope);vm.runInContext(source+'\nglobalThis.api={loadSave,saveChapter,chapterState};',scope);
 const steps=[];
 for(const [id,fields]of [['echo',{reached:1}],['echo',{reached:3}],['ch1',{answer:'same'}],['echo',{done:true}],['ch1',{answer:'late'}],['ch1',{answer:'done'}],['custom',{note:'序章 → 第一章',flags:[true,false]}]]){
  scope.api.saveChapter(id,fields);steps.push({id,fields,expected:JSON.parse(JSON.stringify(scope.api.loadSave()))});
 }
 fixtures.push({unavailable,steps});
}
fs.mkdirSync('validation/save',{recursive:true});fs.writeFileSync('validation/save/source.json',JSON.stringify(fixtures));
console.log('Frozen save.js oracle: '+fixtures.length+' storage modes');
