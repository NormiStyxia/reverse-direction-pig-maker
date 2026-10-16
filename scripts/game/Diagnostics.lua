-- Explicit development opt-in only. Never toggled by player input.
local D={enabled=false}
function D.blocks(key)
    if D.enabled then return false end
    for _,k in ipairs({KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_F11,KEY_F12}) do if key==k then return true end end
    return false
end
return D
