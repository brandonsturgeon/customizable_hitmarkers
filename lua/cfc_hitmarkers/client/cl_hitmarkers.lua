CFC_Hitmarkers = CFC_Hitmarkers or {}
CFC_Hitmarkers.Colors = CFC_Hitmarkers.Colors or {}

local hitmarkerColors = CFC_Hitmarkers.Colors
local hitDuration
local miniHitDuration

local UPDATE_INTERVAL = 0.01
local ROUND_DECIMALS = 1
local HIT_SIZE = 30
local MINI_SIZE = 30
local MINI_SPEED_MIN = 1.5
local MINI_SPEED_MAX = 3
local MINI_INERTIA = 0.93
local MINI_GRAVITY = 0.03

local FONT_DATA = {
    font = "Roboto Mono",
    extended = false,
    size = HIT_SIZE,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    Additive = false,
    outline = false,
}

surface.CreateFont( "CFC_Hitmarkers_HitFont", FONT_DATA )
FONT_DATA.size = MINI_SIZE
surface.CreateFont( "CFC_Hitmarkers_MiniFont", FONT_DATA )

local HITMARKERS_ENABLED = CreateClientConVar( "cfc_hitmarkers_enabled", 1, true, false, "Enables hitmarkers.", 0, 1 )
local HITMARKERS_NPC_ENABLED = CreateClientConVar( "cfc_hitmarkers_npc_enabled", 0, true, false, "Enables hitmarkers for NPCs.", 0, 1 )
local HITMARKERS_ENT_ENABLED = CreateClientConVar( "cfc_hitmarkers_ent_enabled", 0, true, false, "Enables hitmarkers for other entities.", 0, 1 )
local HITMARKERS_SOUND_ENABLED = CreateClientConVar( "cfc_hitmarkers_sound_enabled", 1, true, false, "Enables hitmarker sounds.", 0, 1 )

local HIT_DURATION = CreateClientConVar( "cfc_hitmarkers_hit_duration", 3, true, false, "How long large hit numbers will linger for. 0 to disable.", 0, 10 )
local MINI_DURATION = CreateClientConVar( "cfc_hitmarkers_mini_duration", 2.5, true, false, "How long mini hit numbers will linger for. 0 to disable.", 0, 10 )

local HIT_SOUND = CreateClientConVar( "cfc_hitmarkers_hit_sound", "buttons/lightswitch2.wav", true, false, "Sound used for regular hits." )
local HEADSHOT_SOUND = CreateClientConVar( "cfc_hitmarkers_headshot_sound", "buttons/button16.wav", true, false, "Sound used for headshots." )
local KILL_SOUND = CreateClientConVar( "cfc_hitmarkers_kill_sound", "buttons/combine_button1.wav", true, false, "Sound used for kills." )

local HIT_SOUND_VOLUME = CreateClientConVar( "cfc_hitmarkers_hit_sound_volume", 1.5, true, false, "Volume for hit sounds.", 0, 4 )
local HEADSHOT_SOUND_VOLUME = CreateClientConVar( "cfc_hitmarkers_headshot_sound_volume", 1, true, false, "Volume for headshot sounds.", 0, 4 )
local KILL_SOUND_VOLUME = CreateClientConVar( "cfc_hitmarkers_kill_sound_volume", 1.5, true, false, "Volume for kill sounds.", 0, 4 )

local HIT_COLOR = CreateClientConVar( "cfc_hitmarkers_hit_color", "255 0 0", true, false, "Color for hit numbers." )
local MINI_COLOR = CreateClientConVar( "cfc_hitmarkers_mini_hit_color", "255 100 0", true, false, "Color for mini hit numbers." )

function CFC_Hitmarkers.GetColorFromConvar( colorName, fallbackColor )
    local convarName = "cfc_hitmarkers_" .. colorName .. "_color"
    local col
    local result = ProtectedCall( function()
        local colTbl = string.Explode( " ", GetConVar( convarName ):GetString() )
        col = Color( tonumber( colTbl[1] ), tonumber( colTbl[2] ), tonumber( colTbl[3] ), 255 )
    end )

    return result and col or fallbackColor or Color( 255, 255, 255, 255 ), result
end

function CFC_Hitmarkers.SetColorFromConvar( colorName, fallbackStr, fallbackColor )
    local convarName = "cfc_hitmarkers_" .. colorName .. "_color"
    local col, result = CFC_Hitmarkers.GetColorFromConvar( colorName, fallbackColor )

    if result then
        hitmarkerColors[colorName] = col
    else
        hitmarkerColors[colorName] = fallbackColor or Color( 255, 255, 255, 255 )
        LocalPlayer():ConCommand( convarName .. " " .. ( fallbackStr or "255 255 255" ) )
    end
