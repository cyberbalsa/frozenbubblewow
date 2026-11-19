-- Three to five players. The host owns seats and round results. Each player
-- simulates their own shots and sends cumulative penalties to each opponent.
local _, FB=...
local N=FB.Net
local A={rooms={}}
FB.Arena=A
local unpackFields=unpack or table.unpack
local function validName(s)
    return type(s)=="string" and #s>=2 and #s<=100 and not s:find("[|,%s%c~]")
end
local function serial()
    N.serial=N.serial+1
    return tostring((time()+math.floor(GetTime()*1000)+N.serial*7919)%2147483646+1).."-"..N.serial
end
local function send(to,kind,...)
    return N.Send(kind,"WHISPER",to,...)
end
function A.Fan(kind,...)
    local m=N.match
    local ok=true
    for _,name in ipairs(m.names) do
        if name~=m.me and not m.players[name].left and not send(name,kind,...) then ok=false end
    end
    return ok
end
local function free()
    return not N.match and not N.queue and not InCombatLockdown() and N.Available()
end
local function room(host,id)
    local m={arena=true,me=FB.PlayerName(),peer=host,host=host==FB.PlayerName(),room=id,
        phase="joining",round=0,revision=0,leftMask=0,names={},players={},since=GetTime(),lastHost=GetTime(),pulse=-100}
    if FB.game then FB.game.paused=true end
    N.match=m
    return m
