--[[
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║   RIAD HUB                                                                  ║
    ║   Murder Mystery 2  •  built for Riad                                       ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
]]

if not game:IsLoaded() then game.Loaded:Wait() end
if game.GameId ~= 66654135 then
    game:GetService("Players").LocalPlayer:Kick("Riad Hub: this script is for Murder Mystery 2 only")
    return
end

if getgenv and getgenv().RiadHubUnload then
    pcall(getgenv().RiadHubUnload)
end

-- ============================================================
-- BOOT & LOGGING
-- ============================================================
local Boot = { Log = print, Start = os.clock(), Last = os.clock(), Step = 0, Total = 5 }
do
    local ok, env = pcall(getrenv)
    if ok and type(env) == "table" and type(env.print) == "function" then Boot.Log = env.print end
end

function Boot.Show()
    local ok, exec = pcall(identifyexecutor)
    if not ok or type(exec) ~= "string" then exec = "Unknown" end
    local rule = string.rep("=", 54)
    Boot.Log(table.concat({
        "",
        [[
     ____  ___    _    ____    _   _ _   _ ____
    |  _ \|_ _|  / \  |  _ \  | | | | | | | __ )
    | |_) || |  / _ \ | | | | | |_| | | | |  _ \
    |  _ < | | / ___ \| |_| | |  _  | |_| | |_) |
    |_| \_\___/_/   \_\____/  |_| |_|\___/|____/
        ]],
        rule,
        "   RIAD HUB  //  MURDER MYSTERY 2  //  for Riad",
        "   executor: " .. exec .. "   //   player: " .. game:GetService("Players").LocalPlayer.Name,
        rule,
    }, "\n"))
end

function Boot.Step(label)
    local now = os.clock()
    Boot.Step = math.min(Boot.Step + 1, Boot.Total)
    local filled = math.floor(Boot.Step / Boot.Total * 20 + 0.5)
    Boot.Log(string.format("[Riad Hub] [%s] %3d%%  %-24s +%dms",
        string.rep("#", filled) .. string.rep(".", 20 - filled),
        math.floor(Boot.Step / Boot.Total * 100), label, math.floor((now - Boot.Last) * 1000)))
    Boot.Last = now
end

function Boot.Ready()
    local rule = string.rep("=", 54)
    Boot.Log(table.concat({
        rule,
        string.format("   >> READY in %dms", math.floor((os.clock() - Boot.Start) * 1000)),
        rule,
    }, "\n"))
end

pcall(Boot.Show)
pcall(Boot.Step, "Core")

if not LPH_OBFUSCATED then
    local function Pass(fn) return fn end
    LPH_JIT, LPH_JIT_MAX, LPH_NO_VIRTUALIZE = Pass, Pass, Pass
end

-- ============================================================
-- SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")
local TextChatService   = game:GetService("TextChatService")
local CollectionService = game:GetService("CollectionService")
local CoreGui           = game:GetService("CoreGui")
local Workspace         = game:GetService("Workspace")

local LocalPlayer       = Players.LocalPlayer

local Riad = setmetatable({}, {
    __newindex = function(self, key, value)
        rawset(self, key, type(value) == "function" and LPH_JIT(value) or value)
    end,
})

-- ============================================================
-- CONFIG
-- ============================================================
Riad.Config = {
    Discord = "https://discord.gg/your-invite-here",
    UpdateLog = {
        { "2026-10-08", "Riad Hub for Murder Mystery 2\nFarm, Combat, Teleport, Troll, Player, Visuals, Misc\nBuilt fresh for Riad" },
    },
    UiSource = "https://raw.githubusercontent.com/xDTaraZz/Roblox-Scripts/refs/heads/main/ui.lua",
    SaveFolder = "Riad Hub",
    LoadTimeout = 10,
    AlertTries = 20,
    AlertRetry = 0.5,
    FailLimit = 5,
    FailWindow = 10,
    StatusRefresh = 1,
    TickDelay = 0.5,
    RoleRefresh = 1,
    ShootStands = { Vector3.new(0, 0, 6), Vector3.new(0, 0, -6), Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0), Vector3.new(0, 6, 3) },
    ShootAttempts = 3,
    ShootConfirm = 0.8,
    ShootSettle = 0.25,
    ShootReturn = 0.3,
    ShootCooldown = 1.2,
    StabCooldown = 0.9,
    BusyTimeout = 6,
    StabOffset = 2,
    KillAuraRange = 18,
    GunGrabHold = 0.35,
    FarmSpeed = 25,
    FarmSpeedMax = 28,
    FarmThreatRadius = 30,
    FarmArrive = 1.5,
    FarmBrake = 20,
    FarmLift = 4,
    FarmReach = 400,
    FarmIdle = 0.3,
    FarmSettle = 0.15,
    FarmSkip = 4,
    SpeedDefault = 16,
    JumpDefault = 50,
    LobbyName = "RegularLobby",
    Colors = {
        Murderer = Color3.fromHSV(0, 0.75, 1),
        Sheriff  = Color3.fromHSV(0.6, 0.7, 1),
        Hero     = Color3.fromHSV(0.14, 0.8, 1),
        Innocent = Color3.fromHSV(0.33, 0.6, 0.95),
        Gun      = Color3.fromHSV(0.12, 0.9, 1),
        Coin     = Color3.fromHSV(0.15, 0.6, 1),
    },
    VictimPriority = { Sheriff = 1, Hero = 1, Innocent = 2 },
}

local Config = Riad.Config

-- ============================================================
-- STATE
-- ============================================================
Riad.State = {
    Alive = true,
    Conns = {},
    Roles = {},
    LastRoleFetch = 0,
    LastShoot = 0,
    LastStab = 0,
    ActionBusy = false,
    BusySince = 0,
    ShootBusy = false,
    LastDodge = 0,
    FarmBusy = false,
    FarmHome = nil,
    FarmMover = nil,
    Bag = { Current = 0, Max = 0 },
    SkippedCoins = {},
    XRayMap = nil,
    XRayParts = {},
    Skins = {},
    KillBusy = false,
    NoclipConn = nil,
    NoclipSaved = {},
    FlyConn = nil,
    FlyVelocity = nil,
    StickTarget = nil,
    Hook = nil,
    Esp = { Players = {}, Gun = nil },
    LightingDefaults = nil,
    Halted = {},
    Opt = {
        AutoGrabGun = false,
        AutoShoot = false,
        SilentAim = false,
        AutoKillAll = false,
        KillAura = false,
        KnifeAim = false,
        AutoDodge = false,
        Kaitun = false,
        AutoFarm = false,
        FarmSpeed = 25,
        ResetWhenFull = false,
        AntiFling = false,
        XRay = false,
        Aimbot = false,
        AimSmooth = 70,
        SkinSource = nil,
        EspPlayers = false,
        EspGun = false,
        RoleNotify = false,
        SpeedOn = false,
        WalkSpeed = 24,
        JumpOn = false,
        JumpPower = 70,
        InfJump = false,
        Noclip = false,
        Fly = false,
        Fullbright = false,
        AntiAfk = false,
        TrollTarget = nil,
        TeleportTarget = nil,
    },
}

local State = Riad.State

for _, name in ipairs({ "Util", "Round", "Sheriff", "Murderer", "Troll", "Survive", "Auto", "Farm", "Aim", "Skin", "Teleport", "Movement", "Esp", "Visual", "Session", "Scheduler" }) do
    Riad[name] = {}
end

-- ============================================================
-- UTIL
-- ============================================================
function Riad.Util.Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[Riad] " .. tostring(err)) end
    return ok, err
end

function Riad.Util.Alert(text)
    warn("[Riad] " .. text)
    task.spawn(function()
        for _ = 1, Config.AlertTries do
            if pcall(StarterGui.SetCore, StarterGui, "SendNotification", { Title = "Riad Hub", Text = text, Duration = 10 }) then
                return
            end
            task.wait(Config.AlertRetry)
        end
    end)
end

function Riad.Util.HttpGet(url)
    local ok, body = pcall(game.HttpGet, game, url)
    if ok and type(body) == "string" then return body end
    local send = (type(request) == "function" and request) or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and syn.request) or (type(http) == "table" and http.request)
    if type(send) ~= "function" then return nil end
    local sent, response = pcall(send, { Url = url, Method = "GET" })
    if sent and type(response) == "table" and tonumber(response.StatusCode) == 200 and type(response.Body) == "string" then
        return response.Body
    end
    return nil
