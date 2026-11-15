--[[
    KurvexUI
    J            - открыть / закрыть меню
    ПКМ по функции - настройки + бинд

    Visuals: TargetESP (Marker / Souls), Arrows, NameTags, Trails, JumpCircles, HUD
    Movement: Sprint (пустышка, внутри KeepSprint)
    Combat: Criticals (пустышка)
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local SoundService     = game:GetService("SoundService")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")
local Workspace        = game:GetService("Workspace")
local Debris           = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer

-- если запустил повторно - старая копия выгружается сама
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.KurvexUI_Unload then pcall(env.KurvexUI_Unload) end

---------------------------------------------------------------------
-- КОНСТАНТЫ / ЦВЕТА
---------------------------------------------------------------------
local CLIENT_NAME = "KurvexUI"
local HUD_ICON    = "rbxassetid://139961945073558" -- твоя декаль для ватермарки

local MAIN_COLOR        = Color3.fromRGB(52, 52, 58)
local BACKGROUND_COLOR  = Color3.fromRGB(24, 24, 27)
local SETTINGS_COLOR    = Color3.fromRGB(28, 28, 32)
local BORDER_COLOR      = Color3.fromRGB(85, 85, 92)
local FUNCTION_BG_COLOR = Color3.fromRGB(45, 45, 51)
local ACCENT_COLOR      = Color3.fromRGB(200, 200, 208)
local OFF_COLOR         = Color3.fromRGB(120, 120, 128)
local ON_COLOR          = Color3.fromRGB(235, 235, 240)
local ROW_COLOR         = Color3.fromRGB(38, 38, 43)
local COLUMN_TRANSP     = 0.1
local CairoFont         = Enum.Font.GothamBold

local COLOR_PRESETS = {
    White  = Color3.fromRGB(255, 255, 255),
    Purple = Color3.fromRGB(165, 120, 255),
    Blue   = Color3.fromRGB(90, 170, 255),
    Red    = Color3.fromRGB(255, 80, 80),
    Green  = Color3.fromRGB(90, 230, 120),
    Pink   = Color3.fromRGB(255, 120, 200),
}
local COLOR_OPTIONS = { "White", "Purple", "Blue", "Red", "Green", "Pink", "Rainbow" }

local function PresetColor(name, offset)
    if name == "Rainbow" then
        return Color3.fromHSV((os.clock() * 0.2 + (offset or 0)) % 1, 0.65, 1)
    end
    return COLOR_PRESETS[name] or COLOR_PRESETS.White
end

---------------------------------------------------------------------
-- ЯДРО: коннекты, очистка, апдейтеры
---------------------------------------------------------------------
local Unloaded = false
local Unload

local Connections = {}
local GuiObjects  = {}
local Cleanups    = {}
local Updaters    = {}

local function Track(conn) table.insert(Connections, conn); return conn end
local function OnUnload(fn) table.insert(Cleanups, fn) end
local function AddUpdater(name, fn) table.insert(Updaters, { name = name, fn = fn }) end

local function Corner(parent, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = parent; return c
end
local function Stroke(parent, color, thick, transp)
    local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thick or 1
    s.Transparency = transp or 0; s.Parent = parent; return s
end

-- CoreGui -> gethui -> PlayerGui, что сработает
local function MountGui(gui, keep)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
    end)
    local ok = pcall(function() gui.Parent = CoreGui end)
    if not ok or not gui.Parent then
        local ok2 = false
        if type(gethui) == "function" then
            ok2 = pcall(function() gui.Parent = gethui() end)
        end
        if not ok2 or not gui.Parent then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
    if keep then table.insert(GuiObjects, gui) end
    return gui
end

local Blur = Instance.new("BlurEffect")
Blur.Name = "KurvexUI_Blur"
Blur.Size = 0
Blur.Parent = Lighting

---------------------------------------------------------------------
-- ЗВУК
---------------------------------------------------------------------
local SOUNDS = {
    ToggleOn  = "rbxassetid://7249904928",
    ToggleOff = "rbxassetid://7249903719",
}
local SoundSystem = { Enabled = true, LastPlayTime = 0, SoundCooldown = 0.15 }

local function PlayToggleSound(isOn)
    if not SoundSystem.Enabled then return end
    local t = tick()
    if t - SoundSystem.LastPlayTime < SoundSystem.SoundCooldown then return end
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = isOn and SOUNDS.ToggleOn or SOUNDS.ToggleOff
        sound.Volume = 0.5
        sound.Parent = SoundService
        sound:Play()
        SoundSystem.LastPlayTime = t
        Debris:AddItem(sound, 2)
    end)
end

---------------------------------------------------------------------
-- УВЕДОМЛЕНИЯ
---------------------------------------------------------------------
local NOTIFICATION_DURATION = 1.5
local NOTIFICATION_HEIGHT   = 40
local NOTIFICATION_SPACING  = 8
local notificationIdCounter = 0
local activeNotifications   = {}

local function ShowNotification(message, isEnabled)
    notificationIdCounter += 1
    local notificationId = notificationIdCounter

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KurvexUI_Notification_" .. notificationId
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 1000
    MountGui(screenGui, false)

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, NOTIFICATION_HEIGHT)
    mainFrame.AnchorPoint = Vector2.new(1, 1)
    mainFrame.Position = UDim2.new(1, -20, 1, NOTIFICATION_HEIGHT + 100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.ZIndex = 10000
    mainFrame.Parent = screenGui
    Corner(mainFrame, 6)
    Stroke(mainFrame, BORDER_COLOR, 1, 0.4)

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -40, 1, -10)
    textLabel.Position = UDim2.new(0, 10, 0, 5)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = message
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.Font = CairoFont
    textLabel.TextSize = 13
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = mainFrame

    local statusIcon = Instance.new("Frame")
    statusIcon.Size = UDim2.new(0, 8, 0, 8)
    statusIcon.Position = UDim2.new(1, -15, 0.5, -4)
    statusIcon.BackgroundColor3 = isEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    statusIcon.BorderSizePixel = 0
    statusIcon.Parent = mainFrame
    Corner(statusIcon, 8)

    local notification = { Id = notificationId, Gui = screenGui, Frame = mainFrame, StartTime = tick(), IsActive = true }
    activeNotifications[notificationId] = notification

    local function UpdateAllPositions()
        local cam = Workspace.CurrentCamera
        local halfScreen = cam and cam.ViewportSize.Y / 2 or 400
        local sorted = {}
        for _, n in pairs(activeNotifications) do
            if n.IsActive then table.insert(sorted, n) end
        end
        table.sort(sorted, function(a, b) return a.StartTime < b.StartTime end)
        for i, n in ipairs(sorted) do
            if n.IsActive and n.Frame and n.Frame.Parent then
                local offsetY = (NOTIFICATION_HEIGHT + NOTIFICATION_SPACING) * (i - 1)
                TweenService:Create(n.Frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Position = UDim2.new(1, -20, 1, -(offsetY + NOTIFICATION_HEIGHT + 20)) }):Play()
                if n.Frame.AbsolutePosition.Y < halfScreen then
                    n.IsActive = false
                    TweenService:Create(n.Frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        Position = UDim2.new(1, -20, 0, -NOTIFICATION_HEIGHT), BackgroundTransparency = 1
                    }):Play()
                    task.delay(0.2, function()
                        if n.Gui and n.Gui.Parent then n.Gui:Destroy() end
                        activeNotifications[n.Id] = nil
                    end)
                end
            end
        end
    end

    TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, -20, 1, -(NOTIFICATION_HEIGHT + 20)) }):Play()
    UpdateAllPositions()

    task.delay(NOTIFICATION_DURATION, function()
        if activeNotifications[notificationId] then
            notification.IsActive = false
            TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1, -20, 1, NOTIFICATION_HEIGHT + 100), BackgroundTransparency = 1
            }):Play()
            task.delay(0.2, function()
                if screenGui and screenGui.Parent then screenGui:Destroy() end
                activeNotifications[notificationId] = nil
                UpdateAllPositions()
            end)
        end
    end)
end

---------------------------------------------------------------------
-- РЕЕСТР ФИЧ
-- DefineFeature(имя, { Settings = {...}, OnToggle = fn, OnSetting = fn, Instant = bool })
-- Settings: { Type = "toggle"|"slider"|"cycle", Key, Label, Default, ... }
---------------------------------------------------------------------
local Config      = {} -- Config[feature][key] = value
local FeatureDefs = {}

local function DefineFeature(name, def)
    def.Settings = def.Settings or {}
    FeatureDefs[name] = def
    local cfg = {}
    for _, s in ipairs(def.Settings) do cfg[s.Key] = s.Default end
    Config[name] = cfg
    return cfg
end

local BIND_SETTINGS  = {}
local FeatureToggles = {}

