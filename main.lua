-- ============================================================
-- HOLO MUSIC SERVER  v4.5  — Full Sync
-- License check via GitHub (sinkro1/permission)
-- ============================================================

local HttpService = game:GetService("HttpService")

-- URL daftar Place ID yang diizinkan
local PERMISSION_URL = "https://raw.githubusercontent.com/sinkro1/DJsistem/main/places.txt"

-- Cek Place ID
local function isLicensed()
	local currentPlaceId = tostring(game.PlaceId)
	local success, result = pcall(function()
		return HttpService:GetAsync(PERMISSION_URL, true)
	end)
	if not success then
		warn("[DJsistem] Gagal mengambil data lisensi: " .. tostring(result))
		return false
	end
	for id in result:gmatch("[^\n]+") do
		local clean = id:match("^%s*(.-)%s*$")
		if clean == currentPlaceId then
			return true
		end
	end
	return false
end

if not isLicensed() then
	warn("[DJsistem] tidak memiliki lisensi. Script dihentikan.")
	return
end

print("[DJsistem] Lisensi valid!")

-- ============================================================
-- HOLO MUSIC SERVER  v4.5  — Full Sync
-- ServerScriptService / HoloMusicServer  (Script)
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")
local RunService        = game:GetService("RunService")

local PlaylistModule = require(ReplicatedStorage:WaitForChild("PlaylistModule"))

-- ============================================================
-- REMOTE SETUP
-- ============================================================
local remFolder = ReplicatedStorage:FindFirstChild("HoloMusicRemotes")
if not remFolder then
	remFolder = Instance.new("Folder")
	remFolder.Name   = "HoloMusicRemotes"
	remFolder.Parent = ReplicatedStorage
end

local function getOrCreate(class, name)
	local obj = remFolder:FindFirstChild(name)
	if obj then return obj end
	obj = Instance.new(class)
	obj.Name   = name
	obj.Parent = remFolder
	return obj
end

local RF_GetState         = getOrCreate("RemoteFunction",   "GetState")
local RE_Command          = getOrCreate("RemoteEvent",      "Command")
local RE_State            = getOrCreate("RemoteEvent",      "State")
local RE_Notif            = getOrCreate("RemoteEvent",      "Notif")
local BF_GetStateInternal = getOrCreate("BindableFunction", "GetStateInternal")


-- ============================================================
-- SOUND SETUP
-- ============================================================
local function getOrCreateSound(name)
	local s = SoundService:FindFirstChild(name)
	if not s then
		s = Instance.new("Sound")
		s.Name   = name
		s.Looped = false
		s.Parent = SoundService
	end
	return s
end

local DeckA  = getOrCreateSound("HoloMusicA")
local DeckB  = getOrCreateSound("HoloMusicB")
DeckB.Volume = 0

local SoundboardA = getOrCreateSound("HoloSoundboardA")
local SoundboardB = getOrCreateSound("HoloSoundboardB")
SoundboardA.Volume = 1
SoundboardB.Volume = 1

local function getOrCreateEffect(parent, class, name)
	local fx = parent:FindFirstChild(name)
	if not fx then
		fx = Instance.new(class)
		fx.Name   = name
		fx.Parent = parent
	end
	return fx
end

-- Deck A FX
local FX_A_Reverb = getOrCreateEffect(DeckA, "ReverbSoundEffect", "HoloReverb")
FX_A_Reverb.DecayTime = 1.4; FX_A_Reverb.Density = 0.35
FX_A_Reverb.Diffusion = 0.65; FX_A_Reverb.DryLevel = 0
FX_A_Reverb.WetLevel = -80; FX_A_Reverb.Enabled = false

local FX_A_EQ = getOrCreateEffect(DeckA, "EqualizerSoundEffect", "HoloEQ")
FX_A_EQ.LowGain = 0; FX_A_EQ.MidGain = 0; FX_A_EQ.HighGain = 0
FX_A_EQ.Enabled = false

local FX_A_Echo = getOrCreateEffect(DeckA, "ReverbSoundEffect", "HoloEcho")
FX_A_Echo.DecayTime = 3; FX_A_Echo.Density = 0.6; FX_A_Echo.Diffusion = 0.5
FX_A_Echo.DryLevel = 0; FX_A_Echo.WetLevel = -12; FX_A_Echo.Enabled = false

