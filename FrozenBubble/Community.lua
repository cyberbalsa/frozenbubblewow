-- Dedicated discovery channel, with user-click chat fallback on restricted Forever builds.
local _, FB = ...
local C={name="FrozenBubbleForever",catalog={},pending={},replyAt={},state="offline",lastManual=-100}
FB.Community=C
local function now() return GetTime() end
function C.Join()
    if FB.Debug then FB.Debug.Log("CHANNEL","join",C.name) end
    if InCombatLockdown() then FB.Print("Join the community after combat."); return end
    local join=JoinTemporaryChannel or JoinChannelByName
    if not join then FB.Print("Custom channels are unavailable on this client."); return end
    join(C.name)
    C.joined=true; C.state="joining"; C.joinTime=now(); C.probeAt=nil
    FB.db.community=true
end
function C.Blocked()
    C.state="manual"
    if FB.Debug then FB.Debug.Log("CHANNEL","addon delivery unavailable; manual discovery enabled") end
end
function C.Update()
    if not C.joined then return end
    local id=GetChannelName(C.name)
    C.id=id and id>0 and id or nil
    if C.id and not C.probeAt then
        C.probeAt=now(); C.nonce=tostring(math.floor(now()*1000))
        FB.Net.Send("PROBE","CHANNEL",tostring(C.id),C.nonce)
        C.state="checking"
    end
    if C.state=="checking" and now()-C.probeAt>6 then C.Blocked() end
    if C.state=="joining" and now()-C.joinTime>10 then C.state="unavailable" end
    for key,item in pairs(C.catalog) do if now()-item.seen>180 then C.catalog[key]=nil end end
    for key,request in pairs(C.pending) do
        if now()-request.sent>12 then C.pending[key]=nil; FB.Print("Level request expired. The creator may be offline.") end
    end
    for name,t in pairs(C.replyAt) do if now()-t>60 then C.replyAt[name]=nil end end
end
function C.Broadcast(kind,...)
    if C.state=="ready" and C.id then FB.Net.Send(kind,"CHANNEL",tostring(C.id),...) end
end
function C.Manual(kind,...)
    -- Must be called directly by an OnClick handler. Never automate normal chat sends.
    if not C.id then FB.Print("Join the community channel and wait for it to become active."); return false end
    if now()-C.lastManual<2 then FB.Print("Wait two seconds between announcements."); return false end
    if InCombatLockdown() then return false end
    local fields={"FBF1","1",kind,...}
    for i,v in ipairs(fields) do fields[i]=tostring(v) end
    local message=table.concat(fields,"|")
    if #message>255 then return false end
    local send=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if not send then return false end
    local ok=pcall(send,message,"CHANNEL",nil,tostring(C.id))
    if FB.Debug then FB.Debug.Log("CHANNEL","manual",kind,ok) end
    if ok then C.lastManual=now() end
    return ok
end
function C.Chat(message,sender,channelName)
    if issecretvalue and (issecretvalue(message) or issecretvalue(sender) or issecretvalue(channelName)) then return end
    if channelName~=C.name or type(message)~="string" or message:sub(1,5)~="FBF1|" or #message>255 then return end
    -- Normal chat is only a discovery/catalog transport, never gameplay or an executable payload.
    local body=message:sub(6); local fields=FB.Split(body)
    if fields[2]=="QUEUE" or fields[2]=="SCORE" or fields[2]=="SCOREQ" or fields[2]=="LEVEL" or fields[2]=="CATALOG" then
        FB.Net.Receive(FB.PREFIX,body,"CHANNEL",sender)
    end
end
function C.Hash(data)
    local hash=5381
    for i=1,#data do hash=(hash*33+data:byte(i))%2147483647 end
    return tostring(hash)
end
function C.CleanTitle(title)
    return (title or "Untitled"):gsub("[|%c]",""):sub(1,36)
