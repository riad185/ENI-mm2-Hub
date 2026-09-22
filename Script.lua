--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║   ENI's MM2 Hub  v2                                           ║
    ║   for LO. always.                                             ║
    ║   UI: WindUI  |  Features: original + Identical additions    ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

-- unload prior instance if re-executed
if getgenv and getgenv().ENI_MM2_Unload then
    pcall(getgenv().ENI_MM2_Unload)
end

-- ============================================================
-- WINDUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ============================================================
-- SERVICES
-- ============================================================
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
local LP                = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    -- visuals
    RoleESP = false,
    ItemESP = false,
    ESPBoxes = false,
    ESPNames = true,
    ESPTracers = false,
    ESPDistance = true,
    ESPChams = false,
    ESPDistanceMax = 600,
    GunESP = false,
    CoinESP = false,
    Fullbright = false,
    NoFog = false,
    DisableParticles = false,

    -- combat: gun
    Aimbot = false,
    AutoShoot = false,
    SilentAim = false,
    AimPrediction = true,
    PingComp = true,
    SingleShot = false,
    FOVRadius = 160,
    ShowFOV = false,
    AutoEquipGun = true,
    GrabGunAuto = false,
    GunGrabDist = 300,

    -- combat: knife
    AutoStab = false,
    KillAura = false,
    AutoKill = false,
    KillMode = "Legit",
    KnifeSilentAim = true,
    AuraRange = 15,
    KillAll = false,
    ShowAuraRing = false,
    AutoEquipKnife = true,
    ProximityKnife = true,
    KnifeProxDist = 18,

    -- combat: hitbox
    HitboxExpander = false,
    HitboxSize = 10,
    HitboxTransparency = 0.6,

    -- survival
    MurdererAvoid = false,
    SafetyRadius = 40,
    RetreatToLobby = false,
    ProximityAlert = true,
    SprintWhenChased = true,
    FollowMurderer = false,
    FollowDist = 18,

    -- movement
    Speed = false,
    SpeedValue = 24,
    JumpEnabled = false,
    JumpValue = 50,
    InfiniteJump = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 35,
    AntiRagdoll = false,
    AntiVoid = true,
    AntiFling = true,

    -- farm
    CoinFarm = false,
    FarmSpeed = 28,
    FarmMethod = "Glide",
    SafeCoinFarm = true,
    BagFullStop = true,
    QuickFarm = false,
    CoinBagCap = 40,

    -- teleports
    AutoDrop = false,
    SaveSlot1 = nil,
    SaveSlot2 = nil,

    -- trolling
    FlingStyle = "Torque",

    -- misc
    AntiAFK = true,
    AutoPlay = false,
    DeathNotifs = true,
    SearchFilter = "",
}

local DefaultConfig = {}
for k, v in pairs(Config) do DefaultConfig[k] = v end

local CONFIG_FILE = "ENI_MM2/config.json"

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
            if makefolder and not isfolder("ENI_MM2") then makefolder("ENI_MM2") end
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
-- STATE
-- ============================================================
local State = {
    Highlights = {},
    ItemHighlights = {},
    Boxes = {},
    Tracers = {},
    MinimapDots = {},
    LastItemScan = 0,
    LastAutoShoot = 0,
    LastAutoStab = 0,
    LastKnifeTick = 0,
    LastFarmTick = 0,
    LastSafePosition = nil,
    DeadPlayers = {},
    OriginalHitboxSizes = {},
    IsFlinging = false,
    AuraRing = nil,
    FOVCircle = nil,
    flyBV = nil,
    SilentAimHookActive = true,
    RoundStartedFlag = false,
}

-- ============================================================
-- ESP FOLDER
-- ============================================================
local espFolder = CoreGui:FindFirstChild("ENI_MM2_ESP") or LP.PlayerGui:FindFirstChild("ENI_MM2_ESP")
if not espFolder then
    espFolder = Instance.new("Folder")
    espFolder.Name = "ENI_MM2_ESP"
    pcall(function() espFolder.Parent = CoreGui end)
    if not espFolder.Parent then espFolder.Parent = LP.PlayerGui end
end

-- ============================================================
-- HELPERS
-- ============================================================
local function getChar(p) return p and (p.Character or p.CharacterAdded:Wait()) end
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

local function nearestTarget(maxDist)
    maxDist = maxDist or math.huge
    local best, bestDist = nil, maxDist
    local myHRP = getHRP(LP)
    if not myHRP then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isAlive(p) then
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

-- ============================================================
-- AURA RING (visual)
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
        p.Name = "ENI_AuraRing"
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
        fr.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
        fr.BackgroundTransparency = 0.92
        fr.BorderSizePixel = 0
        fr.Parent = sg
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = fr
        local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(192, 132, 252) s.Thickness = 2.5 s.Transparency = 0.1 s.Parent = fr

        p.Parent = Workspace
        State.AuraRing = p
    end
    State.AuraRing.Size = Vector3.new(diameter, 0.01, diameter)
    State.AuraRing.CFrame = CFrame.new(myRoot.Position.X, myRoot.Position.Y - 2.85, myRoot.Position.Z)
    State.AuraRing.Transparency = 1
end