---------------------------------------------------------------------
-- ОБЩИЕ ХЕЛПЕРЫ ДЛЯ ИГРОКОВ
---------------------------------------------------------------------
-- Высота/центр тела БЕЗ аксессуаров (аксессуары - это Accessory, не BasePart,
-- поэтому берём только детей-частей самого персонажа)
local function GetBodyInfo(char)
    if not char or not char.Parent then return nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil end

    local minY, maxY = math.huge, -math.huge
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            local cf, sz = part.CFrame, part.Size
            local halfY = (math.abs(cf.RightVector.Y) * sz.X
                + math.abs(cf.UpVector.Y) * sz.Y
                + math.abs(cf.LookVector.Y) * sz.Z) / 2
            local y = cf.Position.Y
            if y - halfY < minY then minY = y - halfY end
            if y + halfY > maxY then maxY = y + halfY end
        end
    end
    if minY == math.huge then
        minY = root.Position.Y - 3
        maxY = root.Position.Y + 2.5
    end
    local height = math.max(maxY - minY, 0.5)
    return {
        root   = root,
        hum    = hum,
        center = Vector3.new(root.Position.X, (minY + maxY) / 2, root.Position.Z),
        feet   = Vector3.new(root.Position.X, minY, root.Position.Z),
        height = height,
        S      = height / 1.8,
    }
end

local function IsAlive(plr)
    local c = plr.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

local function GetRoot(plr)
    local c = plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function PickTarget(range)
    local origin
    local myRoot = GetRoot(LocalPlayer)
    if myRoot then
        origin = myRoot.Position
    elseif Workspace.CurrentCamera then
        origin = Workspace.CurrentCamera.CFrame.Position
    else
        return nil
    end
    local best, bestDist = nil, range
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local root = GetRoot(plr)
            if root and IsAlive(plr) then
                local d = (root.Position - origin).Magnitude
                if d < bestDist then best, bestDist = plr.Character, d end
            end
        end
    end
    return best
end

---------------------------------------------------------------------
-- COMBAT: Criticals (пустышка)
---------------------------------------------------------------------
DefineFeature("Criticals", {
    OnToggle = function(on)
        -- пусто
    end,
})

---------------------------------------------------------------------
-- MOVEMENT: Sprint (пустышка, внутри KeepSprint тоже ничего не делает)
---------------------------------------------------------------------
DefineFeature("Sprint", {
    Settings = {
        { Type = "toggle", Key = "KeepSprint", Label = "KeepSprint", Default = false },
    },
    OnToggle = function(on)
        -- пусто
    end,
})

---------------------------------------------------------------------
-- VISUALS: TargetESP (Marker / Souls)
---------------------------------------------------------------------
do
    local enabled = false

    local cfg = DefineFeature("TargetESP", {
        Settings = {
            { Type = "cycle",  Key = "Mode",  Label = "Mode",         Options = { "Marker", "Souls" }, Default = "Marker" },
            { Type = "slider", Key = "Range", Label = "Range",        Min = 10, Max = 200, Step = 5,   Default = 60 },
            { Type = "cycle",  Key = "Color", Label = "Marker color", Options = COLOR_OPTIONS,         Default = "White" },
            { Type = "slider", Key = "Scale", Label = "Marker scale", Min = 1, Max = 6, Step = 0.1,    Default = 2.6 },
        },
        OnToggle = function(on) enabled = on end,
    })

    local MARKER_IMAGE = "rbxassetid://114677874909839"
    local SOULS_IMAGE  = "rbxassetid://86932347364577"
    local SOULS_GROUPS, SOULS_LEN = 3, 25
    local SOULS_A = Color3.fromRGB(165, 120, 255)
    local SOULS_B = Color3.fromRGB(90, 170, 255)

    local function SoulsColor(offset)
        local t = os.clock() * 0.35 + offset / 360
        local a = (math.sin(t * math.pi * 2) + 1) / 2
        return SOULS_A:Lerp(SOULS_B, a)
    end

    local anchor = Instance.new("Part")
    anchor.Name = "KurvexTargetAnchor"
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Transparency = 1
    anchor.CastShadow = false
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    OnUnload(function() anchor:Destroy() end)

    -- маркер
    local markerGui = Instance.new("BillboardGui")
    markerGui.Name = "Marker"
    markerGui.Adornee = anchor
    markerGui.AlwaysOnTop = true
    markerGui.LightInfluence = 0
    markerGui.Size = UDim2.fromScale(1, 1)
    markerGui.Enabled = false
    markerGui.Parent = anchor

    local markerImg = Instance.new("ImageLabel")
    markerImg.BackgroundTransparency = 1
    markerImg.AnchorPoint = Vector2.new(0.5, 0.5)
    markerImg.Position = UDim2.fromScale(0.5, 0.5)
    markerImg.Size = UDim2.fromScale(1, 1)
    markerImg.Image = MARKER_IMAGE
    markerImg.Parent = markerGui

    -- души
    local sprites = {}
    for g = 1, SOULS_GROUPS do
        sprites[g] = {}
        for i = 0, SOULS_LEN - 1 do
            local bb = Instance.new("BillboardGui")
            bb.Adornee = anchor
            bb.AlwaysOnTop = false
            bb.LightInfluence = 0
            bb.Size = UDim2.new(1, 0, 1, 0)
            bb.Enabled = false
            bb.Parent = anchor

            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.BorderSizePixel = 0
            img.Size = UDim2.fromScale(1, 1)
            img.Image = SOULS_IMAGE
            img.ScaleType = Enum.ScaleType.Fit
            img.Parent = bb

            sprites[g][i] = { bb = bb, img = img }
        end
    end

    local appliedMode = nil
    local function ApplyMode(mode)
        appliedMode = mode
        markerGui.Enabled = (mode == "Marker")
        for g = 1, SOULS_GROUPS do
            for i = 0, SOULS_LEN - 1 do
                sprites[g][i].bb.Enabled = (mode == "Souls")
            end
        end
    end

    local START = os.clock()
    local target, lastTarget = nil, nil
    local pickTimer = 0
    local animProg, animVal = 0, 0
    local rotAngle, rotSpeed, reversing = 0, 0, false

    AddUpdater("TargetESP", function(dt)
        if cfg.Mode ~= appliedMode then ApplyMode(cfg.Mode) end

        pickTimer += dt
        if pickTimer >= 0.1 then
            pickTimer = 0
            target = enabled and PickTarget(cfg.Range) or nil
        end
        if not enabled then target = nil end

        local has = target ~= nil and target.Parent ~= nil
        if has then lastTarget = target end

        local step = dt / 0.4
        animProg = math.clamp(animProg + (has and step or -step), 0, 1)
        animVal = 1 - (1 - animProg) ^ 3

        if not has and animProg <= 0 then lastTarget = nil end

        local info = lastTarget and GetBodyInfo(lastTarget) or nil
        if not info or animVal <= 0.01 then
            anchor.Parent = nil
            return
        end
        anchor.Parent = Workspace

        if cfg.Mode == "Marker" then
            anchor.Position = info.center

            local k = dt * 60
            if not reversing then
                rotSpeed += 0.01 * k
                if rotSpeed > 2.3 then rotSpeed = 2.3; reversing = true end
            else
                rotSpeed -= 0.01 * k
                if rotSpeed < -2.3 then rotSpeed = -2.3; reversing = false end
            end
            rotAngle = (rotAngle + rotSpeed * k) % 360

            local size = 1.8 * animVal * cfg.Scale
            markerGui.Size = UDim2.fromScale(size, size)
            markerImg.ImageTransparency = 1 - animVal
            markerImg.ImageColor3 = PresetColor(cfg.Color, 0)
            markerImg.Rotation = rotAngle
        else
            local S = info.S
            local radius, speed, size, distance = 0.6, 27, 0.32, 15
            local ms = (os.clock() - START) * 1000

            anchor.Position = info.feet + Vector3.new(0.2, 1.3, 0) * S

            for g = 1, SOULS_GROUPS do
                for i = 0, SOULS_LEN - 1 do
                    local angle = 0.15 * (ms - i * distance) / speed
                    local s = math.sin(angle) * radius
                    local c = math.cos(angle) * radius
                    local off
                    if g == 1 then
                        off = Vector3.new(s, c, -c)
                    elseif g == 2 then
                        off = Vector3.new(-s, s, -c)
                    else
                        off = Vector3.new(-s, -s, c)
                    end
                    off = (off + Vector3.new(-size / 2, -size / 2, 0)) * S

                    local sp = sprites[g][i]
                    sp.bb.Size = UDim2.new(size * S, 0, size * S, 0)
                    sp.bb.StudsOffsetWorldSpace = off

                    local a = math.clamp(255 - i * 15, 0, 255) / 255
                    sp.img.ImageColor3 = SoulsColor(i * 12)
                    sp.img.ImageTransparency = 1 - a * animVal
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- VISUALS: Arrows
---------------------------------------------------------------------
do
    local enabled = false

    local cfg = DefineFeature("Arrows", {
        Settings = {
            { Type = "cycle",  Key = "Texture",   Label = "Texture",    Options = { "1", "2" },   Default = "1" },
            { Type = "slider", Key = "Radius",    Label = "Radius",     Min = 40,  Max = 300,  Step = 1,  Default = 80 },
            { Type = "slider", Key = "Size",      Label = "Size",       Min = 8,   Max = 64,   Step = 1,  Default = 24 },
            { Type = "slider", Key = "MaxDist",   Label = "Max dist",   Min = 100, Max = 5000, Step = 50, Default = 2000 },
            { Type = "slider", Key = "AnimSpeed", Label = "Anim speed", Min = 1,   Max = 8,    Step = 0.5, Default = 3 },
            { Type = "cycle",  Key = "Color",     Label = "Color",      Options = COLOR_OPTIONS, Default = "White" },
        },
        OnToggle = function(on) enabled = on end,
    })

    local ARROW_TEXTURES = {
        [1] = "rbxassetid://107466177907852",
        [2] = "rbxassetid://73377822137093",
    }
    local function Tex()
        return ARROW_TEXTURES[tonumber(cfg.Texture) or 1] or ARROW_TEXTURES[1]
    end

    local arrowList, arrowProg, arrowLastPos = {}, {}, {}

    local arrowGui = Instance.new("ScreenGui")
    arrowGui.Name = "KurvexUI_Arrows"
    arrowGui.ResetOnSpawn = false
    arrowGui.IgnoreGuiInset = true
    arrowGui.DisplayOrder = 400
    MountGui(arrowGui, true)

    local function RemoveArrow(plr)
        if arrowList[plr] then arrowList[plr]:Destroy() end
        arrowList[plr], arrowProg[plr], arrowLastPos[plr] = nil, nil, nil
    end

    Track(Players.PlayerRemoving:Connect(RemoveArrow))

    local function easeOutCubic(t) return 1 - (1 - t) ^ 3 end

    AddUpdater("Arrows", function(dt)
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local cx, cy = vp.X / 2, vp.Y / 2
        local myRoot = GetRoot(LocalPlayer)

        local wantShow = {}
        if enabled and myRoot then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local r = GetRoot(plr)
                    if r and IsAlive(plr) then
                        if (r.Position - myRoot.Position).Magnitude <= cfg.MaxDist then
                            wantShow[plr] = true
                        end
                    end
                end
            end
        end

        for plr in pairs(wantShow) do
            if not arrowList[plr] then
                local arrow = Instance.new("ImageLabel")
                arrow.Name = "Arrow_" .. plr.Name
                arrow.AnchorPoint = Vector2.new(0.5, 0.5)
                arrow.BackgroundTransparency = 1
                arrow.BorderSizePixel = 0
                arrow.Image = Tex()
                arrow.ImageColor3 = Color3.new(1, 1, 1)
                arrow.ImageTransparency = 1
                arrow.Size = UDim2.fromOffset(0, 0)
                arrow.Visible = false
                local g = Instance.new("UIGradient")
                g.Name = "ShimmerGradient"
                g.Parent = arrow
                arrow.Parent = arrowGui
                arrowList[plr] = arrow
                arrowProg[plr] = 0
            end
        end

        local toRemove = {}
        for plr, arrow in pairs(arrowList) do
            local targetV = wantShow[plr] and 1 or 0
            local cur = arrowProg[plr] or 0

            if cur ~= targetV then
                local step = dt * cfg.AnimSpeed
                if targetV > cur then cur = math.min(cur + step, 1) else cur = math.max(cur - step, 0) end
                arrowProg[plr] = cur
            end

            local r = GetRoot(plr)
            local localPos
            if r then
                localPos = cam.CFrame:PointToObjectSpace(r.Position)
                arrowLastPos[plr] = localPos
            else
                localPos = arrowLastPos[plr]
            end

            local tex = Tex()
            if arrow.Image ~= tex then arrow.Image = tex end

            if cur <= 0.001 and not r then
                arrow.Visible = false
                table.insert(toRemove, plr)
            elseif not localPos then
                arrow.Visible = false
                if cur <= 0.001 then table.insert(toRemove, plr) end
            else
                local eased = (targetV == 1) and easeOutCubic(cur) or cur
                eased = math.max(eased, 0)

                local angle  = math.deg(math.atan2(localPos.X, -localPos.Z))
                local rad    = math.rad(angle)
                local radLen = cfg.Radius * eased
                local offX   = math.sin(rad) * radLen
                local offY   = -math.cos(rad) * radLen

                local curSize = cfg.Size * eased
                arrow.Size = UDim2.fromOffset(curSize, curSize)
                arrow.Position = UDim2.fromOffset(cx + offX, cy + offY)
                arrow.Rotation = angle
                arrow.ImageTransparency = 1 - cur
                arrow.Visible = cur > 0.001

                local g = arrow:FindFirstChild("ShimmerGradient")
                if g then
                    local t = tick()
                    local h, s, v = PresetColor(cfg.Color, 0):ToHSV()
                    local w1 = (math.sin(t * 3.2) + 1) / 2
                    local w2 = (math.cos(t * 2.1) + 1) / 2
                    local w3 = (math.sin(t * 4.5 + 1.5) + 1) / 2
                    local dark  = Color3.fromHSV(h, s, math.clamp(v * (0.35 + w1 * 0.3), 0, 1))
                    local mid   = Color3.fromHSV(h, math.clamp(s * (0.8 + w2 * 0.2), 0, 1), math.clamp(v * (0.65 + w2 * 0.35), 0, 1))
                    local light = Color3.fromHSV(h, math.max(0, s * 0.65), math.clamp(v * (1.1 + w3 * 0.4), 0, 1))
                    g.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0,   dark),
                        ColorSequenceKeypoint.new(0.5, mid),
                        ColorSequenceKeypoint.new(1,   light),
                    })
                    g.Offset   = Vector2.new(math.sin(t * 2.5) * 0.2, math.cos(t * 1.8) * 0.2)
                    g.Rotation = (t * 50) % 360
                end
            end
        end

        for _, plr in ipairs(toRemove) do RemoveArrow(plr) end
    end)
