-- =====================================================
-- ByPass Drone Front FINAL v4
-- Ballistic Lead Aimbot + ESP + Fullbright + Menu
-- =====================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LS = game:GetService("Lighting")
local WS = workspace
local LP = Players.LocalPlayer
local Camera = WS.CurrentCamera

-- === UI LIBRARY ===
local Rayfield
pcall(function()
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

-- =====================================================
-- STATE
-- =====================================================
local S = {
    -- Aimbot
    AimOn = false,
    AimMode = "DronesOnly",
    AimAngle = 30,
    AimSmooth = 0.2,
    AimUseBallistic = true,
    AimBulletSpeed = 600,
    AimMaxDist = 3000,
    AimMinDist = 0,
    AimTeamCheck = true,

    -- FPV
    FPVAimOn = false,
    FPVTarget = "Players",
    FPVAutoLaunch = false,
    FPVLaunchDist = 200,
    FPVAimSmooth = 0.2,

    -- ESP
    ESPPlayers = true,
    ESPDrones = true,
    ESPMissiles = true,
    ESPTurrets = true,
    ESPVehicles = true,
    ESPAmmo = true,
    ESPShowName = true,
    ESPShowDist = true,
    ESPTeamCheck = true,
    ESPMaxDist = 3000,
    ESPMaxTargets = 40,

    -- Movement
    SpeedOn = false,
    SpeedValue = 100,
    JumpOn = false,
    JumpValue = 100,

    -- Spam
    MissileSpam = false,
    MissileDelay = 1,
    DroneSpam = false,
    DroneDelay = 0.5,

    -- Fullbright
    FullbrightOn = false,

    -- Runtime
    IsFiring = false,
    IsAimBtn = false,
    CurrentTarget = nil,
    CurrentAngle = nil,
    CurrentLead = 0,
}

-- =====================================================
-- DATA
-- =====================================================
local DRONE_KEYWORDS = {
    "FPVDrone","AKFPVDrone","oldFPVDrone","InterceptorFPVDrone","KVNFPVDrone","Recon",
    "Drone1","Drone2","Drone3","Drone4","Drone5","Drone6","Drone8","Drone9","Drone10",
    "Drone11","Drone12","Drone13","Drone14","Drone15","Drone16","Drone17","Drone18",
    "Drone19","Drone20","Drone21","Drone22","Drone23","Drone24","Drone25","Drone26",
    "Drone27","Drone28","Drone29","Drone30","Drone31","Drone32","Drone33","Drone34",
    "Drone35","Drone36","Drone37","Drone38","Drone39","Drone40","Drone41","Drone42",
    "Drone43","Drone44","Drone45","Drone46","Drone47","Drone48","Drone49","Drone50",
    "Drone51","Drone52","Drone53","Drone54","Drone55","Drone56","Drone57","Drone58",
    "Drone59","Drone60","Drone61",
    "Flamingo","StormShadow","Zircon","X101","Banderol","Kalibr","X59",
    "OFAB500","OFAB3000","Drone","KVN","UAV"
}
local MISSILE_KEYWORDS = {
    "Flamingo","StormShadow","Zircon","X101","Banderol","Kalibr","X59","OFAB500","OFAB3000"
}
local TURRET_KEYWORDS = {"Strela","Stromer","Shilka","AAGun","Radar","DSHK"}
local VEHICLE_KEYWORDS = {"T-64BV","Tank","Car","Boat"}
local AMMO_KEYWORDS = {"Ammunition","Bomb"}

local ESP_COLORS = {
    Player   = Color3.fromRGB(255, 0, 0),
    FPV      = Color3.fromRGB(255, 100, 0),
    BigDrone = Color3.fromRGB(255, 255, 0),
    Missile  = Color3.fromRGB(255, 0, 255),
    Turret   = Color3.fromRGB(0, 255, 255),
    Vehicle  = Color3.fromRGB(150, 0, 255),
    Ammo     = Color3.fromRGB(200, 200, 200),
}

-- =====================================================
-- HELPERS
-- =====================================================
local function matchAny(name, list)
    for _, k in pairs(list) do
        if string.find(name, k) then return true end
    end
    return false
end

local function isDrone(obj)
    if not obj or not obj:IsA("Model") then return false end
    if matchAny(obj.Name, DRONE_KEYWORDS) then return true end
    if obj:FindFirstChild("Propeller_FL") or obj:FindFirstChild("Warhead") then return true end
    return false
end

local function isMissile(obj)
    if not obj or not obj:IsA("Model") then return false end
    return matchAny(obj.Name, MISSILE_KEYWORDS)
end

local function isEnemyPlayer(p)
    if p == LP then return false end
    if not S.AimTeamCheck then return true end
    if not p.Team or not LP.Team then return true end
    return p.Team ~= LP.Team
end

local function getMyPos()
    local c = LP.Character
    if not c then return Camera.CFrame.Position end
    local h = c:FindFirstChild("HumanoidRootPart")
    return h and h.Position or Camera.CFrame.Position
end

local function getObjectPos(obj)
    if obj:IsA("Player") then
        local c = obj.Character
        if not c then return nil end
        local h = c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
        return h and h.Position or nil
    elseif obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChild("Body") or obj:FindFirstChildWhichIsA("BasePart")
        return p and p.Position or nil
    end
    return nil
end

local function getObjectVelocity(obj)
    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChild("Body") or obj:FindFirstChildWhichIsA("BasePart")
        if p then return p.AssemblyLinearVelocity end
    elseif obj:IsA("Player") and obj.Character then
        local p = obj.Character:FindFirstChild("HumanoidRootPart")
        if p then return p.AssemblyLinearVelocity end
    end
    return Vector3.new(0, 0, 0)
end

local function angleToTarget(targetPos)
    local camLook = Camera.CFrame.LookVector
    local camPos = Camera.CFrame.Position
    local toTarget = (targetPos - camPos).Unit
    local dot = camLook:Dot(toTarget)
    dot = math.clamp(dot, -1, 1)
    return math.deg(math.acos(dot))
end

-- =====================================================
-- BALLISTIC LEAD — предсказание по скорости и дистанции
-- =====================================================
local function calculateLeadPrediction(shooterPos, targetPos, targetVel)
    if not targetPos then return targetPos, 0 end
    if not targetVel or targetVel.Magnitude < 1 then
        return targetPos, 0
    end

    local D = targetPos - shooterPos
    local Vt = targetVel
    local S_bullet = S.AimBulletSpeed

    local a = Vt:Dot(Vt) - S_bullet * S_bullet
    local b = 2 * D:Dot(Vt)
    local c = D:Dot(D)

    -- Линейный случай
    if math.abs(a) < 1e-6 then
        if math.abs(b) < 1e-6 then return targetPos, 0 end
        local t = -c / b
        if t > 0 then
            return targetPos + Vt * t, math.clamp(t, 0, 3)
        end
        return targetPos, 0
    end

    local disc = b*b - 4*a*c
    if disc < 0 then return targetPos, 0 end

    local sqrtDisc = math.sqrt(disc)
    local t1 = (-b - sqrtDisc) / (2*a)
    local t2 = (-b + sqrtDisc) / (2*a)

    local t = nil
    if t1 > 0 and t2 > 0 then t = math.min(t1, t2)
    elseif t1 > 0 then t = t1
    elseif t2 > 0 then t = t2
    else return targetPos, 0 end

    t = math.clamp(t, 0, 2)
    return targetPos + Vt * t, t
end

-- =====================================================
-- ЛОВИМ ВЫСТРЕЛ
-- =====================================================
local fireEvent = RS:FindFirstChild("FireGunEvent")
if fireEvent then
    fireEvent.OnClientEvent:Connect(function()
        S.IsFiring = true
        task.delay(0.15, function() S.IsFiring = false end)
    end)
end

-- =====================================================
-- КНОПКА AIM — ПРАВЫЙ ВЕРХНИЙ УГОЛ
-- =====================================================
local aimGui = Instance.new("ScreenGui")
aimGui.Name = "ByPassAimBtn"
aimGui.ResetOnSpawn = false
aimGui.Parent = LP:WaitForChild("PlayerGui")

local aimBtn = Instance.new("TextButton")
aimBtn.Size = UDim2.new(0, 110, 0, 110)
-- ПРАВЫЙ ВЕРХНИЙ УГОЛ
aimBtn.Position = UDim2.new(1, -130, 0, 60)
aimBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
aimBtn.BackgroundTransparency = 0.3
aimBtn.Text = "AIM"
aimBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
aimBtn.TextScaled = true
aimBtn.Font = Enum.Font.GothamBold
aimBtn.Parent = aimGui

aimBtn.MouseButton1Down:Connect(function() S.IsAimBtn = true end)
aimBtn.MouseButton1Up:Connect(function() S.IsAimBtn = false end)
aimBtn.TouchLongPress:Connect(function() S.IsAimBtn = true end)
aimBtn.TouchTap:Connect(function() S.IsAimBtn = false end)

-- =====================================================
-- HUD ИНДИКАТОР ЦЕЛИ
-- =====================================================
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "ByPassTargetHUD"
hudGui.ResetOnSpawn = false
hudGui.Parent = LP:WaitForChild("PlayerGui")

local hudLabel = Instance.new("TextLabel")
hudLabel.Size = UDim2.new(0, 500, 0, 40)
hudLabel.Position = UDim2.new(0.5, -250, 0, 90)
hudLabel.BackgroundTransparency = 0.5
hudLabel.BackgroundColor3 = Color3.new(0, 0, 0)
hudLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
hudLabel.TextScaled = true
hudLabel.Font = Enum.Font.Code
hudLabel.Text = ""
hudLabel.Parent = hudGui

-- =====================================================
-- AIMBOT
-- =====================================================
local function getClosestDroneByAngle()
    local maxAngle = S.AimAngle
    local best, bestAngle, bestPos, bestVel = nil, maxAngle, nil, nil
    local myPos = getMyPos()

    for _, obj in pairs(WS:GetChildren()) do
        if isDrone(obj) then
            local pos = getObjectPos(obj)
            if pos then
                local wd = (pos - myPos).Magnitude
                if wd >= S.AimMinDist and wd <= S.AimMaxDist then
                    local ang = angleToTarget(pos)
                    if ang < bestAngle then
                        bestAngle = ang
                        best = obj
                        bestPos = pos
                        bestVel = getObjectVelocity(obj)
                    end
                end
            end
        end
    end
    return best, bestPos, bestVel, bestAngle
end

local function getClosestPlayerByAngle()
    local maxAngle = S.AimAngle
    local best, bestAngle, bestPos, bestVel = nil, maxAngle, nil, nil
    local myPos = getMyPos()

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and isEnemyPlayer(p) and p.Character then
            local head = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
            if head then
                local wd = (head.Position - myPos).Magnitude
                if wd >= S.AimMinDist and wd <= S.AimMaxDist then
                    local ang = angleToTarget(head.Position)
                    if ang < bestAngle then
                        bestAngle = ang
                        best = p
                        bestPos = head.Position
                        bestVel = getObjectVelocity(p)
                    end
                end
            end
        end
    end
    return best, bestPos, bestVel, bestAngle
end

local function getTarget()
    if S.AimMode == "DronesOnly" then
        return getClosestDroneByAngle()
    elseif S.AimMode == "PlayersOnly" then
        return getClosestPlayerByAngle()
    elseif S.AimMode == "Both" then
        local d, dp, dv, da = getClosestDroneByAngle()
        local p, pp, pv, pa = getClosestPlayerByAngle()
        if d and p then
            if (da or 999) < (pa or 999) then return d, dp, dv, da else return p, pp, pv, pa end
        end
        return d or p, dp or pp, dv or pv, da or pa
    end
    return nil, nil, nil, nil
end

RunService.RenderStepped:Connect(function()
    if not S.AimOn then
        S.CurrentTarget = nil
        hudLabel.Text = ""
        return
    end

    local aiming = S.IsFiring or S.IsAimBtn
    if not aiming then
        hudLabel.Text = "[AIM] ожидание..."
        hudLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        return
    end

    local t, pos, vel, ang = getTarget()
    S.CurrentTarget = t
    S.CurrentAngle = ang

    if t and pos then
        local shooterPos = Camera.CFrame.Position
        local predPos, predTime = pos, 0

        if S.AimUseBallistic and vel and vel.Magnitude > 1 then
            predPos, predTime = calculateLeadPrediction(shooterPos, pos, vel)
        end

        S.CurrentLead = predTime or 0

        local goal = CFrame.new(shooterPos, predPos)
        Camera.CFrame = Camera.CFrame:Lerp(goal, 1 - S.AimSmooth)

        local name = t.Name
        local dist = math.floor((pos - shooterPos).Magnitude)
        hudLabel.Text = string.format("[AIM] %s | %d st | %.1f° | lead %.2fs",
            name, dist, ang or 0, predTime or 0)
        hudLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        hudLabel.Text = "[AIM] нет цели"
        hudLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    end
end)

-- =====================================================
-- FPV AIMBOT
-- =====================================================
local function getMyFPV()
    for _, obj in pairs(WS:GetChildren()) do
        if isDrone(obj) and string.find(obj.Name, LP.Name) then
            return obj
        end
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    if not S.FPVAimOn then return end
    local drone = getMyFPV()
    if not drone then return end
    local dronePos = getObjectPos(drone)
    if not dronePos then return end

    local targetPos = nil
    if S.FPVTarget == "Players" or S.FPVTarget == "Any" then
        local best, bestD = nil, 500
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LP and isEnemyPlayer(p) and p.Character then
                local head = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
                if head then
                    local d = (head.Position - dronePos).Magnitude
                    if d < bestD then bestD = d; best = head end
                end
            end
        end
        if best then targetPos = best.Position end
    end
    if S.FPVTarget == "Drones" or S.FPVTarget == "Any" then
        local best, bestD = nil, 500
        for _, obj in pairs(WS:GetChildren()) do
            if isDrone(obj) and obj ~= drone then
                local pos = getObjectPos(obj)
                if pos then
                    local d = (pos - dronePos).Magnitude
                    if d < bestD then bestD = d; best = pos end
                end
            end
        end
        if best and (not targetPos or bestD < (targetPos - dronePos).Magnitude) then
            targetPos = best
        end
    end

    if targetPos then
        local goal = CFrame.new(Camera.CFrame.Position, targetPos)
        Camera.CFrame = Camera.CFrame:Lerp(goal, 1 - S.FPVAimSmooth)

        if S.FPVAutoLaunch then
            local d = (targetPos - Camera.CFrame.Position).Magnitude
            if d < S.FPVLaunchDist then
                local fpv = RS:FindFirstChild("FPVRemotes")
                if fpv then
                    local lm = fpv:FindFirstChild("LaunchMissile")
                    if lm then pcall(function() lm:FireServer() end) end
                end
            end
        end
    end
end)

