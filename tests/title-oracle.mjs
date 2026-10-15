// Execute the frozen update verbatim. DOM writes terminate at inert adapters.
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync('reference/h5-source/src/title-screen.js','utf8');
const payload=JSON.parse(fs.readFileSync(0,'utf8'));
const constants=source.slice(source.indexOf('const FW'),source.indexOf('// 两个 pass'));
const init=source.slice(source.indexOf('    const st = (this.st = {'),source.indexOf("    if (params.has('titleT'))"));
const update=source.slice(source.indexOf('    const fmtClock ='),source.indexOf('    const draw ='));
const stub=()=>({classList:{add(){},toggle(){}},style:{},setAttribute(){}});
const M=Object.create(Math); M.random=()=>payload.random;
const context=vm.createContext({Math:M,globalThis:{},bp:stub(),ui:stub(),wash:stub(),root:stub(),hint:stub(),plane:stub(),ticks:stub(),arc:stub(),lat:stub(),fw:1280,fh:576,select(){},onStart(){}});
vm.runInContext(constants+'\nconst opts={motion:true,parallax:true,muted:false};'+init+'\nthis.dispose=()=>{this.active=false};this.active=true;'+update+'\nglobalThis.step=(op)=>{if(op.skip) st.intro=INTRO_END;if(op.holding!==undefined)st.holding=op.holding;if(op.pointer)st.parT=op.pointer;if(op.opts)Object.assign(opts,op.opts);if(op.leave){st.phase="leaving";st.leaveT=0;st.choice={kind:"new"}};if(this.active)update(Math.min(.05,Math.max(0,op.dt)));return JSON.parse(JSON.stringify(st))};',context);
console.log(JSON.stringify(payload.ops.map(op=>context.globalThis.step(op))));