end

if not hitmarkerColors.hit then
    CFC_Hitmarkers.SetColorFromConvar( "hit", "255 0 0", Color( 255, 0, 0, 255 ) )
end

if not hitmarkerColors.mini_hit then
    CFC_Hitmarkers.SetColorFromConvar( "mini_hit", "255 100 0", Color( 255, 100, 0, 255 ) )
end

cvars.AddChangeCallback( "cfc_hitmarkers_hit_color", function()
    CFC_Hitmarkers.SetColorFromConvar( "hit", "255 0 0", Color( 255, 0, 0, 255 ) )
end )

cvars.AddChangeCallback( "cfc_hitmarkers_mini_hit_color", function()
    CFC_Hitmarkers.SetColorFromConvar( "mini_hit", "255 0 0", Color( 255, 0, 0, 255 ) )
end )

cvars.AddChangeCallback( "cfc_hitmarkers_hit_duration", function( _, old, new )
    local oldVal = tonumber( old ) or 3
    local newVal = tonumber( new )

    if not newVal then
        LocalPlayer():ConCommand( "cfc_hitmarkers_hit_duration " .. oldVal )

        return
    end

    hitDuration = newVal
end )

cvars.AddChangeCallback( "cfc_hitmarkers_mini_duration", function( _, old, new )
    local oldVal = tonumber( old ) or 3
    local newVal = tonumber( new )

    if not newVal then
        LocalPlayer():ConCommand( "cfc_hitmarkers_mini_duration " .. oldVal )

        return
    end

    miniHitDuration = newVal
end )

cvars.AddChangeCallback( "cfc_hitmarkers_enabled", function( _, old, new )
    net.Start( "CFC_Hitmarkers_EnableChanged" )
    net.WriteBool( new ~= "0" )
    net.SendToServer()
end )

cvars.AddChangeCallback( "cfc_hitmarkers_npc_enabled", function( _, old, new )
    net.Start( "CFC_Hitmarkers_NPCEnableChanged" )
    net.WriteBool( new ~= "0" )
    net.SendToServer()
end )

cvars.AddChangeCallback( "cfc_hitmarkers_ent_enabled", function( _, old, new )
    net.Start( "CFC_Hitmarkers_EntEnableChanged" )
    net.WriteBool( new ~= "0" )
    net.SendToServer()
end )

CFC_Hitmarkers.MiniHitCount = 0
CFC_Hitmarkers.HitScores = {}
CFC_Hitmarkers.HitColors = {}
CFC_Hitmarkers.HitTimes = {}
CFC_Hitmarkers.HitPoints = {}
CFC_Hitmarkers.MiniHits = {}

hitDuration = HIT_DURATION:GetFloat() or 3
miniHitDuration = MINI_DURATION:GetFloat() or 2.5

local hitScores = CFC_Hitmarkers.HitScores
local hitColors = {}
local hitTimes = {}
local hitPoints = {}
local miniHits = {}

CFC_Hitmarkers.SoundTbl = CFC_Hitmarkers.SoundTbl or {}
CFC_Hitmarkers.SoundTbl.Hit = {
    Path = HIT_SOUND,
    Volume = HIT_SOUND_VOLUME,
    Pitch = function() return math.Rand( 0.9, 1.1 ) end
}
CFC_Hitmarkers.SoundTbl.Headshot = {
    Path = HEADSHOT_SOUND,
    Volume = HEADSHOT_SOUND_VOLUME,
    Pitch = function() return math.Rand( 0.9, 1.1 ) end
}
CFC_Hitmarkers.SoundTbl.Kill = {
    Path = KILL_SOUND,
    Volume = KILL_SOUND_VOLUME,
    Pitch = 1
}

function CFC_Hitmarkers.DoSound( soundType )
    if not HITMARKERS_SOUND_ENABLED:GetBool() then return end 

    local snd = CFC_Hitmarkers.SoundTbl[soundType]

    if not snd then return end

    local path = snd.Path
    local volume = snd.Volume
    local pitch = snd.Pitch

    if type( path ) == "ConVar" then
        path = path:GetString()
    elseif type( path ) == "function" then
        path = path()
    end

    if type( volume ) == "ConVar" then
        volume = volume:GetFloat()
    elseif type( volume ) == "function" then
        volume = volume()
    end

    if type( pitch ) == "ConVar" then
        pitch = pitch:GetFloat()
    elseif type( pitch ) == "function" then
        pitch = pitch()
    end

    sound.PlayFile( "sound/" .. path, "noplay", function( station )
        if not IsValid( station ) then return end

        station:Play()
        station:SetVolume( volume )
        station:SetPlaybackRate( pitch )
    end )
