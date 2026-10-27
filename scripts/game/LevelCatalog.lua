local Data=require('game.data.Levels')
local Catalog={
    {id='prologue',theme='store',node='echo1',name='便利店',levels=Data.prologue,answer='same'},
    {id='ch1',theme='meeting',node='echo2',name='会议室',levels=Data.chapter1,answer='same'},
    {id='office',theme='office',node='echo3',name='办公区',levels=Data.office,answer='fix'},
    {id='dorm',theme='dorm',node='echo4',name='宿舍',levels=Data.dorm,answer='sick'},
}
function Catalog.find(id)
    for i,s in ipairs(Catalog) do if s.id==id or s.theme==id or s.node==id then return s,i end end
end
function Catalog.at(index)
    for _,s in ipairs(Catalog) do
        if index<#s.levels then return s,index end
        index=index-#s.levels
    end
end
function Catalog.count() local n=0;for _,s in ipairs(Catalog) do n=n+#s.levels end;return n end
return Catalog