end

---------------------------------------------------------------------
-- VISUALS: NameTags
---------------------------------------------------------------------
do
    local enabled = false
    local tags = {}

    local function DestroyTag(plr)
        local t = tags[plr]
        if t then pcall(function() t.gui:Destroy() end); tags[plr] = nil end
    end
    local function ClearAll()
        for plr in pairs(tags) do DestroyTag(plr) end
    end

    local cfg = DefineFeature("NameTags", {
        Settings = {
            { Type = "toggle", Key = "Health",      Label = "Health",       Default = true },
            { Type = "toggle", Key = "Distance",    Label = "Distance",     Default = true },
            { Type = "toggle", Key = "DisplayName", Label = "Display name", Default = false },
            { Type = "slider", Key = "MaxDist",     Label = "Max distance", Min = 50, Max = 2000, Step = 50, Default = 1000 },
            { Type = "cycle",  Key = "Color",       Label = "Color",        Options = COLOR_OPTIONS, Default = "White" },
        },
        OnToggle = function(on)
            enabled = on
            if not on then ClearAll() end
        end,
    })

    local function BuildTag(part)
        local gui = Instance.new("BillboardGui")
        gui.Name = "KurvexNameTag"
        gui.Adornee = part
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0
        gui.Size = UDim2.fromOffset(170, 40)
        gui.StudsOffset = Vector3.new(0, 2, 0)

        local name = Instance.new("TextLabel")
        name.BackgroundTransparency = 1
        name.Size = UDim2.new(1, 0, 0, 16)
        name.Font = CairoFont
        name.TextSize = 14
        name.TextColor3 = Color3.new(1, 1, 1)
        name.TextStrokeTransparency = 0.4
        name.Parent = gui

        local barBg = Instance.new("Frame")
        barBg.AnchorPoint = Vector2.new(0.5, 0)
        barBg.Position = UDim2.new(0.5, 0, 0, 19)
        barBg.Size = UDim2.fromOffset(90, 4)
        barBg.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
        barBg.BorderSizePixel = 0
        barBg.Parent = gui
        Corner(barBg, 2)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(1, 1)
        fill.BackgroundColor3 = Color3.fromRGB(80, 230, 110)
        fill.BorderSizePixel = 0
        fill.Parent = barBg
        Corner(fill, 2)

        local info = Instance.new("TextLabel")
        info.BackgroundTransparency = 1
        info.Position = UDim2.fromOffset(0, 25)
        info.Size = UDim2.new(1, 0, 0, 12)
        info.Font = CairoFont
        info.TextSize = 11
        info.TextColor3 = Color3.fromRGB(190, 190, 196)
        info.TextStrokeTransparency = 0.5
        info.Parent = gui

        gui.Parent = part
        return { gui = gui, name = name, barBg = barBg, fill = fill, info = info }
    end

    Track(Players.PlayerRemoving:Connect(DestroyTag))
    OnUnload(ClearAll)

    AddUpdater("NameTags", function(dt)
        if not enabled then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local camPos = cam.CFrame.Position

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))

                if hum and head and head:IsA("BasePart") and hum.Health > 0 then
                    local dist = (head.Position - camPos).Magnitude
                    if dist <= cfg.MaxDist then
                        local t = tags[plr]
                        if not t or not t.gui.Parent or t.gui.Adornee ~= head then
                            DestroyTag(plr)
                            t = BuildTag(head)
                            tags[plr] = t
                        end
                        t.gui.Enabled = true

                        t.name.Text = cfg.DisplayName and plr.DisplayName or plr.Name
                        t.name.TextColor3 = PresetColor(cfg.Color, 0)

                        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        t.barBg.Visible = cfg.Health
                        t.fill.Size = UDim2.fromScale(ratio, 1)
                        t.fill.BackgroundColor3 = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(80, 230, 110), ratio)

                        local parts = {}
                        if cfg.Health then table.insert(parts, tostring(math.floor(hum.Health)) .. " HP") end
                        if cfg.Distance then table.insert(parts, tostring(math.floor(dist)) .. "m") end
                        t.info.Text = table.concat(parts, "  |  ")
                    elseif tags[plr] then
                        tags[plr].gui.Enabled = false
                    end
                else
                    DestroyTag(plr)
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- VISUALS: Trails (след за твоим персонажем)
---------------------------------------------------------------------
do
    local enabled = false
    local trail, a0, a1

    local function DestroyTrail()
        if trail then pcall(function() trail:Destroy() end) end
        if a0 then pcall(function() a0:Destroy() end) end
        if a1 then pcall(function() a1:Destroy() end) end
        trail, a0, a1 = nil, nil, nil
    end

    local cfg = DefineFeature("Trails", {
        Settings = {
            { Type = "slider", Key = "Lifetime", Label = "Lifetime", Min = 0.2, Max = 3, Step = 0.1, Default = 1 },
            { Type = "slider", Key = "Width",    Label = "Width",    Min = 0.2, Max = 2, Step = 0.1, Default = 1 },
            { Type = "cycle",  Key = "Color",    Label = "Color",    Options = COLOR_OPTIONS, Default = "Rainbow" },
        },
        OnToggle = function(on)
            enabled = on
            if not on then DestroyTrail() end
        end,
    })

    OnUnload(DestroyTrail)

    AddUpdater("Trails", function(dt)
        if not enabled then return end
        local root = GetRoot(LocalPlayer)
        if not root then DestroyTrail() return end

        if not (trail and trail.Parent == root and a0 and a0.Parent == root and a1 and a1.Parent == root) then
            DestroyTrail()
            a0 = Instance.new("Attachment")
            a0.Name = "KurvexTrailA0"
            a0.Position = Vector3.new(0, 0.9, 0)
            a0.Parent = root

            a1 = Instance.new("Attachment")
            a1.Name = "KurvexTrailA1"
            a1.Position = Vector3.new(0, -2.6, 0)
            a1.Parent = root

            trail = Instance.new("Trail")
            trail.Name = "KurvexTrail"
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.MinLength = 0.05
            trail.FaceCamera = true
            trail.LightEmission = 0.8
            trail.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(1, 1),
            })
            trail.Parent = root
        end

        trail.Lifetime = cfg.Lifetime
        trail.WidthScale = NumberSequence.new(cfg.Width)
        trail.Color = ColorSequence.new(PresetColor(cfg.Color, 0), PresetColor(cfg.Color, 0.2))
    end)