end

function Riad.Util.LoadLibrary()
    local source = Riad.Util.HttpGet(Config.UiSource)
    if not source or not source:sub(-64):find("return Library%s*$") then
        Riad.Util.Alert("Could not download the menu. Check your connection and run it again.")
        return nil
    end
    local chunk, err = loadstring(source)
    if not chunk then
        Riad.Util.Alert("The menu failed to load on this executor: " .. tostring(err))
        return nil
    end
    local ok, library = pcall(chunk)
    if not ok or type(library) ~= "table" then
        Riad.Util.Alert("The menu failed to load on this executor: " .. tostring(library))
        return nil
    end
    if type(library.Compat) ~= "table" then
        Riad.Util.Alert("The menu is out of date. Wait a few minutes and run the script again.")
        return nil
    end
    return library
end

function Riad.Util.Mount(instance)
    local ok, hui = pcall(gethui)
    if ok and typeof(hui) == "Instance" and pcall(function() instance.Parent = hui end) then return end
    if pcall(function() instance.Parent = game:GetService("CoreGui") end) then return end
    instance.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", Config.LoadTimeout)
end

-- ============================================================
-- GAME REMOTES & HELPERS
-- ============================================================
Riad.Game = {}
local Game = Riad.Game

function Game.Remote(folder, name, class)
    local remote = folder and folder:FindFirstChild(name)
    remote = remote or ReplicatedStorage:FindFirstChild(name, true)
    return remote and remote:IsA(class) and remote or nil
end

do
    local remotes = ReplicatedStorage:WaitForChild("Remotes", Config.LoadTimeout)
    local gameplay = remotes and remotes:WaitForChild("Gameplay", Config.LoadTimeout)
    local extras = remotes and remotes:FindFirstChild("Extras")
    Game.PlayerData = Game.Remote(gameplay, "GetCurrentPlayerData", "RemoteFunction")
    Game.CoinCollected = Game.Remote(gameplay, "CoinCollected", "BaseRemoteEvent")
    Game.CoinsStarted = Game.Remote(gameplay, "CoinsStarted", "BaseRemoteEvent")
    Game.RoundStart = Game.Remote(gameplay, "RoundStart", "BaseRemoteEvent")
    Game.RedeemCode = Game.Remote(extras, "RedeemCode", "RemoteFunction")
end

Game.Needs = {
    RoleNotify = { "RoundStart" },
    ResetWhenFull = { "CoinCollected" },
}

function Game.Missing(idx)
    for _, name in ipairs(Game.Needs[idx] or {}) do
        if not Game[name] then return name end
    end
    return nil
end

function Riad.Util.Connect(signal, fn)
    local conn = signal:Connect(fn)
    table.insert(State.Conns, conn)
    return conn
end

function Riad.Util.Root(player)
    local c = (player or LocalPlayer).Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Riad.Util.Humanoid(player)
    local c = (player or LocalPlayer).Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Riad.Util.Tool(player, name)
    local c = player.Character
    local bp = player:FindFirstChild("Backpack")
    return (c and c:FindFirstChild(name)) or (bp and bp:FindFirstChild(name))
end

-- ============================================================
-- ROUND
-- ============================================================
function Riad.Round.RefreshRoles()
    if os.clock() - State.LastRoleFetch < Config.RoleRefresh then return end
    State.LastRoleFetch = os.clock()
    if not Game.PlayerData then return end
    local ok, roster = pcall(Game.PlayerData.InvokeServer, Game.PlayerData)
    if ok and type(roster) == "table" then
        State.Roles = roster
    end
end

function Riad.Round.RoleOf(player)
    local entry = State.Roles[player.Name]
    if entry and not entry.Dead and entry.Role then return entry.Role end
    if Riad.Util.Tool(player, "Knife") then return "Murderer" end
    if Riad.Util.Tool(player, "Gun") then return "Sheriff" end
    return entry and entry.Dead and "Dead" or "Innocent"
end

function Riad.Round.FindByRole(role)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and Riad.Round.RoleOf(player) == role and Riad.Util.Root(player) then
            return player
        end
    end
    return nil
end

function Riad.Round.Map()
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name ~= Config.LobbyName and child:IsA("Model") and child:FindFirstChild("CoinContainer") then
            return child
        end
    end
    return nil
end

function Riad.Round.Lobby()
    local lobby = workspace:FindFirstChild(Config.LobbyName)
    if lobby then return lobby end
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child.Name:find("Lobby") then return child end
    end
    return nil
end

function Riad.Round.Playing()
    local entry = State.Roles[LocalPlayer.Name]
    local hum = Riad.Util.Humanoid()
    return Riad.Round.Map() ~= nil and hum ~= nil and hum.Health > 0 and entry ~= nil and not entry.Dead
end

function Riad.Round.GunDrop()
    local map = Riad.Round.Map()
    return (map and map:FindFirstChild("GunDrop", true)) or workspace:FindFirstChild("GunDrop")
end

-- ============================================================
-- MOVEMENT
-- ============================================================
function Riad.Movement.SetNoclip(enabled)
    if State.NoclipConn then
        State.NoclipConn:Disconnect()
        State.NoclipConn = nil
    end
    if not enabled then
        Riad.Movement.RestoreCollision()
        return
    end
    local saved = State.NoclipSaved
    State.NoclipConn = Riad.Util.Connect(RunService.Stepped, function()
        local c = LocalPlayer.Character
        if not c then return end
        for _, part in ipairs(c:GetChildren()) do
            if not part:IsA("BasePart") then continue end
            if saved[part] == nil then saved[part] = part.CanCollide end
            part.CanCollide = false
        end
    end)
end

function Riad.Movement.RestoreCollision()
    for part, cc in pairs(State.NoclipSaved) do
        if part.Parent then part.CanCollide = cc end
    end
    table.clear(State.NoclipSaved)
end

function Riad.Movement.RefreshNoclip()
    Riad.Movement.SetNoclip(State.Opt.Noclip or State.FarmBusy)
end

function Riad.Movement.Apply()
    local hum = Riad.Util.Humanoid()
    if not hum then return end
    if State.Opt.SpeedOn then hum.WalkSpeed = State.Opt.WalkSpeed end
    if State.Opt.JumpOn then
        hum.UseJumpPower = true
        hum.JumpPower = State.Opt.JumpPower
    end
end

function Riad.Movement.RestoreSpeed()
    local hum = Riad.Util.Humanoid()
    if hum then hum.WalkSpeed = Config.SpeedDefault end
end

function Riad.Movement.RestoreJump()
    local hum = Riad.Util.Humanoid()
    if hum then hum.JumpPower = Config.JumpDefault end
end

function Riad.Movement.InitInfJump()
    Riad.Util.Connect(UserInputService.JumpRequest, function()
        local hum = Riad.Util.Humanoid()
        if State.Opt.InfJump and hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

function Riad.Movement.SetFly(enabled)
    if State.FlyConn then
        State.FlyConn:Disconnect()
        State.FlyConn = nil
    end
    if State.FlyVelocity then
        State.FlyVelocity:Destroy()
        State.FlyVelocity = nil
    end
    local hum = Riad.Util.Humanoid()
    if hum then hum.PlatformStand = false end
    if not enabled then return end
    local mover = Instance.new("BodyVelocity")
    mover.MaxForce = Vector3.one * 1e9
    mover.Velocity = Vector3.zero
    State.FlyVelocity = mover
    State.FlyConn = Riad.Util.Connect(RunService.RenderStepped, function()
        local root, hum = Riad.Util.Root(), Riad.Util.Humanoid()
        if not root or not hum then return end
        mover.Parent = root
        hum.PlatformStand = true
        local vert = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)
        mover.Velocity = (hum.MoveDirection + Vector3.yAxis * vert) * 70
    end)
end

-- ============================================================
-- UTIL HELPERS
-- ============================================================
function Riad.Util.Busy()
    return State.ActionBusy and os.clock() - State.BusySince < Config.BusyTimeout
end

function Riad.Util.SetBusy(busy)
    State.ActionBusy = busy
    State.BusySince = os.clock()
end

