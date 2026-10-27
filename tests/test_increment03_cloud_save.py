"""Async storage contract. No service requests or production saves are made."""
from pathlib import Path
import json
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.globals().encode=lambda v:json.dumps(plain(v))
def plain(v):
    if hasattr(v,'items'):
        d={k:plain(x) for k,x in v.items()}
        if d and all(isinstance(k,int) for k in d):return [d[k] for k in sorted(d)]
        return d
    return v
lua.globals().decode=lambda v:lua.table_from(json.loads(v),recursive=True)
lua.execute('''
local Cloud=require('game.CloudSave')
local codec={encode=function(v)return encode(v)end,decode=function(v)return decode(v)end}
local key='reverse_pig_save_v1'
local function fixture()
    local a={reads={},writes={}}
    function a:Get(k,e)assert(k==key);self.reads[#self.reads+1]=e end
    function a:Set(k,v,e)assert(k==key);self.writes[#self.writes+1]={raw=v,events=e}end
    return Cloud.open(a,codec),a
end
local function remote(s,a,v)a.reads[#a.reads].ok(v and {[key]=codec.encode(v)}or {})end
-- Load is asynchronous and leaves the menu gated until response.
local s,a=fixture();assert(s.loading and #a.reads==1 and #a.writes==0)
local Title=require('game.TitleState');local t=Title.new(0);t.saveLoading=true
assert(t:disabled(0) and t:disabled(1) and t:disabled(3) and not t:disabled(2) and not t:disabled(4))
remote(s,a,{chapters={timeline={nodes={'2312','echo1'},floors={echo1=3}},ch1={answer='late'}}})
assert(not s.loading and s.persisted and s:latest()=='echo1' and s:answer()=='late')
-- Burst writes coalesce; only a callback acknowledging the newest revision persists.
s:unlock('1447');s:meetingFinished('done');s:tick(.31)
assert(#a.writes==1 and not s.persisted)
s:unlock('echo2');s:tick(1);assert(#a.writes==1)
a.writes[1].events.ok();assert(not s.persisted)
s:tick(0);assert(#a.writes==2)
a.writes[2].events.ok();assert(s.persisted and not s.error)
assert(codec.decode(a.writes[2].raw).chapters.ch1.answer=='done')
-- Second open simulates a new client, reusing only the remote serialized record.
local reopened,b=fixture();b.reads[1].ok({[key]=a.writes[2].raw})
assert(reopened:latest()=='echo2' and reopened:passed('echo1')==3 and reopened:answer()=='done')
-- Timed-out reads never authorize an overwrite. Late callback is ignored.
local offline,c=fixture();offline:tick(8);assert(not offline.loading and offline.status=='offline')
offline:unlock('2312');offline:meetingFinished('same');offline:tick(.4)
assert(#c.writes==0);c.reads[1].ok({});assert(offline.status=='offline')
offline:tick(5);assert(#c.reads==2 and #c.writes==0)
remote(offline,c,{chapters={timeline={nodes={'echo4'},floors={echo4=4}},ch1={answer='late',dormChoice='pc'}}})
assert(offline:hasNode('2312') and offline:hasNode('echo4') and offline:passed('echo4')==4)
assert(offline:answer()=='same' and offline:dormChoice()=='pc')
offline:tick(.4);assert(#c.writes==1)
c.writes[1].events.error(-1,'offline');offline:tick(5);assert(#c.writes==2)
c.writes[1].events.ok();assert(not offline.persisted)
c.writes[2].events.ok();assert(offline.persisted)
-- No save writes simply for loading / playing Level Mode.
local empty,d=fixture();remote(empty,d,nil);empty:tick(100);assert(#d.writes==0)
-- Corrupt remote data is retained by the service, never replaced with an empty save.
local bad,e=fixture();e.reads[1].ok({[key]='not-json'});bad:unlock('2312');bad:tick(5)
assert(#e.writes==0 and #e.reads==2);e.reads[2].ok({[key]={chapters=false}})
assert(bad.error=='invalid-cloud-save')
-- Callback after shutdown cannot mutate a different session.
local closed,f=fixture();closed:close();f.reads[1].ok({[key]={chapters={ch1={answer='done'}}}})
assert(closed:answer()=='same');closed:tick(100);assert(#f.reads==1)
-- API absence/throwing returns a usable in-memory session, not a Lua error.
local missing=Cloud.open(nil,codec);assert(missing.status=='offline' and not missing.loading)
missing:unlock('2312');assert(missing:latest()=='2312' and not missing.persisted)
local throws=Cloud.open({Get=function()error('offline')end},codec);assert(throws.status=='offline')
''')
report={'result':'PASS','coverage':['asynchronous load/menu gating','coalesced serialized writes','current-revision acknowledgement','serialized record reopened','timeout/retry/stale callback','merge offline progress without losing remote unlocks','level mode zero writes','corrupt save protection','shutdown callback','unavailable/throwing API'],
        'limitations':['Mock clientCloud API; not a real service or browser refresh test','No concurrent cross-device conflict resolution']}
Path('docs/migration/increment03-cloud-save-test.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False))
