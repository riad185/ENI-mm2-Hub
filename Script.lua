--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║   RIAD HUB                                                    ║
    ║   MM2 · built for Riad                                        ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

if getgenv and getgenv().RiadHub_Unload then
    pcall(getgenv().RiadHub_Unload)
end

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JaxRol/ZeroPoint/refs/heads/main/GUI/ZeroPoint-GUI"
))()

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService   = game:GetService("TextChatService")
local CollectionService = game:GetService("CollectionService")
local Stats             = game:GetService("Stats")
local LP                = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

local activeConnections = {}

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    RoleESP = false, ESPBoxes = false, ESPNames = true,
    ESPTracers = false, ESPDistance = true, ESPChams = false,
    ESPDistanceMax = 600, GunESP = false, CoinESP = false, GunTracker = false,
    Fullbright = false, NoFog = false, DisableParticles = false, FPSBooster = false,
    PlayerStats = false,

    Aimbot = false, AutoShoot = false, SilentAim = false,
    AimPrediction = true, PingComp = true, SingleShot = false,
    FOVRadius = 160, ShowFOV = false, AimFOV = 200,
    TeamCheck = false, FocusMode = false,
    AutoEquipGun = true, GrabGunAuto = false, GunGrabDist = 300,
    GunCollectReach = 10, AutoTPGun = false, MagicBullet = false,

    AutoStab = false, KillAura = false, AutoKill = false,
    KillMode = "Legit", KnifeSilentAim = true, AuraRange = 15,
    KillAll = false, ShowAuraRing = false, AutoEquipKnife = true,
    ProximityKnife = true, KnifeProxDist = 18,
    AutoKillMurderer = false, AutoKillSheriff = false, DodgeKnife = false,

    HitboxExpander = false, HitboxSize = 10, HitboxTransparency = 0.6,
    GodMode = false,

    MurdererAvoid = false, SafetyRadius = 40, RetreatToLobby = false,
    ProximityAlert = true, SprintWhenChased = true,
    FollowMurderer = false, FollowDist = 18,

    Speed = false, SpeedValue = 24, JumpEnabled = false, JumpValue = 50,
    InfiniteJump = false, Noclip = false, Fly = false, FlySpeed = 35,
    AntiRagdoll = false, AntiVoid = true, AntiFling = true,

    CoinFarm = false, FarmSpeed = 28, FarmMethod = "Teleport",
    SafeCoinFarm = true, BagFullStop = true, QuickFarm = false,
    CoinBagCap = 40, TeleportFarmDelay = 0.05,

    AutoDrop = false, SaveSlot1 = nil, SaveSlot2 = nil,

    FlingStyle = "Torque",
    FlingMurdererPreRound = false,
    FlingSheriffPreRound = false,
    FlingHeroPreRound = false,
    FlingSheriffDuringRound = false,
    RoundEndNotifications = true,
    FlingAllPreRound = false,

    AutoUnbox = false, AutoPrestige = false,

    WebhookEnabled = false, WebhookURL = "",

    AntiAFK = true, AutoPlay = false, DeathNotifs = true,
}

local DefaultConfig = {}
for k, v in pairs(Config) do DefaultConfig[k] = v end

local CONFIG_FILE = "RiadHub/config.json"

local function LoadSavedConfig()
    if isfile and isfile(CONFIG_FILE) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if Config[k] ~= nil then
                    if type(v) == "table" and (k == "SaveSlot1" or k == "SaveSlot2") then
                        Config[k] = CFrame.new(unpack(v))
                    else
                        Config[k] = v
                    end
                end
            end
            return true
        end
    end
    return false
end

local saveDebounce = false
local function AutoSaveConfig()
    if not writefile then return end
    if saveDebounce then return end
    saveDebounce = true
    task.delay(0.25, function()
        saveDebounce = false
        pcall(function()
            if makefolder and not isfolder("RiadHub") then makefolder("RiadHub") end
            local payload = {}
            for k, v in pairs(Config) do
                if typeof(v) == "CFrame" then
                    payload[k] = {v:GetComponents()}
                else
                    payload[k] = v
                end
            end
            writefile(CONFIG_FILE, HttpService:JSONEncode(payload))
        end)
    end)
end

LoadSavedConfig()

-- ============================================================
-- WEBHOOK
-- ============================================================
local function SendWebhook(title, description)
    if not Config.WebhookEnabled then return end
    if Config.WebhookURL == "" then return end
    if not request then return end
    pcall(function()
        request({
            Url = Config.WebhookURL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                username = "Riad Hub",
                content = "**" .. title .. "**\n" .. description
            })
        })
    end)
end

-- ============================================================
-- STATE
-- ============================================================
local State = {
    Highlights = {}, ItemHighlights = {}, Boxes = {}, Tracers = {},
    LastItemScan = 0, LastAutoShoot = 0, LastKnifeTick = 0,
    LastFarmTick = 0, LastESPRefresh = 0, LastHitboxTick = 0,
    LastSafePosition = nil, DeadPlayers = {}, OriginalHitboxSizes = {},
    IsFlinging = false, AuraRing = nil, FOVCircle = nil, flyBV = nil,
    SilentAimHookActive = true, RoundStartedFlag = false,
    Alerted = 0, RoundState = "Waiting", LastRoundResult = nil,
    GunTPActive = false,
}

local espFolder = CoreGui:FindFirstChild("RiadHub_ESP") or LP.PlayerGui:FindFirstChild("RiadHub_ESP")
if not espFolder then
    espFolder = Instance.new("Folder")
    espFolder.Name = "RiadHub_ESP"
    pcall(function() espFolder.Parent = CoreGui end)
    if not espFolder.Parent then espFolder.Parent = LP.PlayerGui end
end

-- ============================================================
-- HELPERS
-- ============================================================
local function getHRP(p)
    local c = p and p.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") or c:FindFirstChildWhichIsA("BasePart")
end
local function getHumanoid(p)
    local c = p and p.Character
    if not c then return nil end
    return c:FindFirstChildOfClass("Humanoid")
end
local function isAlive(p)
    if not p or not p.Character then return false end
    local h = getHumanoid(p)
    return h and h.Health > 0
end
local function getRole(p)
    if not p then return "Innocent" end
    local bp = p:FindFirstChild("Backpack")
    local ch = p.Character
    local knife = (bp and bp:FindFirstChild("Knife")) or (ch and ch:FindFirstChild("Knife"))
    local gun   = (bp and bp:FindFirstChild("Gun"))   or (ch and ch:FindFirstChild("Gun"))
    if knife then return "Murderer" end
    if gun   then return "Sheriff" end
    return "Innocent"
end
local function roleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 40, 40) end
    if role == "Sheriff"  then return Color3.fromRGB(40, 120, 255) end
    return Color3.fromRGB(230, 230, 230)
end
local function getRolePlayers()
    local m, s = nil, nil
    local inno = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isAlive(p) then
            local r = getRole(p)
            if r == "Murderer" then m = p
            elseif r == "Sheriff" then s = p
            else table.insert(inno, p) end
        end
    end
    return m, s, inno
end
local function clearCategory(tbl)
    for _, obj in pairs(tbl) do
        if obj and obj.Parent then obj:Destroy() end
    end
    table.clear(tbl)
end
local function getActiveMap()
    for _, c in ipairs(Workspace:GetChildren()) do
        if c:IsA("Model")
            and not string.find(string.lower(c.Name), "lobby")
            and not Players:GetPlayerFromCharacter(c) then
            if c:FindFirstChild("Spawns") or c:FindFirstChild("CoinAreas")
                or c:FindFirstChild("CoinContainer") or c:FindFirstChild("Base") then
                return c
            end
        end
    end
    return nil
end
local function getLobbyModel()
    for _, c in ipairs(Workspace:GetChildren()) do
        if c:IsA("Model") and string.find(string.lower(c.Name), "lobby") then
            return c
        end
    end
    return Workspace:FindFirstChild("Lobby")
end
local function getAllActiveCoins()
    local coins, seen = {}, {}
    for _, tag in ipairs({"CoinVisual", "Coin"}) do
        for _, v in ipairs(CollectionService:GetTagged(tag)) do
            if v and v.Parent and not v:GetAttribute("Collected") and not v:GetAttribute("Delete") then
                local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
                if part and not seen[part] and part.Transparency < 0.95 then
                    seen[part] = true
                    table.insert(coins, part)
                end
            end
        end
    end
    if #coins == 0 then
        local map = getActiveMap()
        if map then
            local container = map:FindFirstChild("CoinAreas") or map:FindFirstChild("CoinContainer") or map:FindFirstChild("Coins")
            if container then
                for _, c in ipairs(container:GetChildren()) do
                    for _, d in ipairs(c:GetDescendants()) do
                        if (d:GetAttribute("CoinID") or string.find(string.lower(d.Name), "coin"))
                            and d:IsA("BasePart") and not seen[d] and d.Transparency < 0.95 then
                            seen[d] = true
                            table.insert(coins, d)
                        end
                    end
                end
            end
        end
    end
    return coins
end
local function getCurrentCoinCount()
    local pg = LP:FindFirstChild("PlayerGui")
    local mg = pg and pg:FindFirstChild("MainGUI")
    local gu = mg and mg:FindFirstChild("Game")
    local bag = gu and gu:FindFirstChild("CoinBag")
    if bag then
        for _, d in ipairs(bag:GetDescendants()) do
            if d:IsA("TextLabel") and string.find(d.Text, "/") then
                local n = tonumber(string.match(d.Text, "(%d+)%s*/"))
                if n then return n end
            end
        end
    end
    return 0
end
local function getGunDrop()
    local gd = Workspace:FindFirstChild("GunDrop")
    if gd then return gd end
    local map = getActiveMap()
    if map then
        gd = map:FindFirstChild("GunDrop")
        if gd then return gd end
    end
    return Workspace:FindFirstChild("GunDrop", true)