end

---------------------------------------------------------------------
-- VISUALS: JumpCircles (кольцо под ногами при прыжке)
---------------------------------------------------------------------
do
    local enabled = false

    local cfg = DefineFeature("JumpCircles", {
        Settings = {
            { Type = "slider", Key = "Radius",   Label = "Radius",   Min = 2,   Max = 15, Step = 0.5, Default = 6 },
            { Type = "slider", Key = "Duration", Label = "Duration", Min = 0.3, Max = 3,  Step = 0.1, Default = 0.9 },
            { Type = "cycle",  Key = "Color",    Label = "Color",    Options = COLOR_OPTIONS, Default = "Purple" },
        },
        OnToggle = function(on) enabled = on end,
    })

    local folder = Instance.new("Folder")
    folder.Name = "KurvexJumpCircles"
    folder.Parent = Workspace
    OnUnload(function() folder:Destroy() end)

    local function Spawn()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { char }
        local res = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
        local pos = res and (res.Position + Vector3.new(0, 0.05, 0)) or (root.Position - Vector3.new(0, 3, 0))

        local dur, radius = cfg.Duration, cfg.Radius

        local part = Instance.new("Part")
        part.Name = "Circle"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Transparency = 1
        part.Size = Vector3.new(1, 0.05, 1)
        part.CFrame = CFrame.new(pos)

        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top
        sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        sg.CanvasSize = Vector2.new(256, 256)
        sg.LightInfluence = 0
        sg.Adornee = part
        sg.Parent = part

        local frame = Instance.new("Frame")
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Size = UDim2.fromScale(1, 1)
        frame.Parent = sg
        local uic = Instance.new("UICorner")
        uic.CornerRadius = UDim.new(1, 0)
        uic.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 12
        stroke.Color = PresetColor(cfg.Color, math.random())
        stroke.Parent = frame

        part.Parent = folder

        TweenService:Create(part, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = Vector3.new(radius * 2, 0.05, radius * 2) }):Play()
        TweenService:Create(stroke, TweenInfo.new(dur, Enum.EasingStyle.Linear),
            { Transparency = 1 }):Play()
        Debris:AddItem(part, dur + 0.1)
    end

    local stateConn
    local function Hook(char)
        if stateConn then stateConn:Disconnect(); stateConn = nil end
        if not char then return end
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum or Unloaded then return end
        stateConn = hum.StateChanged:Connect(function(_, new)
            if enabled and new == Enum.HumanoidStateType.Jumping then Spawn() end
        end)
    end

    task.spawn(Hook, LocalPlayer.Character)
    Track(LocalPlayer.CharacterAdded:Connect(function(c) task.spawn(Hook, c) end))
    OnUnload(function() if stateConn then stateConn:Disconnect(); stateConn = nil end end)
end

---------------------------------------------------------------------
-- VISUALS: HUD (Watermark / TargetHUD / KeyBinds / InventoryHud)
---------------------------------------------------------------------
local ApplyHUD
local UpdateBindDisplay
local HUD = { Enabled = false }
local TARGET_RANGE = 50

local hudCfg = DefineFeature("HUD", {
    Settings = {
        { Type = "toggle", Key = "Watermark",    Label = "Watermark",    Default = true },
        { Type = "toggle", Key = "TargetHUD",    Label = "TargetHUD",    Default = true },
        { Type = "toggle", Key = "KeyBinds",     Label = "KeyBinds",     Default = true },
        { Type = "toggle", Key = "InventoryHud", Label = "InventoryHud", Default = true },
    },
    OnToggle  = function(on) HUD.Enabled = on; ApplyHUD() end,
    OnSetting = function() ApplyHUD() end,
})

local function MakeDraggable(frame, handle)
    local dragging = false
    local dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "KurvexUI_HUD"
hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.DisplayOrder = 997
MountGui(hudGui, true)

local function MakeHudPanel(name, size, position)
    local p = Instance.new("Frame")
    p.Name = name
    p.Size = size
    p.Position = position
    p.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    p.BackgroundTransparency = 0.15
    p.BorderSizePixel = 0
    p.Visible = false
    p.Parent = hudGui
    Corner(p, 6)
    Stroke(p, BORDER_COLOR, 1, 0.4)
    return p
end

local function HudLabel(parent, text, size, pos, textSize, color, align)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = size; l.Position = pos
    l.Font = CairoFont; l.Text = text; l.TextSize = textSize
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

-- WATERMARK
local fpsLabel
local Watermark = MakeHudPanel("Watermark", UDim2.fromOffset(0, 22), UDim2.new(0, 10, 0.35, 0))
Watermark.AutomaticSize = Enum.AutomaticSize.X
do
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = Watermark

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = Watermark

    local icon = Instance.new("ImageLabel")
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.fromOffset(14, 14)
    icon.Image = HUD_ICON
    icon.ImageColor3 = ACCENT_COLOR
    icon.LayoutOrder = 1
    icon.Parent = Watermark

    local function WmPart(text, order, color)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.AutomaticSize = Enum.AutomaticSize.X
        l.Size = UDim2.new(0, 0, 1, 0)
        l.Font = CairoFont; l.TextSize = 12
        l.Text = text
        l.TextColor3 = color or Color3.new(1, 1, 1)
        l.LayoutOrder = order
        l.Parent = Watermark
        return l
    end
    WmPart(CLIENT_NAME, 2, ACCENT_COLOR)
    WmPart(LocalPlayer.Name, 3)
    WmPart("FPS", 4, Color3.fromRGB(170, 170, 178))
    fpsLabel = WmPart("60", 5)
