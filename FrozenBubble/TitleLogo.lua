-- Title artwork and animation equations from bin/frozen-bubble and CStuff.xs.
local _, FB = ...
local L={}; FB.TitleLogo=L
local data=FB.LogoData
local sin,cos,floor,min,max=math.sin,math.cos,math.floor,math.min,math.max
local path=FB.media.."Title\\"
local function place(tex,parent,x,y,w,h)
    tex:ClearAllPoints(); tex:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y); tex:SetSize(w,h)
end

-- Independent stream keeps cosmetic draws from consuming gameplay randomness.
local function random(s,n)
    s.seed=s.seed*16807%2147483647
    local v=(s.seed-1)/2147483646
    return n and floor(v*n)+1 or v
end

local function choose()
    local method=math.random(8)-1
    local today=date and date("*t")
    if type(today)=="table" then
        if today.month==12 and today.day==25 then return 8 end
        if (today.month==12 and today.day>=21 or today.month==1 or today.month==2 and today.day<=21)
            and math.random()<0.3 then return 8 end
    end
    return method
end

function L.New(menu,base)
    local panel=CreateFrame("Frame",nil,menu)
    panel:SetSize(212,145); panel:SetPoint("TOPLEFT",389,0)
    panel:SetClipsChildren(true); panel:EnableMouse(false)
    return {panel=panel,base=base,method=choose(),seed=math.random(1073741823),tick=0,pool={},used=0}
end

-- All effects share one texture pool. Switching graphics or effect releases
-- the old regions before assigning the new ones.
local function region(s,file,layer,blend)
    s.used=s.used+1
    local t=s.pool[s.used]
    if not t then
        t=s.panel:CreateTexture(nil,"ARTWORK"); s.pool[s.used]=t
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
    end
    t:SetDrawLayer("ARTWORK",layer or 0); t:SetBlendMode(blend or "BLEND")
    if file then t:SetTexture(path..file) end
    t:SetVertexColor(1,1,1); t:SetAlpha(1); t:Show()
    return t
end

local function clear(s)
    for i=1,s.used do s.pool[i]:Hide() end
    s.used=0; s.tiles=nil; s.glint=nil; s.noise=nil; s.stripes=nil; s.snow=nil
    s.base:ClearAllPoints(); s.base:SetPoint("TOPLEFT",400,-15)
    s.base.fbAsset=nil; FB.Animation.Frame(s.base,"menu-logo",1)
end

