-- Production entry: native UrhoX scenes and raw NanoVG UI.
require('game.Application')

-- Maker's remote entry validator requires Start in the entry file itself.
-- Application still owns event handlers and the lifecycle implementation.
local startApplication=Start
function Start()
    startApplication()
end
