-- Session history shared between the 23:12 office and the convenience store.
-- nil/false mine means a direct jump, preserving the frozen default history.
local G={mine=false,reacts={}}
function G.reset()G.mine={};G.reacts={}end
function G.label(key)
    for _,g in ipairs(require('game.data.Story03Data').STICKERS)do for _,s in ipairs(g.list)do if s[1]==key then return s[2]end end end
    return ''
end
return G