-- ============================================================
-- FOV CIRCLE
-- ============================================================
if Drawing and Drawing.new then
    pcall(function()
        State.FOVCircle = Drawing.new("Circle")
        State.FOVCircle.Thickness = 1.5
        State.FOVCircle.Color = Color3.fromRGB(168, 85, 247)
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

-- ============================================================
-- SILENT AIM HOOK
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

local function removeTracer(id)
    if State.Tracers[id] then
        pcall(function() State.Tracers[id]:Remove() end)
        State.Tracers[id] = nil
    end
end

-- ============================================================
-- WINDUI WINDOW
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "ENI's MM2 Hub",
    Icon = "rbxassetid://4483362458",
    Author = "for LO",
    Folder = "ENI_MM2",
    Size = UDim2.fromOffset(620, 500),
    Transparent = true,
    Theme = "Dark",
    User = { Enabled = true, Anonymous = true },
})

Window:EditOpenButton({
    Title = "ENI's MM2 Hub",
    Icon = "rbxassetid://4483362458",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromRGB(255, 105, 180), Color3.fromRGB(140, 200, 255)),
    OnlyMobile = false,
})

local VisualTab    = Window:Tab({ Title = "Visual",    Icon = "eye" })
local CombatTab    = Window:Tab({ Title = "Combat",    Icon = "crosshair" })
local MoveTab      = Window:Tab({ Title = "Movement",  Icon = "move" })
local FarmTab      = Window:Tab({ Title = "Farm",      Icon = "coins" })
local SurvTab      = Window:Tab({ Title = "Survival",  Icon = "shield" })
local TPTime       = Window:Tab({ Title = "Teleports", Icon = "map-pin" })
local TrollTab     = Window:Tab({ Title = "Trolling",  Icon = "smile" })
local MiscTab      = Window:Tab({ Title = "Misc",      Icon = "settings" })

local function bindAutoSave(cb)
    return function(v) cb(v) if not isSyncingUI then AutoSaveConfig() end end
end

-- ============================================================
-- VISUAL TAB
-- ============================================================
VisualTab:Section({ Title = "Role ESP" })

VisualTab:Toggle({
    Title = "Role ESP",
    Desc = "Highlight murderer (red), sheriff (blue), innocents (white)",
    Value = Config.RoleESP,
    Callback = bindAutoSave(function(v) Config.RoleESP = v end)
})

VisualTab:Toggle({
    Title = "ESP Chams",
    Desc = "Full 3D colored fill on characters",
    Value = Config.ESPChams,
    Callback = bindAutoSave(function(v) Config.ESPChams = v if not v then clearCategory(State.Highlights) end end)
})

VisualTab:Toggle({
    Title = "ESP Boxes",
    Desc = "Draw 3D box around each character",
    Value = Config.ESPBoxes,
    Callback = bindAutoSave(function(v) Config.ESPBoxes = v if not v then clearCategory(State.Boxes) end end)
})

VisualTab:Toggle({
    Title = "ESP Names",
    Desc = "Show [Role] Name above each player",
    Value = Config.ESPNames,
    Callback = bindAutoSave(function(v) Config.ESPNames = v end)
})

VisualTab:Toggle({
    Title = "ESP Distance",
    Desc = "Show distance in studs to each player",
    Value = Config.ESPDistance,
    Callback = bindAutoSave(function(v) Config.ESPDistance = v end)
})

VisualTab:Toggle({
    Title = "ESP Tracers",
    Desc = "Line from under you to each player (needs Drawing)",
    Value = Config.ESPTracers,
    Callback = bindAutoSave(function(v) Config.ESPTracers = v end)
})

VisualTab:Slider({
    Title = "ESP Max Distance",
    Desc = "Max render distance for ESP",
    Value = { Min = 50, Max = 2000, Default = Config.ESPDistanceMax },
    Step = 25,
    Callback = bindAutoSave(function(v) Config.ESPDistanceMax = v end)
})

VisualTab:Section({ Title = "Item & World" })

VisualTab:Toggle({
    Title = "Dropped Gun ESP",
    Desc = "Highlight dropped revolver",
    Value = Config.GunESP,
    Callback = bindAutoSave(function(v) Config.GunESP = v if not v then clearCategory(State.ItemHighlights) end end)
})

VisualTab:Toggle({
    Title = "Coin ESP",
    Desc = "Highlight active coin spawns",
    Value = Config.CoinESP,
    Callback = bindAutoSave(function(v) Config.CoinESP = v if not v then clearCategory(State.ItemHighlights) end end)
})

VisualTab:Toggle({
    Title = "Fullbright",
    Desc = "Max lighting brightness",
    Value = Config.Fullbright,
    Callback = bindAutoSave(function(v) Config.Fullbright = v end)
})

VisualTab:Toggle({
    Title = "No Fog",
    Desc = "Remove distance fog",
    Value = Config.NoFog,
    Callback = bindAutoSave(function(v) Config.NoFog = v end)
})

VisualTab:Toggle({
    Title = "Disable Particles",
    Desc = "Anti-lag - kills particle emitters",
    Value = Config.DisableParticles,
    Callback = bindAutoSave(function(v) Config.DisableParticles = v end)
})

-- ============================================================
-- COMBAT TAB
-- ============================================================
CombatTab:Section({ Title = "Gun / Sheriff" })