local FX_A_Flange = getOrCreateEffect(DeckA, "DistortionSoundEffect", "HoloFlange")
FX_A_Flange.Level = 0.1; FX_A_Flange.Enabled = false

-- Deck B FX
local FX_B_Reverb = getOrCreateEffect(DeckB, "ReverbSoundEffect", "HoloReverb")
FX_B_Reverb.DecayTime = 1.4; FX_B_Reverb.Density = 0.35
FX_B_Reverb.Diffusion = 0.65; FX_B_Reverb.DryLevel = 0
FX_B_Reverb.WetLevel = -80; FX_B_Reverb.Enabled = false

local FX_B_EQ = getOrCreateEffect(DeckB, "EqualizerSoundEffect", "HoloEQ")
FX_B_EQ.LowGain = 0; FX_B_EQ.MidGain = 0; FX_B_EQ.HighGain = 0
FX_B_EQ.Enabled = false

local FX_B_Echo = getOrCreateEffect(DeckB, "ReverbSoundEffect", "HoloEcho")
FX_B_Echo.DecayTime = 3; FX_B_Echo.Density = 0.6; FX_B_Echo.Diffusion = 0.5
FX_B_Echo.DryLevel = 0; FX_B_Echo.WetLevel = -12; FX_B_Echo.Enabled = false

local FX_B_Flange = getOrCreateEffect(DeckB, "DistortionSoundEffect", "HoloFlange")
FX_B_Flange.Level = 0.1; FX_B_Flange.Enabled = false

-- GlobalSound
local function syncGlobalSound(source)
	local gs = workspace:FindFirstChild("GlobalSound")
	if not gs or not gs:IsA("Sound") then
		if gs then gs:Destroy() end
		gs = Instance.new("Sound")
		gs.Name   = "GlobalSound"
		gs.Looped = false
		gs.Volume = 0
		gs.Parent = workspace
	end
	gs.Volume = 0
	local function apply()
		if not gs or not gs.Parent then return end
		gs.SoundId       = source.SoundId
		gs.TimePosition  = source.TimePosition
		gs.PlaybackSpeed = source.PlaybackSpeed
		gs.Looped        = source.Looped
		gs.Volume        = 0
		if source.IsPlaying and not gs.IsPlaying then
			pcall(function() gs:Play() end)
		elseif not source.IsPlaying and gs.IsPlaying then
			pcall(function() gs:Stop() end)
		end
	end
	apply()
	source:GetPropertyChangedSignal("SoundId"):Connect(apply)
	source:GetPropertyChangedSignal("IsPlaying"):Connect(apply)
	source.Ended:Connect(apply)
end
syncGlobalSound(DeckA)

-- ============================================================
-- STATE
-- ============================================================
local masterVolume   = 0.7
local crossfade      = 0
local deckAVol       = 1
local deckBVol       = 1
local deckASpeed     = 1
local deckAPitch     = 1
local deckBSpeed     = 1
local deckBPitch     = 1
local deckABaseSpeed = 1
local deckBBaseSpeed = 1
local reverbLevelA   = 0
local bassLevelA     = 0
local reverbLevelB   = 0
local bassLevelB     = 0
local eqLow          = 0.5
local eqMid          = 0.5
local eqHigh         = 0.5
local echoA          = false
local flangeA        = false
local strobeA        = false
local echoB          = false
local flangeB        = false
local strobeB        = false
local echoLevelA     = 0
local flangeLevelA   = 0
local strobeLevelA   = 0
local echoLevelB     = 0
local flangeLevelB   = 0
local strobeLevelB   = 0
local cuePointsA     = { nil, nil, nil, nil }
local cuePointsB     = { nil, nil, nil, nil }
local djActive       = false

local eq7 = { sub=0.5, bass=0.5, lmid=0.5, mid=0.5, umid=0.5, treb=0.5, air=0.5 }
local eq7B = { sub=0.5, bass=0.5, lmid=0.5, mid=0.5, umid=0.5, treb=0.5, air=0.5 }
local eqLowB  = 0.5
local eqMidB  = 0.5
local eqHighB = 0.5