function Riad.Util.WarpAndReturn(targetCF, action)
    local root = Riad.Util.Root()
    if not root or not targetCF or Riad.Util.Busy() then return false end
    Riad.Util.SetBusy(true)
    local home = root.CFrame
    local ok = Riad.Util.Try(function()
        root.CFrame = targetCF
        root.AssemblyLinearVelocity = Vector3.zero
        action()
    end)
    local cur = Riad.Util.Root()
    if cur then cur.CFrame = home end
    Riad.Util.SetBusy(false)
    return ok
end

-- ============================================================
-- SHERIFF
-- ============================================================
function Riad.Sheriff.Gun()
    return Riad.Util.Tool(LocalPlayer, "Gun")
end

function Riad.Sheriff.Equip(tool)
    local hum = Riad.Util.Humanoid()
    if hum and tool.Parent ~= LocalPlayer.Character then
        hum:EquipTool(tool)
    end
end

function Riad.Sheriff.ClearStand(target, targetRoot)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, target.Character }
    for _, offset in ipairs(Config.ShootStands) do
        local pos = (targetRoot.CFrame * CFrame.new(offset)).Position
        if not workspace:Raycast(pos, targetRoot.Position - pos, params) then
            return CFrame.lookAt(pos, targetRoot.Position)
        end
    end
    return CFrame.lookAt((targetRoot.CFrame * CFrame.new(Config.ShootStands[1])).Position, targetRoot.Position)
end

function Riad.Sheriff.ShootTarget(target)
    local gun, targetRoot = Riad.Sheriff.Gun(), Riad.Util.Root(target)
    if not gun or not targetRoot or os.clock() - State.LastShoot < Config.ShootCooldown then
        return false
    end
    State.LastShoot = os.clock()
    Riad.Sheriff.Equip(gun)
    return Riad.Util.WarpAndReturn(Riad.Sheriff.ClearStand(target, targetRoot), function()
        task.wait(Config.ShootSettle)
        local root = Riad.Util.Root()
        local att = root and root:FindFirstChild("GunRaycastAttachment")
        local aimRoot = Riad.Util.Root(target) or targetRoot
        gun.Shoot:FireServer(att and att.WorldCFrame or root.CFrame, aimRoot.CFrame)
        task.wait(Config.ShootReturn)
    end)
end

function Riad.Util.IsDead(player)
    local hum = Riad.Util.Humanoid(player)
    return not hum or hum.Health <= 0
end

function Riad.Sheriff.ShootMurderer()
    Riad.Round.RefreshRoles()
    local m = Riad.Round.FindByRole("Murderer")
    if not m then return false, "No murderer found" end
    for _ = 1, Config.ShootAttempts do
        if not Riad.Sheriff.Gun() then break end
        Riad.Sheriff.ShootTarget(m)
        task.wait(Config.ShootConfirm)
        if Riad.Util.IsDead(m) then return true, m.Name end
        task.wait(math.max(0, Config.ShootCooldown - Config.ShootConfirm))
    end
    return false, m.Name .. " survived"
end

function Riad.Sheriff.AutoShootStep()
    if not State.Opt.AutoShoot or State.ShootBusy or not Riad.Sheriff.Gun() or not Riad.Round.Playing() then return end
    State.ShootBusy = true
    task.spawn(function()
        Riad.Util.Try(Riad.Sheriff.ShootMurderer)
        State.ShootBusy = false
    end)
end

function Riad.Sheriff.GrabGun()
    local drop = Riad.Round.GunDrop()
    if not drop or Riad.Sheriff.Gun() or not Riad.Round.Playing() then return false end
    local part = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true)
    if not part then return false end
    return Riad.Util.WarpAndReturn(part.CFrame, function()
        local root = Riad.Util.Root()
        if root and Riad.Library.Compat.Caps.Touch then
            firetouchinterest(root, part, 0)
            firetouchinterest(root, part, 1)
        end
        task.wait(Config.GunGrabHold)
    end)
end

function Riad.Sheriff.AutoGrabStep()
    if State.Opt.AutoGrabGun and Riad.Round.RoleOf(LocalPlayer) ~= "Murderer" and Riad.Round.GunDrop() then
        task.spawn(Riad.Sheriff.GrabGun)
    end
end

-- ============================================================
-- MURDERER
-- ============================================================
function Riad.Murderer.Knife()
    return Riad.Util.Tool(LocalPlayer, "Knife")
end

function Riad.Murderer.Stab(target)
    local knife, targetRoot = Riad.Murderer.Knife(), Riad.Util.Root(target)
    if not knife or not targetRoot then return false end
    Riad.Sheriff.Equip(knife)
    local events = knife:FindFirstChild("Events")
    if not events then return false end
    local stand = targetRoot.CFrame * CFrame.new(0, 0, Config.StabOffset)
    return Riad.Util.WarpAndReturn(stand, function()
        events.KnifeStabbed:FireServer()
        task.wait()
        local aimRoot = Riad.Util.Root(target) or targetRoot
        events.HandleTouched:FireServer(aimRoot)
        task.wait(Config.StabCooldown)
    end)
end

function Riad.Murderer.Victims()
    local victims = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local hum = Riad.Util.Humanoid(player)
        local entry = State.Roles[player.Name]
        local inRound = entry == nil or not entry.Dead
        if player ~= LocalPlayer and hum and hum.Health > 0 and inRound and Riad.Util.Root(player) then
            table.insert(victims, player)
        end
    end
    table.sort(victims, function(a, b)
        return (Config.VictimPriority[Riad.Round.RoleOf(a)] or 3) < (Config.VictimPriority[Riad.Round.RoleOf(b)] or 3)
    end)
    return victims
end

function Riad.Murderer.KillAll()
    if not Riad.Murderer.Knife() then return 0 end
    local kills = 0
    for _, victim in ipairs(Riad.Murderer.Victims()) do
        if not State.Alive or not Riad.Murderer.Knife() then break end
        if Riad.Murderer.Stab(victim) then kills = kills + 1 end
    end
    return kills
end

function Riad.Murderer.AutoKillStep()
    if not State.Opt.AutoKillAll or State.KillBusy or not Riad.Murderer.Knife() or not Riad.Round.Playing() then return end
    State.KillBusy = true
    task.spawn(function()
        Riad.Util.Try(Riad.Murderer.KillAll)
        State.KillBusy = false
    end)
end

function Riad.Murderer.KillAuraStep()
    local knife, root = Riad.Murderer.Knife(), Riad.Util.Root()
    if not State.Opt.KillAura or not knife or not root or os.clock() - State.LastStab < Config.StabCooldown then return end
    local events = knife:FindFirstChild("Events")
    for _, victim in ipairs(Riad.Murderer.Victims()) do
        local vRoot = Riad.Util.Root(victim)
        if events and vRoot and (vRoot.Position - root.Position).Magnitude <= Config.KillAuraRange then
            State.LastStab = os.clock()
            Riad.Sheriff.Equip(knife)
            events.KnifeStabbed:FireServer()
            events.HandleTouched:FireServer(vRoot)
            return
        end
    end
end

function Riad.Murderer.NearestVictimRoot(origin)
    local best, bestD
    for _, victim in ipairs(Riad.Murderer.Victims()) do
        local vRoot = Riad.Util.Root(victim)
        local d = vRoot and (vRoot.Position - origin).Magnitude
        if d and (not bestD or d < bestD) then best, bestD = vRoot, d end
    end
    return best
end

-- ============================================================
-- SILENT AIM HOOK
-- ============================================================
function Riad.Sheriff.SyncAimHook()
    local wanted = State.Alive and (State.Opt.SilentAim or State.Opt.KnifeAim)
    if wanted and not State.Hook then
        Riad.Util.Try(Riad.Sheriff.InstallAimHook)
    elseif not wanted and State.Hook then
        local restore = State.Hook
        State.Hook = nil
        Riad.Util.Try(restore)
    end
end

function Riad.Sheriff.InstallAimHook()
    if not Riad.Library.Compat.Has({ "Namecall", "CheckCaller" }) then return end
    local original, restore
    original, restore = Riad.Library.Compat.HookMeta(game, "__namecall", function(self, ...)
        if not State.Alive or getnamecallmethod() ~= "FireServer" or checkcaller() then
            return original(self, ...)
        end
        local parent = self.Parent
        local opt = State.Opt
        if opt.SilentAim and self.Name == "Shoot" and parent and parent.Name == "Gun" then
            local m = Riad.Round.FindByRole("Murderer")
            local mRoot = m and Riad.Util.Root(m)
            if mRoot then
                local origin = ...
                return original(self, origin, mRoot.CFrame)
            end
        elseif opt.KnifeAim and self.Name == "KnifeThrown" and parent and parent.Name == "Events" then
            local origin = ...
            local vRoot = Riad.Murderer.NearestVictimRoot(origin.Position)
            if vRoot then return original(self, origin, vRoot.Position) end
        end
        return original(self, ...)
    end)
    State.Hook = restore