CombatTab:Toggle({
    Title = "Aimbot (Camera Lock)",
    Desc = "Camera locks to nearest player",
    Value = Config.Aimbot,
    Callback = bindAutoSave(function(v) Config.Aimbot = v end)
})

CombatTab:Toggle({
    Title = "Auto-Shoot",
    Desc = "Fires revolver at Murderer when in range",
    Value = Config.AutoShoot,
    Callback = bindAutoSave(function(v) Config.AutoShoot = v end)
})

CombatTab:Toggle({
    Title = "Silent Aim",
    Desc = "Redirects gun raycast server-side to Murderer",
    Value = Config.SilentAim,
    Callback = bindAutoSave(function(v) Config.SilentAim = v end)
})

CombatTab:Toggle({
    Title = "Aim Prediction",
    Desc = "Lead shots to compensate target velocity",
    Value = Config.AimPrediction,
    Callback = bindAutoSave(function(v) Config.AimPrediction = v end)
})

CombatTab:Toggle({
    Title = "Ping Compensation",
    Desc = "Adjusts lead by current ping",
    Value = Config.PingComp,
    Callback = bindAutoSave(function(v) Config.PingComp = v end)
})

CombatTab:Toggle({
    Title = "Single Shot Lock",
    Desc = "Fire once then disable auto-shoot",
    Value = Config.SingleShot,
    Callback = bindAutoSave(function(v) Config.SingleShot = v end)
})

CombatTab:Toggle({
    Title = "Auto Equip Gun",
    Desc = "Equip revolver when Murderer in sight",
    Value = Config.AutoEquipGun,
    Callback = bindAutoSave(function(v) Config.AutoEquipGun = v end)
})

CombatTab:Toggle({
    Title = "Full Gun Grabber",
    Desc = "Auto-pickup dropped gun within range",
    Value = Config.GrabGunAuto,
    Callback = bindAutoSave(function(v) Config.GrabGunAuto = v end)
})

CombatTab:Slider({
    Title = "Gun Grab Distance",
    Desc = "Max distance for auto-pickup",
    Value = { Min = 20, Max = 800, Default = Config.GunGrabDist },
    Step = 10,
    Callback = bindAutoSave(function(v) Config.GunGrabDist = v end)
})

CombatTab:Toggle({
    Title = "Show FOV Circle",
    Desc = "Draw aimbot FOV circle on screen",
    Value = Config.ShowFOV,
    Callback = bindAutoSave(function(v) Config.ShowFOV = v end)
})

CombatTab:Slider({
    Title = "FOV Radius",
    Desc = "Radius of aim lock field (pixels)",
    Value = { Min = 50, Max = 700, Default = Config.FOVRadius },
    Step = 10,
    Callback = bindAutoSave(function(v) Config.FOVRadius = v end)
})

CombatTab:Section({ Title = "Knife / Murderer" })

CombatTab:Toggle({
    Title = "Auto-Stab",
    Desc = "Activates knife when target in range",
    Value = Config.AutoStab,
    Callback = bindAutoSave(function(v) Config.AutoStab = v end)
})

CombatTab:Toggle({
    Title = "Kill Aura",
    Desc = "Auto-strike players inside aura range",
    Value = Config.KillAura,
    Callback = bindAutoSave(function(v) Config.KillAura = v end)
})

CombatTab:Toggle({
    Title = "Auto Kill Innocents",
    Desc = "Constantly slash nearby innocents",
    Value = Config.AutoKill,
    Callback = bindAutoSave(function(v) Config.AutoKill = v end)
})

CombatTab:Dropdown({
    Title = "Kill Mode",
    Desc = "Method used for knife strikes",
    Values = { "Legit", "Blatant", "Throw" },
    Value = Config.KillMode,
    Callback = bindAutoSave(function(v) Config.KillMode = v end)
})

CombatTab:Toggle({
    Title = "Knife Silent Aim",
    Desc = "Thrown knife redirects into target",
    Value = Config.KnifeSilentAim,
    Callback = bindAutoSave(function(v) Config.KnifeSilentAim = v end)
})

CombatTab:Toggle({
    Title = "Kill All (No Limit)",
    Desc = "Eliminate every living player on click-hold",
    Value = Config.KillAll,
    Callback = bindAutoSave(function(v) Config.KillAll = v end)
})

CombatTab:Slider({
    Title = "Aura Range",
    Desc = "Distance threshold for melee strikes",
    Value = { Min = 5, Max = 45, Default = Config.AuraRange },
    Step = 1,
    Callback = bindAutoSave(function(v) Config.AuraRange = v end)
})

CombatTab:Toggle({
    Title = "Show Aura Ring",
    Desc = "Draw ring around character showing range",
    Value = Config.ShowAuraRing,
    Callback = bindAutoSave(function(v) Config.ShowAuraRing = v end)
})

CombatTab:Toggle({
    Title = "Auto Equip Knife",
    Desc = "Equip knife when targets near",
    Value = Config.AutoEquipKnife,
    Callback = bindAutoSave(function(v) Config.AutoEquipKnife = v end)
})

CombatTab:Toggle({
    Title = "Proximity Knife",
    Desc = "Pre-draw blade when enemy nears",
    Value = Config.ProximityKnife,
    Callback = bindAutoSave(function(v) Config.ProximityKnife = v end)
})