local deckBLoaded    = false
local deckBPlaying   = false
local deckBTitle     = ""

local library        = {}
local libraryIndex   = 1
local paused         = false
local pausedSoundId  = ""
local pausedTitle    = ""
local pausedPos      = 0
local playGen        = 0

local nowPlayingBy   = { userId = 0, name = "System" }

-- ============================================================
-- HELPERS
-- ============================================================
local function clamp01(v)
	return math.clamp(tonumber(v) or 0, 0, 1)
end

local function normalizeId(raw)
	local s = tostring(raw or ""):gsub("%s+", "")
	if s == "" then return "" end
	if s:match("^%d+$") then return "rbxassetid://" .. s end
	return s
end

local function normalizeTitle(t)
	if not t then return "UNTITLED" end
	return (typeof(t.title) == "string" and t.title ~= "") and t.title or "UNTITLED"
end

local function eqGain(v)
	return math.clamp((clamp01(v) - 0.5) * 24, -12, 12)
end

local function bassBoost(v)
	return math.clamp(clamp01(v) * 12, 0, 12)
end

local function reverbWet(v)
	return -80 + (clamp01(v) * 80)
end

local function deckAHasEQ()
	return (bassLevelA > 0.01)
		or math.abs(eqLow  - 0.5) > 0.01
		or math.abs(eqMid  - 0.5) > 0.01
		or math.abs(eqHigh - 0.5) > 0.01
end

local function deckBHasEQ()
	return (bassLevelB > 0.01)
		or math.abs(eqLowB  - 0.5) > 0.01
		or math.abs(eqMidB  - 0.5) > 0.01
		or math.abs(eqHighB - 0.5) > 0.01
end

local function calc3BandFromEq7(t)
	local low  = (t.sub  + t.bass) / 2
	local mid  = (t.lmid + t.mid)  / 2
	local high = (t.umid + t.treb + t.air) / 3
	return low, mid, high
end

-- ============================================================
-- APPLY EFFECTS & VOLUME
-- ============================================================
local function applyEffects()
	DeckA.PlaybackSpeed = math.clamp(deckABaseSpeed * deckASpeed, 0.5, 2)
	DeckB.PlaybackSpeed = math.clamp(deckBBaseSpeed * deckBSpeed, 0.5, 2)

	local low, mid, high = calc3BandFromEq7(eq7)
	eqLow  = low
	eqMid  = mid
	eqHigh = high

	local lowB, midB, highB = calc3BandFromEq7(eq7B)
	eqLowB  = lowB
	eqMidB  = midB
	eqHighB = highB

	FX_A_Reverb.Enabled  = reverbLevelA > 0.01
	FX_A_Reverb.WetLevel = reverbWet(reverbLevelA)
	FX_A_EQ.LowGain      = math.clamp(eqGain(eqLow) + bassBoost(bassLevelA), -12, 12)
	FX_A_EQ.MidGain      = eqGain(eqMid)
	FX_A_EQ.HighGain     = eqGain(eqHigh)
	FX_A_EQ.Enabled      = deckAHasEQ()
	FX_A_Echo.Enabled    = echoA
	FX_A_Flange.Enabled  = flangeA

	FX_B_Reverb.Enabled  = reverbLevelB > 0.01
	FX_B_Reverb.WetLevel = reverbWet(reverbLevelB)
	FX_B_EQ.LowGain      = math.clamp(eqGain(eqLowB) + bassBoost(bassLevelB), -12, 12)
	FX_B_EQ.MidGain      = eqGain(eqMidB)
	FX_B_EQ.HighGain     = eqGain(eqHighB)
	FX_B_EQ.Enabled      = deckBHasEQ()
	FX_B_Echo.Enabled    = echoB
	FX_B_Flange.Enabled  = flangeB
end

local function applyVolume()
	local cf   = math.clamp(crossfade, 0, 1)
	local volA = math.max(0, 1 - (cf * 1.5))
	local volB = math.max(0, (cf - 0.33) * 1.5)
	DeckA.Volume = masterVolume * deckAVol * volA
	DeckB.Volume = masterVolume * deckBVol * volB
end