end

hook.Add( "InitPostEntity", "CFC_Hitmarkers_DoIUseHitmarkers", function()
    timer.Simple( 10, function()
        net.Start( "CFC_Hitmarkers_EnableChanged" )
        net.WriteBool( HITMARKERS_ENABLED:GetBool() )
        net.SendToServer()

        net.Start( "CFC_Hitmarkers_NPCEnableChanged" )
        net.WriteBool( HITMARKERS_NPC_ENABLED:GetBool() )
        net.SendToServer()

        net.Start( "CFC_Hitmarkers_EntEnableChanged" )
        net.WriteBool( HITMARKERS_ENT_ENABLED:GetBool() )
        net.SendToServer()
    end )
end )

hook.Add( "HUDPaint", "CFC_HitMarkers_DrawHits", function()
    for i = 1, CFC_Hitmarkers.MiniHitCount do
        local miniHit = miniHits[i]
        local screenPos = miniHit.Pos:ToScreen()
        local xPos = screenPos.x
        local yPos = screenPos.y

        draw.SimpleText( miniHit.Text, "CFC_Hitmarkers_MiniFont", xPos, yPos, miniHit.Color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
    end

    for ply, score in pairs( hitScores ) do
        local screenPos = hitPoints[ply]:ToScreen()
        local xPos = screenPos.x
        local yPos = screenPos.y

        draw.SimpleText( tostring( score ), "CFC_Hitmarkers_HitFont", xPos, yPos, hitColors[ply], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
    end
end )

net.Receive( "CFC_Hitmarkers_Hit", function()
    local ply = net.ReadEntity()
    local pos = net.ReadVector()
    local dmg = math.Round( net.ReadFloat(), ROUND_DECIMALS )
    local headShot = net.ReadBool()
    local hitColor = hitmarkerColors.hit
    local miniHitColor = hitmarkerColors.mini_hit

    hitScores[ply] = ( hitScores[ply] or 0 ) + dmg
    hitColors[ply] = Color( hitColor.r, hitColor.g, hitColor.b )
    hitTimes[ply] = RealTime()
    hitPoints[ply] = pos

    local miniHitVel = Vector( math.Rand( -1, 1 ), math.Rand( -1, 1 ), math.Rand( -1, 1 ) )
    miniHitVel:Normalize()

    local miniHitCount = CFC_Hitmarkers.MiniHitCount + 1
    CFC_Hitmarkers.MiniHitCount = miniHitCount

    miniHits[miniHitCount] = {
        Pos = pos,
        Text = headShot and ">" .. dmg .. "<" or dmg .. "",
        Vel = miniHitVel * math.Rand( MINI_SPEED_MIN, MINI_SPEED_MAX ),
        Color = Color( miniHitColor.r, miniHitColor.g, miniHitColor.b ),
        Time = RealTime(),
    }

    CFC_Hitmarkers.DoSound( headShot and "Headshot" or "Hit" )
end )

net.Receive( "CFC_Hitmarkers_Kill", function()
    local ply = net.ReadEntity()

    CFC_Hitmarkers.DoSound( "Kill" )
end )

timer.Create( "CFC_Hitmarkers_UpdatePoints", UPDATE_INTERVAL, 0, function()
    local curTime = RealTime()

    for ply, time in pairs( hitTimes ) do
        local alpha = 255 * ( 1 - ( curTime - time ) / hitDuration )

        if alpha < 0 then
            hitScores[ply] = nil
            hitColors[ply] = nil
            hitTimes[ply] = nil
            hitPoints[ply] = nil
        else
            hitColors[ply].a = alpha
        end
    end

    local miniHitCount = CFC_Hitmarkers.MiniHitCount

    for i = miniHitCount, 1, -1 do
        local miniHit = miniHits[i]
        local alpha = 255 * ( 1 - ( curTime - miniHit.Time ) / miniHitDuration )

        if alpha < 0 then
            table.remove( miniHits, i )
            miniHitCount = miniHitCount - 1
        else
            miniHit.Color.a = alpha
            miniHit.Pos = miniHit.Pos + miniHit.Vel
            miniHit.Vel = miniHit.Vel * MINI_INERTIA + Vector( 0, 0, - MINI_GRAVITY )
        end
    end

    CFC_Hitmarkers.MiniHitCount = miniHitCount
end )