end
local function getGunDropPart(drop)
    if not drop then return nil end
    if drop:IsA("BasePart") then return drop end
    if drop:IsA("Model") or drop:IsA("Folder") or drop:IsA("Tool") then
        local p = drop:FindFirstChild("GunDrop") or drop:FindFirstChild("Handle")
            or drop.PrimaryPart or drop:FindFirstChildWhichIsA("BasePart")
        if p and p:IsA("BasePart") then return p end
        for _, d in ipairs(drop:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
    end
    return nil
end
local function fireTouch(a, b)
    if firetouchinterest and a and b then
        pcall(firetouchinterest, a, b, true)
        pcall(firetouchinterest, a, b, 0)
        task.wait()
        pcall(firetouchinterest, a, b, false)
        pcall(firetouchinterest, a, b, 1)
    end
end
local function interactWithGunDrop(gunPart, gunObj)
    if not gunPart then return end
    local ch = LP.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local prompt = (gunObj and gunObj:FindFirstChildOfClass("ProximityPrompt"))
        or gunPart:FindFirstChildOfClass("ProximityPrompt")
        or (gunObj and gunObj:FindFirstChildWhichIsA("ProximityPrompt", true))
    if prompt and fireproximityprompt then
        pcall(fireproximityprompt, prompt)
    end
    fireTouch(root, gunPart)
    local rh = ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm")
    if rh then fireTouch(rh, gunPart) end
end
local function isTeammate(p)
    if not Config.TeamCheck then return false end
    return false
end
local function nearestTarget(maxDist)
    maxDist = maxDist or math.huge
    local best, bestDist = nil, maxDist
    local myHRP = getHRP(LP)
    if not myHRP then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isAlive(p) and not isTeammate(p) then
            local hrp = getHRP(p)
            if hrp then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < bestDist then best, bestDist = p, d end
            end
        end
    end
    return best
end
local function equipTool(name)
    local ch = LP.Character
    if not ch then return nil end
    local bp = LP:FindFirstChild("Backpack")
    local h = getHumanoid(LP)
    local tool = (ch:FindFirstChild(name)) or (bp and bp:FindFirstChild(name))
    if tool and h and bp and tool.Parent == bp then
        h:EquipTool(tool)
        task.wait(0.05)
    end
    return tool
end

-- ============================================================
-- FLING
-- ============================================================
local function flingCharacter(targetChar)
    if State.IsFlinging then return end
    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local tRoot  = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not tRoot then return end
    local myHum = getHumanoid(LP)
    local tHum  = targetChar:FindFirstChildOfClass("Humanoid")
    if not myHum or myHum.Health <= 0 or not tHum or tHum.Health <= 0 then return end

    State.IsFlinging = true
    local oldCF = myRoot.CFrame

    if sethiddenproperty then
        pcall(sethiddenproperty, LP, "SimulationRadius", 10000)
        pcall(sethiddenproperty, LP, "MaxSimulationRadius", 10000)
    end
    if setsimulationradius then
        pcall(setsimulationradius, 10000)
    end

    for _, obj in ipairs(myRoot:GetChildren()) do
        if obj:IsA("BodyMover") then pcall(function() obj:Destroy() end) end
    end

    local bAV = Instance.new("BodyAngularVelocity")
    bAV.AngularVelocity = Vector3.new(0, 9e9, 0)
    bAV.MaxTorque = Vector3.new(0, 9e9, 0)
    bAV.P = 9e9
    bAV.Parent = myRoot

    local bV = Instance.new("BodyVelocity")
    bV.Velocity = Vector3.zero
    bV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bV.Parent = myRoot

    local conn = RunService.Stepped:Connect(function()
        if myChar and myChar.Parent then
            for _, child in ipairs(myChar:GetDescendants()) do
                if child:IsA("BasePart") then child.CanCollide = false end
            end
        end
    end)
    table.insert(activeConnections, conn)

    local start = tick()
    local duration = 1.5

    while tick() - start < duration do
        if not targetChar or not targetChar.Parent or not tRoot or not tRoot.Parent or tHum.Health <= 0 then break end
        if not myChar or not myChar.Parent or not myRoot or not myRoot.Parent or myHum.Health <= 0 then break end

        if Config.FlingStyle == "Velocity" then
            myRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(0, 1.2, 0))
            myRoot.AssemblyLinearVelocity = Vector3.new(0, 9e9, 0)
            myRoot.AssemblyAngularVelocity = Vector3.new(9e9, 9e9, 9e9)
        elseif Config.FlingStyle == "Orbit" then
            local angle = (tick() - start) * 20
            local off = Vector3.new(math.cos(angle) * 1.5, 0.5, math.sin(angle) * 1.5)
            myRoot.CFrame = CFrame.new(tRoot.Position + off, tRoot.Position)
            myRoot.AssemblyLinearVelocity = Vector3.new(9e9, 9e9, 9e9)
            myRoot.AssemblyAngularVelocity = Vector3.new(9e9, 9e9, 9e9)
        else
            myRoot.CFrame = tRoot.CFrame
            myRoot.AssemblyLinearVelocity = Vector3.new(9e9, 9e9, 9e9)
            myRoot.AssemblyAngularVelocity = Vector3.new(9e9, 9e9, 9e9)
        end
        RunService.Heartbeat:Wait()
    end

    pcall(function() conn:Disconnect() end)
    pcall(function() bAV:Destroy() end)
    pcall(function() bV:Destroy() end)

    if myRoot and myRoot.Parent then
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.AssemblyAngularVelocity = Vector3.zero
        myRoot.CFrame = oldCF
    end
    task.wait(0.15)
    State.IsFlinging = false
end

local function flingByRole(role)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isAlive(p) and getRole(p) == role then
            task.spawn(flingCharacter, p.Character)
            task.wait(0.1)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if State.RoundState ~= "Active" then
            if Config.FlingMurdererPreRound then flingByRole("Murderer") end
            if Config.FlingSheriffPreRound then flingByRole("Sheriff") end
            if Config.FlingHeroPreRound then flingByRole("Innocent") end
            if Config.FlingAllPreRound then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character and isAlive(p) then
                        task.spawn(flingCharacter, p.Character)
                        task.wait(0.1)
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- AURA RING / FOV / GUN TRACKER
-- ============================================================
local function updateAuraRing(myRoot)
    if not Config.ShowAuraRing or not myRoot then
        if State.AuraRing then
            State.AuraRing.Transparency = 1
            State.AuraRing.Parent = nil
        end
        return
    end
    local diameter = Config.AuraRange * 2
    if not State.AuraRing or not State.AuraRing.Parent then
        local p = Instance.new("Part")
        p.Name = "Riad_AuraRing"
        p.Anchored = true
        p.CanCollide = false
        p.CastShadow = false
        p.Transparency = 1
        p.Size = Vector3.new(diameter, 0.01, diameter)
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top
        sg.AlwaysOnTop = true
        sg.LightInfluence = 0
        sg.Adornee = p
        sg.Parent = p
        local fr = Instance.new("Frame")
        fr.Size = UDim2.new(1, 0, 1, 0)
        fr.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
        fr.BackgroundTransparency = 0.92
        fr.BorderSizePixel = 0
        fr.Parent = sg
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = fr
        local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(80, 220, 120) s.Thickness = 2.5 s.Transparency = 0.1 s.Parent = fr
        p.Parent = Workspace
        State.AuraRing = p
    end
    State.AuraRing.Size = Vector3.new(diameter, 0.01, diameter)
    State.AuraRing.CFrame = CFrame.new(myRoot.Position.X, myRoot.Position.Y - 2.85, myRoot.Position.Z)
end

if Drawing and Drawing.new then
    pcall(function()
        State.FOVCircle = Drawing.new("Circle")
        State.FOVCircle.Thickness = 1.5
        State.FOVCircle.Color = Color3.fromRGB(80, 220, 120)
        State.FOVCircle.Filled = false
        State.FOVCircle.Transparency = 0.8
        State.FOVCircle.Visible = false
    end)
end

local function updateFOVCircle()
    if not State.FOVCircle then return end
    if Config.ShowFOV then
        State.FOVCircle.Visible = true
        State.FOVCircle.Radius = Config.FOVRadius
        State.FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        State.FOVCircle.Visible = false
    end
end

-- Gun tracker Drawing objects
local gunTrackerBox, gunTrackerText
if Drawing and Drawing.new then
    pcall(function()
        gunTrackerBox = Drawing.new("Square")
        gunTrackerBox.Thickness = 1.5
        gunTrackerBox.Color = Color3.fromRGB(255, 220, 60)
        gunTrackerBox.Filled = false
        gunTrackerBox.Transparency = 0.8
        gunTrackerBox.Visible = false

        gunTrackerText = Drawing.new("Text")
        gunTrackerText.Size = 14
        gunTrackerText.Center = true
        gunTrackerText.Outline = true
        gunTrackerText.OutlineColor = Color3.new(0, 0, 0)
        gunTrackerText.Color = Color3.fromRGB(255, 220, 60)
        gunTrackerText.Visible = false
    end)
end

local function updateGunTracker()
    if not gunTrackerBox or not gunTrackerText then return end
    if not Config.GunTracker then
        gunTrackerBox.Visible = false
        gunTrackerText.Visible = false
        return
    end
    local gd = getGunDrop()
    local gp = getGunDropPart(gd)
    if not gp then
        gunTrackerBox.Visible = false
        gunTrackerText.Visible = false
        return
    end
    local sp, onScreen = Camera:WorldToViewportPoint(gp.Position)
    if onScreen then
        local myRoot = getHRP(LP)
        local dist = myRoot and math.floor((myRoot.Position - gp.Position).Magnitude) or 0
        gunTrackerBox.Size = Vector2.new(40, 40)
        gunTrackerBox.Position = Vector2.new(sp.X - 20, sp.Y - 20)
        gunTrackerBox.Visible = true
        gunTrackerText.Text = "GUN (" .. dist .. ")"
        gunTrackerText.Position = Vector2.new(sp.X, sp.Y - 30)
        gunTrackerText.Visible = true
    else
        gunTrackerBox.Visible = false
        gunTrackerText.Visible = false
    end
end

-- ============================================================
-- SILENT AIM HOOK (with magic bullet)
-- ============================================================
if hookmetamethod and getnamecallmethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if State.SilentAimHookActive and not checkcaller() and method == "FireServer" then
            if self.Name == "KnifeThrown" and (Config.KnifeSilentAim or Config.SilentAim) then
                local args = {...}
                local tgt = nearestTarget()
                if tgt then
                    local tRoot = getHRP(tgt)
                    if tRoot then
                        local pos = tRoot.Position
                        if Config.AimPrediction then
                            local lead = Config.PingComp and 0.16 or 0.12
                            pos = pos + (tRoot.AssemblyLinearVelocity * lead)
                        end
                        args[2] = CFrame.new(pos)
                        if setnamecallmethod then setnamecallmethod("FireServer") end
                        return oldNamecall(self, unpack(args))
                    end
                end
            elseif self.Name == "Shoot" and Config.SilentAim then
                local args = {...}
                local m = select(1, getRolePlayers())
                if m then
                    local mRoot = getHRP(m)
                    if mRoot then
                        local pos = mRoot.Position
                        if Config.AimPrediction then
                            local lead = Config.PingComp and 0.16 or 0.12
                            pos = pos + (mRoot.AssemblyLinearVelocity * lead)
                        end
                        args[2] = CFrame.new(pos)
                        if setnamecallmethod then setnamecallmethod("FireServer") end
                        return oldNamecall(self, unpack(args))
                    end
                end
            end
        end
        if setnamecallmethod then setnamecallmethod(method) end
        return oldNamecall(self, ...)
    end))
