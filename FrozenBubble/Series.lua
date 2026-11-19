-- Online round readiness and victory limits from the Frozen Bubble room options.
local _,FB=...
local N=FB.Net
local S={limits={0,1,2,3,4,5,6,7,8,9,10,11,12,15,20,30,50,100}}
FB.Series=S
local indices={}
for i,limit in ipairs(S.limits) do indices[limit]=i end

function S.Valid(limit) return indices[limit]~=nil end
function S.Cycle(limit,direction)
    return S.limits[((indices[limit] or 1)-1+direction)%#S.limits+1]
end
function S.Label(limit) return limit==0 and "Unlimited" or "First to "..limit end
function S.Code(chains,limit,safePenalties)
    return limit*2+(chains and 2 or 1)+(safePenalties and 256 or 0)
end
function S.Decode(value)
    local code=FB.Integer(value,1,458)
    if not code then return end
    local safePenalties=code>256
    if safePenalties then code=code-256 end
    local limit=math.floor((code-1)/2)
    if S.Valid(limit) then return limit,code%2==0,safePenalties end
end
function S.Complete(m)
    local s=m and m.series
    return s and s.limit>0 and math.max(s.wins,s.losses)>=s.limit
end
function S.CanContinue(m)
    return m and m.phase=="done" and m.series and not m.departed and not S.Complete(m)
        and (m.result=="won" or m.result=="lost" or m.result=="draw")
end
function S.Caption(m)
    if not m or not m.series then return N.notice or "" end
    if m.result=="aborted" then return m.reason end
    if S.Complete(m) then
        return (m.series.wins>m.series.losses and "Series won" or "Series lost").." · "..m.series.wins.."–"..m.series.losses
    end
    if m.departed then return "Series closed" end
    return "Round "..m.round.." · "..S.Label(m.series.limit)
end
local function duration(seconds)
    local h=math.floor(seconds/3600)
    local m=math.floor(seconds/60)%60
    local s=seconds%60
    if h>0 then return string.format("%dh %02dm %02ds",h,m,s) end
    if m>0 then return string.format("%dm %02ds",m,s) end
    return s.."s"
end

-- show_mp_scores prints the elapsed session time, then ranks every seat,
-- including players who left. The desktop reverses seat order within ties.
function S.Report(m,correction)
    local session=m.series or m
    if not session.startedAt then return end
    if correction then
        if not session.reported then return end
    elseif session.reported then return end
    local log=FB.Community.Log
    local rows={}
    local function add(name,score)
        rows[#rows+1]={name=name,score=score,seat=#rows+1}
    end
    if m.arena then
        for _,name in ipairs(m.names) do
            local player=m.players[name]
            add(player.label,player.wins)
        end
    else
        local own,other=FB.Plaques.DuelNames(FB.PlayerName(),m.peer)
        local wins=m.series and m.series.wins or (m.result=="won" and 1 or 0)
        local losses=m.series and m.series.losses or (m.result=="lost" and 1 or 0)
        if m.host then add(own,wins); add(other,losses)
        else add(other,losses); add(own,wins) end
    end
    table.sort(rows,function(a,b)
        if a.score==b.score then return a.seat>b.seat end
        return a.score>b.score
    end)
    if correction then log("A round was corrected to a draw.")
    else
        session.reported=true
        if (session.limit or 0)>0 and rows[1].score>=session.limit then
            log("Game finished, because victories limit of "..session.limit.." was reached.")
        end
        log("Addicted for: "..duration(math.floor(GetTime()-session.startedAt)))
    end
    if rows[1].score>rows[2].score then log("Winner: "..rows[1].name)
    else log("Draw game!") end
    local scores={}
    for i,row in ipairs(rows) do scores[i]=row.name..": "..row.score end
    log("Scores: "..table.concat(scores,", "))
end

function S.Ready()
    local m=N.match
    if not S.CanContinue(m) or m.ready or InCombatLockdown() or not N.Available() then return end
    m.ready=true; m.readySince=GetTime(); m.lastReady=GetTime()
    N.Whisper("AGAIN",m.id,m.result)
    N.Notify("Waiting for "..m.peer.." to start the next round.")
end
function S.Leave(m)
    if m and (m.series or m.capable) then
        m.departed=true
        if m.phase~="playing" then S.Report(m) end
        N.Whisper("SERIESBYE",m.id)
        if m.parent and (m.phase=="restart" or m.phase=="barrier") then
            N.Whisper("SERIESBYE",m.parent)
            N.Whisper("CANCEL",m.id)
        end
    end
end
local function agrees(m,remote)
    return m.result=="draw" and remote=="draw" or m.result=="lost" and remote=="won"
        or m.result=="won" and remote=="lost"
end
local function advance(m)
    FB.Recordings.CloseOnline(m)
    local round=m.round+1
    local nextMatch={id=m.series.id..":"..round,peer=m.peer,seed=m.seed*16807%2147483647,
        host=m.host,phase="restart",since=GetTime(),lastSeen=GetTime(),lastRetry=-100,
        seq=0,remoteSeq=0,remoteAttack=0,chainReaction=m.chainReaction,limit=m.limit,safePenalties=m.safePenalties,
        capable=true,series=m.series,round=round,parent=m.id,parentResult=m.result,remote=m.remote}
    N.match=nextMatch
    return nextMatch
end
function S.Receive(kind,p,sender)
    local m=N.match
    if kind=="SERIESBYE" then
        local restarting=m and m.parent and (m.phase=="restart" or m.phase=="barrier")
        if m and not m.departed and sender==m.peer and (p[3]==m.id or restarting and p[3]==m.parent) then
            m.departed=true
            if restarting then N.match=nil end
            if m.phase=="done" or restarting then
                N.Notify("Your opponent left the series.")
                S.Report(m)
            end
        end
        return true
    end
    if kind~="AGAIN" and kind~="ROUNDSTART" then return false end
    if not m or m.peer~=sender or not m.series then
        local old=N.results[sender..":"..tostring(p[3])]
        if old and old.departed then N.Send("SERIESBYE","WHISPER",sender,old.id) end
        return true
    end
    if kind=="ROUNDSTART" and not m.host and m.parent==p[3] and (m.phase=="barrier" or m.phase=="playing" or m.phase=="done") then
        N.Whisper("READY",m.id); return true
    end
    if m.id~=p[3] or not S.CanContinue(m) or not agrees(m,p[4]) then return true end
    if kind=="AGAIN" then m.peerReady=true
    elseif not m.host and m.ready and not InCombatLockdown() and N.Available() then
        local nextMatch=advance(m)
        N.WaitForStart(nextMatch)
    end
    return true
end
function S.Update(m,t)
    if not S.CanContinue(m) then return end
    if m.ready and t-m.readySince>20 then
        S.Leave(m); N.Notify("The next round timed out."); return
    end
    if m.peerReady and not m.ready and FB.UI and FB.UI.CanAutoRematch and FB.UI:CanAutoRematch() then S.Ready() end
    if not m.ready or InCombatLockdown() then return end
    if m.host and m.peerReady then
        local nextMatch=advance(m)
        N.Whisper("ROUNDSTART",m.id,m.result); nextMatch.lastRetry=t
    elseif t-m.lastReady>=2 then
        N.Whisper("AGAIN",m.id,m.result); m.lastReady=t
    end
end