CombatTab:Slider({
    Title = "Knife Proximity Distance",
    Desc = "Range for proximity knife equip",
    Value = { Min = 5, Max = 40, Default = Config.KnifeProxDist },
    Step = 1,
    Callback = bindAutoSave(function(v) Config.KnifeProxDist = v end)
})

CombatTab:Button({
    Title = "Kill All (Murderer Only)",
    Desc = "Teleport to every player and stab",
    Callback = function()
        local ch = LP.Character
        local knife = equipTool("Knife")
        if not knife then
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "You need the knife equipped.", Duration = 3 })
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
    end
})

CombatTab:Section({ Title = "Hitbox" })

CombatTab:Toggle({
    Title = "Hitbox Expander",
    Desc = "Inflate player hitboxes for easy stabs/shots",
    Value = Config.HitboxExpander,
    Callback = bindAutoSave(function(v)
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
    end)
})

CombatTab:Slider({
    Title = "Hitbox Size",
    Desc = "Expanded hitbox dimensions (studs)",
    Value = { Min = 4, Max = 30, Default = Config.HitboxSize },
    Step = 1,
    Callback = bindAutoSave(function(v) Config.HitboxSize = v end)
})

CombatTab:Slider({
    Title = "Hitbox Transparency",
    Desc = "Visibility of expanded hitboxes",
    Value = { Min = 0, Max = 1, Default = Config.HitboxTransparency },
    Step = 0.05,
    Callback = bindAutoSave(function(v) Config.HitboxTransparency = v end)
})

-- ============================================================
-- MOVEMENT TAB
-- ============================================================
MoveTab:Section({ Title = "Speed & Jump" })

MoveTab:Toggle({
    Title = "Speed Boost",
    Desc = "Modify walk speed",
    Value = Config.Speed,
    Callback = bindAutoSave(function(v) Config.Speed = v end)
})

MoveTab:Slider({
    Title = "Walk Speed",
    Desc = "Studs per second",
    Value = { Min = 16, Max = 60, Default = Config.SpeedValue },
    Step = 1,
    Callback = bindAutoSave(function(v) Config.SpeedValue = v end)
})

MoveTab:Toggle({
    Title = "Jump Boost",
    Desc = "Modify jump power",
    Value = Config.JumpEnabled,
    Callback = bindAutoSave(function(v) Config.JumpEnabled = v end)
})

MoveTab:Slider({
    Title = "Jump Power",
    Desc = "Jump power value",
    Value = { Min = 50, Max = 150, Default = Config.JumpValue },
    Step = 5,
    Callback = bindAutoSave(function(v) Config.JumpValue = v end)
})

MoveTab:Toggle({
    Title = "Infinite Jump",
    Desc = "Jump mid-air repeatedly",
    Value = Config.InfiniteJump,
    Callback = bindAutoSave(function(v) Config.InfiniteJump = v end)
})

MoveTab:Toggle({
    Title = "Noclip",
    Desc = "Walk through walls and doors",
    Value = Config.Noclip,
    Callback = bindAutoSave(function(v) Config.Noclip = v end)
})

MoveTab:Toggle({
    Title = "Fly",
    Desc = "WASD + Space / LeftCtrl",
    Value = Config.Fly,
    Callback = bindAutoSave(function(v)
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
    end)
})

MoveTab:Slider({
    Title = "Fly Speed",
    Desc = "Studs per second while flying",
    Value = { Min = 15, Max = 150, Default = Config.FlySpeed },
    Step = 5,
    Callback = bindAutoSave(function(v) Config.FlySpeed = v end)
})

MoveTab:Section({ Title = "Safety" })

MoveTab:Toggle({
    Title = "Anti-Ragdoll",
    Desc = "Prevent ragdoll state",
    Value = Config.AntiRagdoll,
    Callback = bindAutoSave(function(v) Config.AntiRagdoll = v end)
})

MoveTab:Toggle({
    Title = "Anti-Fling",
    Desc = "Blocks other players colliding & flinging you",
    Value = Config.AntiFling,
    Callback = bindAutoSave(function(v) Config.AntiFling = v end)
})

MoveTab:Toggle({
    Title = "Anti-Void",
    Desc = "Floor recovery when flung or falling",
    Value = Config.AntiVoid,
    Callback = bindAutoSave(function(v) Config.AntiVoid = v end)
})

-- ============================================================
-- FARM TAB
-- ============================================================
FarmTab:Toggle({
    Title = "Auto Farm Coins",
    Desc = "Collect all active coins on the map",
    Value = Config.CoinFarm,
    Callback = bindAutoSave(function(v) Config.CoinFarm = v end)
})

FarmTab:Dropdown({
    Title = "Farm Method",
    Desc = "Movement method for farming",
    Values = { "Glide", "Tween", "Walk" },
    Value = Config.FarmMethod,
    Callback = bindAutoSave(function(v) Config.FarmMethod = v end)
})

FarmTab:Slider({
    Title = "Farm Speed",
    Desc = "Movement speed while farming",
    Value = { Min = 16, Max = 60, Default = Config.FarmSpeed },
    Step = 1,
    Callback = bindAutoSave(function(v) Config.FarmSpeed = v end)
})

