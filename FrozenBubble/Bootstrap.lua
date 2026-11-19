local addon, FB = ...
_G.FrozenBubble = FB
FB.name = addon
FB.version = "0.1.0-alpha.3"
FB.media = "Interface\\AddOns\\" .. addon .. "\\Media\\"
FB.PREFIX = "FrozenBubble1"

function FB.Clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
function FB.Integer(s, lo, hi)
    local n = tonumber(s)
    if not n or n ~= n or n % 1 ~= 0 or n < lo or n > hi then return nil end
    return n
end
function FB.Split(s)
    local out = {}
    for field in (s .. "|"):gmatch("([^|]*)|") do out[#out + 1] = field end
    return out
end
function FB.Print(s)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff78dcffFrozen Bubble:|r " .. s) end
end
function FB.PlayerName(name)
    if not name then
        local player, realm = UnitFullName("player")
        name = player .. "-" .. (realm or GetNormalizedRealmName())
    elseif not name:find("-", 1, true) then
        name = name .. "-" .. GetNormalizedRealmName()
    end
    return name:gsub("%s", "")
end
function FB.Sound(name)
    if FB.UI and (FB.UI.inactive or FB.UI.frame and not FB.UI.frame:IsShown()) then return end
    if FB.db and FB.db.sound and PlaySoundFile then PlaySoundFile(FB.media .. name .. ".ogg", "SFX") end
end