end

-- TARGET HUD
local TargetPanel = MakeHudPanel("TargetHUD", UDim2.fromOffset(175, 42), UDim2.new(0, 10, 0.35, 30))

local headImg = Instance.new("ImageLabel")
headImg.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
headImg.Size = UDim2.fromOffset(30, 30)
headImg.Position = UDim2.fromOffset(6, 6)
headImg.Parent = TargetPanel
Corner(headImg, 5)

local nameLbl = HudLabel(TargetPanel, "", UDim2.fromOffset(128, 14), UDim2.fromOffset(42, 5), 13)
local hpLbl   = HudLabel(TargetPanel, "", UDim2.fromOffset(128, 12), UDim2.fromOffset(42, 18), 11, Color3.fromRGB(190, 190, 196))

local barBg = Instance.new("Frame")
barBg.Size = UDim2.fromOffset(124, 5)
barBg.Position = UDim2.fromOffset(42, 32)
barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
barBg.BorderSizePixel = 0
barBg.Parent = TargetPanel
Corner(barBg, 2)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = ACCENT_COLOR
barFill.BorderSizePixel = 0
barFill.Parent = barBg
Corner(barFill, 2)

-- INVENTORY HUD
local InventoryPanel = MakeHudPanel("InventoryHud", UDim2.fromOffset(86, 24), UDim2.new(0, 10, 0.35, 80))

local inventorySlots = {}
for i = 1, 4 do
    local s = Instance.new("ImageLabel")
    s.BackgroundTransparency = 1
    s.Size = UDim2.fromOffset(16, 16)
    s.Position = UDim2.fromOffset(5 + (i - 1) * 20, 4)
    s.Visible = false
    s.Parent = InventoryPanel
    local letter = HudLabel(s, "", UDim2.fromScale(1, 1), UDim2.new(), 12, ACCENT_COLOR, Enum.TextXAlignment.Center)
    letter.Name = "Letter"
    inventorySlots[i] = s
end

-- KEYBINDS PANEL
local BindDisplayFrame = MakeHudPanel("BindDisplay", UDim2.new(0, 200, 0, 48), UDim2.new(0, 10, 0.35, 112))

local bdTitle = HudLabel(BindDisplayFrame, "BINDS", UDim2.new(1, -10, 0, 22), UDim2.new(0, 8, 0, 3), 11, ACCENT_COLOR)
bdTitle.Name = "BindTitle"
bdTitle.Font = Enum.Font.GothamBlack

local shimmer = Instance.new("Frame")
shimmer.Size = UDim2.new(1, -16, 0, 1)
shimmer.Position = UDim2.new(0, 8, 0, 26)
shimmer.BackgroundColor3 = Color3.new(1, 1, 1)
shimmer.BorderSizePixel = 0
shimmer.Parent = BindDisplayFrame
local shimmerGrad = Instance.new("UIGradient")
shimmerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 55, 60)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 240)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 55, 60)),
})
shimmerGrad.Parent = shimmer

local BindEmptyLabel = HudLabel(BindDisplayFrame, "нет биндов", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 30), 11,
    Color3.fromRGB(110, 110, 116), Enum.TextXAlignment.Center)
BindEmptyLabel.Name = "BindEmpty"

MakeDraggable(Watermark, Watermark)
MakeDraggable(TargetPanel, TargetPanel)
MakeDraggable(InventoryPanel, InventoryPanel)
MakeDraggable(BindDisplayFrame, BindDisplayFrame)

-- строки биндов
local BindRows = {}
local ROW_H, START_Y = 22, 30
local function RowY(index) return START_Y + (index - 1) * ROW_H end

local function CreateBindRow(feature, key, enabled, index)
    local row = Instance.new("Frame")
    row.Name = "BindRow"
    row.Size = UDim2.new(1, -10, 0, ROW_H - 2)
    row.Position = UDim2.new(0, 45, 0, RowY(index))
    row.BackgroundTransparency = 1
    row.Parent = BindDisplayFrame

    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.Position = UDim2.new(0, 3, 0.5, 0)
    dot.BackgroundColor3 = enabled and ON_COLOR or Color3.fromRGB(80, 80, 86)
    dot.BackgroundTransparency = 1
    dot.BorderSizePixel = 0
    dot.Parent = row
    Corner(dot, 6)

    local fl = Instance.new("TextLabel")
    fl.Size = UDim2.new(0.65, 0, 1, 0)
    fl.Position = UDim2.new(0, 12, 0, 0)
    fl.BackgroundTransparency = 1
    fl.Text = feature
    fl.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 146)
    fl.TextTransparency = 1
    fl.Font = CairoFont; fl.TextSize = 11
    fl.TextXAlignment = Enum.TextXAlignment.Left
    fl.TextTruncate = Enum.TextTruncate.AtEnd
    fl.Parent = row

    local kl = Instance.new("TextLabel")
    kl.Size = UDim2.new(0.35, 0, 1, 0)
    kl.Position = UDim2.new(0.65, 0, 0, 0)
    kl.BackgroundTransparency = 1
    kl.Text = "[" .. key .. "]"
    kl.TextColor3 = ACCENT_COLOR
    kl.TextTransparency = 1
    kl.Font = CairoFont; kl.TextSize = 11
    kl.TextXAlignment = Enum.TextXAlignment.Right
    kl.Parent = row

    local info = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (index - 1) * 0.05)
    TweenService:Create(row, info, { Position = UDim2.new(0, 5, 0, RowY(index)) }):Play()
    TweenService:Create(dot, info, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(fl, info, { TextTransparency = 0 }):Play()
    TweenService:Create(kl, info, { TextTransparency = 0 }):Play()

    return { Row = row, Dot = dot, FL = fl, KL = kl, Enabled = enabled }
end

local function RemoveBindRow(r)
    local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(r.Row, info, { Position = UDim2.new(0, 45, 0, r.Row.Position.Y.Offset) }):Play()
    TweenService:Create(r.Dot, info, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(r.FL, info, { TextTransparency = 1 }):Play()
    TweenService:Create(r.KL, info, { TextTransparency = 1 }):Play()
    task.delay(0.22, function() if r.Row.Parent then r.Row:Destroy() end end)
end

local function PulseDot(dot)
    TweenService:Create(dot, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = UDim2.new(0, 12, 0, 12) }):Play()
    task.delay(0.12, function()
        if dot.Parent then
            TweenService:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Size = UDim2.new(0, 6, 0, 6) }):Play()
        end
    end)
end

