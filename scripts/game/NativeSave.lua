-- Project/user-isolated native file API. Never writes the source or asset tree.
local State=require('game.SaveState')
local Native={}
function Native.open(filename)
    -- Explicit filenames are isolated validation/smoke files, never cloud keys.
    if not filename and GetPlatform()=='Web' then return require('game.CloudSave').open(clientCloud,cjson)end
    filename=filename or 'reverse-pig-save-v1.json'
    return State.new({
        read=function()
            if not fileSystem:FileExists(filename) then return nil end
            local file=File(filename,FILE_READ)
            if not file:IsOpen() then error('Save file unavailable') end
            local ok,data=pcall(function() return file:ReadString() end);file:Close()
            if not ok then error(data) end;return data
        end,
        write=function(data)
            local file=File(filename,FILE_WRITE)
            if not file:IsOpen() then return false end
            local ok,result=pcall(function() return file:WriteString(data) end);file:Close()
            return ok and result
        end,
    },cjson)
end
return Native