FarmTab:Toggle({
    Title = "Safe Farming",
    Desc = "Skip coins near the Murderer",
    Value = Config.SafeCoinFarm,
    Callback = bindAutoSave(function(v) Config.SafeCoinFarm = v end)
})

FarmTab:Toggle({
    Title = "Bag Full Stop",
    Desc = "Auto-stop at coin cap",
    Value = Config.BagFullStop,
    Callback = bindAutoSave(function(v) Config.BagFullStop = v end)
})

FarmTab:Toggle({
    Title = "Quick Mode",
    Desc = "High-velocity rapid sweep",
    Value = Config.QuickFarm,
    Callback = bindAutoSave(function(v) Config.QuickFarm = v end)
})

FarmTab:Slider({
    Title = "Coin Bag Cap",
    Desc = "Stop farming when bag reaches this",
    Value = { Min = 10, Max = 40, Default = Config.CoinBagCap },
    Step = 1,
    Callback = bindAutoSave(function(v) Config.CoinBagCap = v end)
})

-- ============================================================
-- SURVIVAL TAB
-- ============================================================
SurvTab:Toggle({
    Title = "Murderer Avoidance",
    Desc = "Maneuver away from active Murderer",
    Value = Config.MurdererAvoid,
    Callback = bindAutoSave(function(v) Config.MurdererAvoid = v end)
})

SurvTab:Slider({
    Title = "Safety Radius",
    Desc = "Minimum distance kept from Murderer",
    Value = { Min = 20, Max = 80, Default = Config.SafetyRadius },
    Step = 5,
    Callback = bindAutoSave(function(v) Config.SafetyRadius = v end)
})

SurvTab:Toggle({
    Title = "Retreat to Lobby",
    Desc = "Teleport to lobby if Murderer too close",
    Value = Config.RetreatToLobby,
    Callback = bindAutoSave(function(v) Config.RetreatToLobby = v end)
})

SurvTab:Toggle({
    Title = "Proximity Alert",
    Desc = "On-screen alert when Murderer approaches",
    Value = Config.ProximityAlert,
    Callback = bindAutoSave(function(v) Config.ProximityAlert = v end)
})

SurvTab:Toggle({
    Title = "Sprint When Chased",
    Desc = "Speed up when Murderer is near",
    Value = Config.SprintWhenChased,
    Callback = bindAutoSave(function(v) Config.SprintWhenChased = v end)
})

SurvTab:Toggle({
    Title = "Follow Murderer",
    Desc = "Maintain distance behind the Murderer",
    Value = Config.FollowMurderer,
    Callback = bindAutoSave(function(v) Config.FollowMurderer = v end)
})

SurvTab:Slider({
    Title = "Follow Distance",
    Desc = "Distance kept while following",
    Value = { Min = 8, Max = 40, Default = Config.FollowDist },
    Step = 1,
    Callback = bindAutoSave(function(v) Config.FollowDist = v end)
})

SurvTab:Toggle({
    Title = "Role-Based Auto Play",
    Desc = "Automates according to your current role",
    Value = Config.AutoPlay,
    Callback = bindAutoSave(function(v) Config.AutoPlay = v end)
})

-- ============================================================
-- TELEPORTS TAB
-- ============================================================
TPTime:Button({
    Title = "Teleport to Murderer",
    Desc = "Behind the active Murderer",
    Callback = function()
        local m = select(1, getRolePlayers())
        local myRoot = getHRP(LP)
        if m and myRoot then
            local mr = getHRP(m)
            if mr then myRoot.CFrame = mr.CFrame * CFrame.new(0, 0, 4)
                WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Teleported to " .. m.Name, Duration = 2 }) end
        else
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Murderer not found.", Duration = 2 })
        end
    end
})

TPTime:Button({
    Title = "Teleport to Sheriff",
    Desc = "Next to the active Sheriff",
    Callback = function()
        local _, s = getRolePlayers()
        local myRoot = getHRP(LP)
        if s and myRoot then
            local sr = getHRP(s)
            if sr then myRoot.CFrame = sr.CFrame * CFrame.new(0, 0, 4)
                WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Teleported to " .. s.Name, Duration = 2 }) end
        else
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Sheriff not found.", Duration = 2 })
        end
    end
})

TPTime:Button({
    Title = "Teleport to Active Map",
    Desc = "Jump to map spawns",
    Callback = function()
        local map = getActiveMap()
        local myRoot = getHRP(LP)
        if map and myRoot then
            local sp = map:FindFirstChild("Spawns")
            if sp and #sp:GetChildren() > 0 then
                myRoot.CFrame = sp:GetChildren()[1].CFrame * CFrame.new(0, 3, 0)
            else
                local p = map:FindFirstChildWhichIsA("BasePart")
                if p then myRoot.CFrame = p.CFrame * CFrame.new(0, 5, 0) end
            end
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Teleported to " .. map.Name, Duration = 2 })
        else
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "No active map.", Duration = 2 })
        end
    end
})