end

-- ============================================================
-- SURVIVE
-- ============================================================
function Riad.Survive.SafestSpot(threatPos)
    local map = Riad.Round.Map()
    local best, bestD
    for _, coin in ipairs(map and map.CoinContainer:GetChildren() or {}) do
        if coin:IsA("BasePart") then
            local d = (coin.Position - threatPos).Magnitude
            if not bestD or d > bestD then best, bestD = coin, d end
        end
    end
    return best and CFrame.new(best.Position + Vector3.new(0, 3, 0))
end

function Riad.Survive.DodgeStep()
    local root = Riad.Util.Root()
    local m = Riad.Round.FindByRole("Murderer")
    local threat = m and Riad.Util.Root(m)
    if not State.Opt.AutoDodge or not root or not threat or Riad.Murderer.Knife() or Riad.Util.Busy() then return end
    if os.clock() - State.LastDodge < 2.5 or (threat.Position - root.Position).Magnitude > 22 then return end
    local spot = Riad.Survive.SafestSpot(threat.Position)
    if spot then
        State.LastDodge = os.clock()
        root.CFrame = spot
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

-- ============================================================
-- AUTO WIN
-- ============================================================
function Riad.Auto.Step()
    if not State.Opt.Kaitun or not Riad.Round.Playing() then return end
    local opt = State.Opt
    opt.AutoKillAll = Riad.Murderer.Knife() ~= nil
    opt.AutoShoot = Riad.Sheriff.Gun() ~= nil
    opt.AutoGrabGun = true
    opt.AutoDodge = true
    opt.AutoFarm = true
end

-- ============================================================
-- FARM
-- ============================================================
function Riad.Farm.NearestCoin(map, origin)
    local m = not Riad.Murderer.Knife() and Riad.Round.FindByRole("Murderer")
    local threat = m and Riad.Util.Root(m)
    local best, bestD
    for _, coin in ipairs(map.CoinContainer:GetChildren()) do
        local visual = coin:FindFirstChild("CoinVisual")
        local skipAt = State.SkippedCoins[coin]
        local skipped = skipAt and os.clock() - skipAt < Config.FarmSkip
        local dangerous = threat and (coin.Position - threat.Position).Magnitude < Config.FarmThreatRadius
        if coin:IsA("BasePart") and visual and not visual:GetAttribute("Collected") and not skipped and not dangerous then
            local d = (coin.Position - origin).Magnitude
            if not bestD or d < bestD then best, bestD = coin, d end
        end
    end
    return best
end

function Riad.Farm.BagFull()
    return State.Bag.Max > 0 and State.Bag.Current >= State.Bag.Max
end

function Riad.Farm.CanRun()
    return State.Alive and State.Opt.AutoFarm and Riad.Round.Playing() and not Riad.Farm.BagFull()
end

function Riad.Farm.AttachMover(root)
    local att = Instance.new("Attachment")
    att.Parent = root
    local mover = Instance.new("LinearVelocity")
    mover.Attachment0 = att
    mover.MaxForce = math.huge
    mover.RelativeTo = Enum.ActuatorRelativeTo.World
    mover.VectorVelocity = Vector3.zero
    mover.Parent = root
    State.FarmMover = { Attachment = att, Velocity = mover }
    return mover
end

function Riad.Farm.DetachMover()
    local mover = State.FarmMover
    if mover then
        mover.Velocity:Destroy()
        mover.Attachment:Destroy()
        State.FarmMover = nil
    end
end

function Riad.Farm.GlideTo(position)
    local root = Riad.Util.Root()
    local mover = State.FarmMover
    if not root or not mover or mover.Velocity.Parent ~= root then
        Riad.Farm.DetachMover()
        mover = root and Riad.Farm.AttachMover(root) and State.FarmMover
    end
    while mover and Riad.Farm.CanRun() and root.Parent do
        local delta = position - root.Position
        if delta.Magnitude <= Config.FarmArrive then break end
        mover.Velocity.VectorVelocity = delta.Unit * math.min(State.Opt.FarmSpeed, delta.Magnitude * Config.FarmBrake)
        RunService.Heartbeat:Wait()
    end
    if mover then mover.Velocity.VectorVelocity = Vector3.zero end
end

function Riad.Farm.Run()
    local root = Riad.Util.Root()
    if root then Riad.Farm.AttachMover(root) end
    Riad.Movement.RefreshNoclip()
    State.FarmHome = root and root.CFrame
    while Riad.Farm.CanRun() do
        local map, hrp = Riad.Round.Map(), Riad.Util.Root()
        local coin = map and hrp and Riad.Farm.NearestCoin(map, hrp.Position)
        if coin and not Riad.Util.Busy() then
            Riad.Farm.GlideTo(coin.Position)
            task.wait(Config.FarmSettle)
            State.SkippedCoins[coin] = os.clock()
        else
            local mover = State.FarmMover
            if mover then mover.Velocity.VectorVelocity = Vector3.zero end
            task.wait(Config.FarmIdle)
        end
    end
end

function Riad.Farm.Settle()
    local root, home = Riad.Util.Root(), State.FarmHome
    State.FarmHome = nil
    if not root then return end
    root.AssemblyLinearVelocity = Vector3.zero
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local ground = workspace:Raycast(root.Position + Vector3.new(0, Config.FarmLift, 0), Vector3.new(0, -Config.FarmReach, 0), params)
    if ground or not home then return end
    root.CFrame = home
end

function Riad.Farm.Step()
    if State.FarmBusy or not Riad.Farm.CanRun() then return end
    State.FarmBusy = true
    task.spawn(function()
        local ok = Riad.Util.Try(Riad.Farm.Run)
        Riad.Farm.DetachMover()
        Riad.Farm.Settle()
        State.FarmBusy = false
        Riad.Movement.RefreshNoclip()
        local hum = Riad.Util.Humanoid()
        if ok and hum and State.Opt.ResetWhenFull and Riad.Farm.BagFull() then
            hum.Health = 0
        end
    end)
end

function Riad.Farm.InitBagTracking()
    if Game.CoinCollected then
        Riad.Util.Connect(Game.CoinCollected.OnClientEvent, function(_, current, maximum)
            State.Bag.Current = tonumber(current) or 0
            State.Bag.Max = tonumber(maximum) or 0
        end)
    end
    if Game.CoinsStarted then
        Riad.Util.Connect(Game.CoinsStarted.OnClientEvent, function()
            State.Bag.Current, State.Bag.Max = 0, 0
            table.clear(State.SkippedCoins)
        end)
    end
    if not Game.RoundStart then return end
    Riad.Util.Connect(Game.RoundStart.OnClientEvent, function()
        State.Bag.Current, State.Bag.Max = 0, 0
        table.clear(State.Roles)
    end)
end

-- ============================================================
-- MOVEMENT ANTI-FLING
-- ============================================================
function Riad.Movement.AntiFlingStep()
    if not State.Opt.AntiFling then return end
    for _, player in ipairs(Players:GetPlayers()) do
        local c = player ~= LocalPlayer and player.Character
        if c then
            for _, part in ipairs(c:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
    local root = Riad.Util.Root()
    if root and not Riad.Util.Busy() and not State.Opt.Fly and root.AssemblyLinearVelocity.Magnitude > 120 then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

-- ============================================================
-- AIM
-- ============================================================
function Riad.Aim.Target()
    if Riad.Murderer.Knife() then return Riad.Murderer.Victims()[1] end
    return Riad.Round.FindByRole("Murderer")
end

function Riad.Aim.Step(dt)
    if not State.Opt.Aimbot then return end
    local target = Riad.Aim.Target()
    local head = target and target.Character and target.Character:FindFirstChild("Head")
    if not head then return end
    local camera = workspace.CurrentCamera
    local goal = CFrame.lookAt(camera.CFrame.Position, head.Position)
    local alpha = 1 - (State.Opt.AimSmooth / 100) ^ (dt * 60)
    camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(alpha, 0, 1))