end

-- ============================================================
-- ESP BUILDERS
-- ============================================================
local function getOrCreateBillboard(id, adornee, text, color)
    local bb = State.Highlights[id]
    if not bb or not bb.Parent then
        bb = Instance.new("BillboardGui")
        bb.Name = id
        bb.Size = UDim2.new(0, 160, 0, 44)
        bb.StudsOffset = Vector3.new(0, 2.8, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = Config.ESPDistanceMax
        bb.Adornee = adornee
        bb.Parent = espFolder
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Tag"
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextColor3 = color
        lbl.TextStrokeTransparency = 0.3
        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        lbl.Parent = bb
        State.Highlights[id] = bb
    end
    bb.Adornee = adornee
    bb.MaxDistance = Config.ESPDistanceMax
    local tag = bb:FindFirstChild("Tag")
    if tag then tag.Text = text tag.TextColor3 = color end
    return bb
end

local function getOrCreateBox(id, adornee, color)
    local box = State.Boxes[id]
    if not box or not box.Parent then
        box = Instance.new("BoxHandleAdornment")
        box.Name = "box_" .. id
        box.Adornee = adornee
        box.AlwaysOnTop = true
        box.ZIndex = 5
        box.Size = Vector3.new(3.5, 6.2, 3.5)
        box.Transparency = 0.6
        box.Parent = espFolder
        State.Boxes[id] = box
    end
    box.Adornee = adornee
    box.Color3 = color
    return box
end

local function getOrCreateCham(id, char, color)
    local hl = State.Highlights["cham_" .. id]
    if not hl or not hl.Parent then
        hl = Instance.new("Highlight")
        hl.Name = "cham_" .. id
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(243, 240, 255)
        hl.FillTransparency = 0.45
        hl.OutlineTransparency = 0.1
        hl.Adornee = char
        hl.Parent = espFolder
        State.Highlights["cham_" .. id] = hl
    end
    hl.Adornee = char
    hl.FillColor = color
    return hl
end

local function updateTracer(id, targetPos, color)
    if not Drawing or not Drawing.new then return end
    local line = State.Tracers[id]
    if not line then
        pcall(function()
            line = Drawing.new("Line")
            line.Thickness = 1.5
            line.Transparency = 0.85
            line.Color = color
            State.Tracers[id] = line
        end)
        line = State.Tracers[id]
    end
    if not line then return end
    if Config.ESPTracers then
        local targetFeet = targetPos - Vector3.new(0, 2.5, 0)
        local sp, onScreen = Camera:WorldToViewportPoint(targetFeet)
        if onScreen then
            local myRoot = getHRP(LP)
            local fromPos
            if myRoot then
                local feet = myRoot.Position - Vector3.new(0, 2.8, 0)
                local ms, mos = Camera:WorldToViewportPoint(feet)
                if mos then fromPos = Vector2.new(ms.X, ms.Y) end
            end
            if not fromPos then fromPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y) end
            line.From = fromPos
            line.To = Vector2.new(sp.X, sp.Y)
            line.Color = color
            line.Visible = true
        else
            line.Visible = false
        end
    else
        line.Visible = false
    end
end

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Library:CreateWindow({
    Title = "Riad Hub",
    Footer = "MM2",
    Icon = "sparkles",
    Size = UDim2.fromOffset(780, 560),
    Center = true,
    AutoShow = true,
    Resizable = true,
    Glow = true,
    GlobalSearch = true,
    ToggleKeybind = Enum.KeyCode.RightControl,
    ShowMobileButtons = true,
    MobileButtonsSide = "Left",
    MobileButtonDragging = true,
    ScreenEffects = false,
    GuiEffects = false,
})

-- ============================================================
-- HOME
-- ============================================================
local Home = Window:AddTab({
    Name = "Home",
    Icon = "house",
    Description = "Welcome to Riad Hub",
})

local WelcomeBox = Home:AddLeftGroupbox("Welcome", "sparkles")
WelcomeBox:AddLabel("Riad Hub — all systems live.")
WelcomeBox:AddLabel("Themes, effects, watermark, and configs live in Settings.")
WelcomeBox:AddDivider()
WelcomeBox:AddButton("Test Notification", function()
    Library:Notify({ Title = "Riad Hub", Description = "Notifications working.", Time = 3 })
end)
WelcomeBox:AddButton("Unload Hub", function()
    if getgenv().RiadHub_Unload then getgenv().RiadHub_Unload() end
end)

local QuickBox = Home:AddRightGroupbox("Quick Actions", "zap")
QuickBox:AddButton("Teleport to Murderer", function()
    local m = select(1, getRolePlayers())
    local myRoot = getHRP(LP)
    if m and myRoot then
        local mr = getHRP(m)
        if mr then
            myRoot.CFrame = mr.CFrame * CFrame.new(0, 0, 4)
            Library:Notify({ Title = "Riad Hub", Description = "Teleported to " .. m.Name, Time = 2 })
        end
    else
        Library:Notify({ Title = "Riad Hub", Description = "Murderer not found.", Time = 2 })
    end
end)
QuickBox:AddButton("Teleport to Sheriff", function()
    local _, s = getRolePlayers()
    local myRoot = getHRP(LP)
    if s and myRoot then
        local sr = getHRP(s)
        if sr then
            myRoot.CFrame = sr.CFrame * CFrame.new(0, 0, 4)
            Library:Notify({ Title = "Riad Hub", Description = "Teleported to " .. s.Name, Time = 2 })
        end
    else
        Library:Notify({ Title = "Riad Hub", Description = "Sheriff not found.", Time = 2 })
    end
end)
QuickBox:AddButton("Teleport to Hero", function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isAlive(p) then
            local bp = p:FindFirstChild("Backpack")
            local ch = p.Character
            local heroTool = (bp and bp:FindFirstChild("Hero")) or (ch and ch:FindFirstChild("Hero"))
            if heroTool then
                local myRoot = getHRP(LP)
                local pr = getHRP(p)
                if myRoot and pr then
                    myRoot.CFrame = pr.CFrame * CFrame.new(0, 0, 4)
                    Library:Notify({ Title = "Riad Hub", Description = "Teleported to Hero: " .. p.Name, Time = 2 })
                end
                return
            end
        end
    end
    Library:Notify({ Title = "Riad Hub", Description = "Hero not found.", Time = 2 })
end)
QuickBox:AddButton("Teleport to Dropped Gun", function()
    local gd = getGunDrop()
    local gp = getGunDropPart(gd)
    local myRoot = getHRP(LP)
    if gp and myRoot then
        myRoot.CFrame = gp.CFrame * CFrame.new(0, 3, 0)
        Library:Notify({ Title = "Riad Hub", Description = "Teleported to gun.", Time = 2 })
    else
        Library:Notify({ Title = "Riad Hub", Description = "No gun on map.", Time = 2 })
    end
end)
QuickBox:AddButton("Reset Character", function()
    local h = getHumanoid(LP)
    if h then h.Health = 0 end
end)
QuickBox:AddButton("Announce Roles", function()
    local m, s = getRolePlayers()
    local msg = "[Riad] Murderer: " .. (m and m.Name or "?") .. " | Sheriff: " .. (s and s.Name or "?")
    local ch = TextChatService:FindFirstChild("TextChannels")
    local ch2 = ch and ch:FindFirstChild("RBXGeneral")
    if ch2 and ch2.SendAsync then ch2:SendAsync(msg) end
    Library:Notify({ Title = "Riad Hub", Description = "Announced roles.", Time = 2 })
    SendWebhook("Roles Announced", msg)
end)

-- ============================================================
-- VISUAL TAB
-- ============================================================
local VisualTab = Window:AddTab({
    Name = "Visuals",
    Icon = "eye",
    Description = "ESP and world visuals",
})

local ESPBox = VisualTab:AddLeftGroupbox("Role ESP", "eye")
ESPBox:AddToggle("RoleESP", {
    Text = "Role ESP", Default = false,
    Callback = function(v) Config.RoleESP = v AutoSaveConfig() end,
})
ESPBox:AddToggle("ESPChams", {
    Text = "ESP Chams", Default = false,
    Callback = function(v) Config.ESPChams = v if not v then clearCategory(State.Highlights) end AutoSaveConfig() end,
})
ESPBox:AddToggle("ESPBoxes", {
    Text = "ESP Boxes", Default = false,
    Callback = function(v) Config.ESPBoxes = v if not v then clearCategory(State.Boxes) end AutoSaveConfig() end,
})
ESPBox:AddToggle("ESPNames", {
    Text = "ESP Names", Default = true,
    Callback = function(v) Config.ESPNames = v AutoSaveConfig() end,
})
ESPBox:AddToggle("ESPDistance", {
    Text = "ESP Distance", Default = true,
    Callback = function(v) Config.ESPDistance = v AutoSaveConfig() end,
})
ESPBox:AddToggle("ESPTracers", {
    Text = "ESP Tracers", Default = false,
    Callback = function(v) Config.ESPTracers = v AutoSaveConfig() end,
})
ESPBox:AddSlider("ESPDistanceMax", {
    Text = "ESP Max Distance",
    Default = 600, Min = 50, Max = 2000, Rounding = 0, Suffix = " studs",
    Callback = function(v) Config.ESPDistanceMax = v AutoSaveConfig() end,
})