TPTime:Button({
    Title = "Teleport to Lobby",
    Desc = "Lobby safe area",
    Callback = function()
        local lb = getLobbyModel()
        local myRoot = getHRP(LP)
        if lb and myRoot then
            local p = lb:FindFirstChildWhichIsA("BasePart") or (lb:FindFirstChild("Spawns") and lb.Spawns:GetChildren()[1])
            if p then myRoot.CFrame = p.CFrame * CFrame.new(0, 3, 0)
                WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Teleported to Lobby", Duration = 2 }) end
        end
    end
})

TPTime:Toggle({
    Title = "Auto Drop at Round Start",
    Desc = "Drops into map when round begins",
    Value = Config.AutoDrop,
    Callback = bindAutoSave(function(v) Config.AutoDrop = v end)
})

TPTime:Section({ Title = "Saved Coordinates" })

TPTime:Button({
    Title = "Save Location 1",
    Desc = "Stores current position in Slot 1",
    Callback = function()
        local myRoot = getHRP(LP)
        if myRoot then
            Config.SaveSlot1 = myRoot.CFrame
            AutoSaveConfig()
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Slot 1 saved.", Duration = 2 })
        end
    end
})

TPTime:Button({
    Title = "Teleport Location 1",
    Desc = "Return to Slot 1",
    Callback = function()
        local myRoot = getHRP(LP)
        if myRoot and Config.SaveSlot1 then
            myRoot.CFrame = Config.SaveSlot1
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "To Slot 1.", Duration = 2 })
        else
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "No Slot 1 saved.", Duration = 2 })
        end
    end
})

TPTime:Button({
    Title = "Save Location 2",
    Desc = "Stores current position in Slot 2",
    Callback = function()
        local myRoot = getHRP(LP)
        if myRoot then
            Config.SaveSlot2 = myRoot.CFrame
            AutoSaveConfig()
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Slot 2 saved.", Duration = 2 })
        end
    end
})

TPTime:Button({
    Title = "Teleport Location 2",
    Desc = "Return to Slot 2",
    Callback = function()
        local myRoot = getHRP(LP)
        if myRoot and Config.SaveSlot2 then
            myRoot.CFrame = Config.SaveSlot2
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "To Slot 2.", Duration = 2 })
        else
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "No Slot 2 saved.", Duration = 2 })
        end
    end
})

-- ============================================================
-- TROLLING TAB
-- ============================================================
TrollTab:Button({
    Title = "Fling Murderer",
    Desc = "Send the Murderer across the map",
    Callback = function()
        local m = select(1, getRolePlayers())
        if m and m.Character then
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Flinging " .. m.Name .. "...", Duration = 2 })
            task.spawn(flingCharacter, m.Character)
        else
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Murderer not found.", Duration = 2 })
        end
    end
})

TrollTab:Button({
    Title = "Fling Sheriff",
    Desc = "Send the Sheriff across the map",
    Callback = function()
        local _, s = getRolePlayers()
        if s and s.Character then
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Flinging " .. s.Name .. "...", Duration = 2 })
            task.spawn(flingCharacter, s.Character)
        else
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Sheriff not found.", Duration = 2 })
        end
    end
})

TrollTab:Dropdown({
    Title = "Fling Style",
    Desc = "Physics technique for flinging",
    Values = { "Torque", "Velocity", "Orbit" },
    Value = Config.FlingStyle,
    Callback = bindAutoSave(function(v) Config.FlingStyle = v end)
})

-- ============================================================
-- MISC TAB
-- ============================================================
MiscTab:Section({ Title = "Configuration" })

MiscTab:Button({
    Title = "Save Configuration",
    Desc = "Write all current settings to disk",
    Callback = function()
        AutoSaveConfig()
        WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Config saved.", Duration = 2 })
    end
})

MiscTab:Button({
    Title = "Reload Configuration",
    Desc = "Restore settings from disk",
    Callback = function()
        if LoadSavedConfig() then
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Config loaded.", Duration = 2 })
        else
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "No config found.", Duration = 2 })
        end
    end
})

MiscTab:Button({
    Title = "Reset to Defaults",
    Desc = "Restore all defaults",
    Callback = function()
        for k, v in pairs(DefaultConfig) do Config[k] = v end
        AutoSaveConfig()
        WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Defaults restored.", Duration = 2 })
    end
})

MiscTab:Section({ Title = "Character & Info" })

MiscTab:Button({
    Title = "Reset Character",
    Desc = "Safely respawn",
    Callback = function()
        local h = getHumanoid(LP)
        if h then h.Health = 0 end
    end
})

MiscTab:Button({
    Title = "Announce Roles",
    Desc = "Post Murderer & Sheriff to chat",
    Callback = function()
        local m, s = getRolePlayers()
        local msg = "[ENI] "
        msg = msg .. "Murderer: " .. (m and m.Name or "?") .. " | "
        msg = msg .. "Sheriff: " .. (s and s.Name or "?")
        local ch = TextChatService:FindFirstChild("TextChannels")
        local ch2 = ch and ch:FindFirstChild("RBXGeneral")
        if ch2 and ch2.SendAsync then
            ch2:SendAsync(msg)
        else
            pcall(function()
                local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                local say = ev and ev:FindFirstChild("SayMessageRequest")
                if say then say:FireServer(msg, "All") end
            end)
        end
        WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Announced roles.", Duration = 2 })
    end
})