UpdateBindDisplay = function()
    local list = {}
    for featureName, keyName in pairs(BIND_SETTINGS) do
        if type(keyName) == "string" and keyName ~= "None" and keyName ~= "" then
            local toggle = FeatureToggles[featureName]
            table.insert(list, { Feature = featureName, Key = keyName, Enabled = toggle and toggle.Enabled or false })
        end
    end
    table.sort(list, function(a, b) return a.Feature < b.Feature end)

    local present = {}
    for i, b in ipairs(list) do
        present[b.Feature] = true
        local r = BindRows[b.Feature]
        if not r then
            BindRows[b.Feature] = CreateBindRow(b.Feature, b.Key, b.Enabled, i)
        else
            r.KL.Text = "[" .. b.Key .. "]"
            TweenService:Create(r.Row, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Position = UDim2.new(0, 5, 0, RowY(i)) }):Play()
            if r.Enabled ~= b.Enabled then
                r.Enabled = b.Enabled
                TweenService:Create(r.Dot, TweenInfo.new(0.2), {
                    BackgroundColor3 = b.Enabled and ON_COLOR or Color3.fromRGB(80, 80, 86) }):Play()
                TweenService:Create(r.FL, TweenInfo.new(0.2), {
                    TextColor3 = b.Enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 146) }):Play()
                PulseDot(r.Dot)
            end
        end
    end

    for feature, r in pairs(BindRows) do
        if not present[feature] then
            BindRows[feature] = nil
            RemoveBindRow(r)
        end
    end

    local h = (#list == 0) and 48 or (START_Y + #list * ROW_H + 8)
    TweenService:Create(BindDisplayFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 200, 0, h) }):Play()
    TweenService:Create(BindEmptyLabel, TweenInfo.new(0.25), { TextTransparency = (#list == 0) and 0 or 1 }):Play()
end

-- таргет
local thumbCache = {}
local healthAnim, currentTargetId = 1, nil

local function FindHudTarget()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return LocalPlayer, char end
    local best, bestDist, bestChar = nil, TARGET_RANGE, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            if r and h and h.Health > 0 then
                local d = (r.Position - root.Position).Magnitude
                if d < bestDist then best, bestDist, bestChar = p, d, p.Character end
            end
        end
    end
    if best then return best, bestChar end
    return LocalPlayer, char
end

local function UpdateTarget(dt)
    local tPlayer, tChar = FindHudTarget()
    local hum = tChar and tChar:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if currentTargetId ~= tPlayer.UserId then
        currentTargetId = tPlayer.UserId
        local uid = tPlayer.UserId
        if thumbCache[uid] then
            headImg.Image = thumbCache[uid]
        else
            task.spawn(function()
                local ok, img = pcall(function()
                    return (Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100))
                end)
                thumbCache[uid] = ok and img or ""
                if currentTargetId == uid then headImg.Image = thumbCache[uid] end
            end)
        end
    end

    local name = tPlayer.Name
    if #name > 12 then name = name:sub(1, 12) end
    nameLbl.Text = name

    local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    healthAnim += (ratio - healthAnim) * (1 - math.exp(-15 * dt))
    barFill.Size = UDim2.fromScale(healthAnim, 1)
    hpLbl.Text = math.floor(hum.Health) .. " HP"
end

local function UpdateInventory()
    local items = {}
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if char then for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") then table.insert(items, t) end end end
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then table.insert(items, t) end end end
    for i, s in ipairs(inventorySlots) do
        local tool = items[i]
        if tool then
            s.Image = tool.TextureId
            s.Letter.Text = (tool.TextureId == "") and tool.Name:sub(1, 1):upper() or ""
            s.Visible = true
        else
            s.Visible = false
        end
    end
end

local HUDPanels = {
    Watermark    = Watermark,
    TargetHUD    = TargetPanel,
    KeyBinds     = BindDisplayFrame,
    InventoryHud = InventoryPanel,
}

ApplyHUD = function()
    for name, panel in pairs(HUDPanels) do
        panel.Visible = HUD.Enabled and hudCfg[name] == true
    end
end

local frames, acc = 0, 0
AddUpdater("HUD", function(dt)
    frames += 1; acc += dt
    if acc >= 0.5 then
        if fpsLabel and fpsLabel.Parent then
            fpsLabel.Text = tostring(math.floor(frames / acc))
        end
        frames, acc = 0, 0
    end
    if HUD.Enabled then
        if hudCfg.TargetHUD then UpdateTarget(dt) end
        if hudCfg.InventoryHud then UpdateInventory() end
    end
    shimmerGrad.Offset = Vector2.new(((os.clock() * 0.7) % 2) - 1, 0)
end)

UpdateBindDisplay()

---------------------------------------------------------------------
-- MISC: Unload
---------------------------------------------------------------------
DefineFeature("Unload", {
    Instant = true,
    OnToggle = function() Unload() end,
})

---------------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ ВСЕХ МОДУЛЕЙ
---------------------------------------------------------------------
Track(RunService.RenderStepped:Connect(function(dt)
    for _, u in ipairs(Updaters) do
        local ok, err = pcall(u.fn, dt)
        if not ok and not u.warned then
            u.warned = true
            warn("[" .. CLIENT_NAME .. "] " .. u.name .. ": " .. tostring(err))
        end
    end
end))

---------------------------------------------------------------------
-- МЕНЮ
---------------------------------------------------------------------
local ActiveSettingsFrame, ActiveSettingsFeature = nil, nil
local IsMenuOpen    = false
local ListeningBind = false
local PopupConns    = {}

local function CloseActiveSettings()
    for _, c in ipairs(PopupConns) do pcall(function() c:Disconnect() end) end
    table.clear(PopupConns)
    ListeningBind = false

    local f = ActiveSettingsFrame
    ActiveSettingsFrame, ActiveSettingsFeature = nil, nil
    if f and f.Parent then
        TweenService:Create(f, TweenInfo.new(0.15), { Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 }):Play()
        task.delay(0.15, function() if f.Parent then f:Destroy() end end)
    end
end

local function FmtValue(v, step)
    if step < 1 then return string.format("%.1f", v) end
    return tostring(math.floor(v + 0.5))
end

local function HoverTint(btn, from, to)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = to }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = from }):Play()
    end)
end

local function BuildToggleControl(parent, def, cfg, feature, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.BackgroundColor3 = ROW_COLOR
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.LayoutOrder = order
    btn.Parent = parent
    Corner(btn, 4)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -34, 1, 0); lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = def.Label
    lbl.TextColor3 = Color3.fromRGB(230, 230, 235); lbl.Font = CairoFont; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 14, 0, 14); box.Position = UDim2.new(1, -22, 0.5, -7)
    box.BorderSizePixel = 0
    box.BackgroundColor3 = cfg[def.Key] and ON_COLOR or Color3.fromRGB(30, 30, 35)
    box.Parent = btn
    Corner(box, 3)
    Stroke(box, Color3.fromRGB(120, 120, 128), 1)

    btn.MouseButton1Click:Connect(function()
        cfg[def.Key] = not cfg[def.Key]
        TweenService:Create(box, TweenInfo.new(0.15), {
            BackgroundColor3 = cfg[def.Key] and ON_COLOR or Color3.fromRGB(30, 30, 35) }):Play()
        if feature.OnSetting then feature.OnSetting(def.Key, cfg[def.Key]) end
    end)
    HoverTint(btn, ROW_COLOR, Color3.fromRGB(52, 52, 58))
end

