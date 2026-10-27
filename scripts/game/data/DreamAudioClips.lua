-- Source-rendered dream.js methods; see export-increment03-ambient.mjs receipt.
local clips={}
for _,id in ipairs({'burst','hold','swap','unswap','murmur','rewind'})do clips['dream-'..id]='audio/increment03/dream-'..id..'.wav'end
for i=0,23 do clips['dream-air-'..i]='audio/increment03/dream-air-'..i..'.wav'end
return clips