-- =====================================================
-- ESP — с кэшем и оптимизацией
-- =====================================================
local function categorize(obj)
    if not obj or not obj:IsA("Model") then return nil, nil end
    local n = obj.Name
    if matchAny(n, MISSILE_KEYWORDS) then return "Missile", ESP_COLORS.Missile end
    if matchAny(n, DRONE_KEYWORDS) then
        if string.find(n, "Interceptor") or string.find(n, "KVN") or string.find(n, "Recon") then
            return "BigDrone", ESP_COLORS.BigDrone
        end
        return "FPV", ESP_COLORS.FPV
    end
    if obj:FindFirstChild("Propeller_FL") or obj:FindFirstChild("Warhead") then
        return "FPV", ESP_COLORS.FPV
    end
    if matchAny(n, TURRET_KEYWORDS) then return "Turret", ESP_COLORS.Turret end
    if matchAny(n, VEHICLE_KEYWORDS) then return "Vehicle", ESP_COLORS.Vehicle end
    if matchAny(n, AMMO_KEYWORDS) then return "Ammo", ESP_COLORS.Ammo end
    return nil, nil
end

local function addESP(obj, color, name, dist)
    if not obj then return end

    local ex = obj:FindFirstChild("ByPassESP")
    if not ex then
        ex = Instance.new("Highlight")
        ex.Name = "ByPassESP"
        ex.Adornee = obj
        ex.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        ex.Parent = obj
    end
    ex.FillColor = color
    ex.FillTransparency = 0.85
    ex.OutlineColor = color
    ex.OutlineTransparency = 0

    if obj:IsA("Model") then
        local box = obj:FindFirstChild("ByPassBox")
        if not box then
            box = Instance.new("SelectionBox")
            box.Name = "ByPassBox"
            box.Adornee = obj
            box.LineThickness = 0.15
            box.Transparency = 0
            box.SurfaceTransparency = 0.9
            box.Parent = obj
        end
        box.Color3 = color
        box.SurfaceColor3 = color
    end

    local bg = obj:FindFirstChild("ByPassLabel")
    if not bg then
        local head = obj:FindFirstChild("Head")
                  or obj:FindFirstChild("HumanoidRootPart")
                  or obj:FindFirstChild("Body")
                  or obj.PrimaryPart
                  or obj:FindFirstChildWhichIsA("BasePart")
        if head then
            bg = Instance.new("BillboardGui")
            bg.Name = "ByPassLabel"
            bg.Adornee = head
            bg.Size = UDim2.new(0, 200, 0, 50)
            bg.StudsOffset = Vector3.new(0, 3, 0)
            bg.AlwaysOnTop = true
            bg.Parent = obj

            local lbl = Instance.new("TextLabel")
            lbl.Name = "Text"
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = color
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
            lbl.TextScaled = false
            lbl.Font = Enum.Font.GothamBold
            lbl.Text = name or obj.Name
            lbl.Parent = bg
        end
    end

    if bg then
        local lbl = bg:FindFirstChild("Text")
        if lbl then
            lbl.TextColor3 = color
            local fontSize = math.clamp(2000 / math.max(dist or 100, 20), 14, 90)
            lbl.TextSize = fontSize
            local boxH = fontSize * 2
            bg.Size = UDim2.new(0, boxH * 4, 0, boxH)

            local txt = name or obj.Name
            if S.ESPShowDist and dist then
                txt = txt .. "\n" .. dist .. "m"
            end
            lbl.Text = txt
        end
    end