end

-- ============================================================
-- VISUAL / X-RAY
-- ============================================================
function Riad.Visual.ClearXRay()
    for part, original in pairs(State.XRayParts) do
        if part.Parent then part.Transparency = original end
    end
    table.clear(State.XRayParts)
    State.XRayMap = nil
end

function Riad.Visual.XRayStep()
    if not State.Opt.XRay then
        if State.XRayMap then Riad.Visual.ClearXRay() end
        return
    end
    local map = Riad.Round.Map() or Riad.Round.Lobby()
    if not map or State.XRayMap == map then return end
    Riad.Visual.ClearXRay()
    State.XRayMap = map
    local coins = map:FindFirstChild("CoinContainer")
    for _, part in ipairs(map:GetDescendants()) do
        if part:IsA("BasePart") and not (coins and part:IsDescendantOf(coins)) then
            State.XRayParts[part] = part.Transparency
            part.Transparency = math.max(part.Transparency, 0.6)
        end
    end
end

-- ============================================================
-- SKINS
-- ============================================================
function Riad.Skin.MeshOf(tool)
    local handle = tool and tool:FindFirstChild("Handle")
    return handle and handle:FindFirstChildWhichIsA("SpecialMesh")
end

function Riad.Skin.Copy(sourceName, weaponName)
    local source = sourceName and Players:FindFirstChild(sourceName)
    local mesh = source and Riad.Skin.MeshOf(Riad.Util.Tool(source, weaponName))
    if not mesh then return false end
    State.Skins[weaponName] = { MeshId = mesh.MeshId, TextureId = mesh.TextureId, Scale = mesh.Scale }
    return true
end

function Riad.Skin.ApplyStep()
    for weaponName, look in pairs(State.Skins) do
        local mesh = Riad.Skin.MeshOf(Riad.Util.Tool(LocalPlayer, weaponName))
        if mesh and mesh.MeshId ~= look.MeshId then
            mesh.MeshId, mesh.TextureId, mesh.Scale = look.MeshId, look.TextureId, look.Scale
        end
    end
end

-- ============================================================
-- TROLL
-- ============================================================
function Riad.Troll.Target()
    return State.Opt.TrollTarget and Players:FindFirstChild(State.Opt.TrollTarget)
end

function Riad.Troll.Fling(target)
    local root, targetRoot = Riad.Util.Root(), Riad.Util.Root(target)
    if not root or not targetRoot or Riad.Util.Busy() then return false end
    Riad.Util.SetBusy(true)
    local home = root.CFrame
    local spin = Instance.new("BodyAngularVelocity")
    spin.MaxTorque = Vector3.one * math.huge
    spin.AngularVelocity = Vector3.new(0, 9e4, 0)
    spin.Parent = root
    Riad.Movement.SetNoclip(true)
    local started = os.clock()
    while os.clock() - started < 2.5 do
        local cur = Riad.Util.Root(target)
        if not cur or not root.Parent then break end
        root.CFrame = cur.CFrame
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        RunService.Heartbeat:Wait()
    end
    spin:Destroy()
    if root.Parent then
        root.AssemblyAngularVelocity = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = home
    end
    Riad.Util.SetBusy(false)
    Riad.Movement.RefreshNoclip()
    return true
end

function Riad.Troll.Spectate(target)
    local hum = target and Riad.Util.Humanoid(target) or Riad.Util.Humanoid()
    if hum then workspace.CurrentCamera.CameraSubject = hum end
end

function Riad.Troll.StickStep()
    local target = State.StickTarget and Players:FindFirstChild(State.StickTarget)
    local root, targetRoot = Riad.Util.Root(), target and Riad.Util.Root(target)
    if root and targetRoot and not Riad.Util.Busy() then
        root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2)
    end
end

-- ============================================================
-- TELEPORT
-- ============================================================
function Riad.Teleport.To(cframe)
    local root = Riad.Util.Root()
    if root and cframe then
        root.CFrame = cframe + Vector3.new(0, 3, 0)
        return true
    end
    return false
end

function Riad.Teleport.ToPlayer(name)
    local player = name and Players:FindFirstChild(name)
    local root = player and Riad.Util.Root(player)
    return Riad.Teleport.To(root and root.CFrame)
end

function Riad.Teleport.ToLobby()
    local lobby = Riad.Round.Lobby()
    local sp = lobby and (lobby:FindFirstChild("Spawns", true) or lobby:FindFirstChildWhichIsA("SpawnLocation", true))
    local part = sp and (sp:IsA("BasePart") and sp or sp:FindFirstChildWhichIsA("BasePart"))
    if not part and lobby then part = lobby:FindFirstChildWhichIsA("BasePart", true) end
    return Riad.Teleport.To(part and part.CFrame)
end

function Riad.Teleport.ToMap()
    local map = Riad.Round.Map()
    local sp = map and map:FindFirstChild("Spawns")
    local part = sp and sp:FindFirstChildWhichIsA("BasePart") or (map and map.CoinContainer:FindFirstChildWhichIsA("BasePart"))
    return Riad.Teleport.To(part and part.CFrame)
end

-- ============================================================
-- ESP
-- ============================================================
function Riad.Esp.Init()
    Riad.Esp.Folder = Instance.new("Folder")
    Riad.Esp.Folder.Name = HttpService:GenerateGUID(false)
    Riad.Util.Mount(Riad.Esp.Folder)
end

function Riad.Esp.MakeHighlight(adornee, color)
    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.65
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = adornee
    hl.Parent = Riad.Esp.Folder
    return hl
end

function Riad.Esp.MakeLabel(adornee, color)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromOffset(180, 36)
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
    gui.AlwaysOnTop = true
    gui.Adornee = adornee
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.4
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = gui
    gui.Parent = Riad.Esp.Folder
    return gui, label
end

function Riad.Esp.DropEntry(entry)
    if entry then
        entry.Highlight:Destroy()
        entry.Gui:Destroy()
    end
end

function Riad.Esp.RefreshPlayers()
    local entries = State.Esp.Players
    local myRoot = Riad.Util.Root()
    for _, player in ipairs(Players:GetPlayers()) do
        local character, root = player.Character, Riad.Util.Root(player)
        local entry = entries[player]
        local role = Riad.Round.RoleOf(player)
        local visible = State.Opt.EspPlayers and player ~= LocalPlayer and character and root and role ~= "Dead"
        if not visible then
            Riad.Esp.DropEntry(entry)
            entries[player] = nil
        else
            if not entry or entry.Character ~= character then
                Riad.Esp.DropEntry(entry)
                local gui, label = Riad.Esp.MakeLabel(root, Color3.new(1, 1, 1))
                entry = { Character = character, Highlight = Riad.Esp.MakeHighlight(character, Color3.new(1, 1, 1)), Gui = gui, Label = label }
                entries[player] = entry
            end
            local color = Config.Colors[role] or Config.Colors.Innocent
            local distance = myRoot and math.floor((root.Position - myRoot.Position).Magnitude) or 0
            entry.Highlight.FillColor, entry.Highlight.OutlineColor, entry.Label.TextColor3 = color, color, color
            entry.Label.Text = string.format("%s [%s] %dm", player.DisplayName, role, distance)
        end
    end
    for player, entry in pairs(entries) do
        if not player.Parent then
            Riad.Esp.DropEntry(entry)
            entries[player] = nil
        end
    end
end

function Riad.Esp.RefreshGun()
    local drop = State.Opt.EspGun and Riad.Round.GunDrop()
    local entry = State.Esp.Gun
    if entry and entry.Adornee == drop then return end
    Riad.Esp.DropEntry(entry)
    State.Esp.Gun = nil
    if drop then
        local gui, label = Riad.Esp.MakeLabel(drop, Config.Colors.Gun)
        label.Text = "GUN DROP"
        State.Esp.Gun = { Adornee = drop, Highlight = Riad.Esp.MakeHighlight(drop, Config.Colors.Gun), Gui = gui }
    end
end

function Riad.Esp.Destroy()
    if Riad.Esp.Folder then Riad.Esp.Folder:Destroy() end
    table.clear(State.Esp.Players)
    State.Esp.Gun = nil
end