local function BuildSliderControl(parent, def, cfg, feature, order)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 42)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = order
    holder.Parent = parent

    local step  = def.Step or 1
    local range = def.Max - def.Min

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(160, 160, 166)
    lbl.Font = CairoFont; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -16, 0, 10)
    track.Position = UDim2.new(0, 8, 0, 24)
    track.BackgroundColor3 = Color3.fromRGB(45, 45, 51)
    track.BorderSizePixel = 0
    track.Parent = holder
    Corner(track, 5)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = ACCENT_COLOR
    fill.BorderSizePixel = 0
    fill.Parent = track
    Corner(fill, 5)

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    Corner(thumb, 8)

    local function show(v)
        local r = math.clamp((v - def.Min) / range, 0, 1)
        fill.Size = UDim2.new(r, 0, 1, 0)
        thumb.Position = UDim2.new(r, -8, 0.5, -8)
        lbl.Text = def.Label .. ": " .. FmtValue(v, step)
    end
    show(cfg[def.Key])

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 0, 24)
    hit.Position = UDim2.new(0, 0, 0, 17)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.Parent = holder

    local dragging = false
    local function applyX(x)
        local r = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = def.Min + range * r
        v = math.floor(v / step + 0.5) * step
        v = math.clamp(v, def.Min, def.Max)
        v = tonumber(string.format("%.3f", v))
        cfg[def.Key] = v
        show(v)
        if feature.OnSetting then feature.OnSetting(def.Key, v) end
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            applyX(input.Position.X)
        end
    end)
    table.insert(PopupConns, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            applyX(input.Position.X)
        end
    end))
    table.insert(PopupConns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

-- ЛКМ - следующее значение, ПКМ - предыдущее
local function BuildCycleControl(parent, def, cfg, feature, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = ROW_COLOR
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = CairoFont; btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(230, 230, 235)
    btn.LayoutOrder = order
    btn.Parent = parent
    Corner(btn, 4)
    Stroke(btn, Color3.fromRGB(70, 70, 78), 1, 0.4)

    local function refresh()
        btn.Text = def.Label .. ": " .. tostring(cfg[def.Key])
    end
    refresh()

    local function shift(dir)
        local idx = 1
        for i, o in ipairs(def.Options) do
            if o == cfg[def.Key] then idx = i; break end
        end
        idx = ((idx - 1 + dir) % #def.Options) + 1
        cfg[def.Key] = def.Options[idx]
        refresh()
        if feature.OnSetting then feature.OnSetting(def.Key, cfg[def.Key]) end
    end

    btn.MouseButton1Click:Connect(function() shift(1) end)
    btn.MouseButton2Click:Connect(function() shift(-1) end)
    HoverTint(btn, ROW_COLOR, Color3.fromRGB(52, 52, 58))
end

local function ToggleSettings(featureName, button, screenGuiRef)
    if not button or not button.Parent then return end

    if ActiveSettingsFrame and ActiveSettingsFrame.Parent then
        local same = (ActiveSettingsFeature == featureName)
        CloseActiveSettings()
        if same then return end
    end

    local feature = FeatureDefs[featureName]
    local cfg     = Config[featureName]
    local buttonPos, buttonSize = button.AbsolutePosition, button.AbsoluteSize

    local settingsFrame = Instance.new("Frame")
    settingsFrame.Name = featureName .. "_Settings_Popup"
    settingsFrame.Size = UDim2.new(0, 220, 0, 0)
    settingsFrame.BackgroundColor3 = SETTINGS_COLOR
    settingsFrame.BackgroundTransparency = 1
    settingsFrame.BorderSizePixel = 0
    settingsFrame.ClipsDescendants = true
    settingsFrame.ZIndex = 1000
    settingsFrame.Parent = screenGuiRef
    Corner(settingsFrame, 6)
    Stroke(settingsFrame, BORDER_COLOR, 1, 0.3)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 1, -10)
    content.Position = UDim2.new(0, 5, 0, 5)
    content.BackgroundTransparency = 1
    content.Parent = settingsFrame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    local totalH, order = 10, 0
    local function slot(h)
        order += 1
        totalH += h + (order > 1 and 6 or 0)
        return order
    end

    -- настройки фичи
    if #feature.Settings > 0 then
        for _, def in ipairs(feature.Settings) do
            if def.Type == "toggle" then
                BuildToggleControl(content, def, cfg, feature, slot(26))
            elseif def.Type == "slider" then
                BuildSliderControl(content, def, cfg, feature, slot(42))
            elseif def.Type == "cycle" then
                BuildCycleControl(content, def, cfg, feature, slot(28))
            end
        end
    else
        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, 0, 0, 30); info.BackgroundTransparency = 1
        info.Text = "Нет доп. настроек"; info.TextColor3 = Color3.fromRGB(150, 150, 156)
        info.Font = CairoFont; info.TextSize = 12; info.TextXAlignment = Enum.TextXAlignment.Center
        info.LayoutOrder = slot(30)
        info.Parent = content
    end

    -- бинд
    do
        local sep = Instance.new("Frame")
        sep.Size = UDim2.new(1, 0, 0, 1); sep.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
        sep.BorderSizePixel = 0
        sep.LayoutOrder = slot(1)
        sep.Parent = content

        local bindTitle = Instance.new("TextLabel")
        bindTitle.Size = UDim2.new(1, 0, 0, 16); bindTitle.BackgroundTransparency = 1
        bindTitle.Text = "Bind"; bindTitle.TextColor3 = Color3.fromRGB(180, 180, 186)
        bindTitle.Font = CairoFont; bindTitle.TextSize = 12
        bindTitle.TextXAlignment = Enum.TextXAlignment.Left
        bindTitle.LayoutOrder = slot(16)
        bindTitle.Parent = content

        local function bindText(cur) return cur == "None" and "[ нажми чтобы назначить ]" or "[ " .. cur .. " ]" end
        local function bindColor(cur) return cur == "None" and Color3.fromRGB(125, 125, 132) or ACCENT_COLOR end

        local currentBind = BIND_SETTINGS[featureName] or "None"

        local bindBtn = Instance.new("TextButton")
        bindBtn.Size = UDim2.new(1, 0, 0, 26)
        bindBtn.BackgroundColor3 = ROW_COLOR
        bindBtn.BorderSizePixel = 0
        bindBtn.Font = CairoFont; bindBtn.TextSize = 12
        bindBtn.Text = bindText(currentBind)
        bindBtn.TextColor3 = bindColor(currentBind)
        bindBtn.AutoButtonColor = false
        bindBtn.LayoutOrder = slot(26)
        bindBtn.Parent = content
        Corner(bindBtn, 4)

        local clearBtn = Instance.new("TextButton")
        clearBtn.Size = UDim2.new(1, 0, 0, 22)
        clearBtn.BackgroundColor3 = Color3.fromRGB(48, 38, 38)
        clearBtn.BorderSizePixel = 0
        clearBtn.Font = CairoFont; clearBtn.TextSize = 11
        clearBtn.Text = "✕  сбросить бинд"
        clearBtn.TextColor3 = Color3.fromRGB(190, 130, 130)
        clearBtn.AutoButtonColor = false
        clearBtn.LayoutOrder = slot(22)
        clearBtn.Parent = content
        Corner(clearBtn, 4)

        local bindConn = nil
        local function stopListening()
            if bindConn then bindConn:Disconnect(); bindConn = nil end
            task.delay(0.1, function() ListeningBind = false end)
        end

        bindBtn.MouseButton1Click:Connect(function()
            if ListeningBind then return end
            ListeningBind = true
            bindBtn.Text = "[ жди нажатия... ]"
            bindBtn.TextColor3 = Color3.fromRGB(255, 210, 90)
            bindConn = UserInputService.InputBegan:Connect(function(inp)
                if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
                if inp.KeyCode == Enum.KeyCode.Escape then
                    local cur = BIND_SETTINGS[featureName] or "None"
                    bindBtn.Text = bindText(cur); bindBtn.TextColor3 = bindColor(cur)
                    stopListening()
                    return
                end
                local keyName = inp.KeyCode.Name
                BIND_SETTINGS[featureName] = keyName
                bindBtn.Text = bindText(keyName); bindBtn.TextColor3 = bindColor(keyName)
                stopListening()
                ShowNotification("Бинд: " .. featureName .. " → " .. keyName, true)
                UpdateBindDisplay()
            end)
            table.insert(PopupConns, bindConn)
        end)

        clearBtn.MouseButton1Click:Connect(function()
            BIND_SETTINGS[featureName] = nil
            bindBtn.Text = bindText("None"); bindBtn.TextColor3 = bindColor("None")
            if bindConn then stopListening() end
            ShowNotification("Бинд " .. featureName .. " сброшен", false)
            UpdateBindDisplay()
        end)

        bindBtn.MouseEnter:Connect(function()
            if not ListeningBind then
                TweenService:Create(bindBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(52, 52, 58) }):Play()
            end
        end)
        bindBtn.MouseLeave:Connect(function()
            TweenService:Create(bindBtn, TweenInfo.new(0.1), { BackgroundColor3 = ROW_COLOR }):Play()
        end)
        HoverTint(clearBtn, Color3.fromRGB(48, 38, 38), Color3.fromRGB(65, 42, 42))
    end

    -- позиция (не вылезаем за экран)
    local cam = Workspace.CurrentCamera
    local viewH = cam and cam.ViewportSize.Y or 1080
    local posY = math.min(buttonPos.Y, math.max(viewH - totalH - 10, 10))
    settingsFrame.Position = UDim2.new(0, buttonPos.X + buttonSize.X + 10, 0, posY)

    ActiveSettingsFrame, ActiveSettingsFeature = settingsFrame, featureName
    TweenService:Create(settingsFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 220, 0, totalH), BackgroundTransparency = 0
    }):Play()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KurvexUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
MountGui(ScreenGui, true)

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 1300, 0, 600)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundTransparency = 1
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local Columns = {
    { Name = "Combat",   Position = UDim2.new(0, 15, 0, 10),
      Features = { "Criticals" } },
    { Name = "Movement", Position = UDim2.new(0, 275, 0, 10),
      Features = { "Sprint" } },
    { Name = "Visuals",  Position = UDim2.new(0, 535, 0, 10),
      Features = { "TargetESP", "Arrows", "NameTags", "Trails", "JumpCircles", "HUD" } },
    { Name = "Misc",     Position = UDim2.new(0, 795, 0, 10),
      Features = { "Unload" } },
}

local ColumnWindows = {}

local function AnimateColumnOpen(columnWindow, targetPosition)
    columnWindow.Position = UDim2.new(targetPosition.X.Scale, targetPosition.X.Offset,
        targetPosition.Y.Scale, targetPosition.Y.Offset - 30)
    columnWindow.BackgroundTransparency = 1
    columnWindow.Visible = true
    TweenService:Create(columnWindow, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = targetPosition, BackgroundTransparency = COLUMN_TRANSP
    }):Play()
    for _, child in pairs(columnWindow:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            child.TextTransparency = 1
            TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
        end
    end
end

local function AnimateColumnClose(columnWindow, targetPosition)
    TweenService:Create(columnWindow, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(targetPosition.X.Scale, targetPosition.X.Offset,
            targetPosition.Y.Scale, targetPosition.Y.Offset + 30),
        BackgroundTransparency = 1
    }):Play()
    task.delay(0.25, function()
        if columnWindow and columnWindow.Parent and not IsMenuOpen then columnWindow.Visible = false end
    end)
end

local function CalculateFixedHeight(columnData)
    return 45 + 40 * #columnData.Features + 8 * (#columnData.Features - 1) + 12
end