end

local function removeESP(obj)
    if not obj then return end
    local h = obj:FindFirstChild("ByPassESP"); if h then h:Destroy() end
    local b = obj:FindFirstChild("ByPassLabel"); if b then b:Destroy() end
    local s = obj:FindFirstChild("ByPassBox"); if s then s:Destroy() end
end

local function getDist(obj)
    local pos = getObjectPos(obj)
    if not pos then return math.huge end
    return (pos - getMyPos()).Magnitude
end

-- Кэш для ESP
local cachedDrones = {}
local cachedTurrets = {}
local cachedVehicles = {}
local cachedAmmo = {}
local lastScan = 0
local SCAN_INTERVAL = 0.5

local function scanWorld()
    local drones, turrets, vehicles, ammo = {}, {}, {}, {}
    for _, obj in pairs(WS:GetChildren()) do
        if obj:IsA("Model") then
            local cat = categorize(obj)
            if cat == "FPV" or cat == "BigDrone" or cat == "Missile" then
                table.insert(drones, obj)
            elseif cat == "Turret" then table.insert(turrets, obj)
            elseif cat == "Vehicle" then table.insert(vehicles, obj)
            elseif cat == "Ammo" then table.insert(ammo, obj)
            end
        end
    end
    cachedDrones = drones
    cachedTurrets = turrets
    cachedVehicles = vehicles
    cachedAmmo = ammo