end
function C.Validate(data)
    local grid=FB.Engine.Unpack(data)
    if not grid or not next(grid) then return nil end
    -- Editor levels use the original ten rows; all bubbles must connect to the ceiling.
    local e=FB.Engine.New({},1,"custom"); e.grid=grid
    local attached={}
    for c=1,8 do
        if grid[c] then for _,key in ipairs(e:Group(c,false)) do attached[key]=true end end
    end
    for key in pairs(grid) do
        local row=FB.Engine.Cell(key)
        if row>10 or not attached[key] then return nil end
    end
    return grid
end
function C.Save(title,data,author)
    if not C.Validate(data) then return nil,"Use at least one bubble; connect every bubble to the top, within ten rows." end
    title=C.CleanTitle(title); if title=="" then title="Untitled" end
    local id=C.Hash(data)
    local count=0; for _ in pairs(FB.db.custom) do count=count+1 end
    if count>=100 and not FB.db.custom[id] then return nil,"Your library is full (100 levels). Delete a level first." end
    FB.db.custom[id]={id=id,title=title,data=data,author=author or FB.PlayerName(),published=false}
    return id
end
function C.Publish(id,manual)
    local item=FB.db.custom[id]
    if not item then return end
    item.published=true
    if manual then C.Manual("LEVEL",id,item.title)
    else C.Broadcast("LEVEL",id,item.title) end
end
function C.Browse(manual)
    if manual then C.Manual("CATALOG") else C.Broadcast("CATALOG") end
end
function C.Request(key)
    local item=C.catalog[key]
    if not item then return end
    if C.pending[key] then return end
    C.pending[key]={sent=now(),peer=item.peer,id=item.id,title=item.title}
    FB.Net.Send("GETLEVEL","WHISPER",item.peer,item.id)
end
function C.Receive(message,channel,sender)
    local p=FB.Split(message)
    if p[1]~="1" then return false end
    local kind=p[2]
    sender=FB.PlayerName(sender)
    if kind=="PROBE" then
        if channel=="CHANNEL" and sender==FB.PlayerName() and p[3]==C.nonce then C.state="ready" end
        return true
    end
    if sender==FB.PlayerName() then return false end
    if kind=="LEVEL" and (channel=="CHANNEL" or channel=="WHISPER") then
        if not FB.Integer(p[3],0,2147483646) or not p[4] or #p[4]>36 or p[4]:find("[%c]") then return true end
        local count=0; for _ in pairs(C.catalog) do count=count+1 end
        local key=sender..":"..p[3]
        if count<200 or C.catalog[key] then C.catalog[key]={peer=sender,id=p[3],title=p[4],seen=now()} end
        return true
    elseif kind=="CATALOG" and channel=="CHANNEL" then
        if now()-(C.replyAt[sender] or -100)<20 then return true end
        C.replyAt[sender]=now()
        local count=0
        for id,item in pairs(FB.db.custom) do
            if item.published then
                FB.Net.Send("LEVEL","WHISPER",sender,id,item.title); count=count+1
                if count>=10 then break end
            end
        end
        return true
    elseif kind=="GETLEVEL" and channel=="WHISPER" then
        local item=FB.db.custom[p[3]]
        if item and item.published and now()-(C.replyAt[sender..":get"] or -100)>2 then
            C.replyAt[sender..":get"]=now()
            FB.Net.Send("LEVELDATA","WHISPER",sender,item.id,item.data)
        end
        return true
    elseif kind=="LEVELDATA" and channel=="WHISPER" then
        local key=sender..":"..tostring(p[3]); local request=C.pending[key]
        if request and now()-request.sent<=12 and p[4] and C.Hash(p[4])==request.id then
            local id,err=C.Save(request.title,p[4],sender)
            if FB.Debug then FB.Debug.Log("LEVEL",id and "downloaded" or "rejected",sender,request.id,err) end
            C.pending[key]=nil
            FB.Print(id and ("Downloaded "..request.title..". Open your level library to play.") or err)
        end
        return true
    end
    return false
end