MiscTab:Button({
    Title = "Copy Death List",
    Desc = "Copy deceased players to clipboard",
    Callback = function()
        if #State.DeadPlayers == 0 then
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "No deaths recorded.", Duration = 2 })
            return
        end
        local txt = "MM2 Dead: " .. table.concat(State.DeadPlayers, ", ")
        if setclipboard then
            setclipboard(txt)
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Copied.", Duration = 2 })
        end
    end
})

MiscTab:Toggle({
    Title = "Death Notifications",
    Desc = "Alert on each death with role tag",
    Value = Config.DeathNotifs,
    Callback = bindAutoSave(function(v) Config.DeathNotifs = v end)
})

MiscTab:Section({ Title = "Server" })

MiscTab:Button({
    Title = "Rejoin Server",
    Desc = "Rejoin this exact server",
    Callback = function()
        local qot = (syn and syn.queue_on_teleport) or queue_on_teleport or queueonteleport
        if qot then
            pcall(qot, [[
                task.spawn(function()
                    repeat task.wait(0.5) until game:IsLoaded()
                    task.wait(1)
                    if isfile and isfile("ENI_MM2.lua") then loadstring(readfile("ENI_MM2.lua"))() end
                end)
            ]])
        end
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end
})

MiscTab:Button({
    Title = "Server Hop (Random)",
    Desc = "Random populated server",
    Callback = function()
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
        WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "No server found.", Duration = 2 })
    end
})

MiscTab:Button({
    Title = "Server Hop (Low Pop)",
    Desc = "Find a low population server for farming",
    Callback = function()
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
        WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "No low-pop server found.", Duration = 2 })
    end
})

MiscTab:Section({ Title = "Environment" })

MiscTab:Toggle({
    Title = "Anti-AFK",
    Desc = "Prevent idle disconnect",
    Value = Config.AntiAFK,
    Callback = bindAutoSave(function(v) Config.AntiAFK = v end)
})

MiscTab:Button({
    Title = "Unload ENI's MM2 Hub",
    Desc = "Disable everything & remove UI",
    Callback = function()
        if getgenv().ENI_MM2_Unload then
            getgenv().ENI_MM2_Unload()
        end
    end
})

-- ============================================================
-- INFO PANEL (Round Status / Murderer / Sheriff)
-- ============================================================
local InfoTab = Window:Tab({ Title = "Info", Icon = "info" })

InfoTab:Section({ Title = "Round Status" })

local statusPara = InfoTab:Paragraph({ Title = "Waiting...", Desc = "Round state", Image = nil })
local timerPara  = InfoTab:Paragraph({ Title = "0:00",       Desc = "Time remaining" })
local murderPara = InfoTab:Paragraph({ Title = "Undetected", Desc = "Murderer" })
local sherifPara = InfoTab:Paragraph({ Title = "Undetected", Desc = "Sheriff" })

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
                    statusPara:SetTitle(cr.Text)
                    timerPara:SetTitle(tm.Text)
                end)
                if cr.Text == "Current Round" and not State.RoundStartedFlag then
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
                elseif cr.Text ~= "Current Round" then
                    State.RoundStartedFlag = false
                end
            end
        end
        local m, s = getRolePlayers()
        pcall(function()
            murderPara:SetTitle(m and (m.Name .. (isAlive(m) and "" or " [DEAD]")) or "Undetected")
            sherifPara:SetTitle(s and (s.Name .. (isAlive(s) and "" or " [DEAD]")) or "Undetected")
        end)
    end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