local WorldBox = VisualTab:AddRightGroupbox("World", "globe")
WorldBox:AddToggle("GunESP", {
    Text = "Dropped Gun ESP", Default = false,
    Callback = function(v) Config.GunESP = v if not v then clearCategory(State.ItemHighlights) end AutoSaveConfig() end,
})
WorldBox:AddToggle("GunTracker", {
    Text = "Gun Tracker", Default = false,
    Callback = function(v) Config.GunTracker = v AutoSaveConfig() end,
})
WorldBox:AddToggle("CoinESP", {
    Text = "Coin ESP", Default = false,
    Callback = function(v) Config.CoinESP = v if not v then clearCategory(State.ItemHighlights) end AutoSaveConfig() end,
})
WorldBox:AddToggle("PlayerStats", {
    Text = "Player Stats", Default = false,
    Callback = function(v) Config.PlayerStats = v AutoSaveConfig() end,
})
WorldBox:AddToggle("Fullbright", {
    Text = "Fullbright", Default = false,
    Callback = function(v) Config.Fullbright = v AutoSaveConfig() end,
})
WorldBox:AddToggle("NoFog", {
    Text = "No Fog", Default = false,
    Callback = function(v) Config.NoFog = v AutoSaveConfig() end,
})
WorldBox:AddToggle("DisableParticles", {
    Text = "Disable Particles", Default = false,
    Callback = function(v)
        Config.DisableParticles = v
        if v then
            task.spawn(function()
                for _, d in ipairs(Workspace:GetDescendants()) do
                    if d:IsA("ParticleEmitter") then d.Enabled = false end
                end
            end)
        end
        AutoSaveConfig()
    end,
})
WorldBox:AddToggle("FPSBooster", {
    Text = "FPS Booster", Default = false,
    Callback = function(v)
        Config.FPSBooster = v
        if v then
            pcall(function() Lighting.GlobalShadows = false end)
            pcall(function() Lighting.FogEnd = 1e6 end)
            pcall(function() Settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        else
            pcall(function() Settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        end
        AutoSaveConfig()
    end,
})

-- ============================================================
-- COMBAT TAB
-- ============================================================
local CombatTab = Window:AddTab({
    Name = "Combat",
    Icon = "sword",
    Description = "Aim, shoot, stab",
})

local GunBox = CombatTab:AddLeftGroupbox("Gun · Sheriff", "crosshair")
GunBox:AddToggle("Aimbot", {
    Text = "Aimbot", Default = false,
    Callback = function(v) Config.Aimbot = v AutoSaveConfig() end,
})
GunBox:AddToggle("AutoShoot", {
    Text = "Auto-Shoot", Default = false,
    Callback = function(v) Config.AutoShoot = v AutoSaveConfig() end,
})
GunBox:AddToggle("SilentAim", {
    Text = "Silent Aim", Default = false,
    Callback = function(v) Config.SilentAim = v AutoSaveConfig() end,
})
GunBox:AddToggle("AimPrediction", {
    Text = "Aim Prediction", Default = true,
    Callback = function(v) Config.AimPrediction = v AutoSaveConfig() end,
})
GunBox:AddToggle("PingComp", {
    Text = "Ping Compensation", Default = true,
    Callback = function(v) Config.PingComp = v AutoSaveConfig() end,
})
GunBox:AddToggle("FocusMode", {
    Text = "Focus Mode", Default = false,
    Callback = function(v) Config.FocusMode = v AutoSaveConfig() end,
})
GunBox:AddToggle("TeamCheck", {
    Text = "Team Check", Default = false,
    Callback = function(v) Config.TeamCheck = v AutoSaveConfig() end,
})
GunBox:AddToggle("MagicBullet", {
    Text = "Magic Bullet", Default = false,
    Callback = function(v) Config.MagicBullet = v AutoSaveConfig() end,
})
GunBox:AddToggle("SingleShot", {
    Text = "Single Shot Lock", Default = false,
    Callback = function(v) Config.SingleShot = v AutoSaveConfig() end,
})
GunBox:AddToggle("AutoEquipGun", {
    Text = "Auto Equip Gun", Default = true,
    Callback = function(v) Config.AutoEquipGun = v AutoSaveConfig() end,
})
GunBox:AddToggle("GrabGunAuto", {
    Text = "Full Gun Grabber", Default = false,
    Callback = function(v) Config.GrabGunAuto = v AutoSaveConfig() end,
})
GunBox:AddSlider("GunGrabDist", {
    Text = "Gun Grab Distance",
    Default = 300, Min = 20, Max = 800, Rounding = 0, Suffix = " studs",
    Callback = function(v) Config.GunGrabDist = v AutoSaveConfig() end,
})
GunBox:AddSlider("GunCollectReach", {
    Text = "Gun Collect Reach",
    Default = 10, Min = 1, Max = 30, Rounding = 0, Suffix = " studs",
    Callback = function(v) Config.GunCollectReach = v AutoSaveConfig() end,
})
GunBox:AddToggle("AutoTPGun", {
    Text = "Auto Teleport to Gun", Default = false,
    Callback = function(v) Config.AutoTPGun = v AutoSaveConfig() end,
})
GunBox:AddButton("Pick Up Gun Once", function()
    local gd = getGunDrop()
    local gp = getGunDropPart(gd)
    if gp then
        interactWithGunDrop(gp, gd)
        Library:Notify({ Title = "Riad Hub", Description = "Attempted gun pickup.", Time = 2 })
    else
        Library:Notify({ Title = "Riad Hub", Description = "No gun on map.", Time = 2 })
    end
end)
GunBox:AddButton("Shoot Murderer Once", function()
    local m = select(1, getRolePlayers())
    if m and isAlive(m) then
        local gun = equipTool("Gun")
        if gun and gun:FindFirstChild("Shoot") then
            local myRoot = getHRP(LP)
            local mRoot = getHRP(m)
            if myRoot and mRoot then
                gun.Shoot:FireServer(myRoot.CFrame, CFrame.new(mRoot.Position))
                Library:Notify({ Title = "Riad Hub", Description = "Fired once at " .. m.Name, Time = 2 })
            end
        end
    end
end)
GunBox:AddToggle("ShowFOV", {
    Text = "Show FOV Circle", Default = false,
    Callback = function(v) Config.ShowFOV = v AutoSaveConfig() end,
})
GunBox:AddSlider("FOVRadius", {
    Text = "FOV Radius",
    Default = 160, Min = 50, Max = 700, Rounding = 0,
    Callback = function(v) Config.FOVRadius = v AutoSaveConfig() end,
})
GunBox:AddSlider("AimFOV", {
    Text = "Aim FOV",
    Default = 200, Min = 50, Max = 700, Rounding = 0,
    Callback = function(v) Config.AimFOV = v AutoSaveConfig() end,
})

local KnifeBox = CombatTab:AddLeftGroupbox("Knife · Murderer", "sword")
KnifeBox:AddToggle("AutoStab", {
    Text = "Auto-Stab", Default = false,
    Callback = function(v) Config.AutoStab = v AutoSaveConfig() end,
})
KnifeBox:AddToggle("KillAura", {
    Text = "Kill Aura", Default = false,
    Callback = function(v) Config.KillAura = v AutoSaveConfig() end,
})
KnifeBox:AddToggle("AutoKill", {
    Text = "Auto Kill Innocents", Default = false,
    Callback = function(v) Config.AutoKill = v AutoSaveConfig() end,
})
KnifeBox:AddToggle("AutoKillMurderer", {
    Text = "Auto Kill Murderer", Default = false,
    Callback = function(v) Config.AutoKillMurderer = v AutoSaveConfig() end,
})
KnifeBox:AddToggle("AutoKillSheriff", {
    Text = "Auto Kill Sheriff", Default = false,
    Callback = function(v) Config.AutoKillSheriff = v AutoSaveConfig() end,
})
KnifeBox:AddToggle("DodgeKnife", {
    Text = "Dodge Knife", Default = false,
    Callback = function(v) Config.DodgeKnife = v AutoSaveConfig() end,
})
KnifeBox:AddToggle("KillAll", {
    Text = "Kill All", Default = false,
    Callback = function(v) Config.KillAll = v AutoSaveConfig() end,
})
KnifeBox:AddDropdown("KillMode", {
    Text = "Kill Mode",
    Values = { "Legit", "Blatant", "Throw" },
    Default = "Legit",
    Callback = function(v) Config.KillMode = v AutoSaveConfig() end,
})
KnifeBox:AddToggle("KnifeSilentAim", {
    Text = "Knife Silent Aim", Default = true,
    Callback = function(v) Config.KnifeSilentAim = v AutoSaveConfig() end,
})
KnifeBox:AddSlider("AuraRange", {
    Text = "Aura Range",
    Default = 15, Min = 5, Max = 45, Rounding = 0, Suffix = " studs",
    Callback = function(v) Config.AuraRange = v AutoSaveConfig() end,
})
KnifeBox:AddToggle("ShowAuraRing", {
    Text = "Show Aura Ring", Default = false,
    Callback = function(v) Config.ShowAuraRing = v AutoSaveConfig() end,
})
KnifeBox:AddToggle("AutoEquipKnife", {
    Text = "Auto Equip Knife", Default = true,
    Callback = function(v) Config.AutoEquipKnife = v AutoSaveConfig() end,
})
KnifeBox:AddButton("Kill All (Murderer Only)", function()
    local knife = equipTool("Knife")
    if not knife then
        Library:Notify({ Title = "Riad Hub", Description = "You need the knife equipped.", Time = 3 })
        return
    end
    local myHRP = getHRP(LP)
    if not myHRP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isAlive(p) then
            local hrp = getHRP(p)
            if hrp then
                myHRP.CFrame = hrp.CFrame
                task.wait(0.05)
                knife:Activate()
                task.wait(0.05)
            end
        end
    end
end)

local HitboxBox = CombatTab:AddRightGroupbox("Hitbox / Godmode", "square")
HitboxBox:AddToggle("HitboxExpander", {
    Text = "Hitbox Expander", Default = false,
    Callback = function(v)
        Config.HitboxExpander = v
        if not v then
            for part, sz in pairs(State.OriginalHitboxSizes) do
                if part and part.Parent then
                    part.Size = sz
                    part.Transparency = 1
                end
            end
            State.OriginalHitboxSizes = {}
        end
        AutoSaveConfig()
    end,
})
HitboxBox:AddSlider("HitboxSize", {
    Text = "Hitbox Size",
    Default = 10, Min = 4, Max = 30, Rounding = 0, Suffix = " studs",
    Callback = function(v) Config.HitboxSize = v AutoSaveConfig() end,
})
HitboxBox:AddSlider("HitboxTransparency", {
    Text = "Hitbox Transparency",
    Default = 60, Min = 0, Max = 100, Rounding = 0,
    Callback = function(v) Config.HitboxTransparency = v / 100 AutoSaveConfig() end,
})
HitboxBox:AddToggle("GodMode", {
    Text = "God Mode", Default = false,
    Callback = function(v)
        Config.GodMode = v
        if v then
            task.spawn(function()
                while Config.GodMode do
                    task.wait(0.1)
                    local h = getHumanoid(LP)
                    if h then h.MaxHealth = math.huge h.Health = math.huge end
                end
            end)
        else
            local h = getHumanoid(LP)
            if h then h.MaxHealth = 100 h.Health = 100 end
        end
        AutoSaveConfig()
    end,
})

-- ============================================================
-- MOVEMENT TAB
-- ============================================================
local MoveTab = Window:AddTab({
    Name = "Movement",
    Icon = "move",
    Description = "Speed, fly, noclip",
})

local CharBox = MoveTab:AddLeftGroupbox("Character", "user")
CharBox:AddToggle("Speed", {
    Text = "Speed Boost", Default = false,
    Callback = function(v) Config.Speed = v AutoSaveConfig() end,
})
CharBox:AddSlider("SpeedValue", {
    Text = "Walk Speed",
    Default = 24, Min = 16, Max = 60, Rounding = 0,
    Callback = function(v) Config.SpeedValue = v AutoSaveConfig() end,
})
CharBox:AddToggle("JumpEnabled", {
    Text = "Jump Boost", Default = false,
    Callback = function(v) Config.JumpEnabled = v AutoSaveConfig() end,
})
CharBox:AddSlider("JumpValue", {
    Text = "Jump Power",
    Default = 50, Min = 50, Max = 150, Rounding = 0,
    Callback = function(v) Config.JumpValue = v AutoSaveConfig() end,
})
CharBox:AddToggle("InfiniteJump", {
    Text = "Infinite Jump", Default = false,
    Callback = function(v) Config.InfiniteJump = v AutoSaveConfig() end,
})
CharBox:AddToggle("Noclip", {
    Text = "Noclip", Default = false,
    Callback = function(v) Config.Noclip = v AutoSaveConfig() end,
})
CharBox:AddToggle("Fly", {
    Text = "Fly", Default = false,
    Callback = function(v)
        Config.Fly = v
        if v then
            local myRoot = getHRP(LP)
            if myRoot and not State.flyBV then
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Velocity = Vector3.zero
                bv.Parent = myRoot
                State.flyBV = bv
            end
        else
            if State.flyBV then State.flyBV:Destroy() State.flyBV = nil end
        end
        AutoSaveConfig()
    end,
})
CharBox:AddSlider("FlySpeed", {
    Text = "Fly Speed",
    Default = 35, Min = 15, Max = 150, Rounding = 0, Suffix = " studs/s",
    Callback = function(v) Config.FlySpeed = v AutoSaveConfig() end,
})

local SafeBox = MoveTab:AddRightGroupbox("Safety", "shield")
SafeBox:AddToggle("AntiRagdoll", {
    Text = "Anti-Ragdoll", Default = false,
    Callback = function(v) Config.AntiRagdoll = v AutoSaveConfig() end,
})
SafeBox:AddToggle("AntiFling", {
    Text = "Anti-Fling", Default = true,
    Callback = function(v) Config.AntiFling = v AutoSaveConfig() end,
})
SafeBox:AddToggle("AntiVoid", {
    Text = "Anti-Void", Default = true,
    Callback = function(v) Config.AntiVoid = v AutoSaveConfig() end,
})

-- ============================================================
-- FARM TAB
-- ============================================================
local FarmTab = Window:AddTab({
    Name = "Farm",
    Icon = "coins",
    Description = "Auto-farm coins",
})

local FarmBox = FarmTab:AddLeftGroupbox("Coin Farm", "coins")
FarmBox:AddToggle("CoinFarm", {
    Text = "Auto Farm Coins", Default = false,
    Callback = function(v) Config.CoinFarm = v AutoSaveConfig() end,
})
FarmBox:AddDropdown("FarmMethod", {
    Text = "Farm Method",
    Values = { "Teleport", "Glide", "Tween", "Walk" },
    Default = "Teleport",
    Callback = function(v) Config.FarmMethod = v AutoSaveConfig() end,
})
FarmBox:AddSlider("FarmSpeed", {
    Text = "Farm Speed",
    Default = 28, Min = 16, Max = 60, Rounding = 0,
    Callback = function(v) Config.FarmSpeed = v AutoSaveConfig() end,
})
FarmBox:AddSlider("TeleportFarmDelay", {
    Text = "Teleport Farm Delay (x0.01s)",
    Default = 5, Min = 1, Max = 50, Rounding = 0,
    Callback = function(v) Config.TeleportFarmDelay = v / 100 AutoSaveConfig() end,
})
FarmBox:AddToggle("SafeCoinFarm", {
    Text = "Safe Farming", Default = true,
    Callback = function(v) Config.SafeCoinFarm = v AutoSaveConfig() end,
})
FarmBox:AddToggle("BagFullStop", {
    Text = "Bag Full Stop", Default = true,
    Callback = function(v) Config.BagFullStop = v AutoSaveConfig() end,
})
FarmBox:AddToggle("QuickFarm", {
    Text = "Quick Mode", Default = false,
    Callback = function(v) Config.QuickFarm = v AutoSaveConfig() end,
})
FarmBox:AddSlider("CoinBagCap", {
    Text = "Coin Bag Cap",
    Default = 40, Min = 10, Max = 40, Rounding = 0,
    Callback = function(v) Config.CoinBagCap = v AutoSaveConfig() end,
})

-- ============================================================
-- SURVIVAL TAB
-- ============================================================
local SurvTab = Window:AddTab({
    Name = "Survival",
    Icon = "shield",
    Description = "Avoid the murderer",
})

local SurvBox = SurvTab:AddLeftGroupbox("Avoidance", "shield")
SurvBox:AddToggle("MurdererAvoid", {
    Text = "Murderer Avoidance", Default = false,
    Callback = function(v) Config.MurdererAvoid = v AutoSaveConfig() end,
})
SurvBox:AddSlider("SafetyRadius", {
    Text = "Safety Radius",
    Default = 40, Min = 20, Max = 80, Rounding = 0, Suffix = " studs",
    Callback = function(v) Config.SafetyRadius = v AutoSaveConfig() end,
})
SurvBox:AddToggle("RetreatToLobby", {
    Text = "Retreat to Lobby", Default = false,
    Callback = function(v) Config.RetreatToLobby = v AutoSaveConfig() end,
})
SurvBox:AddToggle("ProximityAlert", {
    Text = "Proximity Alert", Default = true,
    Callback = function(v) Config.ProximityAlert = v AutoSaveConfig() end,
})
SurvBox:AddToggle("SprintWhenChased", {
    Text = "Sprint When Chased", Default = true,
    Callback = function(v) Config.SprintWhenChased = v AutoSaveConfig() end,
})
SurvBox:AddToggle("FollowMurderer", {
    Text = "Follow Murderer", Default = false,
    Callback = function(v) Config.FollowMurderer = v AutoSaveConfig() end,
})
SurvBox:AddSlider("FollowDist", {
    Text = "Follow Distance",
    Default = 18, Min = 8, Max = 40, Rounding = 0, Suffix = " studs",
    Callback = function(v) Config.FollowDist = v AutoSaveConfig() end,
})
SurvBox:AddToggle("AutoPlay", {
    Text = "Role-Based Auto Play", Default = false,
    Callback = function(v) Config.AutoPlay = v AutoSaveConfig() end,
})

-- ============================================================
-- TELEPORTS TAB
-- ============================================================
local TPTab = Window:AddTab({
    Name = "Teleports",
    Icon = "map-pin",
    Description = "Fast travel",
})

local QuickTP = TPTab:AddLeftGroupbox("Quick Teleports", "zap")
QuickTP:AddButton("Teleport to Murderer", function()
    local m = select(1, getRolePlayers())
    local myRoot = getHRP(LP)
    if m and myRoot then
        local mr = getHRP(m)
        if mr then
            myRoot.CFrame = mr.CFrame * CFrame.new(0, 0, 4)
            Library:Notify({ Title = "Riad Hub", Description = "Teleported to " .. m.Name, Time = 2 })
        end
    else
        Library:Notify({ Title = "Riad Hub", Description = "Murderer not found.", Time = 2 })
    end
end)
QuickTP:AddButton("Teleport to Sheriff", function()
    local _, s = getRolePlayers()
    local myRoot = getHRP(LP)
    if s and myRoot then
        local sr = getHRP(s)
        if sr then
            myRoot.CFrame = sr.CFrame * CFrame.new(0, 0, 4)
            Library:Notify({ Title = "Riad Hub", Description = "Teleported to " .. s.Name, Time = 2 })
        end
    else
        Library:Notify({ Title = "Riad Hub", Description = "Sheriff not found.", Time = 2 })
    end
end)
QuickTP:AddButton("Teleport to Hero", function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isAlive(p) then
            local bp = p:FindFirstChild("Backpack")
            local ch = p.Character
            local heroTool = (bp and bp:FindFirstChild("Hero")) or (ch and ch:FindFirstChild("Hero"))
            if heroTool then
                local myRoot = getHRP(LP)
                local pr = getHRP(p)
                if myRoot and pr then
                    myRoot.CFrame = pr.CFrame * CFrame.new(0, 0, 4)
                    Library:Notify({ Title = "Riad Hub", Description = "Teleported to Hero: " .. p.Name, Time = 2 })
                end
                return
            end
        end
    end
    Library:Notify({ Title = "Riad Hub", Description = "Hero not found.", Time = 2 })
end)
QuickTP:AddButton("Teleport to Active Map", function()
    local map = getActiveMap()
    local myRoot = getHRP(LP)
    if map and myRoot then
        local sp = map:FindFirstChild("Spawns")
        if sp and #sp:GetChildren() > 0 then
            myRoot.CFrame = sp:GetChildren()[1].CFrame * CFrame.new(0, 3, 0)
        end
        Library:Notify({ Title = "Riad Hub", Description = "Teleported to " .. map.Name, Time = 2 })
    else
        Library:Notify({ Title = "Riad Hub", Description = "No active map.", Time = 2 })
    end
end)
QuickTP:AddButton("Teleport to Lobby", function()
    local lb = getLobbyModel()
    local myRoot = getHRP(LP)
    if lb and myRoot then
        local p = lb:FindFirstChildWhichIsA("BasePart")
        if p then myRoot.CFrame = p.CFrame * CFrame.new(0, 3, 0) end
        Library:Notify({ Title = "Riad Hub", Description = "Teleported to Lobby", Time = 2 })
    end
end)
QuickTP:AddButton("Teleport to Dropped Gun", function()
    local gd = getGunDrop()
    local gp = getGunDropPart(gd)
    local myRoot = getHRP(LP)
    if gp and myRoot then
        myRoot.CFrame = gp.CFrame * CFrame.new(0, 3, 0)
        Library:Notify({ Title = "Riad Hub", Description = "Teleported to gun.", Time = 2 })
    else
        Library:Notify({ Title = "Riad Hub", Description = "No gun on map.", Time = 2 })
    end
end)
QuickTP:AddToggle("AutoDrop", {
    Text = "Auto Drop at Round Start", Default = false,
    Callback = function(v) Config.AutoDrop = v AutoSaveConfig() end,
})

local SlotBox = TPTab:AddRightGroupbox("Saved Slots", "bookmark")
SlotBox:AddButton("Save Slot 1", function()
    local myRoot = getHRP(LP)
    if myRoot then
        Config.SaveSlot1 = myRoot.CFrame
        AutoSaveConfig()
        Library:Notify({ Title = "Riad Hub", Description = "Slot 1 saved.", Time = 2 })
    end
end)
SlotBox:AddButton("Go To Slot 1", function()
    local myRoot = getHRP(LP)
    if myRoot and Config.SaveSlot1 then
        myRoot.CFrame = Config.SaveSlot1
        Library:Notify({ Title = "Riad Hub", Description = "To Slot 1.", Time = 2 })
    else
        Library:Notify({ Title = "Riad Hub", Description = "No Slot 1 saved.", Time = 2 })
    end
end)
SlotBox:AddButton("Save Slot 2", function()
    local myRoot = getHRP(LP)
    if myRoot then
        Config.SaveSlot2 = myRoot.CFrame
        AutoSaveConfig()
        Library:Notify({ Title = "Riad Hub", Description = "Slot 2 saved.", Time = 2 })
    end
end)
SlotBox:AddButton("Go To Slot 2", function()
    local myRoot = getHRP(LP)
    if myRoot and Config.SaveSlot2 then
        myRoot.CFrame = Config.SaveSlot2
        Library:Notify({ Title = "Riad Hub", Description = "To Slot 2.", Time = 2 })
    else
        Library:Notify({ Title = "Riad Hub", Description = "No Slot 2 saved.", Time = 2 })
    end
end)

-- ============================================================
-- TROLLING TAB
-- ============================================================
local TrollTab = Window:AddTab({
    Name = "Trolling",
    Icon = "smile",
    Description = "Fling suite",
})

local FlingBox = TrollTab:AddLeftGroupbox("Fling — Manual", "wind")
FlingBox:AddButton("Fling Murderer", function()
    local m = select(1, getRolePlayers())
    if m and m.Character then
        Library:Notify({ Title = "Riad Hub", Description = "Flinging " .. m.Name .. "...", Time = 2 })
        task.spawn(flingCharacter, m.Character)
        SendWebhook("Fling", "Flinging murderer: " .. m.Name)
    else
        Library:Notify({ Title = "Riad Hub", Description = "Murderer not found.", Time = 2 })
    end
end)
FlingBox:AddButton("Fling Sheriff", function()
    local _, s = getRolePlayers()
    if s and s.Character then
        Library:Notify({ Title = "Riad Hub", Description = "Flinging " .. s.Name .. "...", Time = 2 })
        task.spawn(flingCharacter, s.Character)
    else
        Library:Notify({ Title = "Riad Hub", Description = "Sheriff not found.", Time = 2 })
    end
end)
FlingBox:AddDropdown("FlingStyle", {
    Text = "Fling Style",
    Values = { "Torque", "Velocity", "Orbit" },
    Default = "Torque",
    Callback = function(v) Config.FlingStyle = v AutoSaveConfig() end,
})

local PreRoundBox = TrollTab:AddRightGroupbox("Fling — Pre-Round", "alert-triangle")
PreRoundBox:AddLabel("⚠ All pre-round fling toggles are DETECTED.")
PreRoundBox:AddDivider()
PreRoundBox:AddToggle("FlingMurdererPreRound", {
    Text = "Fling Murderer (Pre-Round)", Default = false,
    Callback = function(v) Config.FlingMurdererPreRound = v AutoSaveConfig() end,
})
PreRoundBox:AddToggle("FlingSheriffPreRound", {
    Text = "Fling Sheriff (Pre-Round)", Default = false,
    Callback = function(v) Config.FlingSheriffPreRound = v AutoSaveConfig() end,
})
PreRoundBox:AddToggle("FlingHeroPreRound", {
    Text = "Fling Hero (Pre-Round)", Default = false,
    Callback = function(v) Config.FlingHeroPreRound = v AutoSaveConfig() end,
})
PreRoundBox:AddToggle("FlingAllPreRound", {
    Text = "Fling ALL Players (Pre-Round)", Default = false,
    Callback = function(v) Config.FlingAllPreRound = v AutoSaveConfig() end,
})
PreRoundBox:AddToggle("FlingSheriffDuringRound", {
    Text = "Fling Sheriff During Round", Default = false,
    Callback = function(v) Config.FlingSheriffDuringRound = v AutoSaveConfig() end,
})

task.spawn(function()
    while true do
        task.wait(1)
        if Config.FlingSheriffDuringRound and State.RoundState == "Active" then
            local _, s = getRolePlayers()
            if s and s.Character and isAlive(s) then
                task.spawn(flingCharacter, s.Character)
            end
        end
    end
end)

-- ============================================================
-- AUTO MODULES (new features)
-- ============================================================
local UnboxBox = Window:Tab({ Title = "Auto", Icon = "package", Description = "Auto systems" })

UnboxBox:AddLeftGroupbox("Auto Systems", "package")
UnboxBox:AddToggle("AutoUnbox", {
    Text = "Auto Unbox", Default = false,
    Callback = function(v) Config.AutoUnbox = v AutoSaveConfig() end,
})
UnboxBox:AddToggle("AutoPrestige", {
    Text = "Auto Prestige", Default = false,
    Callback = function(v) Config.AutoPrestige = v AutoSaveConfig() end,
})

-- ============================================================
-- MISC TAB
-- ============================================================
local MiscTab = Window:AddTab({
    Name = "Misc",
    Icon = "settings",
    Description = "Config, server, session",
})

local CfgBox = MiscTab:AddLeftGroupbox("Configuration", "save")
CfgBox:AddButton("Save Config", function()
    AutoSaveConfig()
    Library:Notify({ Title = "Riad Hub", Description = "Config saved.", Time = 2 })
end)
CfgBox:AddButton("Reload Config", function()
    if LoadSavedConfig() then
        Library:Notify({ Title = "Riad Hub", Description = "Config loaded.", Time = 2 })
    else
        Library:Notify({ Title = "Riad Hub", Description = "No config found.", Time = 2 })
    end
end)
CfgBox:AddButton("Reset to Defaults", function()
    for k, v in pairs(DefaultConfig) do Config[k] = v end
    AutoSaveConfig()
    Library:Notify({ Title = "Riad Hub", Description = "Defaults restored.", Time = 2 })
end)

local SessionBox = MiscTab:AddLeftGroupbox("Session", "info")
SessionBox:AddToggle("AntiAFK", {
    Text = "Anti-AFK", Default = true,
    Callback = function(v) Config.AntiAFK = v AutoSaveConfig() end,
})
SessionBox:AddToggle("DeathNotifs", {
    Text = "Death Notifications", Default = true,
    Callback = function(v) Config.DeathNotifs = v AutoSaveConfig() end,
})
SessionBox:AddToggle("RoundEndNotifications", {
    Text = "Round End Notifications", Default = true,
    Callback = function(v) Config.RoundEndNotifications = v AutoSaveConfig() end,
})
SessionBox:AddButton("Copy Death List", function()
    if #State.DeadPlayers == 0 then
        Library:Notify({ Title = "Riad Hub", Description = "No deaths recorded.", Time = 2 })
        return
    end
    if setclipboard then
        setclipboard("MM2 Dead: " .. table.concat(State.DeadPlayers, ", "))
        Library:Notify({ Title = "Riad Hub", Description = "Copied.", Time = 2 })
    end
end)

local WebhookBox = MiscTab:AddLeftGroupbox("Webhook", "message-circle")
WebhookBox:AddToggle("WebhookEnabled", {
    Text = "Webhook Enabled", Default = false,
    Callback = function(v) Config.WebhookEnabled = v AutoSaveConfig() end,
})
WebhookBox:AddInput("WebhookURL", {
    Text = "Webhook URL",
    Default = "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(v)
        Config.WebhookURL = v
        AutoSaveConfig()
    end,
})
WebhookBox:AddButton("Send Test", function()
    SendWebhook("Test", "Riad Hub webhook test.")
    Library:Notify({ Title = "Riad Hub", Description = "Test sent.", Time = 2 })
end)

local ServerBox = MiscTab:AddRightGroupbox("Server", "server")
ServerBox:AddButton("Rejoin Server", function()
    local qot = (syn and syn.queue_on_teleport) or queue_on_teleport or queueonteleport
    if qot then
        pcall(qot, [[
            task.spawn(function()
                repeat task.wait(0.5) until game:IsLoaded()
                task.wait(1)
                if isfile and isfile("RiadHub.lua") then loadstring(readfile("RiadHub.lua"))() end
            end)
        ]])
    end
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
end)
ServerBox:AddButton("Server Hop (Random)", function()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and res then
        local data = HttpService:JSONDecode(res)
        if data and data.data then
            local valid = {}
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and s.playing >= 5 and s.playing < s.maxPlayers then
                    table.insert(valid, s)
                end
            end
            if #valid == 0 then
                for _, s in ipairs(data.data) do
                    if s.id ~= game.JobId and s.playing >= 2 and s.playing < s.maxPlayers then
                        table.insert(valid, s)
                    end
                end
            end
            if #valid > 0 then
                local c = valid[math.random(1, #valid)]
                TeleportService:TeleportToPlaceInstance(game.PlaceId, c.id, LP)
                return
            end
        end
    end
    Library:Notify({ Title = "Riad Hub", Description = "No server found.", Time = 2 })
end)
ServerBox:AddButton("Server Hop (Low Pop)", function()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and res then
        local data = HttpService:JSONDecode(res)
        if data and data.data then
            local valid = {}
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and s.playing >= 2 and s.playing <= 5 then
                    table.insert(valid, s)
                end
            end
            if #valid > 0 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, valid[1].id, LP)
                return
            end
        end
    end
    Library:Notify({ Title = "Riad Hub", Description = "No low-pop server found.", Time = 2 })
end)
ServerBox:AddButton("Copy Job ID", function()
    if setclipboard then
        setclipboard(game.JobId)
        Library:Notify({ Title = "Riad Hub", Description = "Job ID copied.", Time = 2 })
    end
end)
ServerBox:AddButton("Copy Place ID", function()
    if setclipboard then
        setclipboard(tostring(game.PlaceId))
        Library:Notify({ Title = "Riad Hub", Description = "Place ID copied.", Time = 2 })
    end
end)

-- ============================================================
-- INFO TAB
-- ============================================================
local InfoTab = Window:AddTab({
    Name = "Info",
    Icon = "info",
    Description = "Round status",
})

local StatusBox = InfoTab:AddLeftGroupbox("Round Status", "activity")
local statusLabel = StatusBox:AddLabel("Round: Waiting")
local timerLabel  = StatusBox:AddLabel("Timer: 0:00")
local murderLabel = StatusBox:AddLabel("Murderer: Undetected")
local sherifLabel = StatusBox:AddLabel("Sheriff: Undetected")
local resultLabel = StatusBox:AddLabel("Last round: —")

task.spawn(function()
    while true do
        task.wait(0.5)
        local rtp = Workspace:FindFirstChild("RoundTimerPart")
        if rtp and rtp:FindFirstChild("SurfaceGui") then
            local sg = rtp.SurfaceGui
            local cr = sg:FindFirstChild("CurrentRound")
            local tm = sg:FindFirstChild("Timer")
            if cr and tm then
                pcall(function()
                    statusLabel:SetText("Round: " .. cr.Text)
                    timerLabel:SetText("Timer: " .. tm.Text)
                end)

                local prevState = State.RoundState
                if cr.Text == "Current Round" then
                    State.RoundState = "Active"
                else
                    State.RoundState = "Intermission"
                end

                if prevState == "Active" and State.RoundState == "Intermission" then
                    local myRole = getRole(LP)
                    local resultText = "Round ended"
                    if myRole == "Murderer" then
                        resultText = "Murderer survived"
                    elseif myRole == "Sheriff" then
                        resultText = "Sheriff won"
                    else
                        resultText = "Innocent survived"
                    end
                    pcall(function() resultLabel:SetText("Last round: " .. resultText) end)
                    if Config.RoundEndNotifications then
                        Library:Notify({ Title = "Round End", Description = resultText, Time = 4 })
                    end
                end

                if State.RoundState == "Active" and not State.RoundStartedFlag then
                    State.RoundStartedFlag = true
                    if Config.AutoDrop then
                        local map = getActiveMap()
                        local myRoot = getHRP(LP)
                        if map and myRoot then
                            local sp = map:FindFirstChild("Spawns")
                            if sp and #sp:GetChildren() > 0 then
                                myRoot.CFrame = sp:GetChildren()[1].CFrame * CFrame.new(0, 4, 0)
                            end
                        end
                    end
                elseif State.RoundState == "Intermission" then
                    State.RoundStartedFlag = false
                end
            end
        end
        local m, s = getRolePlayers()
        pcall(function()
            murderLabel:SetText("Murderer: " .. (m and (m.Name .. (isAlive(m) and "" or " [DEAD]")) or "Undetected"))
            sherifLabel:SetText("Sheriff: " .. (s and (s.Name .. (isAlive(s) and "" or " [DEAD]")) or "Undetected"))
        end)
    end
end)

local ActionsBox = InfoTab:AddRightGroupbox("Quick Actions", "zap")
ActionsBox:AddButton("Reset Character", function()
    local h = getHumanoid(LP)
    if h then h.Health = 0 end
end)
ActionsBox:AddButton("Announce Roles", function()
    local m, s = getRolePlayers()
    local msg = "[Riad] Murderer: " .. (m and m.Name or "?") .. " | Sheriff: " .. (s and s.Name or "?")
    local ch = TextChatService:FindFirstChild("TextChannels")
    local ch2 = ch and ch:FindFirstChild("RBXGeneral")
    if ch2 and ch2.SendAsync then ch2:SendAsync(msg) end
    Library:Notify({ Title = "Riad Hub", Description = "Announced roles.", Time = 2 })
end)

Window:LoadSettingsTab({
    ScriptName = "Riad Hub",
    Name = "Settings",
    Icon = "settings",
    Description = "Riad Hub interface settings",
    ShowWatermark = true,
    LoadManagers = true,
    ThemeFolder = "RiadHub",
    ConfigFolder = "RiadHub",
    ConfigSubFolder = "MM2",
})

-- ============================================================
-- MAIN LOOP
-- ============================================================
local heartbeat = RunService.Heartbeat:Connect(function()
    local now = tick()
    local myChar = LP.Character
    local myRoot = getHRP(LP)
    local myHum  = getHumanoid(LP)

    -- ESP
    if Config.RoleESP and myRoot then
        if now - State.LastESPRefresh > 0.066 then
            State.LastESPRefresh = now
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character and isAlive(p) then
                    local pRoot = getHRP(p)
                    if pRoot then
                        local dist = math.floor((myRoot.Position - pRoot.Position).Magnitude)
                        if dist <= Config.ESPDistanceMax then
                            local role = getRole(p)
                            local col  = roleColor(role)
                            local txt  = p.Name
                            if Config.ESPNames then txt = "[" .. role .. "] " .. p.Name end
                            if Config.ESPDistance then txt = txt .. " (" .. dist .. ")" end
                            if Config.PlayerStats then
                                local h = getHumanoid(p)
                                if h then txt = txt .. " " .. math.floor(h.Health) .. "hp" end
                            end
                            getOrCreateBillboard("bb_" .. p.UserId, pRoot, txt, col)
                            if Config.ESPBoxes then getOrCreateBox("bx_" .. p.UserId, pRoot, col) end
                            if Config.ESPChams then getOrCreateCham(p.UserId, p.Character, col) end
                        end
                    end
                end
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and isAlive(p) then
                local pRoot = getHRP(p)
                if pRoot then
                    updateTracer("tr_" .. p.UserId, pRoot.Position, roleColor(getRole(p)))
                end
            end
        end
    elseif not Config.RoleESP then
        clearCategory(State.Highlights)
        clearCategory(State.Boxes)
        clearCategory(State.Tracers)
    end

    -- Item ESP
    if now - State.LastItemScan > 0.5 then
        State.LastItemScan = now
        clearCategory(State.ItemHighlights)
        if Config.GunESP then
            local gd = getGunDrop()
            local gp = getGunDropPart(gd)
            if gp then
                local hl = Instance.new("Highlight")
                hl.Adornee = gp
                hl.FillColor = Color3.fromRGB(255, 220, 60)
                hl.OutlineColor = Color3.fromRGB(255, 220, 60)
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = espFolder
                table.insert(State.ItemHighlights, hl)
            end
        end
        if Config.CoinESP then
            for _, c in ipairs(getAllActiveCoins()) do
                local hl = Instance.new("Highlight")
                hl.Adornee = c
                hl.FillColor = Color3.fromRGB(251, 191, 36)
                hl.OutlineColor = Color3.fromRGB(251, 191, 36)
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = espFolder
                table.insert(State.ItemHighlights, hl)
            end
        end
    end

    -- Gun Tracker
    updateGunTracker()

    -- Auto TP to Gun
    if Config.AutoTPGun and myRoot then
        local gd = getGunDrop()
        local gp = getGunDropPart(gd)
        if gp and (myRoot.Position - gp.Position).Magnitude > 5 then
            myRoot.CFrame = gp.CFrame * CFrame.new(0, 3, 0)
        end
    end

    -- Aimbot
    if Config.Aimbot then
        local tgt = nearestTarget()
        if tgt then
            local tRoot = getHRP(tgt)
            if tRoot then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, tRoot.Position)
            end
        end
    end

    -- Fly
    if Config.Fly and State.flyBV then
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
        State.flyBV.Velocity = move * Config.FlySpeed
    end

    -- Noclip
    if Config.Noclip and myChar then
        for _, p in ipairs(myChar:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end

    -- Speed / Jump
    if myHum then
        if Config.Speed then
            if myHum.WalkSpeed ~= Config.SpeedValue then myHum.WalkSpeed = Config.SpeedValue end
        else
            if myHum.WalkSpeed ~= 16 and not Config.CoinFarm then myHum.WalkSpeed = 16 end
        end
        if Config.JumpEnabled and myHum.JumpPower ~= Config.JumpValue then
            myHum.JumpPower = Config.JumpValue
        end
    end

    -- Anti-Ragdoll
    if Config.AntiRagdoll and myHum then
        pcall(function()
            myHum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            myHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end)
        myHum.PlatformStand = false
    end

    -- Environment
    if Config.Fullbright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
    end
    if Config.NoFog then Lighting.FogEnd = 1e6 end

    -- Anti-Fling / Anti-Void
    if myRoot and myHum then
        local velMag = myRoot.AssemblyLinearVelocity.Magnitude
        local angMag = myRoot.AssemblyAngularVelocity.Magnitude

        if not State.IsFlinging and myHum.Health > 0 and myHum.FloorMaterial ~= Enum.Material.Air
            and velMag < 75 and angMag < 35 then
            State.LastSafePosition = myRoot.CFrame
        end

        if not State.IsFlinging and (Config.AntiFling or Config.AntiVoid) and State.LastSafePosition then
            if velMag > 120 or angMag > 90 then
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myRoot.CFrame = State.LastSafePosition
            end
            if Config.AntiVoid and (State.LastSafePosition.Y - myRoot.Position.Y > 30) then
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myRoot.CFrame = State.LastSafePosition
            end
        end
    end

    updateAuraRing(myRoot)
    updateFOVCircle()

    -- Auto-Shoot
    if Config.AutoShoot and myRoot and now - State.LastAutoShoot >= 0.5 then
        local m = select(1, getRolePlayers())
        if m and isAlive(m) then
            local gun = equipTool("Gun")
            if gun and gun:FindFirstChild("Shoot") then
                local mRoot = getHRP(m)
                if mRoot then
                    local rayAtt = myRoot:FindFirstChild("GunRaycastAttachment")
                    local origin = rayAtt and rayAtt.WorldCFrame or myRoot.CFrame
                    local pos = mRoot.Position
                    if Config.AimPrediction then
                        pos = pos + mRoot.AssemblyLinearVelocity * 0.12
                    end
                    gun.Shoot:FireServer(origin, CFrame.new(pos))
                    State.LastAutoShoot = now
                    if Config.SingleShot then Config.AutoShoot = false end
                end
            end
        end
    end

    -- Kill Aura / Auto Kill
    if (Config.KillAura or Config.AutoKill or Config.AutoStab) and myRoot and now - State.LastKnifeTick >= 0.2 then
        local knife = equipTool("Knife")
        if knife then
            local events = knife:FindFirstChild("Events")
            if events then
                if (Config.KillMode == "Throw" or Config.KnifeSilentAim)
                    and events:FindFirstChild("KnifeThrown") and knife:FindFirstChild("Handle") then
                    local tgt = nearestTarget(Config.KillAll and math.huge or Config.AuraRange)
                    if tgt then
                        local tRoot = getHRP(tgt)
                        if tRoot then
                            local pos = tRoot.Position
                            if Config.AimPrediction then
                                pos = pos + tRoot.AssemblyLinearVelocity * 0.16
                            end
                            events.KnifeThrown:FireServer(knife.Handle.CFrame, CFrame.new(pos))
                            State.LastKnifeTick = now
                        end
                    end
                elseif events:FindFirstChild("HandleTouched") then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LP and isAlive(p) then
                            local tRoot = getHRP(p)
                            if tRoot then
                                local d = (myRoot.Position - tRoot.Position).Magnitude
                                if Config.KillAll or d <= Config.AuraRange then
                                    events.HandleTouched:FireServer(tRoot)
                                    if events:FindFirstChild("KnifeStabbed") then
                                        events.KnifeStabbed:FireServer()
                                    end
                                    State.LastKnifeTick = now
                                    if not Config.KillAll then break end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Auto Kill Murderer/Sheriff (as the opposing role)
    if (Config.AutoKillMurderer or Config.AutoKillSheriff) and myRoot and now - State.LastKnifeTick >= 0.2 then
        local target = nil
        if Config.AutoKillMurderer then
            target = select(1, getRolePlayers())
        elseif Config.AutoKillSheriff then
            target = select(2, getRolePlayers())
        end
        if target and isAlive(target) then
            local knife = equipTool("Knife")
            if knife then
                local events = knife:FindFirstChild("Events")
                if events then
                    local tRoot = getHRP(target)
                    if tRoot and (myRoot.Position - tRoot.Position).Magnitude <= Config.AuraRange then
                        if events:FindFirstChild("HandleTouched") then
                            events.HandleTouched:FireServer(tRoot)
                            if events:FindFirstChild("KnifeStabbed") then
                                events.KnifeStabbed:FireServer()
                            end
                            State.LastKnifeTick = now
                        end
                    end
                end
            end
        end
    end

    -- Dodge Knife
    if Config.DodgeKnife and myRoot and myHum then
        local murderer = select(1, getRolePlayers())
        if murderer and isAlive(murderer) then
            local mRoot = getHRP(murderer)
            if mRoot then
                local dist = (myRoot.Position - mRoot.Position).Magnitude
                if dist < Config.AuraRange and murderer.Character:FindFirstChild("Knife") then
                    local away = (myRoot.Position - mRoot.Position).Unit
                    myRoot.CFrame = myRoot.CFrame + Vector3.new(away.X * 1.5, 0, away.Z * 1.5)
                end
            end
        end
    end

    -- Hitbox Expander
    if Config.HitboxExpander and now - State.LastHitboxTick > 0.1 then
        State.LastHitboxTick = now
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and isAlive(p) then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if not State.OriginalHitboxSizes[hrp] then
                        State.OriginalHitboxSizes[hrp] = hrp.Size
                    end
                    hrp.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                    hrp.Transparency = Config.HitboxTransparency
                    hrp.CanCollide = false
                end
            end
        end
    end

    -- Full Gun Grabber
    if Config.GrabGunAuto and myRoot then
        local gd = getGunDrop()
        local gp = getGunDropPart(gd)
        if gp and (myRoot.Position - gp.Position).Magnitude <= Config.GunGrabDist then
            interactWithGunDrop(gp, gd)
        end
    end

    -- Murderer Avoid / Follow
    local murderer = select(1, getRolePlayers())
    if myRoot and murderer and isAlive(murderer) then
        local mRoot = getHRP(murderer)
        if mRoot then
            local dist = (myRoot.Position - mRoot.Position).Magnitude
            if Config.MurdererAvoid and dist < Config.SafetyRadius then
                if Config.SprintWhenChased and myHum then
                    myHum.WalkSpeed = math.max(myHum.WalkSpeed, 26)
                end
                if Config.RetreatToLobby then
                    local lb = getLobbyModel()
                    if lb then
                        local sp = lb:FindFirstChildWhichIsA("BasePart")
                        if sp then myRoot.CFrame = sp.CFrame * CFrame.new(0, 3, 0) end
                    end
                else
                    local away = (myRoot.Position - mRoot.Position).Unit
                    myRoot.CFrame = myRoot.CFrame + Vector3.new(away.X * 0.8, 0, away.Z * 0.8)
                end
            end
            if Config.ProximityAlert and dist < Config.SafetyRadius then
                if not State.Alerted or now - State.Alerted > 3 then
                    State.Alerted = now
                    Library:Notify({ Title = "⚠ MURDERER NEAR", Description = "Distance: " .. math.floor(dist) .. " studs", Time = 2 })
                end
            end
            if Config.FollowMurderer then
                local target = mRoot.Position - (mRoot.CFrame.LookVector * Config.FollowDist)
                myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.new(target, mRoot.Position), 0.15)
            end
        end
    end

    -- Coin Farm
    if Config.CoinFarm and myRoot and now - State.LastFarmTick >= 0.05 then
        if Config.BagFullStop and getCurrentCoinCount() >= Config.CoinBagCap then
            Config.CoinFarm = false
            Library:Notify({ Title = "Riad Hub", Description = "Coin bag full. Farming stopped.", Time = 3 })
        else
            local coins = getAllActiveCoins()
            local best, bestDist = nil, math.huge
            for _, c in ipairs(coins) do
                local d = (myRoot.Position - c.Position).Magnitude
                local safe = true
                if Config.SafeCoinFarm and murderer and isAlive(murderer) then
                    local mRoot = getHRP(murderer)
                    if mRoot and (c.Position - mRoot.Position).Magnitude < Config.SafetyRadius then
                        safe = false
                    end
                end
                if safe and d < bestDist then best, bestDist = c, d end
            end

            if best then
                if myHum then myHum.WalkSpeed = Config.FarmSpeed end
                local targetPos = best.Position
                local dist = (myRoot.Position - targetPos).Magnitude

                if Config.FarmMethod == "Teleport" then
                    myRoot.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
                    fireTouch(myRoot, best)
                    task.wait(Config.TeleportFarmDelay)
                elseif Config.FarmMethod == "Tween" then
                    local t = math.max(dist / Config.FarmSpeed, 0.05)
                    TweenService:Create(myRoot, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)}):Play()
                    if dist < 7 then
                        fireTouch(myRoot, best)
                        local rh = myChar:FindFirstChild("RightHand") or myChar:FindFirstChild("Right Arm")
                        if rh then fireTouch(rh, best) end
                    end
                elseif Config.FarmMethod == "Glide" or Config.QuickFarm then
                    local dir = (targetPos - myRoot.Position)
                    if dir.Magnitude > 0.3 then
                        myRoot.AssemblyLinearVelocity = dir.Unit * Config.FarmSpeed
                    else
                        myRoot.AssemblyLinearVelocity = Vector3.zero
                    end
                    if dist < 7 then
                        fireTouch(myRoot, best)
                        local rh = myChar:FindFirstChild("RightHand") or myChar:FindFirstChild("Right Arm")
                        if rh then fireTouch(rh, best) end
                    end
                else
                    if myHum then
                        myHum:MoveTo(targetPos)
                        if targetPos.Y > myRoot.Position.Y + 2.0 and myHum:GetState() ~= Enum.HumanoidStateType.Jumping then
                            myHum:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                    if dist < 7 then
                        fireTouch(myRoot, best)
                        local rh = myChar:FindFirstChild("RightHand") or myChar:FindFirstChild("Right Arm")
                        if rh then fireTouch(rh, best) end
                    end
                end
                State.LastFarmTick = now
            end
        end
    end

    -- Auto Play
    if Config.AutoPlay and myRoot and myHum then
        local role = getRole(LP)
        if role == "Sheriff" then
            if murderer and isAlive(murderer) then
                local mRoot = getHRP(murderer)
                if mRoot and (myRoot.Position - mRoot.Position).Magnitude < 60 then
                    Config.AutoShoot = true
                end
            end
        elseif role == "Innocent" then
            Config.CoinFarm = true
        elseif role == "Murderer" then
            Config.KillAura = true
        end
    end
end)

table.insert(activeConnections, heartbeat)

-- ============================================================
-- DEATH TRACKING
-- ============================================================
local function hookDeath(p)
    if not p.Character then return end
    local h = p.Character:WaitForChild("Humanoid", 5)
    if h then
        h.Died:Connect(function()
            table.insert(State.DeadPlayers, p.Name)
            if Config.DeathNotifs then
                local r = getRole(p)
                Library:Notify({ Title = "Death", Description = p.Name .. " [" .. r .. "]", Time = 3 })
            end
            SendWebhook("Death", p.Name .. " [" .. getRole(p) .. "]")
        end)
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        if p.Character then hookDeath(p) end
        p.CharacterAdded:Connect(function() task.wait(0.5) hookDeath(p) end)
    end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= LP then
        p.CharacterAdded:Connect(function() task.wait(0.5) hookDeath(p) end)
    end
end)

