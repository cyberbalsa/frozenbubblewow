local _, FB = ...
local D={limit=500}; FB.Debug=D
function D.Log(kind,...)
    if not FB.db or not FB.db.debug then return end
    local parts={}
    for i=1,select("#",...) do
        local value=select(i,...)
        if issecretvalue and issecretvalue(value) then parts[#parts+1]="<restricted>"
        else parts[#parts+1]=tostring(value):gsub("[\r\n]"," "):sub(1,250) end
    end
    local rows=FB.db.debugLog
    rows[#rows+1]=date("%Y-%m-%d %H:%M:%S").." ["..kind.."] "..table.concat(parts," ")
    while #rows>D.limit do table.remove(rows,1) end
end
function D.Init()
    -- Enabled for this first testing release; /fb debug off disables it.
    if FB.db.debug==nil then FB.db.debug=true end
    FB.db.debugLog=FB.db.debugLog or {}
    local version,build,_,interface=GetBuildInfo()
    D.Log("SESSION",FB.version,version,build,interface)
    if geterrorhandler and seterrorhandler then
        local previous=geterrorhandler()
        seterrorhandler(function(err)
            if type(err)=="string" and err:find("FrozenBubble",1,true) then D.Log("LUA_ERROR",err) end
            return previous(err)
        end)
    end
end
function D.Command(command)
    if command=="on" then FB.db.debug=true; D.Log("DEBUG","enabled"); FB.Print("Debug logging enabled.")
    elseif command=="off" then FB.db.debug=false; FB.Print("Debug logging disabled.")
    elseif command=="clear" then FB.db.debugLog={}; FB.Print("Debug log cleared.")
    elseif command=="errors" then
        if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar("scriptErrors","1") else SetCVar("scriptErrors","1") end
        FB.Print("WoW Lua error popups enabled.")
    else
        FB.Print("Debug "..(FB.db.debug and "on" or "off").."; "..#FB.db.debugLog.." entries. Channel: "..FB.Community.state)
        for i=math.max(1,#FB.db.debugLog-11),#FB.db.debugLog do FB.Print(FB.db.debugLog[i]) end
        FB.Print("/fb debug on | off | clear | errors. Full log saves in FrozenBubbleDB.debugLog on logout or /reload.")
    end
end