local function UpdateColumnLayout(columnName)
    local columnData
    for _, col in ipairs(Columns) do if col.Name == columnName then columnData = col; break end end
    if not columnData then return end
    local columnWindow = ColumnWindows[columnName]
    local fc = columnWindow and columnWindow:FindFirstChild("FeaturesContainer")
    if not fc then return end

    local currentY = 0
    for _, featureName in ipairs(columnData.Features) do
        local ff = fc:FindFirstChild(featureName .. "_Frame")
        if ff then
            ff.Position = UDim2.new(0, 0, 0, currentY)
            currentY += 48
        end
    end
    columnWindow.Size = UDim2.new(0, 250, 0, CalculateFixedHeight(columnData))
    fc.Size = UDim2.new(1, 0, 0, currentY)
end

local function SetFeatureState(featureName, enabled, silent)
    local t = FeatureToggles[featureName]
    local def = FeatureDefs[featureName]
    if not t or not def then return end
    t.Enabled = enabled
    t.StatusLabel.Text = enabled and "On" or "Off"
    t.StatusLabel.TextColor3 = enabled and ON_COLOR or OFF_COLOR
    TweenService:Create(t.NameLabel, TweenInfo.new(0.2), {
        TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 205, 210) }):Play()
    if not silent then
        PlayToggleSound(enabled)
        ShowNotification(featureName .. ": " .. (enabled and "ENABLED" or "DISABLED"), enabled)
    end
    if def.OnToggle then
        local ok, err = pcall(def.OnToggle, enabled)
        if not ok then warn("[" .. CLIENT_NAME .. "] " .. featureName .. ": " .. tostring(err)) end
    end
    UpdateBindDisplay()
end

local function RunInstant(featureName)
    PlayToggleSound(false)
    local def = FeatureDefs[featureName]
    if def and def.OnToggle then def.OnToggle(true) end
end

local function BuildFeatureButton(featuresContainer, featureName)
    local def = FeatureDefs[featureName]

    local featureFrame = Instance.new("Frame", featuresContainer)
    featureFrame.Name = featureName .. "_Frame"
    featureFrame.Size = UDim2.new(1, 0, 0, 40)
    featureFrame.BackgroundTransparency = 1
    featureFrame.BorderSizePixel = 0

    local featureButton = Instance.new("TextButton", featureFrame)
    featureButton.Name = featureName .. "_Button"
    featureButton.Size = UDim2.new(1, -4, 0, 40)
    featureButton.Position = UDim2.new(0, 2, 0, 0)
    featureButton.BackgroundColor3 = FUNCTION_BG_COLOR
    featureButton.BackgroundTransparency = 1
    featureButton.Text = ""
    featureButton.BorderSizePixel = 0
    featureButton.AutoButtonColor = false
    Corner(featureButton, 4)

    local nameText = Instance.new("TextLabel", featureButton)
    nameText.Name = "NameText"
    nameText.Size = UDim2.new(0.72, 0, 1, 0)
    nameText.Position = UDim2.new(0, 10, 0, 0)
    nameText.BackgroundTransparency = 1
    nameText.Text = featureName
    nameText.TextColor3 = Color3.fromRGB(205, 205, 210)
    nameText.Font = CairoFont
    nameText.TextSize = 13
    nameText.TextXAlignment = Enum.TextXAlignment.Left

    local statusLabel = Instance.new("TextLabel", featureButton)
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(0.28, 0, 1, 0)
    statusLabel.Position = UDim2.new(0.72, -8, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = CairoFont
    statusLabel.TextSize = 13
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right

    if def.Instant then
        statusLabel.Text = "→"; statusLabel.TextColor3 = ACCENT_COLOR
    else
        statusLabel.Text = "Off"; statusLabel.TextColor3 = OFF_COLOR
    end

    FeatureToggles[featureName] = {
        Button = featureButton, NameLabel = nameText,
        StatusLabel = statusLabel, Enabled = false, Frame = featureFrame
    }

    featureButton.MouseEnter:Connect(function()
        TweenService:Create(featureButton, TweenInfo.new(0.1), { BackgroundTransparency = 0.1 }):Play()
    end)
    featureButton.MouseLeave:Connect(function()
        TweenService:Create(featureButton, TweenInfo.new(0.1), { BackgroundTransparency = 1 }):Play()
    end)

    if def.Instant then
        featureButton.MouseButton1Click:Connect(function()
            CloseActiveSettings()
            RunInstant(featureName)
        end)
    else
        featureButton.MouseButton1Click:Connect(function()
            CloseActiveSettings()
            SetFeatureState(featureName, not FeatureToggles[featureName].Enabled)
        end)
    end
    featureButton.MouseButton2Click:Connect(function()
        ToggleSettings(featureName, featureButton, ScreenGui)
    end)
end

local function BuildOneColumn(columnData)
    local columnWindow = Instance.new("Frame", MainFrame)
    columnWindow.Name = columnData.Name .. "_Column"
    columnWindow.Size = UDim2.new(0, 250, 0, CalculateFixedHeight(columnData))
    columnWindow.Position = columnData.Position
    columnWindow.BackgroundColor3 = BACKGROUND_COLOR
    columnWindow.BackgroundTransparency = COLUMN_TRANSP
    columnWindow.BorderSizePixel = 0
    columnWindow.Visible = false
    Corner(columnWindow, 8)
    Stroke(columnWindow, BORDER_COLOR, 1)

    local titleFrame = Instance.new("Frame", columnWindow)
    titleFrame.Name = "TitleFrame"
    titleFrame.Size = UDim2.new(1, 0, 0, 35)
    titleFrame.BackgroundColor3 = MAIN_COLOR
    titleFrame.BorderSizePixel = 0
    Corner(titleFrame, 8)
    local tbm = Instance.new("Frame", titleFrame)
    tbm.Size = UDim2.new(1, 0, 0, 8); tbm.Position = UDim2.new(0, 0, 1, -8)
    tbm.BackgroundColor3 = MAIN_COLOR; tbm.BorderSizePixel = 0; tbm.ZIndex = 2

    local titleLabel = Instance.new("TextLabel", titleFrame)
    titleLabel.Size = UDim2.new(1, -10, 1, 0); titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1; titleLabel.Text = columnData.Name
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255); titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextSize = 14; titleLabel.TextXAlignment = Enum.TextXAlignment.Left; titleLabel.ZIndex = 3

    local fc = Instance.new("Frame", columnWindow)
    fc.Name = "FeaturesContainer"
    fc.Size = UDim2.new(1, -12, 1, -47); fc.Position = UDim2.new(0, 6, 0, 41)
    fc.BackgroundTransparency = 1; fc.BorderSizePixel = 0; fc.ClipsDescendants = true

    ColumnWindows[columnData.Name] = columnWindow

    for _, featureName in ipairs(columnData.Features) do
        BuildFeatureButton(fc, featureName)
    end
    task.defer(function() UpdateColumnLayout(columnData.Name) end)
end

for _, columnData in ipairs(Columns) do BuildOneColumn(columnData) end

SetFeatureState("HUD", true, true)

local guiVisible = false

local function SetMenu(open)
    guiVisible = open
    IsMenuOpen = open
    PlayToggleSound(open)
    if open then
        MainFrame.Visible = true
        TweenService:Create(Blur, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = 20 }):Play()
        for _, columnData in ipairs(Columns) do
            local cw = ColumnWindows[columnData.Name]
            if cw then AnimateColumnOpen(cw, columnData.Position) end
        end
    else
        CloseActiveSettings()
        TweenService:Create(Blur, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = 0 }):Play()
        for _, columnData in ipairs(Columns) do
            local cw = ColumnWindows[columnData.Name]
            if cw then AnimateColumnClose(cw, columnData.Position) end
        end
        task.delay(0.3, function() if not guiVisible then MainFrame.Visible = false end end)
    end
end

Track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if Unloaded or ListeningBind then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.J then
        SetMenu(not guiVisible)
        return
    end

    local keyName = input.KeyCode.Name
    for featureName, bound in pairs(BIND_SETTINGS) do
        local def = FeatureDefs[featureName]
        if bound == keyName and FeatureToggles[featureName] and def then
            if def.Instant then
                RunInstant(featureName)
            else
                SetFeatureState(featureName, not FeatureToggles[featureName].Enabled)
            end
        end
    end
end))

---------------------------------------------------------------------
-- UNLOAD
---------------------------------------------------------------------
Unload = function()
    if Unloaded then return end
    Unloaded = true
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    for _, fn in ipairs(Cleanups) do pcall(fn) end
    table.clear(Cleanups)
    CloseActiveSettings()
    TweenService:Create(Blur, TweenInfo.new(0.3), { Size = 0 }):Play()
    ShowNotification(CLIENT_NAME .. " выгружен", false)
    task.delay(0.4, function()
        for _, g in ipairs(GuiObjects) do pcall(function() g:Destroy() end) end
        pcall(function() Blur:Destroy() end)
    end)
    if env.KurvexUI_Unload == Unload then env.KurvexUI_Unload = nil end
end

env.KurvexUI_Unload = Unload

print("[" .. CLIENT_NAME .. "] Загружен | J - открыть / закрыть меню")
