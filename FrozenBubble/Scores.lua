local _, FB = ...
local S = {}; FB.Scores = S
S.modes={"campaign","endless","training","training-chain"}
function S.Label(mode)
    return mode=="training-chain" and "Training (chain)" or (mode:gsub("^%l",string.upper))
end
function S.Init(db)
    if not FB.Series.Valid(db.versusLimit) then db.versusLimit=db.schema and 0 or 5 end
    db.schema=1
    db.scores=db.scores or {}; db.pendingScores=db.pendingScores or {}; db.peers=db.peers or {}; db.custom=db.custom or {}
    db.unlocked=FB.Clamp(tonumber(db.unlocked) or 1,1,100)
    if db.sound==nil then db.sound=true end
    if db.music==nil then db.music=true end
    if db.musicVolume==nil then db.musicVolume=0.8 end
    db.wins=db.wins or 0; db.losses=db.losses or 0
end
-- Campaign progress outranks points; the original uses time to break ties
-- at the same level. An old level-100 record does not identify a clear.
local function better(a,b)
    if a.mode=="campaign" then
        if (a.completed==true)~=(b.completed==true) then return a.completed==true end
        if a.level~=b.level then return a.level>b.level end
        return (a.elapsed or a.seconds)<(b.elapsed or b.seconds)
    elseif a.score~=b.score then return a.score>b.score end
    return a.seconds<b.seconds
end
local function ordered(a,b)
    if better(a,b) then return true end
    if better(b,a) then return false end
    if a.name~=b.name then return a.name<b.name end
    return (a.date or 0)<(b.date or 0)
end
local function makeEntry(mode,score,level,seconds,completed)
    local entry={name=FB.PlayerName(),mode=mode,score=math.floor(score),level=level or 1,
        seconds=math.floor(seconds),date=time(),completed=completed==true and mode=="campaign" and level==100 or nil}
    if mode=="campaign" then entry.elapsed=seconds end
    return entry
end
local function store(entry)
    local rows,mode=FB.db.scores,entry.mode
    rows[#rows+1]=entry
    local worst,count=nil,0
    for i,row in ipairs(rows) do
        if row.mode==mode then
            count=count+1
            if not worst or not ordered(row,rows[worst]) then worst=i end
        end
    end
    if count>30 and table.remove(rows,worst)==entry then return end
    S.revision=(S.revision or 0)+1
    return entry
end
function S.Record(mode,score,level,seconds,completed)
    if mode=="custom" or mode=="versus" then return end
    return store(makeEntry(mode,score,level,seconds,completed))
end

-- handle_new_hiscores compares the run with the last entry in each
-- desktop table. A tie at the cutoff also gets the name prompt.
function S.Qualifies(entry)
    local mode=entry.mode
    if mode~="campaign" and mode~="training" and mode~="training-chain" then return false end
    local limit=mode=="campaign" and 10 or 20
    local ahead=0
    for _,row in ipairs(FB.db.scores) do
        if row.mode==mode and (mode=="campaign" and better(row,entry) or mode~="campaign" and row.score>entry.score) then
            ahead=ahead+1
        end
    end
    return ahead<limit
end

function S.Finish(mode,score,level,seconds,completed)
    local entry=makeEntry(mode,score,level,seconds,completed)
    if not S.Qualifies(entry) then return store(entry) end
    FB.db.pendingScores[#FB.db.pendingScores+1]=entry
    return entry
end

-- Keep interrupted name entries across reloads. Only accepted scores appear
-- in a leaderboard or answer a community score query.
function S.Pending(entry)
    local owner=FB.PlayerName()
    for i,row in ipairs(FB.db.pendingScores) do
        if row.name==owner and (not entry or entry==row) then return row,i end
    end
end

function S.Submit(entry,value)
    local pending,index=S.Pending(entry)
    if not pending or pending~=entry then return end
    table.remove(FB.db.pendingScores,index)
    local name=(value or ""):gsub("[|%c]",""):match("^%s*(.-)%s*$")
    if name=="" or #name>96 then return end
    entry.displayName=name
    return store(entry)
end
function S.Best(mode,name)
    local best
    for _,row in ipairs(FB.db.scores) do
        if row.mode==mode and (not name or row.name==name) and (not best or ordered(row,best)) then best=row end
    end
    return best
end
function S.Fields(row)
    return row.mode,row.score,row.level,row.seconds,row.completed and 1 or 0
end
function S.Receive(sender,fields)
    local mode=fields[3]
    if mode~="campaign" and mode~="endless" and mode~="training" and mode~="training-chain" then return end
    local score=FB.Integer(fields[4],0,100000000)
    local level=FB.Integer(fields[5],1,100)
    local seconds=FB.Integer(fields[6],0,10000000)
    if not score or not level or not seconds then return end
    if fields[7] and fields[7]~="0" and fields[7]~="1" then return end
    local completed=fields[7]=="1"
    if completed and (mode~="campaign" or level~=100) then return end
    local key=sender..":"..mode
    local entry={name=sender,mode=mode,score=score,level=level,seconds=seconds,date=time(),completed=completed or nil}
    local old=FB.db.peers[key]
    if old and not better(entry,old) then return end
    FB.db.peers[key]=entry; S.revision=(S.revision or 0)+1
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
        local players={}
        local function consider(row)
            if row.mode==mode and (not players[row.name] or ordered(row,players[row.name])) then
                players[row.name]=row
            end
        end
        for _,row in ipairs(FB.db.scores) do consider(row) end
        for _,row in pairs(FB.db.peers) do consider(row) end
        for _,row in pairs(players) do rows[#rows+1]=row end
    else for _,row in ipairs(FB.db.scores) do if row.mode==mode then rows[#rows+1]=row end end end
    table.sort(rows,ordered)
    return rows
end