end

local function updateESP()
    local now = tick()
    if now - lastScan > SCAN_INTERVAL then
        lastScan = now
        scanWorld()
    end

    -- Игроки
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local isE = (not S.ESPTeamCheck) or isEnemyPlayer(p)
            if S.ESPPlayers and isE and getDist(p.Character) < S.ESPMaxDist then
                addESP(p.Character, ESP_COLORS.Player, p.Name, math.floor(getDist(p.Character)))
            else
                removeESP(p.Character)
            end
        end
    end

    -- Дроны
    if S.ESPDrones then
        local shown = 0
        for _, obj in pairs(cachedDrones) do
            if shown >= S.ESPMaxTargets then break end
            local d = getDist(obj)
            if d < S.ESPMaxDist then
                local _, color = categorize(obj)
                addESP(obj, color or ESP_COLORS.FPV, obj.Name, math.floor(d))
                shown = shown + 1
            else
                removeESP(obj)
            end
        end
    else
        for _, obj in pairs(cachedDrones) do removeESP(obj) end
    end

    -- Турели
    if S.ESPTurrets then
        for _, obj in pairs(cachedTurrets) do
            local d = getDist(obj)
            if d < S.ESPMaxDist then
                addESP(obj, ESP_COLORS.Turret, obj.Name, math.floor(d))
            else
                removeESP(obj)
            end
        end
    else
        for _, obj in pairs(cachedTurrets) do removeESP(obj) end
    end

    -- Транспорт
    if S.ESPVehicles then
        for _, obj in pairs(cachedVehicles) do
            local d = getDist(obj)
            if d < S.ESPMaxDist then
                addESP(obj, ESP_COLORS.Vehicle, obj.Name, math.floor(d))
            else
                removeESP(obj)
            end
        end
    else
        for _, obj in pairs(cachedVehicles) do removeESP(obj) end
    end

    -- Боеприпасы
    if S.ESPAmmo then
        for _, obj in pairs(cachedAmmo) do
            local d = getDist(obj)
            if d < S.ESPMaxDist then
                addESP(obj, ESP_COLORS.Ammo, obj.Name, math.floor(d))
            else
                removeESP(obj)
            end
        end
    else
        for _, obj in pairs(cachedAmmo) do removeESP(obj) end
    end