-- ============================================================
-- INPUT
-- ============================================================
table.insert(activeConnections, UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local h = getHumanoid(LP)
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

table.insert(activeConnections, UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.End then
        Config.KillAura = false
        Config.AutoShoot = false
        Config.CoinFarm = false
        Config.AutoKill = false
        Config.AutoStab = false
        Config.SilentAim = false
        Config.FlingMurdererPreRound = false
        Config.FlingSheriffPreRound = false
        Config.FlingHeroPreRound = false
        Config.FlingAllPreRound = false
        Config.FlingSheriffDuringRound = false
        Config.AutoTPGun = false
        Library:Notify({ Title = "Riad Hub", Description = "EMERGENCY STOP — features halted.", Time = 3 })
    end
end))

table.insert(activeConnections, LP.Idled:Connect(function()
    if Config.AntiAFK then
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new(0, 0))
    end
end))

-- ============================================================
-- UNLOAD
-- ============================================================
getgenv().RiadHub_Unload = function()
    State.SilentAimHookActive = false
    for _, c in ipairs(activeConnections) do
        pcall(function() c:Disconnect() end)
    end
    activeConnections = {}
    clearCategory(State.Highlights)
    clearCategory(State.Boxes)
    clearCategory(State.ItemHighlights)
    for id in pairs(State.Tracers) do
        pcall(function() State.Tracers[id]:Remove() end)
    end
    if gunTrackerBox then pcall(function() gunTrackerBox:Remove() end) end
    if gunTrackerText then pcall(function() gunTrackerText:Remove() end) end
    if State.AuraRing then pcall(function() State.AuraRing:Destroy() end) State.AuraRing = nil end
    if State.FOVCircle then pcall(function() State.FOVCircle:Remove() end) State.FOVCircle = nil end
    for part, sz in pairs(State.OriginalHitboxSizes) do
        if part and part.Parent then
            part.Size = sz
            part.Transparency = 1
        end
    end
    if State.flyBV then pcall(function() State.flyBV:Destroy() end) end
    if espFolder and espFolder.Parent then pcall(function() espFolder:Destroy() end) end
    pcall(function() Library:Unload() end)
    getgenv().RiadHub_Unload = nil
end

Library:Notify({
    Title = "Riad Hub",
    Description = "Loaded. Right-Ctrl to toggle.",
    Time = 5,
})
