local _, FB = ...
local S = {}; FB.Scores = S
S.modes={"campaign","endless","training"}
function S.Init(db)
    db.schema=1
    db.scores=db.scores or {}; db.peers=db.peers or {}; db.custom=db.custom or {}
    db.unlocked=FB.Clamp(tonumber(db.unlocked) or 1,1,100)
    if db.sound==nil then db.sound=true end
    if db.music==nil then db.music=true end
    if db.musicVolume==nil then db.musicVolume=0.8 end
    db.wins=db.wins or 0; db.losses=db.losses or 0
end
function S.Record(mode, score, level, seconds)
    if mode=="custom" or mode=="versus" then return end
    local rows=FB.db.scores
    rows[#rows+1]={name=FB.PlayerName(),mode=mode,score=math.floor(score),level=level or 1,
        seconds=math.floor(seconds),date=time()}
    table.sort(rows,function(a,b) return a.score>b.score end)
    local count=0
    for i,row in ipairs(rows) do
        if row.mode==mode then
            count=count+1
            if count>30 then table.remove(rows,i); break end
        end
    end
end
function S.Best(mode)
    for _,row in ipairs(FB.db.scores) do if row.mode==mode then return row end end
end
function S.Receive(sender, fields)
    local mode=fields[3]
    if mode~="campaign" and mode~="endless" and mode~="training" then return end
    local score=FB.Integer(fields[4],0,100000000)
    local level=FB.Integer(fields[5],1,100)
    local seconds=FB.Integer(fields[6],0,10000000)
    if not score or not level or not seconds then return end
    local key=sender..":"..mode
    local old=FB.db.peers[key]
    if old and old.score>=score then return end
    FB.db.peers[key]={name=sender,mode=mode,score=score,level=level,seconds=seconds,date=time()}
    local keys={}
    for k in pairs(FB.db.peers) do keys[#keys+1]=k end
    if #keys>100 then
        table.sort(keys,function(a,b) return FB.db.peers[a].date<FB.db.peers[b].date end)
        for i=1,#keys-100 do FB.db.peers[keys[i]]=nil end
    end
end
function S.Rows(shared,mode)
    local rows={}
    if shared then
        local best=S.Best(mode); if best then rows[#rows+1]=best end
        for _,row in pairs(FB.db.peers) do if row.mode==mode then rows[#rows+1]=row end end
    else for _,row in ipairs(FB.db.scores) do if row.mode==mode then rows[#rows+1]=row end end end
    table.sort(rows,function(a,b) if a.score==b.score then return a.seconds<b.seconds end; return a.score>b.score end)
    return rows
end