end

-- ESP — раз в 0.1 сек, чтобы не лагало
task.spawn(function()
    while task.wait(0.1) do
        if S.ESPPlayers or S.ESPDrones or S.ESPTurrets or S.ESPVehicles or S.ESPAmmo then
            updateESP()
        end
    end
end)

-- =====================================================
-- SPEED / JUMP
-- =====================================================
local function applySpeed()
    local c = LP.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then
        h.WalkSpeed = S.SpeedOn and S.SpeedValue or 16
        h.JumpPower = S.JumpOn and S.JumpValue or 50
    end
end
RunService.Heartbeat:Connect(function() if S.SpeedOn or S.JumpOn then applySpeed() end end)
LP.CharacterAdded:Connect(function() task.wait(1); applySpeed() end)

-- =====================================================
-- FULLBRIGHT (стабильный)
-- =====================================================
local function applyFullbright()
    LS.Brightness = 2
    LS.ClockTime = 14
    LS.GlobalShadows = false
    LS.FogEnd = 100000
    LS.Ambient = Color3.fromRGB(190, 190, 190)
    LS.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
end

local function restoreLighting()
    LS.Brightness = 2
    LS.GlobalShadows = true
    LS.Ambient = Color3.fromRGB(70, 70, 70)
    LS.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end