-- ============================================================
-- FULLBRIGHT
-- ============================================================
function Riad.Visual.SetFullbright(enabled)
    if enabled and not State.LightingDefaults then
        State.LightingDefaults = { Ambient = Lighting.Ambient, Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows }
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e9
        Lighting.GlobalShadows = false
    elseif not enabled and State.LightingDefaults then
        for prop, value in pairs(State.LightingDefaults) do
            Lighting[prop] = value
        end
        State.LightingDefaults = nil
    end
end

-- ============================================================
-- SESSION
-- ============================================================
function Riad.Session.RedeemCode(code)
    local remote = Game.RedeemCode
    if not remote then return "The code box was not found in this game version" end
    local ok, message = pcall(remote.InvokeServer, remote, code)
    return ok and tostring(message) or "Request failed"
end

function Riad.Session.Rejoin()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

function Riad.Session.Hop()
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId)
    local body = Riad.Util.HttpGet(url)
    local ok, servers = pcall(HttpService.JSONDecode, HttpService, body or "")
    if not ok or type(servers) ~= "table" then return end
    for _, server in ipairs(servers.data or {}) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
            return
        end
    end
end

function Riad.Session.InitAntiAfk()
    Riad.Util.Connect(LocalPlayer.Idled, function()
        if State.Opt.AntiAfk then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

function Riad.Session.InitRoleNotify(notify)
    if not Game.RoundStart then return end
    Riad.Util.Connect(Game.RoundStart.OnClientEvent, function()
        task.wait(2)
        State.LastRoleFetch = 0
        Riad.Round.RefreshRoles()
        if not State.Opt.RoleNotify then return end
        local m, s = Riad.Round.FindByRole("Murderer"), Riad.Round.FindByRole("Sheriff")
        notify(string.format("Murderer: %s | Sheriff: %s | You: %s",
            m and m.Name or "?",
            s and s.Name or "?",
            Riad.Round.RoleOf(LocalPlayer)))
    end)
end

-- ============================================================
-- SCHEDULER
-- ============================================================
Riad.Scheduler.Jobs = {
    Tick = {
        { "Roles", Riad.Round.RefreshRoles },
        { "Auto Win", Riad.Auto.Step, "Kaitun" },
        { "Auto Farm", Riad.Farm.Step, "AutoFarm" },
        { "X-Ray", Riad.Visual.XRayStep, "XRay" },
        { "Skins", Riad.Skin.ApplyStep },
        { "Movement", Riad.Movement.Apply, { "SpeedOn", "JumpOn" } },
        { "Auto Grab Gun", Riad.Sheriff.AutoGrabStep, "AutoGrabGun" },
        { "Auto Shoot", Riad.Sheriff.AutoShootStep, "AutoShoot" },
        { "Auto Kill All", Riad.Murderer.AutoKillStep, "AutoKillAll" },
        { "Role ESP", Riad.Esp.RefreshPlayers, "EspPlayers" },
        { "Gun ESP", Riad.Esp.RefreshGun, "EspGun" },
    },
    Stepped = { { "Anti Fling", Riad.Movement.AntiFlingStep, "AntiFling" } },
    Render = { { "Aimbot", Riad.Aim.Step, "Aimbot" } },
    Heartbeat = {
        { "Kill Aura", Riad.Murderer.KillAuraStep, "KillAura" },
        { "Auto Dodge", Riad.Survive.DodgeStep, "AutoDodge" },
        { "Stick To Player", Riad.Troll.StickStep, "StickTo" },
    },
}

function Riad.Scheduler.OnToggles(job)
    local on = {}
    if not Riad.Library or job[3] == nil then return on end
    for _, idx in ipairs(type(job[3]) == "table" and job[3] or { job[3] }) do
        local toggle = Riad.Library.Toggles[idx]
        if toggle and toggle.Value then on[#on + 1] = toggle end
    end
    return on
end

function Riad.Scheduler.Halt(job, err)
    local reason = tostring(err):match("^[^\n]*")
    job.Streak = nil
    if #Riad.Scheduler.OnToggles(job) == 0 then
        job.Stopped = true
        warn("[Riad] " .. job[1] .. " paused until turned on:", reason)
        return
    end
    job.Halting = true
    warn("[Riad] " .. job[1] .. " stopped:", reason)
    table.insert(State.Halted, { job, reason })
end

function Riad.Scheduler.Run(job, ...)
    if job.Halting then return end
    if job.Stopped then
        if #Riad.Scheduler.OnToggles(job) == 0 then return end
        job.Stopped = nil
    end
    local ok, err = pcall(job[2], ...)
    if ok then
        job.Streak = nil
        return
    end
    local streak = job.Streak
    if not streak then
        streak = { count = 0, since = os.clock() }
        job.Streak = streak
        warn("[Riad] " .. job[1] .. ":", err)
    end
    streak.count += 1
    if job[3] == nil or streak.count < Config.FailLimit or os.clock() - streak.since < Config.FailWindow then return end
    Riad.Scheduler.Halt(job, err)
end

function Riad.Scheduler.RunLane(lane, ...)
    for _, job in ipairs(Riad.Scheduler.Jobs[lane]) do
        Riad.Scheduler.Run(job, ...)
    end
end

function Riad.Scheduler.Boot(notify)
    Riad.Esp.Init()
    Riad.Farm.InitBagTracking()
    Riad.Util.Connect(RunService.Stepped, function()
        Riad.Scheduler.RunLane("Stepped")
    end)
    Riad.Movement.InitInfJump()
    Riad.Session.InitAntiAfk()
    Riad.Session.InitRoleNotify(notify)
    Riad.Util.Connect(RunService.RenderStepped, function(dt)
        Riad.Scheduler.RunLane("Render", dt)
    end)
    Riad.Util.Connect(RunService.Heartbeat, function()
        Riad.Scheduler.RunLane("Heartbeat")
    end)
    task.spawn(function()
        while State.Alive do
            Riad.Scheduler.RunLane("Tick")
            task.wait(Config.TickDelay)
        end
    end)
end

function Riad.Scheduler.Stop()
    State.Alive = false
    getgenv().RiadHubUnload = nil
    Riad.Sheriff.SyncAimHook()
    State.StickTarget = nil
    Riad.Movement.SetFly(false)
    Riad.Movement.SetNoclip(false)
    for _, conn in ipairs(State.Conns) do
        conn:Disconnect()
    end
    table.clear(State.Conns)
    if State.Opt.SpeedOn then Riad.Movement.RestoreSpeed() end
    if State.Opt.JumpOn then Riad.Movement.RestoreJump() end
    Riad.Troll.Spectate(nil)
    Riad.Visual.SetFullbright(false)
    Riad.Visual.ClearXRay()
    Riad.Farm.DetachMover()
    Riad.Esp.Destroy()
end

-- ============================================================
-- BUILD INTERFACE
-- ============================================================
local function BuildInterface()
    local Library = Riad.Util.LoadLibrary()
    if not Library then return false end
    Riad.Library = Library
    pcall(Boot.Step, "UI library")
    local opt = State.Opt
    local live = {}

    local function Notify(text, kind)
        Library:Notify("Riad Hub", text, 5, kind or "Info")
    end

    local function Bind(idx)
        return function(value) opt[idx] = value end
    end

    local function AimHookBind(idx)
        return function(value)
            opt[idx] = value
            Riad.Sheriff.SyncAimHook()
        end
    end

    local function Picked(idx)
        local option = Library.Options[idx]
        opt[idx] = option and option.Value or nil
        return opt[idx]
    end

    local function FlingAsync(target)
        if target then task.spawn(Riad.Troll.Fling, target) end
    end

    -- ========================================================
    -- COMBAT TAB
    -- ========================================================
    local function BuildCombatTab(window)
        local tab = window:AddTab("Combat", "crosshair", "Sheriff and murderer tools")

        local gunBox = tab:AddLeftGroupbox("Sheriff / Hero")
        gunBox:AddToggle("SilentAim", {
            Text = "Silent Aim",
            Description = "Every shot you fire goes to the murderer",
            Default = false,
            Callback = AimHookBind("SilentAim"),
        }):AddKeyPicker("SilentAimKey", { Default = "None", Mode = "Toggle" })
        Library.Compat.NeedCap("SilentAim", { "Namecall", "CheckCaller" })
        gunBox:AddToggle("AutoShoot", {
            Text = "Auto Shoot Murderer",
            Description = "Kills the murderer as soon as you hold the gun",
            Default = false,
            Risky = true,
            Callback = Bind("AutoShoot"),
        }):AddKeyPicker("AutoShootKey", { Default = "None", Mode = "Toggle" })
        gunBox:AddButton({ Text = "Shoot Murderer Now", Style = "Primary", Func = function()
            local ok, detail = Riad.Sheriff.ShootMurderer()
            Notify(ok and ("Shot " .. tostring(detail)) or tostring(detail or "You need the gun"), ok and "Success" or "Warning")
        end })
        gunBox:AddToggle("AutoGrabGun", {
            Text = "Auto Grab Gun",
            Description = "Picks up the dropped gun the moment the sheriff dies",
            Default = false,
            Callback = Bind("AutoGrabGun"),
        }):AddKeyPicker("AutoGrabGunKey", { Default = "None", Mode = "Toggle" })
        gunBox:AddButton({ Text = "Grab Gun Now", Func = function()
            local got = Riad.Sheriff.GrabGun()
            Notify(got and "Gun grabbed" or "No gun on the ground", got and "Success" or "Warning")
        end })

        local knifeBox = tab:AddRightGroupbox("Murderer")
        knifeBox:AddToggle("AutoKillAll", {
            Text = "Auto Kill All",
            Description = "Ends the round by killing everyone when you are the murderer",
            Default = false,
            Risky = true,
            Callback = Bind("AutoKillAll"),
        }):AddKeyPicker("AutoKillAllKey", { Default = "None", Mode = "Toggle" })
        knifeBox:AddButton({ Text = "Kill All Now", Style = "Primary", Func = function()
            task.spawn(function()
                Notify(string.format("Killed %d players", Riad.Murderer.KillAll()))
            end)
        end })
        knifeBox:AddToggle("KillAura", {
            Text = "Kill Aura",
            Description = "Kills anyone who gets close while you hold the knife",
            Default = false,
            Risky = true,
            Callback = Bind("KillAura"),
        }):AddKeyPicker("KillAuraKey", { Default = "None", Mode = "Toggle" })
        knifeBox:AddToggle("KnifeAim", {
            Text = "Knife Throw Aim",
            Description = "Thrown knives fly to the nearest player",
            Default = false,
            Callback = AimHookBind("KnifeAim"),
        })
        Library.Compat.NeedCap("KnifeAim", { "Namecall", "CheckCaller" })

        local aimBox = tab:AddRightGroupbox("Aimbot")
        aimBox:AddToggle("Aimbot", {
            Text = "Aimbot",
            Description = "Locks your camera on the murderer, or on the next victim when you hold the knife",
            Default = false,
            Callback = Bind("Aimbot"),
        }):AddKeyPicker("AimbotKey", { Default = "Q", Mode = "Hold" })
        aimBox:AddSlider("AimSmooth", {
            Text = "Smoothness",
            Min = 0, Max = 95, Default = opt.AimSmooth, Rounding = 0, Suffix = "%",
            Callback = function(value)
                opt.AimSmooth = tonumber(value) or 0
            end,
        })

        local smartBox = tab:AddLeftGroupbox("Auto Play")
        smartBox:AddToggle("Kaitun", {
            Text = "Auto Win",
            Description = "Plays every round for you in any role",
            Default = false,
            Risky = true,
            Callback = function(value)
                opt.Kaitun = value
                if value then return end
                for _, idx in ipairs({ "AutoKillAll", "AutoShoot", "AutoGrabGun", "AutoDodge", "AutoFarm" }) do
                    opt[idx] = Library.Options[idx].Value
                end
            end,
        }):AddKeyPicker("KaitunKey", { Default = "None", Mode = "Toggle" })
        smartBox:AddToggle("AutoDodge", {
            Text = "Auto Dodge Murderer",
            Description = "Escapes to the far side of the map when the murderer gets close",
            Default = false,
            Callback = Bind("AutoDodge"),
        }):AddKeyPicker("AutoDodgeKey", { Default = "None", Mode = "Toggle" })
    end

    -- ========================================================
    -- TELEPORT TAB
    -- ========================================================
    local function BuildTeleportTab(window)
        local tab = window:AddTab("Teleport", "globe", "Map, lobby and players")
        local placeBox = tab:AddLeftGroupbox("Places")
        placeBox:AddButton({ Text = "Lobby", Func = Riad.Teleport.ToLobby })
            :AddButton({ Text = "Map", Func = Riad.Teleport.ToMap })
        placeBox:AddButton({ Text = "To Murderer", Func = function()
            local target = Riad.Round.FindByRole("Murderer")
            Riad.Teleport.ToPlayer(target and target.Name)
        end })
            :AddButton({ Text = "To Sheriff", Func = function()
                local target = Riad.Round.FindByRole("Sheriff")
                Riad.Teleport.ToPlayer(target and target.Name)
            end })
        local playerBox = tab:AddRightGroupbox("Players")
        playerBox:AddDropdown("TeleportTarget", {
            Text = "Player",
            SpecialType = "Player",
            Searchable = true,
            Callback = Bind("TeleportTarget"),
        })
        playerBox:AddButton({ Text = "Teleport", Style = "Primary", Func = function()
            Riad.Teleport.ToPlayer(Picked("TeleportTarget"))
        end })
    end

    -- ========================================================
    -- TROLL TAB
    -- ========================================================
    local function BuildTrollTab(window)
        local tab = window:AddTab("Troll", "zap", "Fling, stick and spectate")
        local box = tab:AddLeftGroupbox("Target")
        box:AddDropdown("TrollTarget", {
            Text = "Player",
            SpecialType = "Player",
            Searchable = true,
            Callback = function(value)
                opt.TrollTarget = value
                local stick, spec = Library.Options.StickTo, Library.Options.Spectate
                if stick and stick.Value then State.StickTarget = value end
                if spec and spec.Value then Riad.Troll.Spectate(Riad.Troll.Target()) end
            end,
        })
        box:AddButton({ Text = "Fling", Style = "Primary", Func = function()
            Picked("TrollTarget")
            FlingAsync(Riad.Troll.Target())
        end })
            :AddButton({ Text = "Fling Murderer", Func = function()
                FlingAsync(Riad.Round.FindByRole("Murderer"))
            end })
        box:AddButton({ Text = "Fling Everyone", Style = "Warning", DoubleClick = true, Func = function()
            task.spawn(function()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player == LocalPlayer or not Riad.Util.Root(player) then continue end
                    Riad.Troll.Fling(player)
                end
            end)
        end })
        local followBox = tab:AddRightGroupbox("Follow")
        followBox:AddToggle("StickTo", {
            Text = "Stick To Player",
            Description = "Stays glued right behind the selected player",
            Default = false,
            Callback = function(value)
                State.StickTarget = value and Picked("TrollTarget") or nil
            end,
        })
        followBox:AddToggle("Spectate", {
            Text = "Spectate",
            Default = false,
            Callback = function(value)
                Picked("TrollTarget")
                Riad.Troll.Spectate(value and Riad.Troll.Target() or nil)
            end,
        })
    end

    -- ========================================================
    -- PLAYER TAB
    -- ========================================================
    local function BuildPlayerTab(window)
        local tab = window:AddTab("Player", "user", "Movement")
        local moveBox = tab:AddLeftGroupbox("Movement")
        moveBox:AddToggle("SpeedOn", {
            Text = "Walk Speed",
            Default = false,
            Callback = function(value)
                opt.SpeedOn = value
                if not value then Riad.Movement.RestoreSpeed() end
            end,
        })
        moveBox:AddSlider("WalkSpeed", {
            Text = "Speed", Min = 16, Max = 120, Default = opt.WalkSpeed, Rounding = 0,
            Callback = function(value)
                opt.WalkSpeed = tonumber(value) or Config.SpeedDefault
            end,
        })
        moveBox:AddToggle("JumpOn", {
            Text = "Jump Power",
            Default = false,
            Callback = function(value)
                opt.JumpOn = value
                if not value then Riad.Movement.RestoreJump() end
            end,
        })
        moveBox:AddSlider("JumpPower", {
            Text = "Power", Min = 50, Max = 200, Default = opt.JumpPower, Rounding = 0,
            Callback = function(value)
                opt.JumpPower = tonumber(value) or Config.JumpDefault
            end,
        })
        local extraBox = tab:AddRightGroupbox("Extra")
        extraBox:AddToggle("AntiFling", {
            Text = "Anti Fling",
            Description = "Other players cannot push or launch you",
            Default = false,
            Callback = Bind("AntiFling"),
        })
        extraBox:AddToggle("InfJump", { Text = "Infinite Jump", Default = false, Callback = Bind("InfJump") })
        extraBox:AddToggle("Noclip", {
            Text = "Noclip",
            Default = false,
            Callback = function(value)
                opt.Noclip = value
                Riad.Movement.RefreshNoclip()
            end,
        }):AddKeyPicker("NoclipKey", { Default = "None", Mode = "Toggle" })
        extraBox:AddToggle("Fly", {
            Text = "Fly",
            Description = "Space to go up, Left Ctrl to go down",
            Default = false,
            Callback = function(value)
                opt.Fly = value
                Riad.Movement.SetFly(value)
            end,
        }):AddKeyPicker("FlyKey", { Default = "None", Mode = "Toggle" })
    end

    -- ========================================================
    -- VISUALS TAB
    -- ========================================================
    local function BuildVisualTab(window)
        local tab = window:AddTab("Visuals", "eye", "Roles and gun")
        local espBox = tab:AddLeftGroupbox("ESP")
        espBox:AddToggle("EspPlayers", {
            Text = "Role ESP",
            Description = "Murderer red, sheriff blue, hero yellow, innocents green",
            Default = false,
            Callback = Bind("EspPlayers"),
        })
        espBox:AddToggle("EspGun", { Text = "Gun Drop ESP", Default = false, Callback = Bind("EspGun") })
        espBox:AddToggle("RoleNotify", {
            Text = "Role Notify",
            Description = "Tells you who the murderer and sheriff are at round start",
            Default = false,
            Callback = Bind("RoleNotify"),
        })
        espBox:AddToggle("XRay", {
            Text = "X-Ray",
            Description = "Makes map walls semi-transparent for vision",
            Default = false,
            Callback = Bind("XRay"),
        })
        espBox:AddToggle("Fullbright", {
            Text = "Fullbright",
            Description = "Removes darkness from the map",
            Default = false,
            Callback = function(v)
                opt.Fullbright = v
                Riad.Visual.SetFullbright(v)
            end,
        })

        local skinBox = tab:AddRightGroupbox("Skins", "sparkles")
        skinBox:AddDropdown("SkinSource", {
            Text = "Copy Skins From",
            SpecialType = "Player",
            Searchable = true,
            Callback = Bind("SkinSource"),
        })
        skinBox:AddButton({ Text = "Copy Knife", Func = function()
            local ok = Riad.Skin.Copy(Picked("SkinSource"), "Knife")
            Notify(ok and "Knife skin copied" or "Could not copy knife", ok and "Success" or "Warning")
        end })
        skinBox:AddButton({ Text = "Copy Gun", Func = function()
            local ok = Riad.Skin.Copy(Picked("SkinSource"), "Gun")
            Notify(ok and "Gun skin copied" or "Could not copy gun", ok and "Success" or "Warning")
        end })
        skinBox:AddButton({ Text = "Reset Skins", Func = function()
            State.Skins = {}
            Notify("Skins reset to default.", "Info")
        end })
    end

    -- ========================================================
    -- FARM TAB
    -- ========================================================
    local function BuildFarmTab(window)
        local tab = window:AddTab("Farm", "coins", "Auto-farm coins")

        local mainBox = tab:AddLeftGroupbox("Auto Farm")
        mainBox:AddToggle("AutoFarm", {
            Text = "Auto Farm Coins",
            Description = "Glides to coins using LinearVelocity",
            Default = false,
            Callback = Bind("AutoFarm"),
        }):AddKeyPicker("AutoFarmKey", { Default = "None", Mode = "Toggle" })
        mainBox:AddSlider("FarmSpeed", {
            Text = "Farm Speed",
            Min = 10, Max = 60, Default = opt.FarmSpeed, Rounding = 0,
            Callback = function(v) opt.FarmSpeed = tonumber(v) or 25 end,
        })
        mainBox:AddToggle("ResetWhenFull", {
            Text = "Reset When Bag Full",
            Description = "Respawns when coin bag hits max",
            Default = false,
            Callback = Bind("ResetWhenFull"),
        })

        local statusBox = tab:AddRightGroupbox("Status", "info")
        local bagLabel = statusBox:AddLabel("Bag: 0 / 0")
        local roundLabel = statusBox:AddLabel("Round: Waiting")
        local murdererLabel = statusBox:AddLabel("Murderer: ?")
        local sheriffLabel = statusBox:AddLabel("Sheriff: ?")
        local roleLabel = statusBox:AddLabel("Your Role: —")

        task.spawn(function()
            while State.Alive do
                task.wait(Config.StatusRefresh)
                if State.Opt.AutoFarm or true then
                    pcall(function()
                        bagLabel:SetText(string.format("Bag: %d / %d", State.Bag.Current, State.Bag.Max))
                        roundLabel:SetText("Round: " .. State.RoundState)
                        local m, s = Riad.Round.FindByRole("Murderer"), Riad.Round.FindByRole("Sheriff")
                        murdererLabel:SetText("Murderer: " .. (m and m.Name or "?"))
                        sheriffLabel:SetText("Sheriff: " .. (s and s.Name or "?"))
                        roleLabel:SetText("Your Role: " .. Riad.Round.RoleOf(LocalPlayer))
                    end)
                end
            end
        end)

        local linkBox = tab:AddRightGroupbox("Links", "link")
        linkBox:AddLabel("Discord: " .. Config.Discord)
        linkBox:AddLabel(" ")
        for _, entry in ipairs(Config.UpdateLog) do
            linkBox:AddLabel(entry[1] .. " — " .. entry[2]:gsub("\n", " | "))
        end
    end

    -- ========================================================
    -- MISC TAB
    -- ========================================================
    local function BuildMiscTab(window)
        local tab = window:AddTab("Misc", "settings", "Session & config")

        local sessionBox = tab:AddLeftGroupbox("Session")
        sessionBox:AddToggle("AntiAfk", {
            Text = "Anti-AFK", Default = true,
            Callback = Bind("AntiAfk"),
        })
        sessionBox:AddButton({ Text = "Rejoin Server", Func = Riad.Session.Rejoin })
        sessionBox:AddButton({ Text = "Server Hop", Func = function()
            Riad.Session.Hop()
            Notify("Searching for server...", "Info")
        end })
        sessionBox:AddButton({ Text = "Panic All Off", Style = "Warning", Func = function()
            for idx, _ in pairs(opt) do
                if type(opt[idx]) == "boolean" then opt[idx] = false end
            end
            Notify("All toggles disabled.", "Warning")
        end })

        local codeBox = tab:AddRightGroupbox("Redeem Code")
        codeBox:AddInput("RedeemCodeInput", {
            Text = "Code", Default = "", Placeholder = "Enter code...",
            Callback = function(v) end,
        })
        codeBox:AddButton({ Text = "Redeem", Style = "Primary", Func = function()
            local code = Picked("RedeemCodeInput")
            if code and code ~= "" then
                local msg = Riad.Session.RedeemCode(code)
                Notify(msg, "Info")
            end
        end })
    end

    -- Build all tabs
    BuildCombatTab(Window)
    BuildTeleportTab(Window)
    BuildTrollTab(Window)
    BuildPlayerTab(Window)
    BuildVisualTab(Window)
    BuildFarmTab(Window)
    BuildMiscTab(Window)

    -- Settings tab (auto-generated by library)
    Window:AddSettingsTab("Settings", "settings")

    pcall(Boot.Step, "UI built")
    return true
end

-- ============================================================
-- START
-- ============================================================
local ok = BuildInterface()
if not ok then return end

Riad.Scheduler.Boot(function(text, kind)
    Library:Notify("Riad Hub", text, 5, kind or "Info")
end)

pcall(Boot.Step, "Scheduler")
pcall(Boot.Ready)

-- ============================================================
-- UNLOAD
-- ============================================================
getgenv().RiadHubUnload = function()
    Riad.Scheduler.Stop()
end

Library:Notify({
    Title = "Riad Hub",
    Description = "Loaded. Right-Ctrl to toggle.",
    Time = 5,
    Image = "check-circle",
})
