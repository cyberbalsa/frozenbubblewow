-- Dedicated discovery channel, with user-click chat fallback on restricted Forever builds.
local _, FB = ...
local C={name="FrozenBubbleForever",catalog={},pending={},replyAt={},log={},state="offline",lastManual=-100}
FB.Community=C
C.maxBoards=100
C.blankBoard=string.rep("0",98)
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
local function askForBoards(request)
    request.attempts=request.attempts+1
    request.sent=now()
    FB.Net.Send("GETBOARDS","WHISPER",request.peer,request.id,#request.boards+1)
end
function C.Update()
    if C.who and C.who.untilTime and now()>=C.who.untilTime then
        local names={}
        for name in pairs(C.who.names) do names[#names+1]=name end
        table.sort(names); C.Log("Players in lobby: "..table.concat(names,", "))
        C.who.untilTime=nil
    end
    for key,request in pairs(C.pending) do
        if request.boards and now()-request.sent>=4 and request.attempts<3 then
            askForBoards(request)
        elseif now()-request.sent>12 then
            C.pending[key]=nil; FB.Print("Level request expired. The creator may be offline.")
        end
    end
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
    for name,t in pairs(C.replyAt) do if now()-t>60 then C.replyAt[name]=nil end end
end
function C.Broadcast(kind,...)
    if C.state=="ready" and C.id then return FB.Net.Send(kind,"CHANNEL",tostring(C.id),...) end
end
function C.Log(message,sender,room)
    local action=sender and (message:match("^/me (.+)") or message:match("^/action (.+)"))
    local line
    if action then line="* "..sender.." "..action
    elseif sender then line="<"..sender.."> "..message
    else line="*** "..message end
    if room then line="[Room] "..line end
    line=line:gsub("|","||")
    C.log[#C.log+1]=line
    if #C.log>100 then table.remove(C.log,1) end
    if FB.UI and FB.UI.AppendLobbyLine then FB.UI:AppendLobbyLine(line) end
end
function C.ValidChat(message)
    return type(message)=="string" and #message<=160 and message:find("%S") and not message:find("%c")
end
function C.Say(message)
    if not C.ValidChat(message) then return nil,"Enter a message of up to 160 bytes." end
    if InCombatLockdown() then return nil,"Send lobby chat after combat." end
    if C.state=="manual" and C.id then
        if C.Manual("LOBBY",message) then return true end
    elseif C.state=="ready" and C.id then
        if C.Broadcast("LOBBY",message) then return true end
    else return nil,"Join FrozenBubbleForever and wait for the channel check." end
    return nil,"Chat is busy. Press Enter to retry."
end
function C.Who()
    if C.who and C.who.untilTime then return true end
    local nonce=tostring(math.floor(now()*1000))
    local sent
    if C.state=="manual" then sent=C.Manual("LWHO",nonce) else sent=C.Broadcast("LWHO",nonce) end
    if not sent then return nil,"Join the community channel and wait for delivery before listing players." end
    C.who={nonce=nonce,untilTime=now()+4,expires=now()+30,names={[FB.PlayerName()]=true},count=1}
    return true
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
    -- Manual channel posts carry lobby text and discovery notices.
    local body=message:sub(6); local fields=FB.Split(body)
    if fields[2]=="LOBBY" or fields[2]=="LWHO" or fields[2]=="AROOM" or fields[2]=="QUEUE" or fields[2]=="SCORE" or fields[2]=="SCOREQ" or fields[2]=="LEVEL" or fields[2]=="LEVELSET" or fields[2]=="CATALOG" then
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
    -- The desktop editor permits floating groups and gaps. open_level loads
    -- them as drawn, and normal match resolution decides when they fall.
    for key in pairs(grid) do if FB.Engine.Cell(key)>10 then return nil end end
    return grid
end
function C.Boards(item)
    return item.boards or {item.data}
end
function C.Code(boards)
    if #boards==1 then return boards[1] end
    return "FBSET1:"..table.concat(boards)
end
-- Frozen Bubble's level editor writes ten rows of alternating width, using
-- zero-based colors and a dash for an empty cell. One blank line divides boards.
function C.LevelText(boards)
    local levels={}
    for i,data in ipairs(boards) do
        local rows,at={},1
        for row=1,10 do
            local cells={}
            for col=1,FB.Engine.Columns(row) do
                local color=tonumber(data:sub(at,at)); at=at+1
                cells[col]=color==0 and "-" or tostring(color-1)
            end
            rows[row]=(row%2==0 and "  " or "")..table.concat(cells,"   ")
        end
        levels[i]=table.concat(rows,"\n")
    end
    return table.concat(levels,"\n\n").."\n"
end
local function readLevelText(text)
    if #text>65535 then return end
    local boards,rows={},{}
    for line in (text:gsub("\r\n","\n").."\n\n"):gmatch("([^\n]*)\n") do
        if line:find("%S") then
            local row=#rows+1
            if row>10 then return end
            local cells={}
            for token in line:gmatch("%S+") do
                if token=="-" then cells[#cells+1]="0"
                elseif token:match("^[0-7]$") then cells[#cells+1]=tostring(tonumber(token)+1)
                else return end
            end
            if #cells~=FB.Engine.Columns(row) then return end
            rows[row]=table.concat(cells)
        elseif #rows>0 then
            local data=table.concat(rows)
            data=data..string.rep("0",98-#data)
            if #boards>=C.maxBoards or data~=C.blankBoard and not C.Validate(data) then return end
            boards[#boards+1]=data; rows={}
        end
    end
    if #boards>0 then return boards end
end
function C.Decode(code)
    if type(code)~="string" then return end
    if #code==98 and (code==C.blankBoard or C.Validate(code)) then return {code} end
    if code:sub(1,7)~="FBSET1:" then return readLevelText(code) end
    local length=#code-7
    if length<98 or length%98~=0 or length>98*C.maxBoards then return end
    local boards={}
    for pos=8,#code,98 do
        local data=code:sub(pos,pos+97)
        if data~=C.blankBoard and not C.Validate(data) then return end
        boards[#boards+1]=data
    end
    return boards
end
function C.SaveSet(title,boards,author,replacing)
    if #boards<1 or #boards>C.maxBoards then return nil,"A set holds 1 to 100 boards." end
    local emptyBoard
    for i=1,#boards do
        if not author and boards[i]==C.blankBoard then
            emptyBoard=emptyBoard or i
        elseif not C.Validate(boards[i]) then
            return nil,"Board "..i.." must contain a bubble within the ten editable rows."
        end
    end
    title=C.CleanTitle(title); if title=="" then title="Untitled" end
    local code=C.Code(boards)
    local id
    if not emptyBoard then id=(#boards>1 and "s" or "")..C.Hash(code) end
    local library=FB.db.custom
    local old=replacing and library[replacing]
    local player=FB.PlayerName()
    local owned=old and (old.author==player or old.emptyBoard)
    local count,key=0,nil
    for stored,item in pairs(library) do
        count=count+1
        if id and item.id==id then
            if C.Code(C.Boards(item))~=code then return nil,"A different layout has the same library ID." end
            if author then
                if item.author==author and item.title==title then return stored end
            elseif stored==replacing and (owned or title==item.title) then key=stored
            elseif not key and item.title==title then key=stored end
        end
    end
    if not key and id and not library[id] then key=id end
    if not key and owned and replacing:match("^local%-") then key=replacing end
    if not library[key] and not owned and count>=100 then return nil,"Your library is full. Delete a saved set first." end
    -- The wire ID describes a layout. Blank drafts and differently named files
    -- with the same layout still need separate slots in the desktop-style editor.
    if not key then
        repeat
            FB.db.localSetSerial=(FB.db.localSetSerial or 0)+1
            key="local-"..FB.db.localSetSerial
        until not library[key]
    end
    local existing=library[key]
    if not existing or existing.id~=id or existing.title~=title or emptyBoard then
        local item={id=id,title=title,author=author or player,published=false,emptyBoard=emptyBoard}
        if #boards==1 then item.data=boards[1] else item.boards={unpack(boards)} end
        library[key]=item
    end
    if owned and replacing~=key then library[replacing]=nil end
    return key
end
function C.Save(title,data,author)
    return C.SaveSet(title,{data},author)
end
local function listing(item)
    if item.boards then return "LEVELSET",item.id,item.title,#item.boards end
    return "LEVEL",item.id,item.title
end
function C.Publish(id,manual)
    local item=FB.db.custom[id]
    if not item then return end
    if item.emptyBoard then return nil,"Fill board "..item.emptyBoard.." before publishing this set." end
    -- Peers request by sender and layout checksum. The name explicitly offered
    -- by this player wins when their library contains two copies.
    for _,other in pairs(FB.db.custom) do
        if other.id==item.id then other.published=false end
    end
    item.published=true
    if manual then C.Manual(listing(item)) else C.Broadcast(listing(item)) end
    return true
end
local function publishedLayout(id)
    if not id then return end
    local library=FB.db.custom
    if library[id] and library[id].id==id and library[id].published then return library[id] end
    for _,item in pairs(library) do if item.id==id and item.published then return item end end
end
function C.Browse(manual)
    if manual then C.Manual("CATALOG") else C.Broadcast("CATALOG") end
end
function C.Request(key)
    local item=C.catalog[key]
    if not item then return end
    if C.pending[key] then return end
    C.pending[key]={sent=now(),peer=item.peer,id=item.id,title=item.title}
    if item.count then
        local request=C.pending[key]
        request.count,request.boards,request.attempts=item.count,{},0
        askForBoards(request)
    else FB.Net.Send("GETLEVEL","WHISPER",item.peer,item.id) end
end
function C.Receive(message,channel,sender)
    local p=FB.Split(message)
    if p[1]~="1" then return false end
    local kind=p[2]
    sender=FB.PlayerName(sender)
    if kind=="LOBBY" then
        local line=message:sub(9)
        if channel=="CHANNEL" and C.joined and C.ValidChat(line) then
            C.Log(line,sender)
            if sender~=FB.PlayerName() and FB.UI and (FB.UI.screen=="rooms" or FB.UI.screen=="lobby") then FB.Sound("chatted") end
        end
        return true
    end
    if kind=="PROBE" then
        if channel=="CHANNEL" and sender==FB.PlayerName() and p[3]==C.nonce then C.state="ready" end
        return true
    end
    if sender==FB.PlayerName() then return false end
    if kind=="LWHO" then
        local ui=FB.UI
        if channel=="CHANNEL" and C.joined and ui and ui.frame and ui.frame:IsShown() and (ui.screen=="rooms" or ui.screen=="lobby")
            and not FB.Net.match and p[3] and #p[3]<=16 and p[3]:match("^%d+$") and now()-(C.replyAt[sender..":who"] or -100)>=3 then
            C.replyAt[sender..":who"]=now(); FB.Net.Send("LHERE","WHISPER",sender,p[3])
        end
        return true
    elseif kind=="LHERE" then
        local q=C.who
        if channel=="WHISPER" and q and q.untilTime and now()<=q.untilTime and p[3]==q.nonce and q.count<100 and not q.names[sender] then
            q.names[sender]=true; q.count=q.count+1
        end
        return true
    elseif (kind=="LEVEL" or kind=="LEVELSET") and (channel=="CHANNEL" or channel=="WHISPER") then
        local size
        if kind=="LEVELSET" then
            size=FB.Integer(p[5],2,C.maxBoards)
            if not size or not p[3] or not p[3]:match("^s%d+$") or not FB.Integer(p[3]:sub(2),0,2147483646) then return true end
        elseif not FB.Integer(p[3],0,2147483646) then return true end
        if not p[4] or #p[4]>36 or p[4]:find("[%c]") then return true end
        local count=0; for _ in pairs(C.catalog) do count=count+1 end
        local key=sender..":"..p[3]
        if count<200 or C.catalog[key] then C.catalog[key]={peer=sender,id=p[3],title=p[4],count=size,seen=now()} end
        return true
    elseif kind=="CATALOG" and channel=="CHANNEL" then
        if now()-(C.replyAt[sender] or -100)<20 then return true end
        C.replyAt[sender]=now()
        local count=0
        for id,item in pairs(FB.db.custom) do
            if item.published then
                local message,key,title,size=listing(item)
                if size then FB.Net.Send(message,"WHISPER",sender,key,title,size)
                else FB.Net.Send(message,"WHISPER",sender,key,title) end
                count=count+1
                if count>=10 then break end
            end
        end
        return true
    elseif kind=="GETBOARDS" and channel=="WHISPER" then
        local item=publishedLayout(p[3])
        local first=FB.Integer(p[4],1,C.maxBoards)
        if item and item.boards and first and first<=#item.boards and
            now()-(C.replyAt[sender..":boards"] or -100)>=0.15 then
            C.replyAt[sender..":boards"]=now()
            FB.Net.Send("BOARDS","WHISPER",sender,item.id,first,item.boards[first]..(item.boards[first+1] or ""))
        end
        return true
    elseif kind=="BOARDS" and channel=="WHISPER" then
        local key=sender..":"..tostring(p[3])
        local request=C.pending[key]
        if not request or not request.boards or now()-request.sent>12 then return true end
        local first=#request.boards+1
        local size=math.min(2,request.count-first+1)
        if FB.Integer(p[4],1,C.maxBoards)~=first or not p[5] or #p[5]~=98*size then return true end
        for n=1,size do
            local board=p[5]:sub((n-1)*98+1,n*98)
            if not C.Validate(board) then C.pending[key]=nil; FB.Print("Invalid board in level set."); return true end
            request.boards[#request.boards+1]=board
        end
        if #request.boards<request.count then
            request.attempts=0; askForBoards(request)
        else
            C.pending[key]=nil
            if "s"..C.Hash(C.Code(request.boards))~=request.id then FB.Print("Level set checksum mismatch."); return true end
            local id,err=C.SaveSet(request.title,request.boards,sender)
            FB.Print(id and ("Downloaded "..request.title.." ("..request.count.." boards).") or err)
        end
        return true
    elseif kind=="GETLEVEL" and channel=="WHISPER" then
        local item=publishedLayout(p[3])
        if item and item.data and now()-(C.replyAt[sender..":get"] or -100)>2 then
            C.replyAt[sender..":get"]=now()
            FB.Net.Send("LEVELDATA","WHISPER",sender,item.id,item.data)
        end
        return true
    elseif kind=="LEVELDATA" and channel=="WHISPER" then
        local key=sender..":"..tostring(p[3]); local request=C.pending[key]
        if request and not request.boards and now()-request.sent<=12 and p[4] and C.Hash(p[4])==request.id then
            local id,err=C.Save(request.title,p[4],sender)
            if FB.Debug then FB.Debug.Log("LEVEL",id and "downloaded" or "rejected",sender,request.id,err) end
            C.pending[key]=nil
            FB.Print(id and ("Downloaded "..request.title..". Open your level library to play.") or err)
        end
        return true
    end
    return false
end