local heartbeat = RunService.Heartbeat:Connect(function()
    local now = tick()
    local myChar = LP.Character
    local myRoot = getHRP(LP)
    local myHum  = getHumanoid(LP)

    -- ==== ESP refresh ====
    if Config.RoleESP and myRoot then
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
                        getOrCreateBillboard("bb_" .. p.UserId, pRoot, txt, col)
                        if Config.ESPBoxes then getOrCreateBox("bx_" .. p.UserId, pRoot, col) end
                        if Config.ESPChams then getOrCreateCham(p.UserId, p.Character, col) end
                        updateTracer("tr_" .. p.UserId, pRoot.Position, col)
                    end
                end
            else
                local bb = State.Highlights["bb_" .. p.UserId]
                if bb then bb:Destroy() State.Highlights["bb_" .. p.UserId] = nil end
                local bx = State.Boxes["bx_" .. p.UserId]
                if bx then bx:Destroy() State.Boxes["bx_" .. p.UserId] = nil end
                local ch = State.Highlights["cham_" .. p.UserId]
                if ch then ch:Destroy() State.Highlights["cham_" .. p.UserId] = nil end
                removeTracer("tr_" .. p.UserId)
            end
        end
    elseif not Config.RoleESP then
        clearCategory(State.Highlights)
        clearCategory(State.Boxes)
        clearCategory(State.Tracers)
    end

    -- ==== Item ESP (throttled) ====
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

    -- ==== Aimbot (camera) ====
    if Config.Aimbot then
        local tgt = nearestTarget()
        if tgt then
            local tRoot = getHRP(tgt)
            if tRoot then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, tRoot.Position)
            end
        end
    end

    -- ==== Fly ====
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

    -- ==== Noclip ====
    if Config.Noclip and myChar then
        for _, p in ipairs(myChar:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end

    -- ==== Speed / Jump ====
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

    -- ==== Anti-Ragdoll ====
    if Config.AntiRagdoll and myHum then
        pcall(function()
            myHum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            myHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end)
        myHum.PlatformStand = false
    end

    -- ==== Environment ====
    if Config.Fullbright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
    end
    if Config.NoFog then Lighting.FogEnd = 1e6 end

    if Config.DisableParticles then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ParticleEmitter") then d.Enabled = false end
        end
    end

    -- ==== Anti-Fling / Anti-Void (uses safe position) ====
    if myRoot and myHum then
        local vel = myRoot.AssemblyLinearVelocity
        local ang = myRoot.AssemblyAngularVelocity
        local velMag = vel.Magnitude
        local angMag = ang.Magnitude

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

    -- ==== Aura Ring / FOV Circle ====
    updateAuraRing(myRoot)
    updateFOVCircle()

    -- ==== Auto-Shoot ====
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

    -- ==== Kill Aura / Auto Kill / Auto Stab ====
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

    -- ==== Hitbox Expander ====
    if Config.HitboxExpander then
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

    -- ==== Full Gun Grabber ====
    if Config.GrabGunAuto and myRoot then
        local gd = getGunDrop()
        local gp = getGunDropPart(gd)
        if gp and (myRoot.Position - gp.Position).Magnitude <= Config.GunGrabDist then
            interactWithGunDrop(gp, gd)
        end
    end

    -- ==== Murderer Avoid / Follow ====
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
                -- light on-screen hint via notification (throttled by proximity)
                if not State.Alerted or now - State.Alerted > 3 then
                    State.Alerted = now
                    WindUI:Notify({ Title = "⚠ MURDERER NEAR", Content = "Distance: " .. math.floor(dist) .. " studs", Duration = 2 })
                end
            end
            if Config.FollowMurderer then
                local target = mRoot.Position - (mRoot.CFrame.LookVector * Config.FollowDist)
                myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.new(target, mRoot.Position), 0.15)
            end
        end
    end

    -- ==== Coin Farm ====
    if Config.CoinFarm and myRoot and now - State.LastFarmTick >= 0.05 then
        if Config.BagFullStop and getCurrentCoinCount() >= Config.CoinBagCap then
            Config.CoinFarm = false
            WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "Coin bag full. Farming stopped.", Duration = 3 })
        else
            local coins = getAllActiveCoins()
            local best, bestDist = nil, 1000
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

                if myChar then
                    for _, part in ipairs(myChar:GetChildren()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end

                local spd = Config.QuickFarm and 38 or math.clamp(Config.FarmSpeed, 16, 42)

                if Config.FarmMethod == "Tween" then
                    local t = math.max(dist / spd, 0.05)
                    TweenService:Create(myRoot, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)}):Play()
                    if dist < 7 then
                        fireTouch(myRoot, best)
                        local rh = myChar:FindFirstChild("RightHand") or myChar:FindFirstChild("Right Arm")
                        if rh then fireTouch(rh, best) end
                    end
                elseif Config.FarmMethod == "Glide" or Config.QuickFarm then
                    local dir = (targetPos - myRoot.Position)
                    if dir.Magnitude > 0.3 then
                        myRoot.AssemblyLinearVelocity = dir.Unit * spd
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

    -- ==== Auto Play (light) ====
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
                WindUI:Notify({ Title = "Death", Content = p.Name .. " [" .. r .. "]", Duration = 3 })
            end
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
-- INPUT: INFINITE JUMP, TOGGLE, EMERGENCY STOP
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
        WindUI:Notify({ Title = "ENI's MM2 Hub", Content = "EMERGENCY STOP - features halted.", Duration = 3 })
    end
end))

-- ============================================================
-- ANTI-AFK
-- ============================================================
LP.Idled:Connect(function()
    if Config.AntiAFK then
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new(0, 0))
    end
end)

-- ============================================================
-- UNLOAD
-- ============================================================
getgenv().ENI_MM2_Unload = function()
    State.SilentAimHookActive = false
    for _, c in ipairs(activeConnections) do
        pcall(function() c:Disconnect() end)
    end
    clearCategory(State.Highlights)
    clearCategory(State.Boxes)
    clearCategory(State.ItemHighlights)
    for id in pairs(State.Tracers) do
        pcall(function() State.Tracers[id]:Remove() end)
    end
    if State.AuraRing then pcall(function() State.AuraRing:Destroy() end) State.AuraRing = nil end
    if State.FOVCircle then pcall(function() State.FOVCircle:Remove() end) State.FOVCircle = nil end
    for part, sz in pairs(State.OriginalHitboxSizes) do
        if part and part.Parent then
            part.Size = sz
            part.Transparency = 1
        end
    end
    if State.flyBV then pcall(function() State.flyBV:Destroy() end) end
    if screenGui and screenGui.Parent then screenGui:Destroy() end
    getgenv().ENI_MM2_Unload = nil
end

-- ============================================================
-- LOADED NOTIFICATION
-- ============================================================
WindUI:Notify({
    Title = "ENI's MM2 Hub",
    Content = "Loaded. Press END for emergency stop.",
    Duration = 4,
})