local strobeTimer = 0
RunService.Heartbeat:Connect(function(dt)
	if not (strobeA or strobeB) then return end
	strobeTimer = strobeTimer + dt
	local pulse = math.abs(math.sin(strobeTimer * 8))
	local cf    = math.clamp(crossfade, 0, 1)
	if strobeA then DeckA.Volume = masterVolume * deckAVol * math.max(0, 1 - (cf * 1.5)) * pulse end
	if strobeB then DeckB.Volume = masterVolume * deckBVol * math.max(0, (cf - 0.33) * 1.5) * pulse end
end)

-- ============================================================
-- BROADCAST STATE
-- ============================================================
local function buildState()
	return {
		soundId        = DeckA.SoundId,
		title          = DeckA:GetAttribute("NowTitle") or "",
		isPlaying      = DeckA.IsPlaying,
		timePos        = DeckA.TimePosition,
		timeLen        = DeckA.TimeLength,
		paused         = paused,
		deckBSoundId   = DeckB.SoundId,
		deckBTitle     = deckBTitle,
		deckBIsPlaying = deckBPlaying or DeckB.IsPlaying,
		deckBTimePos   = DeckB.TimePosition,
		deckBTimeLen   = DeckB.TimeLength,
		deckBLoaded    = deckBLoaded,
		volume         = masterVolume,
		deckAVol       = deckAVol,
		deckBVol       = deckBVol,
		crossfadePos   = crossfade,
		speed          = deckASpeed,
		pitch          = deckAPitch,
		deckASpeed     = deckASpeed,
		deckAPitch     = deckAPitch,
		deckBSpeed     = deckBSpeed,
		deckBPitch     = deckBPitch,
		reverbLevelA   = reverbLevelA,
		bassLevelA     = bassLevelA,
		reverbLevelB   = reverbLevelB,
		bassLevelB     = bassLevelB,
		eqLow          = eqLow,
		eqMid          = eqMid,
		eqHigh         = eqHigh,
		eqLowB         = eqLowB,
		eqMidB         = eqMidB,
		eqHighB        = eqHighB,
		eq7sub         = eq7.sub,
		eq7bass        = eq7.bass,
		eq7lmid        = eq7.lmid,
		eq7mid         = eq7.mid,
		eq7umid        = eq7.umid,
		eq7treb        = eq7.treb,
		eq7air         = eq7.air,
		eq7subB        = eq7B.sub,
		eq7bassB       = eq7B.bass,
		eq7lmidB       = eq7B.lmid,
		eq7midB        = eq7B.mid,
		eq7umidB       = eq7B.umid,
		eq7trebB       = eq7B.treb,
		eq7airB        = eq7B.air,
		echoA          = echoA,
		flangeA        = flangeA,
		strobeA        = strobeA,
		echoB          = echoB,
		flangeB        = flangeB,
		strobeB        = strobeB,
		echoLevelA     = echoLevelA,
		flangeLevelA   = flangeLevelA,
		strobeLevelA   = strobeLevelA,
		echoLevelB     = echoLevelB,
		flangeLevelB   = flangeLevelB,
		strobeLevelB   = strobeLevelB,
		cuePointsA     = cuePointsA,
		cuePointsB     = cuePointsB,
		djActive       = djActive,
		reverb         = reverbLevelA > 0.01,
		bass           = bassLevelA   > 0.01,
		reverbLevel    = reverbLevelA,
		bassLevel      = bassLevelA,
		libraryCount   = #library,
		libraryIndex   = libraryIndex,
		nowPlayingBy   = nowPlayingBy,
		serverNow      = os.clock(),
		deckABaseSpeed = deckABaseSpeed,
		deckBBaseSpeed = deckBBaseSpeed,
	}
end

local function broadcast()
	RE_State:FireAllClients(buildState())
end

BF_GetStateInternal.OnInvoke = function()
	return buildState()
end

-- ============================================================
-- LIBRARY / PLAYLIST
-- ============================================================
local function loadLibrary()
	local ok, tracks = pcall(function() return PlaylistModule.GetTracks() end)
	if not ok or typeof(tracks) ~= "table" then return {} end
	local out = {}
	for _, t in ipairs(tracks) do
		if typeof(t) == "table" then
			local id = normalizeId(tostring(t.id or ""))
			if id ~= "" then
				table.insert(out, { id = id, title = normalizeTitle({ id = id, title = tostring(t.title or "") }) })
			end
		end
	end
	return out