-- Draw the inverse mapping used by the desktop pixel sampler. Each quad
-- interpolates four source coordinates on the GPU. A second additive draw
-- supplies the extra light on the bright side of a fold.
local function mesh(s)
    local m=s.method
    local w,h=190,119
    local px,py,ox,oy=11,15,0,0
    if m==3 or m==4 then
        w,h=209,m==3 and 130 or 124
        px,py,ox,oy=1,m==3 and 9 or 12,9,m==3 and 5 or 2
    end
    local dx=m==0 and w or m==6 and 12 or 4
    local dy=m==6 and 12 or h
    s.tiles={}
    s.w,s.h,s.ox,s.oy=w,h,ox,oy
    for y=0,h-1,dy do
        for x=0,w-1,dx do
            local width,height=min(dx,w-x),min(dy,h-y)
            local t=region(s,"logo.tga")
            place(t,s.panel,px+x,py+y,width,height)
            local light
            if m==1 or m==4 then
                light=region(s,"logo.tga",1,"ADD")
                place(light,s.panel,px+x,py+y,width,height)
            end
            s.tiles[#s.tiles+1]={x=x,y=y,r=x+width,b=y+height,t=t,light=light}
        end
    end
    s.base:Hide()
end

local waterX,waterY={},{}
for i=0,199 do waterX[i]=2*cos(i*2*math.pi/200) end
for i=0,149 do waterY[i]=2*sin(i*2*math.pi/150) end

local function warp(s)
    if not s.tiles then mesh(s) end
    local m,k,w,h=s.method,s.tick,s.w,s.h
    local wave=sin(k/(m==4 and 40 or 50))
    local cx,cy=floor(w/2),floor(h/2)
    local angle=sin(k/40)/20
    local ca,sa=cos(angle),sin(angle)
    local function uv(x,y)
        local u,v=x,y
        if m==0 then
            u=(x-cx)*ca-(y-cy)*sa+cx
            v=(x-cx)*sa+(y-cy)*ca+cy
        elseif m==1 then
            u=x+sin((2*x+k)/50)*5
        elseif m==3 then
            local scale=1+wave/10
            u=(x-cx)*scale+cx
            v=(y-cy)*(1-wave*cos(math.pi*(x-cx)/w)/scale/8)+cy
        elseif m==4 then
            local scale=1+(x-cx)*wave/w/5
            u,v=(x-cx)*scale+cx,(y-cy)*scale+cy
        else
            u=x+waterX[(x+y+k)%200]
            v=y+waterY[(x+y+k)%150]
        end
        return (24+u-s.ox)/256,(24+v-s.oy)/256
    end
    for _,tile in ipairs(s.tiles) do
        local a,b=uv(tile.x,tile.y)
        local c,d=uv(tile.x,tile.b)
        local e,f=uv(tile.r,tile.y)
        local g,j=uv(tile.r,tile.b)
        tile.t:SetTexCoord(a,b,c,d,e,f,g,j)
        if tile.light then
            local gain=m==4 and 1-wave/10 or 1.1+cos((tile.x+tile.r+k)/50)/10
            local shade=min(1,gain)
            tile.t:SetVertexColor(shade,shade,shade)
            tile.light:SetTexCoord(a,b,c,d,e,f,g,j)
            tile.light:SetAlpha(max(0,gain-1))
        end
    end
end

local function glint(s)
    if not s.glint then s.glint=region(s,nil,1,"ADD") end
    local index=data.frames[floor(s.tick%(1000*math.pi)+0.5)%#data.frames+1]
    local center=data.centers[index+1]
    local t=s.glint
    local page=floor(index/256)+1
    if t.fbGlintPage~=page or not s.glintReady then
        t:SetTexture(path.."glint-"..page..".blp"); t.fbGlintPage=page; s.glintReady=true
    end
    local x,y=index%16/16,floor(index%256/16)/16
    t:SetTexCoord(x,x+1/16,y,y+1/16)
    place(t,s.panel,11+center%256-32,15+floor(center/256)-32,64,64)
end

local function white(x,y)
    x,y=floor(x)+1,floor(y)+1
    return data.white[y] and data.white[y]:byte(x)==49
end

local function updatePoints(s,steps)
    if not s.points then
        s.points={}
        for i=1,200 do
            local x,y
            repeat x=random(s,95)+47; y=random(s,59)+29 until white(x,y)
            local a=random(s)*2*math.pi
            s.points[i]={x=x,y=y,a=a,dx=cos(a),dy=sin(a)}
        end
    end
    for i,p in ipairs(s.points) do
        if not p.t then
            p.t=region(s,nil,1); p.t:SetColorTexture(1,0.8,0.8,0.8); p.t:SetSize(1,1)
        end
        local x,y=p.x,p.y
        for _=1,steps do
            x,y=p.x,p.y
            if not white(x+p.dx,y+p.dy) then
                for n=1,50 do
                    local angle=n*math.pi/50
                    local a=p.a+angle
                    if not white(x+cos(a),y+sin(a)) then a=p.a-angle end
                    if white(x+cos(a),y+sin(a)) then
                        p.a,p.dx,p.dy=a,cos(a),sin(a); break
                    end
                end
            end
            if white(x+p.dx,y+p.dy) then p.x,p.y=x+p.dx,y+p.dy end
        end
        p.t:ClearAllPoints(); p.t:SetPoint("TOPLEFT",s.panel,"TOPLEFT",11+floor(x),-15-floor(y))
    end
end

local function television(s,steps)
    if not s.stripes then
        s.stripes={}; s.noise=region(s,"noise.tga",1)
        place(s.noise,s.panel,11,15,190,119); s.base:Hide()
    end
    for k=s.tick-steps+1,s.tick do
        if (s.interference or 0)>0 then s.interference=s.interference-1
        elseif random(s,100)==1 then s.interference=floor(15+5*cos(k)) end
    end
    local noisy=(s.interference or 0)>0
    s.noise:SetShown(noisy)
    local count=0
    if noisy then
        local i=random(s,20)-1
        local x,y=i%5*192+1,floor(i/5)*121+1
        s.noise:SetTexCoord(x/1024,(x+190)/1024,y/512,(y+119)/512)
    else
        local k=s.tick
        local base=0.9+cos(k/50)*0.1
        local second=min(1,max(0,base+cos(k/30)*0.2))
        local period,phase=12+2*sin(k/50),k/10+sin(k/100)*5
        local first=0
        while first<119 do
            local sign=sin(first/period+phase)>0
            local last=first+1
            while last<119 and (sin(last/period+phase)>0)==sign do last=last+1 end
            count=count+1
            local t=s.stripes[count]
            if not t then t=region(s,"logo.tga"); s.stripes[count]=t end
            place(t,s.panel,11,15+first,190,last-first)
            t:SetTexCoord(24/256,214/256,(24+first)/256,(24+last)/256)
            t:SetAlpha(sign and base or second); t:Show(); first=last
        end
    end
    for i=count+1,#s.stripes do s.stripes[i]:Hide() end
end

-- The desktop compositor writes landed flakes back into the logo. Keep a
-- sparse alpha plane for those deposits, merging adjacent pixels when drawn.
local flakeAlpha={{0,0,0,0,0},{0,128,255,128,0},{0,255,255,255,0},
                  {0,128,255,128,0},{0,0,0,0,0}}
local function snowAlpha(s,x,y)
    local lx,ly=x-9,y-15
    local base=0
    if lx>=0 and lx<190 and ly>=0 and ly<119 then
        base=tonumber(data.alpha[ly+1]:sub(lx*2+1,lx*2+2),16)
    end
    local row=s.rows[y]
    local deposited=row and row[x] or 0
    return deposited+(255-deposited)*base/255
end

local function land(s,x,y,opacity)
    local ix,iy=floor(x),floor(y)
    local fx,fy=x-ix,y-iy
    for j=0,3 do
        local py=iy+j
        if py>=0 and py<134 then
            local row=s.rows[py]
            if not row then row={}; s.rows[py]=row end
            for i=0,3 do
                local px=ix+i
                if px>=0 and px<209 then
                    local a=flakeAlpha[j+1][i+1]*fx + flakeAlpha[j+1][i+2]*(1-fx)
                    local b=flakeAlpha[j+2][i+1]*fx + flakeAlpha[j+2][i+2]*(1-fx)
                    local alpha=(a*fy+b*(1-fy))*opacity
                    if alpha>0 then
                        local old=row[px] or 0
                        row[px]=floor(alpha+(255-alpha)*old/255+0.5); s.dirty[py]=true
                    end
                end
            end
        end
    end
end

local function drawBank(state,s)
    for py in pairs(s.dirty) do
        local line=s.lines[py] or {}; s.lines[py]=line
        local row=s.rows[py]
        local x,n=0,0
        while x<209 do
            local first=x
            local alpha=row[x] or 0
            repeat x=x+1 until x==209 or (row[x] or 0)~=alpha
            if alpha>0 then
                n=n+1
                local t=line[n]
                if not t then t=region(state,nil,1); t:SetColorTexture(1,1,1,1); line[n]=t end
                place(t,state.panel,1+first,py,x-first,1); t:SetAlpha(alpha/255); t:Show()
            end
        end
        for i=n+1,#line do line[i]:Hide() end
        s.dirty[py]=nil
    end
end

local function snowfall(state,steps)
    local s=state.snow
    if not s then
        s={flakes={},counter=1000,remaining=0,rows={},dirty={},lines={}}
        state.snow=s
        state.base:ClearAllPoints(); state.base:SetPoint("TOPLEFT",399,-15)
        for i=1,200 do s.flakes[i]={} end
    end
    for step=1,steps do
        for _,f in ipairs(s.flakes) do
            if not f.x then
                if s.remaining==0 then
                    f.x=1+random(state,202); f.y=-2; f.phase=100*random(state)
                    f.coeff=0.3+0.7*random(state); f.speed=0.1+0.2*random(state)
                    f.width=1+random(state); f.opacity=1; s.remaining=s.counter
                    s.counter=max(50,s.counter-2)
                else s.remaining=s.remaining-1 end
                if step==steps and f.t then f.t:Hide() end
            else
                local x=f.x+sin(f.phase*f.coeff)*f.width
                local ix,iy=floor(x),floor(f.y)
                local hit=iy>=0 and snowAlpha(s,ix,iy+1)>191+random(state,64)
                    and snowAlpha(s,ix+3,iy+1)>191+random(state,64)
                if hit then land(s,x,f.y,f.opacity) end
                if step==steps then
                    if not f.t then
                        f.t=region(state,"flake.tga",2); f.t:SetTexCoord(0,5/8,0,5/8)
                    end
                    place(f.t,state.panel,1+x-1,f.y-1,5,5); f.t:SetAlpha(f.opacity); f.t:SetShown(not hit)
                end
                f.phase=f.phase+0.1; f.y=f.y+f.speed
                if f.y>112 then f.opacity=(132-f.y)/20 end
                if hit or f.y>=130 then f.x=nil end
            end
        end
    end
    drawBank(state,s)
end

function L.Draw(s,steps,enabled)
    local mode=enabled and s.method or -1
    if s.active==mode and steps==0 then return end
    if s.active~=mode then
        clear(s); s.glintReady=nil
        if s.points then for _,p in ipairs(s.points) do p.t=nil end end
        if mode>=0 then
            s.base:SetTexture(path.."logo.tga"); s.base:SetTexCoord(24/256,214/256,24/256,143/256)
        end
        s.active=mode
    end
    if mode<0 then return end
    s.tick=s.tick+steps
    if mode==2 then glint(s)
    elseif mode==5 then updatePoints(s,steps)
    elseif mode==7 then television(s,steps)
    elseif mode==8 then snowfall(s,steps)
    else warp(s) end
end
L.Choose=choose
