-- Commands entered in the Frozen Bubble lobby edit box.
local _,FB=...
local C,A,N=FB.Community,FB.Arena,FB.Net
local L={}; FB.LobbyCommands=L
local function candidates(room)
    if room then return room.names end
    local seen={[FB.PlayerName()]=true}
    for name,peer in pairs(N.peers) do if peer.queued then seen[name]=true end end
    for host in pairs(A.rooms) do seen[host]=true end
    if C.who and C.who.expires>=GetTime() then
        for name in pairs(C.who.names) do seen[name]=true end
    end
    local names={}
    for name in pairs(seen) do names[#names+1]=name end
    table.sort(names); return names
end
local function resolve(input,room)
    if not input or #input<2 or #input>100 or input:find("[|,%s%c~]") then return nil,"Enter a character name." end
    local lower=input:lower()
    local found
    for _,name in ipairs(candidates(room)) do
        if name:lower()==lower then return name end
        if name:match("^[^-]+"):lower()==lower then
            if found then return nil,"Use Player-Realm for that name." end
            found=name
        end
    end
    return found or FB.PlayerName(input)
end
function L.Complete(text,room)
    local before,word=text:match("^(.-)(%S+)$")
    if not word then return text end
    local matches,common=0,nil
    for _,name in ipairs(candidates(room)) do
        if name:sub(1,#word):lower()==word:lower() then
            matches=matches+1
            if not common then common=name
            else
                local bytes=0
                for char in common:gmatch(".[\128-\191]*") do
                    if char:lower()~=name:sub(bytes+1,bytes+#char):lower() then break end
                    bytes=bytes+#char
                end
                common=common:sub(1,bytes)
            end
        end
    end
    if matches==0 then return text end
    if matches>1 then FB.Sound("stick") end
    return before..common..(matches==1 and (before=="" and ": " or " ") or "")
end
local function autokick(input,reason,room)
    if input=="" then
        local names={}
        for _,entry in pairs(A.autoKick) do names[#names+1]=entry.name end
        table.sort(names)
        C.Log(#names==0 and "Nobody in autokick list." or ("Autokick: "..table.concat(names,", ")))
        return true
    end
    local name,err=resolve(input,room)
    if not name then return nil,err end
    local key=name:lower()
    if key==FB.PlayerName():lower() then return nil,"Choose another player." end
    if A.autoKick[key] and reason=="" then
        A.autoKick[key]=nil; C.Log("Removed "..name.." from autokick."); return true
    end
    A.autoKick[key]={name=name,reason=reason}
    C.Log("Added "..name.." to autokick.")
    if room and room.host and room.phase=="room" and room.players[name] then return A.Kick(room,name,reason) end
    return true
end
function L.Submit(text,room)
    if not C.ValidChat(text) then return nil,"Enter a message of up to 160 bytes." end
    if room and (room~=N.match or room.phase~="room") then return nil,"The room has changed." end
    local command,args=text:match("^/(%S+)%s*(.*)$")
    if text:sub(1,1)~="/" or (command=="me" or command=="action") and args~="" then
        if room then return A.Say(room,text) end
        return C.Say(text)
    end
    if command=="list" then
        if not room then return C.Who() end
        C.Log("Players in game: "..table.concat(room.names,", "))
    elseif command=="server" then
        C.Log(C.name.." · "..GetNormalizedRealmName().." · "..C.state)
    elseif command=="help" then
        local m=N.match
        C.Log("/me <action>, /list, /server, /fs, /autokick [Player-Realm] [reason]"..
            (m and m.arena and m.host and m.phase=="room" and ", /kick <Player-Realm> [reason]" or ""))
    elseif command=="fs" then FB.UI:ToggleFullWindow()
    elseif command=="kick" or command=="autokick" then
        room=N.match and N.match.arena and N.match.phase=="room" and N.match or nil
        local player,reason=args:match("^(%S*)%s*(.*)$")
        if #reason>120 then return nil,"Use a reason of up to 120 bytes." end
        if command=="autokick" then return autokick(player,reason,room) end
        if not room or not room.host then return nil,"Only the room host can kick a player." end
        local name,err=resolve(player,room)
        if not name then return nil,err end
        return A.Kick(room,name,reason)
    else return nil,"Unknown command. Type /help for lobby commands." end
    return true
end