end

local function reloadLibrary()
	library = loadLibrary()
	libraryIndex = math.clamp(libraryIndex, 1, math.max(1, #library))
end

-- ============================================================
-- PLAYBACK CORE
-- ============================================================
local function playTrack(track)
	paused        = false
	pausedSoundId = ""
	pausedTitle   = ""
	pausedPos     = 0
	playGen      += 1
	DeckA:Stop()
	DeckA.SoundId      = normalizeId(track.id)
	DeckA.TimePosition = 0
	DeckA:SetAttribute("NowTitle", normalizeTitle(track))
	deckABaseSpeed = math.clamp(tonumber(track.speed) or 1, 0.5, 2)
	applyEffects()
	applyVolume()
	local ok = pcall(function() DeckA:Play() end)
	if not ok then warn("[HoloMusic] Play failed:", track.id) end
	broadcast()
end

local function resumeTrack()
	if not paused or pausedSoundId == "" then
		paused = false; broadcast(); return
	end
	paused   = false
	playGen += 1
	DeckA:Stop()
	DeckA.SoundId      = pausedSoundId
	DeckA.TimePosition = math.max(0, pausedPos)
	DeckA:SetAttribute("NowTitle", pausedTitle)
	applyEffects(); applyVolume()
	local ok = pcall(function() DeckA:Play() end)
	if not ok then warn("[HoloMusic] Resume failed") end
	broadcast()
end

DeckA.Ended:Connect(function()
	if paused then broadcast(); return end
	if crossfade >= 0.9 and deckBLoaded and DeckB.SoundId ~= "" then
		local bId    = DeckB.SoundId
		local bTitle = deckBTitle
		DeckB:Stop(); DeckB.SoundId = ""; DeckB.Volume = 0
		deckBLoaded = false; deckBTitle = ""; crossfade = 0
		applyVolume()
		playTrack({ id = bId, title = bTitle })
		return
	end
	broadcast()
end)

DeckB.Ended:Connect(function()
	deckBPlaying  = false
	deckBLoaded   = false
	deckBTitle    = ""
	DeckB.SoundId = ""; DeckB.Volume = 0
	broadcast()
end)

-- ============================================================
-- DECK B
-- ============================================================
local function loadDeckB(track)
	local id = normalizeId(tostring(track.id or ""))
	if id == "" then return end
	local title = normalizeTitle({ id = id, title = tostring(track.title or "") })
	DeckB:Stop()
	DeckB.SoundId      = id
	DeckB.TimePosition = 0
	deckBTitle   = title
	deckBLoaded  = true
	deckBPlaying = false
	cuePointsB   = { nil, nil, nil, nil }
	applyVolume(); broadcast()
	task.spawn(function()
		deckBPlaying = false
		local tw = 0
		while (DeckB.TimeLength or 0) <= 0 and tw < 15 do
			task.wait(0.3); tw += 0.3
			broadcast()
		end
		broadcast()
	end)
end

-- ============================================================
-- RESET
-- ============================================================
local function resetAllSettings()
	masterVolume = 0.7; crossfade = 0
	deckAVol = 1; deckBVol = 1
	deckASpeed = 1; deckAPitch = 1
	deckBSpeed = 1; deckBPitch = 1
	deckABaseSpeed = 1; deckBBaseSpeed = 1
	reverbLevelA = 0; bassLevelA = 0
	reverbLevelB = 0; bassLevelB = 0
	eq7 = { sub=0.5, bass=0.5, lmid=0.5, mid=0.5, umid=0.5, treb=0.5, air=0.5 }
	eq7B = { sub=0.5, bass=0.5, lmid=0.5, mid=0.5, umid=0.5, treb=0.5, air=0.5 }
	echoA = false; flangeA = false; strobeA = false
	echoB = false; flangeB = false; strobeB = false
	echoLevelA = 0; flangeLevelA = 0; strobeLevelA = 0
	echoLevelB = 0; flangeLevelB = 0; strobeLevelB = 0
	cuePointsA = { nil, nil, nil, nil }
	cuePointsB = { nil, nil, nil, nil }
	djActive   = false
	applyEffects(); applyVolume()
end

-- ============================================================
-- PLAYER LIFECYCLE
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	RE_State:FireClient(player, buildState())
end)

-- ============================================================
-- REMOTE FUNCTIONS
-- ============================================================
RF_GetState.OnServerInvoke = function(_player)
	return buildState()
end

-- ============================================================
-- COMMAND HANDLER
-- ============================================================
RE_Command.OnServerEvent:Connect(function(player, data)
	if typeof(data) ~= "table" then return end
	local action  = tostring(data.action or "")
	local payload = data.data

	if action == "RequestState" then
		RE_State:FireClient(player, buildState()); return
	end

	if action == "SetVolume"    then masterVolume = clamp01(payload); applyVolume(); broadcast(); return end
	if action == "SetDeckAVol"  then deckAVol = clamp01(payload); applyVolume(); broadcast(); return end
	if action == "SetDeckBVol"  then deckBVol = clamp01(payload); applyVolume(); broadcast(); return end
	if action == "SetCrossfade" then crossfade = clamp01(payload); applyVolume(); broadcast(); return end

	if action == "SetSpeed" then
		deckASpeed = math.clamp(tonumber(payload) or 1, 0.5, 2)
		applyEffects(); broadcast(); return
	end
	if action == "SetPitch" then
		deckAPitch = math.clamp(tonumber(payload) or 1, 0.5, 2)
		applyEffects(); broadcast(); return
	end
	if action == "SetDeckSpeed" then
		if typeof(payload) ~= "table" then return end
		local v = math.clamp(tonumber(payload.value) or 1, 0.5, 2)
		if tostring(payload.deck) == "B" then deckBSpeed = v else deckASpeed = v end
		applyEffects(); broadcast(); return
	end
	if action == "SetDeckPitch" then
		if typeof(payload) ~= "table" then return end
		local v = math.clamp(tonumber(payload.value) or 1, 0.5, 2)
		if tostring(payload.deck) == "B" then deckBPitch = v else deckAPitch = v end
		applyEffects(); broadcast(); return
	end

	if action == "SetReverbA" then reverbLevelA = clamp01(tonumber(payload) or 0); applyEffects(); broadcast(); return end
	if action == "SetBassA"   then bassLevelA   = clamp01(tonumber(payload) or 0); applyEffects(); broadcast(); return end
	if action == "SetReverbB" then reverbLevelB = clamp01(tonumber(payload) or 0); applyEffects(); broadcast(); return end
	if action == "SetBassB"   then bassLevelB   = clamp01(tonumber(payload) or 0); applyEffects(); broadcast(); return end
	if action == "SetReverb"  then reverbLevelA = clamp01(tonumber(payload) or 0); applyEffects(); broadcast(); return end
	if action == "SetBass"    then bassLevelA   = clamp01(tonumber(payload) or 0); applyEffects(); broadcast(); return end

	if action == "SetEQ" then
		if typeof(payload) ~= "table" then return end
		local target = (tostring(payload.deck) == "B") and eq7B or eq7
		if tonumber(payload.sub)  then target.sub  = clamp01(payload.sub)  end
		if tonumber(payload.bass) then target.bass = clamp01(payload.bass) end
		if tonumber(payload.lmid) then target.lmid = clamp01(payload.lmid) end
		if tonumber(payload.mid)  then target.mid  = clamp01(payload.mid)  end
		if tonumber(payload.umid) then target.umid = clamp01(payload.umid) end
		if tonumber(payload.treb) then target.treb = clamp01(payload.treb) end
		if tonumber(payload.air)  then target.air  = clamp01(payload.air)  end
		applyEffects(); broadcast(); return
	end

	if action == "SetEcho" then
		if typeof(payload) ~= "table" then return end
		if tostring(payload.deck) == "B" then
			echoB      = payload.active == true
			echoLevelB = clamp01(tonumber(payload.level) or 0)
		else
			echoA      = payload.active == true
			echoLevelA = clamp01(tonumber(payload.level) or 0)
		end
		applyEffects(); broadcast(); return
	end
	if action == "SetFlange" then
		if typeof(payload) ~= "table" then return end
		if tostring(payload.deck) == "B" then
			flangeB      = payload.active == true
			flangeLevelB = clamp01(tonumber(payload.level) or 0)
		else
			flangeA      = payload.active == true
			flangeLevelA = clamp01(tonumber(payload.level) or 0)
		end
		applyEffects(); broadcast(); return
	end
	if action == "SetStrobe" then
		if typeof(payload) ~= "table" then return end
		local active = payload.active == true
		if tostring(payload.deck) == "B" then
			strobeB      = active
			strobeLevelB = clamp01(tonumber(payload.level) or 0)
			if not active then applyVolume() end
		else
			strobeA      = active
			strobeLevelA = clamp01(tonumber(payload.level) or 0)
			if not active then applyVolume() end
		end
		broadcast(); return
	end

	if action == "SetCuePoints" then
		if typeof(payload) ~= "table" then return end
		if tostring(payload.deck) == "B" then
			cuePointsB = payload.points or { nil, nil, nil, nil }
		else
			cuePointsA = payload.points or { nil, nil, nil, nil }
		end
		broadcast(); return
	end

	if action == "SetDjActive" then
		djActive = payload == true
		if djActive then
			local gs = workspace:FindFirstChild("GlobalSound")
			if gs and gs:IsA("Sound") then gs:Pause() end
			local gm = workspace:FindFirstChild("GlobalMusic2D")
			if gm and gm:IsA("Sound") then gm:Pause() end
			for _, part in ipairs(workspace:GetChildren()) do
				if part:IsA("BasePart") and part.Name == "MusicSpeaker" then
					local snd = part:FindFirstChild("MusicSound")
					if snd and snd:IsA("Sound") then snd:Pause() end
				end
			end
			RE_Notif:FireAllClients({ title = "DJ MODE ON", body = "Musik dikontrol DJ!", color = "DJGOLD" })
		else
			local gs = workspace:FindFirstChild("GlobalSound")
			if gs and gs:IsA("Sound") then gs:Resume() end
			local gm = workspace:FindFirstChild("GlobalMusic2D")
			if gm and gm:IsA("Sound") then gm:Resume() end
			for _, part in ipairs(workspace:GetChildren()) do
				if part:IsA("BasePart") and part.Name == "MusicSpeaker" then
					local snd = part:FindFirstChild("MusicSound")
					if snd and snd:IsA("Sound") then snd:Resume() end
				end
			end
			RE_Notif:FireAllClients({ title = "DJ MODE OFF", body = "Musik normal kembali.", color = "SUCCESS" })
		end
		broadcast(); return
	end

	if action == "PlayResume" then
		nowPlayingBy = { userId = player.UserId, name = player.Name }
		if paused then
			resumeTrack()
		elseif not DeckA.IsPlaying and DeckA.SoundId ~= "" then
			applyEffects(); applyVolume()
			pcall(function() DeckA:Play() end)
			broadcast()
		end
		return
	end

	if action == "Pause" then
		nowPlayingBy = { userId = player.UserId, name = player.Name }
		if DeckA.IsPlaying then
			paused        = true
			pausedSoundId = DeckA.SoundId
			pausedTitle   = DeckA:GetAttribute("NowTitle") or ""
			pausedPos     = DeckA.TimePosition
			playGen      += 1
			DeckA:Pause()
			broadcast()
		end
		return
	end

	if action == "StopDeckA" then
		paused        = false
		pausedSoundId = ""
		pausedTitle   = ""
		pausedPos     = 0
		playGen      += 1
		DeckA:Stop()
		DeckA:SetAttribute("NowTitle", "")
		broadcast()
		return
	end

	if action == "StopDeckB" then
		deckBPlaying = false
		DeckB:Stop()
		DeckB.SoundId = ""; DeckB.Volume = 0
		deckBLoaded = false; deckBTitle = ""
		applyVolume(); broadcast()
		return
	end

	if action == "Seek" or action == "SeekDeckA" then
		local pos = tonumber(payload) or 0
		local len = DeckA.TimeLength or 0
		if len > 0 then
			DeckA.TimePosition = math.clamp(pos, 0, len)
			if paused then pausedPos = DeckA.TimePosition end
			broadcast()
		end
		return
	end

	if action == "LoadDeckA" then
		if typeof(payload) ~= "table" then return end
		local id    = normalizeId(tostring(payload.id or ""))
		local title = normalizeTitle({ id = id, title = tostring(payload.title or "") })
		if id == "" then return end
		nowPlayingBy = { userId = player.UserId, name = player.Name }
		paused = false; playGen += 1
		local gen = playGen
		deckABaseSpeed = math.clamp(tonumber(payload.speed) or 1, 0.5, 2)
		DeckA:Stop(); DeckA.SoundId = id; DeckA.TimePosition = 0
		DeckA:SetAttribute("NowTitle", title)
		cuePointsA = { nil, nil, nil, nil }
		applyEffects(); applyVolume(); broadcast()
		task.spawn(function()
			local tw = 0
			while (DeckA.TimeLength or 0) <= 0 and tw < 15 do
				task.wait(0.3); tw += 0.3
				if playGen == gen then broadcast() end
			end
			if playGen == gen then broadcast() end
		end)
		return
	end

	if action == "LoadDeckB" then
		if typeof(payload) ~= "table" then return end
		local id = normalizeId(tostring(payload.id or ""))
		if id ~= "" then
			deckBBaseSpeed = math.clamp(tonumber(payload.speed) or 1, 0.5, 2)
			loadDeckB({ id = id, title = tostring(payload.title or ""), speed = tonumber(payload.speed) or 1 })
		else
			DeckB:Stop(); DeckB.SoundId = ""; DeckB.Volume = 0
			deckBLoaded = false; deckBPlaying = false; deckBTitle = ""
			cuePointsB = { nil, nil, nil, nil }
			applyVolume(); broadcast()
		end
		return
	end

	if action == "PlayDeckB" then
		if DeckB.SoundId ~= "" then
			deckBLoaded = true; deckBPlaying = true
			applyVolume(); broadcast()
			task.spawn(function()
				if DeckB.TimePosition > 0 then
					pcall(function() DeckB:Resume() end)
				else
					pcall(function() DeckB:Play() end)
				end
				local t = 0
				while not DeckB.IsPlaying and t < 5 do task.wait(0.1); t += 0.1 end
				if not DeckB.IsPlaying then deckBPlaying = false end
				broadcast()
			end)
		end
		return
	end

	if action == "PauseDeckB" then DeckB:Pause(); deckBPlaying = false; broadcast(); return end

	if action == "SeekDeckB" then
		local pos = tonumber(payload) or 0
		local len = DeckB.TimeLength or 0
		if len > 0 then DeckB.TimePosition = math.clamp(pos, 0, len); broadcast() end
		return
	end

	if action == "SwapDecks" then
		if deckBLoaded and DeckB.SoundId ~= "" then
			local bId    = DeckB.SoundId
			local bTitle = deckBTitle
			local bPos   = DeckB.TimePosition
			DeckB:Stop(); DeckB.SoundId = ""; DeckB.Volume = 0
			deckBLoaded = false; deckBTitle = ""; crossfade = 0
			applyVolume()
			DeckA:Stop(); DeckA.SoundId = bId; DeckA.TimePosition = bPos
			DeckA:SetAttribute("NowTitle", bTitle)
			cuePointsA = { nil, nil, nil, nil }
			cuePointsB = { nil, nil, nil, nil }
			applyEffects()
			pcall(function() DeckA:Play() end)
			playGen += 1; broadcast()
		end
		return
	end

	if action == "SyncBPM" then DeckB.PlaybackSpeed = DeckA.PlaybackSpeed; broadcast(); return end

	if action == "PlaySoundboard" then
		if typeof(payload) ~= "table" then return end
		local deck = tostring(payload.deck or "A")
		local id   = normalizeId(tostring(payload.soundId or ""))
		if id ~= "" then
			local sb = (deck == "B") and SoundboardB or SoundboardA
			sb:Stop(); sb.SoundId = id
			pcall(function() sb:Play() end)
			broadcast()
		end
		return
	end

	if action == "ResetDJ" then resetAllSettings(); broadcast(); return end
	if action == "ReloadLibrary" then reloadLibrary(); broadcast(); return end
end)

-- ============================================================
-- STARTUP
-- ============================================================
applyEffects()
applyVolume()
reloadLibrary()
broadcast()

print("[HoloMusic] Server v4.5 — Full Sync")