end
local function seat(m,name)
    m.names[#m.names+1]=name
    local short=name:match("^[^-]+")
    local label=short
    for _,v in pairs(m.players) do
        if v.short==short then label=name; v.label=v.name end
    end
    m.players[name]={index=#m.names,name=name,short=short,label=label,wins=0,seen=GetTime()}
end
local function announce(m,manual)
    local count=m.phase=="room" and #m.names or 0
    local code=FB.Series.Code(m.chainReaction,m.limit)
    if manual then FB.Community.Manual("AROOM",m.room,count,code)
    else N.Broadcast("AROOM",m.room,count,code) end
    m.advert=GetTime()
end
function A.Announce() local m=N.match; if m and m.arena and m.host then announce(m,true) end end
function A.Host()
    if not free() then return end
    local m=room(FB.PlayerName(),serial())
    m.phase="room"; m.revision=1; m.limit=FB.db.versusLimit; m.chainReaction=FB.db.versusChains==true
    m.keepRoom=FB.db.arenaContinue~=false; m.targeting=FB.db.arenaTargeting~=false
    seat(m,m.me); announce(m)
    N.Notify("Room open. Start when at least three players have joined.")
end
function A.Join(host)
    if not free() or not validName(host) then return end
    host=FB.PlayerName(host)
    if host==FB.PlayerName() then return end
    local listing=A.rooms[host]
    local m=room(host,listing and listing.id or "*")
    m.nonce=serial()
    send(host,"AJOIN",m.room,m.nonce); m.pulse=GetTime()
    N.Notify("Joining "..host.."'s room…")
end
function A.Expire(t)
    for host,v in pairs(A.rooms) do if t-v.seen>24 then A.rooms[host]=nil end end
end
local function seats(m,name)
    local words={}
    local code=FB.Series.Code(m.chainReaction,m.limit)
    local function part(first)
        send(name,"ASEATS",m.room,m.players[name].nonce,m.revision,#m.names,first,code,table.concat(words,","),(m.keepRoom and 1 or 0)+(m.targeting and 2 or 0))
    end
    local first,length=1,0
    for i,n in ipairs(m.names) do
        if length+#n>146 then part(first); words={}; length=0; first=i end
        words[#words+1]=n; length=length+#n+1
    end
    part(first)
end
local function acceptSeats(m,p)
    if m.host or not (m.phase=="joining" or m.phase=="room") or p[4]~=m.nonce
        or not p[3]:match("^%d+%-%d+$") or #p[3]>32 or (m.room~="*" and m.room~=p[3]) then return end
    local rev,count,first=FB.Integer(p[5],1,1000000),FB.Integer(p[6],2,5),FB.Integer(p[7],1,5)
    local limit,chains=FB.Series.Decode(p[8])
    local flags=FB.Integer(p[10],0,3)
    if not flags or not rev or rev<=m.revision or rev<(m.pendingRev or 0) or not count or not first or not limit or not p[9] then return end
    if m.pendingRev~=rev then m.pendingRev=rev; m.seats={} end
    for name in p[9]:gmatch("[^,]+") do
        if first>count or not validName(name) or FB.PlayerName(name)~=name then return end
        m.seats[first]=name; first=first+1
    end
    local members={}
    for i=1,count do
        local name=m.seats[i]
        if not name or members[name] then return end
        members[name]=true
    end
    if m.seats[1]~=m.peer or not members[m.me] then return end
    m.names={}; m.players={}
    for i=1,count do seat(m,m.seats[i]) end
    m.revision,m.room,m.phase,m.limit,m.chainReaction=rev,p[3],"room",limit,chains
    m.keepRoom=flags%2==1; m.targeting=flags>=2
    m.lastHost=GetTime(); m.pulse=-100
    N.Notify("In "..m.peer.."'s room. "..count.." of 5 seats filled.")
end
local function close(m,reason)
    if N.match~=m then return end
    if m.played and FB.game and FB.game.mode=="versus" then FB.game=nil end
    N.match=nil
    if FB.UI and FB.UI.screen=="opponent" then FB.UI:ShowLobby() end
    N.Notify(reason)
end
function A.Leave(reason)
    local m=N.match
    if not m or not m.arena then return end
    if m.host then
        A.Fan("ACLOSE",m.room)
        N.Broadcast("AROOM",m.room,0,FB.Series.Code(m.chainReaction,m.limit))
    else
        send(m.peer,"ALEAVE",m.room,m.nonce)
        if m.phase=="playing" and m.keepRoom and not reason then FB.db.losses=FB.db.losses+1 end
    end
    close(m,reason or "Left the room.")
end
local function prepare(m,round,seed)
    m.round,m.seed=round,seed
    m.id=m.room..":"..round; m.phase="seating"; m.since=GetTime(); m.pulse=-100
    m.winner=nil; m.target=nil; m.finishSince=nil; m.mask=m.leftMask; m.wantNext=nil; m.requested=nil
    for _,name in ipairs(m.names) do
        local v=m.players[name]
        v.ready=name==m.me; v.lost=v.left==true; v.sent=0; v.ackMask=-1; v.target=nil; v.wantNext=nil
        v.chatUntil=nil; v.chatText=nil; v.remote=nil; v.remoteSeq=0; v.remoteAttack=0; v.remoteShots=nil; v.remoteLocked=nil
        v.remoteFire=nil; v.chainBase=nil; v.chainBudget=nil; v.chainReaction=m.chainReaction
    end
end
function A.Complete(m)
    if m.winner and m.winner>0 and m.limit>0 and m.players[m.names[m.winner]].wins>=m.limit then return true end
    local present=0
    for _,v in pairs(m.players) do if not v.left then present=present+1 end end
    return m.phase=="done" and present<=1
end
function A.Start()
    local m=N.match
    if not m or not m.arena or InCombatLockdown() then return end
    if m.phase=="done" and not A.Complete(m) then
        m.wantNext=true; m.players[m.me].wantNext=true; m.pulse=-100
        N.Notify("Ready for the next round."); return
    end
    if not m.host or m.phase~="room" or #m.names<3 then return end
    prepare(m,1,tonumber(m.room:match("^%d+")))
    announce(m); N.Notify("Waiting for every board to be ready.")
end
function A.Opponents(m)
    local list={}
    for _,n in ipairs(m.names) do if n~=m.me then list[#list+1]=m.players[n] end end
    return list
end
function A.Target(slot)
    local m=N.match
    if not m or not m.arena or m.phase~="playing" or FB.game.status~="playing" then return end
    local v=A.Opponents(m)[slot]
    if slot~=0 and (not m.targeting or not v or v.lost) then return end
    m.target=v and v.name; m.lastState=-100
end
function A.Penalty(n)
    local m=N.match
    if not m or not m.arena or m.phase~="playing" then return end
    local count=0
    for _,v in pairs(m.players) do if v.name~=m.me and not v.lost then count=count+1 end end
    if count==0 then return end
    if m.target and m.players[m.target].lost then m.target=nil end
    for _,v in pairs(m.players) do
        if v.name~=m.me and not v.lost and (not m.target or v.name==m.target) then
            v.sent=v.sent+(m.target and n or math.ceil(n/count))
        end
    end
end
function A.SendStates(m,fields)
    local target=m.target and m.players[m.target].index or 0
    for _,v in pairs(m.players) do
        if v.name~=m.me and not v.left then
            fields[6]=v.sent
            fields[17]=target
            if not send(v.name,"ASTATE",unpackFields(fields,1,17)) then
                local tick=fields[13]; fields[13]=target
                send(v.name,"ASTATE",unpackFields(fields,1,13)); fields[13]=tick
            end
        end
    end
end
local function begin(m)
    if InCombatLockdown() then A.Leave("Combat started."); return false end
    m.phase="playing"; m.seq=0; m.lastState=-100; m.played=true
    for _,v in pairs(m.players) do
        if v.name~=m.me then
            v.remote=FB.Engine.New(nil,m.seed,"versus",m.chainReaction)
            v.remote.launchY=362; v.remote.hurryMax=math.huge; v.phase="playing"; v.lastSeen=GetTime()
        end
    end
    FB.StartVersus(m.seed,m.chainReaction)
    FB.game.launchY=362; FB.game.onPenalty=A.Penalty; FB.game.onShoot=N.Fire
    N.Notify("Round "..m.round.." · "..#m.names.." players")
    m.pulse=-100
    return true
end
local function lost(m,v)
    if v.lost then return end
    v.lost=true; m.mask=m.mask+2^(v.index-1)
    if v.remote then v.remote.status="lost"; v.remote.projectile=nil; v.phase="done" end
    if v.name==m.me or m.target==v.name then m.target=nil end
    m.pulse=-100
end
local function depart(m,v)
    if m.phase=="room" then
        table.remove(m.names,v.index); m.players[v.name]=nil
        for i,n in ipairs(m.names) do m.players[n].index=i end
        m.revision=m.revision+1; m.pulse=-100; m.advert=-100
    elseif m.keepRoom then
        if not v.left then
            v.left=true; m.leftMask=m.leftMask+2^(v.index-1)
            lost(m,v); m.pulse=-100
            if m.host and m.phase=="seating" and m.leftMask==2^#m.names-2 then
                A.Leave("Everyone else left before the round started.")
            end
        end
    else A.Leave(v.name.." left the room.") end
end
local function syncDepartures(m,mask)
    for _,v in pairs(m.players) do
        if math.floor(mask/2^(v.index-1))%2==1 and not v.left then depart(m,v) end
    end
end
local function finish(m,winner)
    if m.phase~="playing" then return end
    m.phase="done"; m.winner=winner; m.pulse=-100
    local name=m.names[winner]
    if name then m.players[name].wins=m.players[name].wins+1 end
    for _,v in pairs(m.players) do
        local g=v.name==m.me and FB.game or v.remote
        g.status=not name and "draw" or name==v.name and "won" or "lost"; g.projectile=nil
        v.phase="done"
    end
    if name then
        local key=name==m.me and "wins" or "losses"
        FB.db[key]=FB.db[key]+1; FB.Sound(name==m.me and "applause" or "lose")
    end
    N.Notify(name and (name.." won round "..m.round..".") or "Draw.")
end
local function pulse(m)
    if m.host then
        for _,v in pairs(m.players) do
            if v.name~=m.me and not v.left then
                if (v.rev or 0)<m.revision then seats(m,v.name)
                elseif m.phase=="seating" then send(v.name,"APREP",m.room,m.revision,m.round,m.seed,m.leftMask)
                else send(v.name,"AHOST",m.room,m.revision,m.round,m.mask or 0,m.winner or -1,(m.requested or m.wantNext) and 1 or 0,m.leftMask) end
            end
        end
    elseif m.phase=="joining" then send(m.peer,"AJOIN",m.room,m.nonce)
    else
        send(m.peer,"APULSE",m.room,m.nonce,m.revision,m.round,m.phase,
            m.players[m.me].lost and 1 or 0,m.mask or 0,m.wantNext and 1 or 0)
    end
    m.pulse=GetTime()
end
function A.Receive(kind,p,channel,sender)
    if kind=="AROOM" and channel~="WHISPER" then
        local count=FB.Integer(p[4],0,5); local limit,chains=FB.Series.Decode(p[5])
        if not p[3] or #p[3]>32 or not p[3]:match("^%d+%-%d+$") or not count or not limit then return true end
        local total=0; for _ in pairs(A.rooms) do total=total+1 end
        if count==0 then A.rooms[sender]=nil
        elseif total<100 or A.rooms[sender] then A.rooms[sender]={id=p[3],seen=GetTime(),count=count,limit=limit,chains=chains} end
        return true
    end
    if channel~="WHISPER" or not kind or kind:sub(1,1)~="A" or kind=="ACCEPT" or kind=="AGAIN" then return false end
    local m=N.match
    if not m or not m.arena or not p[3] then return true end
    if m.phase=="joining" and (kind=="ASEATS" or kind=="AFULL") and sender:lower()==m.peer:lower() then m.peer=sender end
    if kind=="AJOIN" and m.host and m.phase=="room" and (p[3]=="*" or m.room==p[3]) then
        if not validName(sender) or not p[4] or not p[4]:match("^%d+%-%d+$") or #p[4]>32 then return true end
        local v=m.players[sender]
        if not v and #m.names>=5 then send(sender,"AFULL",p[4]); return true end
        if not v then seat(m,sender); v=m.players[sender]; m.revision=m.revision+1; m.advert=-100 end
        v.nonce=p[4]; v.seen=GetTime(); seats(m,sender); m.pulse=-100
    elseif kind=="ASEATS" and sender==m.peer then acceptSeats(m,p)
    elseif kind=="AFULL" and sender==m.peer and m.phase=="joining" and p[3]==m.nonce then close(m,"That room is full.")
    elseif kind=="ACLOSE" and not m.host and sender==m.peer and p[3]==m.room then close(m,"The host closed the room.")
    elseif kind=="ALEAVE" and m.host and m.players[sender] and p[4]==m.players[sender].nonce and (p[3]==m.room or p[3]=="*") then
        depart(m,m.players[sender])
    elseif kind=="APREP" and not m.host and sender==m.peer and p[3]==m.room and tonumber(p[4])==m.revision then
        local round,seed=FB.Integer(p[5],1,1000000),FB.Integer(p[6],1,2147483646)
        local left=FB.Integer(p[7],0,2^#m.names-1)
        if (m.phase=="room" or m.phase=="done") and round==m.round+1 and seed and left and #m.names>=3 then
            prepare(m,round,seed); syncDepartures(m,left); m.lastHost=GetTime(); pulse(m)
        end
    elseif kind=="APULSE" and m.host and p[3]==m.room then
        local v=m.players[sender]
        if v and not v.left and v.nonce==p[4] then
            v.seen=GetTime(); v.rev=FB.Integer(p[5],0,m.revision) or 0
            if tonumber(p[6])==m.round and v.rev==m.revision then
                if m.phase=="seating" and p[7]=="seating" then v.ready=true end
                if m.phase=="playing" and p[7]=="playing" then
                    if p[8]=="1" then lost(m,v) end
                    v.ackMask=FB.Integer(p[9],0,31)
                end
                if m.phase=="done" and p[7]=="done" and p[10]=="1" then v.wantNext=true; m.requested=true end
            end
        end
    elseif kind=="AHOST" and not m.host and sender==m.peer and p[3]==m.room and tonumber(p[4])==m.revision and tonumber(p[5])==m.round then
        local mask,winner=FB.Integer(p[6],0,2^#m.names-1),FB.Integer(p[7],-1,#m.names)
        local left=FB.Integer(p[9],0,2^#m.names-1)
        if not mask or not winner or not left then return true end
        m.lastHost=GetTime()
        if m.phase~="room" and m.phase~="joining" then syncDepartures(m,left) end
        if m.phase=="seating" and not begin(m) then return true end
        if m.phase=="playing" then
            for _,v in pairs(m.players) do if math.floor(mask/2^(v.index-1))%2==1 then lost(m,v) end end
            if winner>=0 then finish(m,winner) end
        end
        if m.phase=="done" and p[8]=="1" then m.requested=true end
    elseif p[3]==m.id and m.phase=="playing" then
        local v=m.players[sender]
        if v and not v.left and kind=="ACHAT" then FB.MatchChat.Receive(m,table.concat(p,"|",4),v)
        elseif v and not v.lost then
            if kind=="AFIRE" then FB.PeerView.Fire(v,p)
            elseif kind=="ASTATE" and (#p==19 or #p==15) then
                local target=FB.Integer(p[#p],0,#m.names)
                if target then
                    p[#p]=nil
                    local before=v.remoteSeq; N.ApplyState(v,p)
                    if before~=v.remoteSeq then v.target=m.names[target] end
                end
            end
        end
    end
    return true
end
function A.Update(m,dt,t)
    if m.phase=="joining" and t-m.since>22 then close(m,"Room unavailable."); return end
    if m.phase~="joining" and not m.host and t-m.lastHost>35 then close(m,"Lost contact with the host."); return end
    if m.host then
        for _,v in pairs(m.players) do
            if v.name~=m.me and not v.left and t-v.seen>35 then depart(m,v); return end
        end
        if m.phase=="room" and t-(m.advert or 0)>=8 then announce(m) end
        if m.phase=="seating" then
            local ready=true
            for _,v in pairs(m.players) do if not v.left and not v.ready then ready=false end end
            if ready then
                if not begin(m) then return end
            elseif t-m.since>30 then A.Leave("The room could not synchronize."); return end
        end
    end
    if m.phase=="playing" or m.phase=="done" then
        for _,v in pairs(m.players) do if v.remote and not v.left then FB.PeerView.Update(v,dt) end end
    end
    if m.phase=="playing" then
        if FB.game.status=="lost" then lost(m,m.players[m.me]) end
        if t-m.lastState>=3 then N.State() end
        if m.host then
            local count,last=0,nil
            for _,v in pairs(m.players) do if not v.lost then count=count+1; last=v end end
            if count<=1 then
                m.finishSince=m.finishSince or t
                if count==0 or t-m.finishSince>=1 and (last.name==m.me or last.ackMask==m.mask) then finish(m,last and last.index or 0) end
            end
        end
    elseif m.phase=="done" and not A.Complete(m) then
        if m.requested and not m.wantNext and FB.UI and FB.UI:CanAutoRematch() then A.Start() end
        if m.host and (m.wantNext or m.requested) then
            local ready=true
            for _,v in pairs(m.players) do if not v.left and not v.wantNext then ready=false end end
            if ready then m.requested=nil; prepare(m,m.round+1,m.seed*16807%2147483647) end
        end
    end
    if t-m.pulse>=3 then pulse(m) end
end