local brightProps = {"Brightness","ClockTime","GlobalShadows","FogEnd","Ambient","OutdoorAmbient"}
for _, prop in pairs(brightProps) do
    pcall(function()
        LS:GetPropertyChangedSignal(prop):Connect(function()
            if S.FullbrightOn then
                task.defer(applyFullbright)
            end
        end)
    end)
end

local lastFB = false
task.spawn(function()
    while task.wait(0.3) do
        if S.FullbrightOn ~= lastFB then
            lastFB = S.FullbrightOn
            if S.FullbrightOn then applyFullbright() else restoreLighting() end
        end
    end
end)

-- =====================================================
-- SPAM
-- =====================================================
local missiles = {
    RS:FindFirstChild("LaunchTestMissile"),
    RS:FindFirstChild("LaunchTestMissile2"),
    RS:FindFirstChild("BallisticMissileRemote"),
}
task.spawn(function()
    local i = 1
    while task.wait(S.MissileDelay) do
        if S.MissileSpam then
            local r = missiles[i]
            if r then pcall(function() r:FireServer() end) end
            i = (i % #missiles) + 1
        end
    end
end)

task.spawn(function()
    while task.wait(S.DroneDelay) do
        if S.DroneSpam then
            local f = RS:FindFirstChild("FPVRemotes")
            if f then
                local sr = f:FindFirstChild("SpawnRequest")
                if sr then pcall(function() sr:FireServer() end) end
            end
        end
    end
end)

-- =====================================================
-- MENU
-- =====================================================
if Rayfield then
    local Window = Rayfield:CreateWindow({
        Name = "ByPass Drone Front FINAL v4",
        LoadingTitle = "Загрузка...",
        LoadingSubtitle = "by ByPass",
        ConfigurationSaving = {Enabled = false},
        KeySystem = false,
    })

    -- AIMBOT
    local AimTab = Window:CreateTab("Aimbot", 4483362458)

    AimTab:CreateToggle({Name = "Aimbot ВКЛ", CurrentValue = false,
        Callback = function(v) S.AimOn = v end})

    AimTab:CreateDropdown({Name = "Цель",
        Options = {"DronesOnly","PlayersOnly","Both"},
        CurrentOption = {"DronesOnly"},
        Callback = function(o) S.AimMode = o[1] end})

    AimTab:CreateSlider({Name = "Угол захвата",
        Range = {5, 90}, Increment = 5, Suffix = "°",
        CurrentValue = 30,
        Callback = function(v) S.AimAngle = v end})

    AimTab:CreateSlider({Name = "Плавность",
        Range = {0, 0.9}, Increment = 0.05,
        CurrentValue = 0.2,
        Callback = function(v) S.AimSmooth = v end})

    AimTab:CreateToggle({Name = "Ballistic Lead (авто)",
        CurrentValue = true,
        Callback = function(v) S.AimUseBallistic = v end})

    AimTab:CreateSlider({Name = "Скорость пули (studs/сек)",
        Range = {100, 3000}, Increment = 50,
        CurrentValue = 600,
        Callback = function(v) S.AimBulletSpeed = v end})

    AimTab:CreateSlider({Name = "Макс дистанция",
        Range = {100, 5000}, Increment = 100, Suffix = " studs",
        CurrentValue = 3000,
        Callback = function(v) S.AimMaxDist = v end})

    AimTab:CreateSlider({Name = "Мин дистанция",
        Range = {0, 500}, Increment = 10, Suffix = " studs",
        CurrentValue = 0,
        Callback = function(v) S.AimMinDist = v end})

    AimTab:CreateToggle({Name = "Проверка команды",
        CurrentValue = true,
        Callback = function(v) S.AimTeamCheck = v end})

    AimTab:CreateSection("FPV Aimbot")

    AimTab:CreateToggle({Name = "FPV Aimbot",
        CurrentValue = false,
        Callback = function(v) S.FPVAimOn = v end})

    AimTab:CreateDropdown({Name = "FPV цель",
        Options = {"Players","Drones","Any"},
        CurrentOption = {"Players"},
        Callback = function(o) S.FPVTarget = o[1] end})

    AimTab:CreateToggle({Name = "FPV авто-пуск",
        CurrentValue = false,
        Callback = function(v) S.FPVAutoLaunch = v end})

    AimTab:CreateSlider({Name = "FPV дистанция пуска",
        Range = {50, 1000}, Increment = 25, Suffix = " studs",
        CurrentValue = 200,
        Callback = function(v) S.FPVLaunchDist = v end
