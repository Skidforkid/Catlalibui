--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  CatlavanUI v2.0  —  UI library (Roblox / Luau)              ║
    ╚══════════════════════════════════════════════════════════════╝

    БЫСТРЫЙ СТАРТ
        local Lib = loadstring(readfile("CatlavanUI.lua"))()
        local UI  = Lib.new({ Name = "Catlavan", ToggleKey = Enum.KeyCode.RightShift })

        local col = UI:AddColumn("Combat")
        local f   = col:AddFeature("Aimbot", { Bind = "None", Callback = function(on) end })

        -- ПКМ по фиче открывает popup. Всё, что добавишь ниже, живёт в нём:
        f:AddToggle("Visible check", { Default = true,  Callback = function(v) end })
        f:AddSwitch("Team check",    { Default = false, Callback = function(v) end })
        f:AddTextbox("Target name",  { Placeholder = "name...", Callback = function(text) end })
        f:AddSlider("FOV",           { Min = 10, Max = 360, Default = 90, Suffix = "°", Callback = function(v) end })
        f:AddDropdown("Part",        { Values = {"Head","Torso"}, Default = "Head", Callback = function(v) end })
        f:AddDropdown("Targets",     { Values = {"Players","NPC"}, Multi = true, Callback = function(list) end })
        f:AddColorPicker("Color",    { Default = Color3.fromRGB(178,71,240), Callback = function(c) end })
        f:AddKeybind("Panic key",    { Default = "None", OnPress = function() end })
        f:AddButton("Reset",         function() end)
        f:AddLabel("Любой текст")
        f:AddSeparator("Section")

    API
        Lib.new(opts)            opts: Name, ToggleKey, Folder
        UI:AddColumn(name)       -> Column
        UI:Notify(text, state, duration)   state: true / false / nil
        UI:SetVisible(bool)      UI:Destroy()
        UI:SetBindList(bool)     список активных биндов (перетаскиваемый)
        UI:CreateHUD(opts)       -> HUD (:Set(bool) :SetMode("full"|"compact") :Destroy())
        UI:SaveConfig(name) / UI:LoadConfig(name)
        UI.Flags[flag]           текущие значения  |  UI.Options[flag] -> элемент (:Get() :Set(v, silent))

        Column:AddFeature(name, { Bind, Callback, Toggleable, Key })  -> Feature
        Column:AddButton(name, callback)
        Feature:Set(state, silent) / :Toggle() / :SetBind("F")
        Feature:AddToggle / AddSwitch / AddTextbox / AddSlider / AddDropdown
                AddColorPicker / AddKeybind / AddButton / AddLabel / AddSeparator

    Управление биндом: клик по кнопке бинда → нажми клавишу.  ESC — отмена, Backspace — убрать.
]]

-- ════════════════════════════ SERVICES ════════════════════════════
local S = setmetatable({}, {
    __index = function(t, name)
        local svc = game:GetService(name)
        rawset(t, name, svc)
        return svc
    end,
})

local Lib = {}
Lib.__index = Lib
Lib.Version = "2.0"
Lib.SoundEnabled = true
Lib.Sounds = {
    On = "rbxassetid://81628823068249",
    Off = "rbxassetid://135089017654613",
}

-- ════════════════════════════ THEME ════════════════════════════
local Theme = {
    Accent = Color3.fromHex("#b247f0"),
    AccentDark = Color3.fromHex("#6a1c97"),
    Glow = Color3.fromHex("#c25aff"),
    Border = Color3.fromHex("#8a4cc4"),
    Window = Color3.fromRGB(0, 0, 0),
    Popup = Color3.fromRGB(10, 10, 15),
    Element = Color3.fromRGB(22, 22, 30),
    ElementHover = Color3.fromRGB(36, 36, 50),
    Off = Color3.fromRGB(45, 45, 60),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(165, 165, 180),
    On = Color3.fromRGB(50, 255, 50),
    Bad = Color3.fromRGB(255, 50, 50),
    Font = Enum.Font.GothamBold,
    FontMed = Enum.Font.GothamMedium,
}
Lib.Theme = Theme

-- ════════════════════════════ UTIL ════════════════════════════
local Util = { lastSound = 0 }
Lib.Util = Util

-- Декларативное создание инстансов: меньше local-переменных, меньше кода.
local function New(class, props, children)
    local inst = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then
            parent = v
        else
            inst[k] = v
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    inst.Parent = parent
    return inst
end
Util.New = New

function Util.Corner(r)
    return New("UICorner", { CornerRadius = UDim.new(0, r) })
end

function Util.Stroke(color, thickness, transparency)
    return New("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

function Util.Pad(l, t, r, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
    })
end

function Util.List(padding)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

function Util.Label(props, children)
    local p = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Theme.Font,
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 18),
        Text = "",
    }
    for k, v in pairs(props or {}) do
        p[k] = v
    end
    return New("TextLabel", p, children)
end

function Util.Tween(inst, time, goal, style, dir)
    local tween = S.TweenService:Create(
        inst,
        TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        goal
    )
    tween:Play()
    return tween
end

function Util.Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[CatlavanUI] callback error: " .. tostring(err))
    end
end

function Util.Shift(u, dx, dy)
    return UDim2.new(u.X.Scale, u.X.Offset + (dx or 0), u.Y.Scale, u.Y.Offset + (dy or 0))
end

function Util.Sound(isOn)
    if not Lib.SoundEnabled then return end
    local now = os.clock()
    if now - Util.lastSound < 0.15 then return end
    Util.lastSound = now
    pcall(function()
        local snd = New("Sound", {
            SoundId = isOn and Lib.Sounds.On or Lib.Sounds.Off,
            Volume = 0.5,
            Parent = S.SoundService,
        })
        snd:Play()
        S.Debris:AddItem(snd, 2)
    end)
end

-- Координаты указателя в системе ScreenGui с IgnoreGuiInset = true
function Util.Pointer(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        return Vector2.new(input.Position.X, input.Position.Y) + S.GuiService:GetGuiInset()
    end
    return S.UserInputService:GetMouseLocation()
end

function Util.Inside(gui, p)
    local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
    return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
end

-- Перетаскивание: слушает глобальный InputChanged, поэтому курсор может выходить за пределы ручки.
function Util.Drag(hit, onMove, onEnd)
    hit.InputBegan:Connect(function(input)
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
        onMove(Util.Pointer(input), true)
        local conns = {}
        conns[1] = S.UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                onMove(Util.Pointer(i), false)
            end
        end)
        conns[2] = S.UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == kind then
                conns[1]:Disconnect()
                conns[2]:Disconnect()
                if onEnd then onEnd() end
            end
        end)
    end)
end

function Util.MakeDraggable(frame, handle, onBegin, onEnd)
    local startPtr, startPos
    Util.Drag(handle, function(p, first)
        if first then
            startPtr, startPos = p, frame.Position
            if onBegin then onBegin() end
            return
        end
        local d = p - startPtr
        frame.Position = Util.Shift(startPos, d.X, d.Y)
    end, onEnd)
end

function Util.GuiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and typeof(hui) == "Instance" then return hui end
    if pcall(function() return #S.CoreGui:GetChildren() end) then return S.CoreGui end
    return S.Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Файлы (работают только в экзекуторе, иначе молча возвращают false/nil)
Util.FS = {}
function Util.FS.Read(path)
    local ok, data = pcall(function()
        if isfile(path) then return readfile(path) end
    end)
    return ok and data or nil
end
function Util.FS.Write(path, data)
    return (pcall(function() writefile(path, data) end))
end
function Util.FS.Folder(path)
    pcall(function()
        if not isfolder(path) then makefolder(path) end
    end)
end

function Util.Encode(v)
    if typeof(v) == "Color3" then return { __color = v:ToHex() } end
    return v
end
function Util.Decode(v)
    if type(v) == "table" and v.__color then return Color3.fromHex(v.__color) end
    return v
end

-- ════════════════════════════ ELEMENTS ════════════════════════════
-- ctx = { UI = ui, Feature = feature|nil, Parent = frame, n = counter }
local Elements = {}
Lib.Elements = Elements

local Element = {}
Element.__index = Element

function Element:Get()
    return self.Value
end

function Element:_store(value, fire)
    self.Value = value
    if self.Flag then self.UI.Flags[self.Flag] = value end
    if fire then Util.Call(self.Callback, value) end
end

function Element:_render() end

function Element:Set(value, silent)
    if self._coerce then value = self:_coerce(value) end
    self:_store(value, not silent)
    self:_render(value)
end

function Element:SetVisible(state)
    self.Root.Visible = state
end

function Element:Destroy()
    if self.Flag then
        self.UI.Flags[self.Flag] = nil
        self.UI.Options[self.Flag] = nil
    end
    local kbs = self.UI._keybinds
    for i = #kbs, 1, -1 do
        if kbs[i] == self then table.remove(kbs, i) end
    end
    self.Root:Destroy()
end

local function Opts(o)
    return type(o) == "table" and o or {}
end

local function Make(ctx, kind, name, opts, default, flagged)
    local el = setmetatable({
        Kind = kind,
        Name = name,
        UI = ctx.UI,
        Value = default,
        Callback = opts.Callback,
    }, Element)
    if flagged ~= false then
        el.Flag = opts.Flag or ((ctx.Feature and ctx.Feature.Key or "Global") .. "/" .. name)
        ctx.UI.Flags[el.Flag] = default
        ctx.UI.Options[el.Flag] = el
    end
    ctx.n = ctx.n + 1
    el.Order = ctx.n
    return el
end

local function Row(ctx, el, height, button)
    local props = {
        Name = el.Name,
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = el.Order,
        Parent = ctx.Parent,
    }
    if button then
        props.Text = ""
        props.AutoButtonColor = false
    end
    el.Root = New(button and "TextButton" or "Frame", props)
    return el.Root
end

-- ── Toggle (чекбокс) ──
function Elements.Toggle(ctx, name, opts)
    opts = Opts(opts)
    local el = Make(ctx, "Toggle", name, opts, opts.Default == true)
    local row = Row(ctx, el, 26, true)
    Util.Label({ Text = name, Size = UDim2.new(1, -30, 1, 0), Parent = row })
    local box = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
        Parent = row,
    }, { Util.Corner(4), Util.Stroke(Theme.Border, 1, 0.6) })
    local fill = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = box,
    }, { Util.Corner(3) })
    el._render = function(_, on)
        Util.Tween(box, 0.12, { BackgroundColor3 = on and Theme.AccentDark or Theme.Off })
        Util.Tween(fill, 0.15, { Size = on and UDim2.fromOffset(10, 10) or UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
    end
    row.MouseButton1Click:Connect(function()
        Util.Sound(not el.Value)
        el:Set(not el.Value)
    end)
    el:_render(el.Value)
    return el
end

-- ── Switch (ползунок-пилюля) ──
function Elements.Switch(ctx, name, opts)
    opts = Opts(opts)
    local el = Make(ctx, "Switch", name, opts, opts.Default == true)
    local row = Row(ctx, el, 26, true)
    Util.Label({ Text = name, Size = UDim2.new(1, -46, 1, 0), Parent = row })
    local track = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(36, 18),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
        Parent = row,
    }, { Util.Corner(9) })
    local knob = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
        Parent = track,
    }, { Util.Corner(7) })
    el._render = function(_, on)
        Util.Tween(track, 0.15, { BackgroundColor3 = on and Theme.Accent or Theme.Off })
        Util.Tween(knob, 0.15, { Position = on and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
    end
    row.MouseButton1Click:Connect(function()
        Util.Sound(not el.Value)
        el:Set(not el.Value)
    end)
    el:_render(el.Value)
    return el
end

-- ── Textbox ──
function Elements.Textbox(ctx, name, opts)
    opts = Opts(opts)
    local numeric = opts.Numeric == true
    local default = numeric and (tonumber(opts.Default) or 0) or tostring(opts.Default == nil and "" or opts.Default)
    local el = Make(ctx, "Textbox", name, opts, default)
    local row = Row(ctx, el, 48)
    Util.Label({ Text = name, Size = UDim2.new(1, 0, 0, 18), Parent = row })
    local stroke = Util.Stroke(Theme.Border, 1, 0.6)
    local box = New("TextBox", {
        Position = UDim2.fromOffset(0, 21),
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        Text = tostring(default),
        PlaceholderText = opts.Placeholder or "Type here...",
        PlaceholderColor3 = Theme.SubText,
        TextColor3 = Theme.Text,
        Font = Theme.FontMed,
        TextSize = 13,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    }, { Util.Corner(4), Util.Pad(8, 0, 8, 0), stroke })

    el._coerce = function(self, v)
        if numeric then
            local n = tonumber(v)
            if n == nil then return self.Value end
            if opts.Min then n = math.max(n, opts.Min) end
            if opts.Max then n = math.min(n, opts.Max) end
            return n
        end
        return tostring(v == nil and "" or v)
    end
    el._render = function(_, v)
        box.Text = tostring(v)
    end

    box:GetPropertyChangedSignal("Text"):Connect(function()
        if numeric then
            local clean = box.Text:gsub("[^%d%.%-]", "")
            if clean ~= box.Text then
                box.Text = clean
                return
            end
        end
        if opts.Live then
            el:_store(numeric and (tonumber(box.Text) or el.Value) or box.Text, true)
        end
    end)
    box.Focused:Connect(function()
        Util.Tween(stroke, 0.1, { Color = Theme.Accent, Transparency = 0 })
    end)
    box.FocusLost:Connect(function()
        Util.Tween(stroke, 0.1, { Color = Theme.Border, Transparency = 0.6 })
        el:Set(box.Text)
    end)
    return el
end

-- ── Slider ──
function Elements.Slider(ctx, name, opts)
    opts = Opts(opts)
    local min, max, inc = opts.Min or 0, opts.Max or 100, opts.Increment or 1
    local decimals = #(tostring(inc):match("%.(%d+)") or "")
    local fmt = "%." .. decimals .. "f"
    local function snap(v)
        v = math.clamp(tonumber(v) or min, min, max)
        v = math.floor((v - min) / inc + 0.5) * inc + min
        return tonumber(string.format(fmt, math.clamp(v, min, max)))
    end

    local el = Make(ctx, "Slider", name, opts, snap(opts.Default or min))
    local row = Row(ctx, el, 38)
    Util.Label({ Text = name, Size = UDim2.new(0.6, 0, 0, 18), Parent = row })
    local valueLabel = Util.Label({
        Size = UDim2.new(0.4, 0, 0, 18),
        Position = UDim2.fromScale(0.6, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Theme.SubText,
        Parent = row,
    })
    local track = New("Frame", {
        Position = UDim2.fromOffset(0, 26),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
        Parent = row,
    }, { Util.Corner(3) })
    local fill = New("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    }, { Util.Corner(3) })
    New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
        Parent = fill,
    }, { Util.Corner(6) })
    local hit = New("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 18),
        Size = UDim2.new(1, 0, 0, 22),
        Parent = row,
    })

    el._coerce = function(_, v)
        return snap(v)
    end
    el._render = function(_, v)
        local a = (max > min) and (v - min) / (max - min) or 0
        fill.Size = UDim2.fromScale(a, 1)
        valueLabel.Text = string.format(fmt, v) .. (opts.Suffix or "")
    end
    Util.Drag(hit, function(p)
        local a = math.clamp((p.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = snap(min + (max - min) * a)
        if v ~= el.Value then el:Set(v) end
    end)
    el:_render(el.Value)
    return el
end

-- ── Dropdown (одиночный и Multi) ──
function Elements.Dropdown(ctx, name, opts)
    opts = Opts(opts)
    local multi = opts.Multi == true
    local el = Make(ctx, multi and "MultiDropdown" or "Dropdown", name, opts, multi and {} or opts.Default)
    el.Values = opts.Values or {}
    local selected, open = {}, false

    el.Root = New("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = el.Order,
        Parent = ctx.Parent,
    }, { Util.List(4) })

    local head = New("TextButton", {
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Parent = el.Root,
    }, { Util.Corner(4), Util.Stroke(Theme.Border, 1, 0.6) })
    Util.Label({
        Text = name,
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(0.45, -8, 1, 0),
        TextColor3 = Theme.SubText,
        Parent = head,
    })
    local current = Util.Label({
        Position = UDim2.fromScale(0.4, 0),
        Size = UDim2.new(0.6, -26, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Theme.Accent,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = head,
    })
    local arrow = Util.Label({
        Text = ">",
        Position = UDim2.new(1, -18, 0, 0),
        Size = UDim2.fromOffset(12, 28),
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = head,
    })
    local list = New("ScrollingFrame", {
        Visible = false,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        Parent = el.Root,
    }, { Util.Corner(4), Util.List(0) })

    local function recolor()
        for _, b in ipairs(list:GetChildren()) do
            if b:IsA("TextButton") then
                local on
                if multi then on = selected[b.Name] == true else on = tostring(el.Value) == b.Name end
                b.TextColor3 = on and Theme.Accent or Theme.Text
            end
        end
    end

    local function setOpen(state)
        open = state
        list.Visible = state
        Util.Tween(arrow, 0.15, { Rotation = state and 90 or 0 })
    end

    local function rebuild()
        for _, b in ipairs(list:GetChildren()) do
            if b:IsA("TextButton") then b:Destroy() end
        end
        for i, v in ipairs(el.Values) do
            local btn = New("TextButton", {
                Name = tostring(v),
                Text = tostring(v),
                AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = Theme.FontMed,
                TextSize = 13,
                TextColor3 = Theme.Text,
                LayoutOrder = i,
                Parent = list,
            })
            btn.MouseButton1Click:Connect(function()
                Util.Sound(true)
                if multi then
                    local nextSel = {}
                    for k in pairs(selected) do nextSel[k] = true end
                    nextSel[tostring(v)] = (not nextSel[tostring(v)]) or nil
                    local out = {}
                    for _, val in ipairs(el.Values) do
                        if nextSel[tostring(val)] then table.insert(out, val) end
                    end
                    el:Set(out)
                else
                    el:Set(v)
                    setOpen(false)
                end
            end)
        end
        list.Size = UDim2.new(1, 0, 0, math.min(#el.Values, 6) * 26)
        recolor()
    end

    el._coerce = function(self, v)
        if not multi then return v end
        local map = {}
        if type(v) == "table" then
            for k, x in pairs(v) do
                if type(k) == "number" then map[tostring(x)] = true elseif x == true then map[tostring(k)] = true end
            end
        end
        selected = map
        local out = {}
        for _, val in ipairs(self.Values) do
            if map[tostring(val)] then table.insert(out, val) end
        end
        return out
    end
    el._render = function(_, v)
        if multi then
            local parts = {}
            for _, x in ipairs(v) do table.insert(parts, tostring(x)) end
            current.Text = #parts > 0 and table.concat(parts, ", ") or "None"
        else
            current.Text = v ~= nil and tostring(v) or "None"
        end
        recolor()
    end
    function el:SetValues(newValues)
        self.Values = newValues
        rebuild()
        self:Set(self.Value, true)
    end

    head.MouseButton1Click:Connect(function()
        setOpen(not open)
    end)
    rebuild()
    el:Set(multi and (opts.Default or {}) or opts.Default, true)
    return el
end

-- ── ColorPicker ──
function Elements.ColorPicker(ctx, name, opts)
    opts = Opts(opts)
    local default = opts.Default or Color3.fromRGB(178, 71, 240)
    local el = Make(ctx, "ColorPicker", name, opts, default)
    el._h, el._s, el._v = default:ToHSV()

    el.Root = New("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = el.Order,
        Parent = ctx.Parent,
    }, { Util.List(6) })

    local head = New("TextButton", {
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = el.Root,
    })
    Util.Label({ Text = name, Size = UDim2.new(1, -46, 1, 0), Parent = head })
    local swatch = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(38, 18),
        BackgroundColor3 = default,
        BorderSizePixel = 0,
        Parent = head,
    }, { Util.Corner(4), Util.Stroke(Theme.Text, 1, 0.7) })

    local panel = New("Frame", {
        Visible = false,
        Size = UDim2.new(1, 0, 0, 124),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = el.Root,
    })
    local sv = New("Frame", {
        Size = UDim2.new(1, 0, 0, 100),
        BackgroundColor3 = Color3.fromHSV(el._h, 1, 1),
        BorderSizePixel = 0,
        Parent = panel,
    }, {
        Util.Corner(4),
        New("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        }, { Util.Corner(4), New("UIGradient", { Transparency = NumberSequence.new(0, 1) }) }),
        New("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0,
        }, { Util.Corner(4), New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) }),
    })
    local cursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(9, 9),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = sv,
    }, { Util.Corner(5), Util.Stroke(Color3.new(1, 1, 1), 1.5) })

    local rainbow = {}
    for i = 0, 6 do
        table.insert(rainbow, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)))
    end
    rainbow[#rainbow] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))
    local hue = New("Frame", {
        Position = UDim2.fromOffset(0, 108),
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = panel,
    }, { Util.Corner(4), New("UIGradient", { Color = ColorSequence.new(rainbow) }) })
    local hueCursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(0, 4, 1, 4),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = hue,
    }, { Util.Corner(2), Util.Stroke(Color3.new(0, 0, 0), 1) })

    el._coerce = function(self, c)
        if typeof(c) ~= "Color3" then return self.Value end
        self._h, self._s, self._v = c:ToHSV()
        return c
    end
    el._render = function(self)
        swatch.BackgroundColor3 = Color3.fromHSV(self._h, self._s, self._v)
        sv.BackgroundColor3 = Color3.fromHSV(self._h, 1, 1)
        cursor.Position = UDim2.fromScale(self._s, 1 - self._v)
        hueCursor.Position = UDim2.fromScale(self._h, 0.5)
    end
    local function apply(h, s, v)
        el._h, el._s, el._v = h or el._h, s or el._s, v or el._v
        el:_store(Color3.fromHSV(el._h, el._s, el._v), true)
        el:_render()
    end
    Util.Drag(sv, function(p)
        apply(
            nil,
            math.clamp((p.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1),
            1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
        )
    end)
    Util.Drag(hue, function(p)
        apply(math.clamp((p.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 0.999))
    end)
    head.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
    end)
    el:_render()
    return el
end

-- ── Keybind ──
function Elements.Keybind(ctx, name, opts)
    opts = Opts(opts)
    local el = Make(ctx, "Keybind", name, opts, opts.Default or "None")
    el.OnPress = opts.OnPress
    local row = Row(ctx, el, 26)
    Util.Label({ Text = name, Size = UDim2.new(1, -84, 1, 0), Parent = row })
    local btn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(78, 22),
        BackgroundColor3 = Theme.Element,
        AutoButtonColor = false,
        Text = "",
        Font = Theme.Font,
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextTruncate = Enum.TextTruncate.AtEnd,
        BorderSizePixel = 0,
        Parent = row,
    }, { Util.Corner(4), Util.Stroke(Theme.Border, 1, 0.6) })

    el._render = function(_, v)
        btn.Text = v
    end
    btn.MouseButton1Click:Connect(function()
        btn.Text = "Press key..."
        Util.Sound(true)
        el.UI:_listen(function(key)
            if key == nil then
                el:_render(el.Value) -- ESC: отмена
            else
                Util.Sound(key ~= "None")
                el:Set(key)
            end
        end)
    end)
    if opts.Register ~= false then
        table.insert(ctx.UI._keybinds, el)
    end
    el:_render(el.Value)
    return el
end

-- ── Button ──
function Elements.Button(ctx, name, opts)
    if type(opts) == "function" then opts = { Callback = opts } end
    opts = Opts(opts)
    local el = Make(ctx, "Button", name, opts, nil, false)
    local row = Row(ctx, el, 28, true)
    row.BackgroundTransparency = 0
    row.BackgroundColor3 = Theme.Element
    row.Text = name
    row.Font = Theme.Font
    row.TextSize = 13
    row.TextColor3 = Theme.Text
    Util.Corner(4).Parent = row
    Util.Stroke(Theme.Border, 1, 0.6).Parent = row
    row.MouseEnter:Connect(function()
        Util.Tween(row, 0.1, { BackgroundColor3 = Theme.ElementHover })
    end)
    row.MouseLeave:Connect(function()
        Util.Tween(row, 0.1, { BackgroundColor3 = Theme.Element })
    end)
    row.MouseButton1Click:Connect(function()
        Util.Sound(true)
        row.BackgroundColor3 = Theme.AccentDark
        Util.Tween(row, 0.25, { BackgroundColor3 = Theme.ElementHover })
        Util.Call(el.Callback)
    end)
    function el:SetText(text)
        row.Text = text
    end
    return el
end

-- ── Label ──
function Elements.Label(ctx, text, opts)
    opts = Opts(opts)
    local el = Make(ctx, "Label", text, opts, text, false)
    el.Root = Util.Label({
        Name = "Label",
        Text = text,
        Size = UDim2.new(1, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = opts.Color or Theme.SubText,
        Font = Theme.FontMed,
        LayoutOrder = el.Order,
        Parent = ctx.Parent,
    })
    function el:SetText(t)
        self.Root.Text = t
    end
    return el
end

-- ── Separator ──
function Elements.Separator(ctx, name)
    name = name or ""
    local el = Make(ctx, "Separator", name, {}, nil, false)
    local row = Row(ctx, el, 14)
    New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Border,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Parent = row,
    })
    if name ~= "" then
        Util.Label({
            Text = name,
            TextSize = 11,
            TextColor3 = Theme.SubText,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 0,
            BackgroundColor3 = Theme.Popup,
            Parent = row,
        }, { Util.Pad(0, 0, 6, 0) })
    end
    return el
end

-- ════════════════════════════ FEATURE ════════════════════════════
local Feature = {}
Feature.__index = Feature

for kind, ctor in pairs(Elements) do
    Feature["Add" .. kind] = function(self, ...)
        return ctor(self._ctx, ...)
    end
end

function Feature:Set(state, silent)
    state = state == true
    if self.Enabled == state then return end
    self.Enabled = state
    self.Status.Text = state and "On" or "Off"
    Util.Tween(self.Status, 0.12, { TextColor3 = state and Theme.On or Theme.Bad })
    Util.Tween(self.Accent, 0.12, { BackgroundTransparency = state and 0 or 1 })
    if not silent then
        Util.Sound(state)
        self.UI:Notify(self.Name .. " [" .. self.Column.Name .. "]: " .. (state and "ENABLED" or "DISABLED"), state)
    end
    Util.Call(self.Callback, state)
    self.UI:_refreshBindList()
end

function Feature:Toggle()
    if self.Toggleable then
        self:Set(not self.Enabled)
    else
        Util.Sound(true)
        Util.Call(self.Callback)
    end
end

function Feature:SetBind(key)
    self._bindEl:Set(key or "None")
end

-- ════════════════════════════ COLUMN ════════════════════════════
local Column = {}
Column.__index = Column

function Column:_animate(open)
    local home = self.Home
    if open then
        self.Frame.BackgroundTransparency = 1
        self.Frame.Position = Util.Shift(home, 50, 0)
        Util.Tween(self.Frame, 0.25, { BackgroundTransparency = 0.05, Position = home })
    else
        Util.Tween(self.Frame, 0.2, { BackgroundTransparency = 1, Position = Util.Shift(home, 50, 0) },
            Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    end
end

function Column:AddFeature(name, opts)
    opts = Opts(opts)
    local ui = self.UI
    local f = setmetatable({
        UI = ui,
        Column = self,
        Name = name,
        Key = opts.Key or (self.Name .. "_" .. name),
        Enabled = false,
        Bind = opts.Bind or "None",
        Callback = opts.Callback,
        Toggleable = opts.Toggleable ~= false,
    }, Feature)
    ui.Features[f.Key] = f
    table.insert(ui.FeatureList, f)
    table.insert(self.Features, f)

    -- строка в колонке
    f.Button = New("TextButton", {
        Name = name,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.Element,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = #self.Features,
        Parent = self.List,
    }, { Util.Corner(4) })
    f.Accent = New("Frame", {
        Position = UDim2.new(0, 0, 0, 6),
        Size = UDim2.new(0, 3, 1, -12),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = f.Button,
    }, { Util.Corner(2) })
    Util.Label({
        Text = name,
        TextSize = 14,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.7, -12, 1, 0),
        Parent = f.Button,
    })
    f.Status = Util.Label({
        Text = f.Toggleable and "Off" or "",
        TextColor3 = Theme.Bad,
        Position = UDim2.new(0.7, -10, 0, 0),
        Size = UDim2.fromScale(0.3, 1),
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = f.Button,
    })

    -- popup (создаётся сразу, скрыт)
    local content, footer
    f.Popup = New("CanvasGroup", {
        Name = f.Key .. "_Popup",
        Size = UDim2.fromOffset(Lib.PopupWidth, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Popup,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Visible = false,
        Active = true,
        ZIndex = 50,
        Parent = ui.Gui,
    }, {
        Util.Corner(6),
        Util.Stroke(Theme.Border, 1, 0.3),
        Util.Pad(8, 8, 8, 8),
        Util.List(6),
        Util.Label({ Name = "Header", Text = name, TextSize = 14, LayoutOrder = 0 }),
    })
    content = New("Frame", {
        Name = "Content",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = f.Popup,
    }, { Util.List(6) })
    footer = New("Frame", {
        Name = "Footer",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = f.Popup,
    }, { Util.List(6) })
    f._ctx = { UI = ui, Feature = f, Parent = content, n = 0 }
    f._bindEl = Elements.Keybind({ UI = ui, Feature = f, Parent = footer, n = 0 }, "Bind", {
        Default = f.Bind,
        Register = false,
        Flag = f.Key .. "/Bind",
        Callback = function(key)
            f.Bind = key
            ui:_refreshBindList()
        end,
    })

    -- взаимодействие
    f.Button.MouseEnter:Connect(function()
        Util.Tween(f.Button, 0.1, { BackgroundTransparency = 0.2 })
    end)
    f.Button.MouseLeave:Connect(function()
        Util.Tween(f.Button, 0.1, { BackgroundTransparency = 0.5 })
    end)
    f.Button.MouseButton1Click:Connect(function()
        f:Toggle()
    end)
    f.Button.MouseButton2Click:Connect(function()
        ui:_openPopup(f)
    end)
    return f
end

function Column:AddButton(name, callback)
    return self:AddFeature(name, { Toggleable = false, Callback = callback })
end

-- ════════════════════════════ LIB (WINDOW) ════════════════════════════
Lib.PopupWidth = 220

function Lib.new(opts)
    opts = Opts(opts)
    local self = setmetatable({
        Name = opts.Name or "Catlavan",
        ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift,
        Folder = opts.Folder or "CatlavanClient",
        Visible = false,
        Columns = {},
        Features = {},
        FeatureList = {},
        Flags = {},
        Options = {},
        _conns = {},
        _keybinds = {},
        _notifs = {},
        _huds = {},
        _token = 0,
        _listenEnd = 0,
    }, Lib)

    self.Gui = New("ScreenGui", {
        Name = self.Name .. "_GUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
        Parent = Util.GuiParent(),
    })
    self.Main = New("Frame", {
        Name = "Main",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        Parent = self.Gui,
    })

    -- единый глобальный обработчик ввода
    self:_connect(S.UserInputService.InputBegan, function(input, processed)
        local kind = input.UserInputType
        -- клик вне popup закрывает его
        if self._popup and (kind == Enum.UserInputType.MouseButton1
            or kind == Enum.UserInputType.MouseButton2 or kind == Enum.UserInputType.Touch) then
            local p = Util.Pointer(input)
            if not Util.Inside(self._popup.Frame, p) and not Util.Inside(self._popup.Feature.Button, p) then
                self:_closePopup()
            end
        end
        if kind ~= Enum.UserInputType.Keyboard or processed then return end
        if self._listenConn or os.clock() - self._listenEnd < 0.2 then return end

        if input.KeyCode == self.ToggleKey then
            self:SetVisible(not self.Visible)
            return
        end
        local key = input.KeyCode.Name
        for _, f in ipairs(self.FeatureList) do
            if f.Bind == key then f:Toggle() end
        end
        for _, kb in ipairs(self._keybinds) do
            if kb.Value == key then Util.Call(kb.OnPress, kb) end
        end
    end)
    return self
end

function Lib:_connect(signal, fn)
    table.insert(self._conns, signal:Connect(fn))
end

-- ── видимость меню ──
function Lib:SetVisible(state)
    state = state == true
    if self.Visible == state then return end
    self.Visible = state
    self._token = self._token + 1
    local token = self._token
    Util.Sound(state)
    self:_closePopup()
    if state then self.Main.Visible = true end
    for _, col in ipairs(self.Columns) do
        col:_animate(state)
    end
    if not state then
        task.delay(0.22, function()
            if self._token == token then self.Main.Visible = false end
        end)
    end
end

-- ── колонки ──
function Lib:AddColumn(name)
    local col = setmetatable({ UI = self, Name = name, Features = {} }, Column)
    col.Frame = New("Frame", {
        Name = "Column_" .. name,
        Size = UDim2.fromOffset(250, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Window,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Parent = self.Main,
    }, { Util.Corner(8), Util.Pad(6, 0, 6, 6), Util.List(6) })
    local title = Util.Label({
        Text = name,
        TextSize = 16,
        Size = UDim2.new(1, 0, 0, 35),
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 0,
        Parent = col.Frame,
    })
    col.List = New("Frame", {
        Name = "Features",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = col.Frame,
    }, { Util.List(8) })
    Util.MakeDraggable(col.Frame, title, function()
        self:_closePopup()
    end, function()
        col.Moved = true
        col.Home = col.Frame.Position
    end)
    table.insert(self.Columns, col)
    self:_layoutColumns()
    return col
end

function Lib:_layoutColumns()
    local n, w, gap = #self.Columns, 250, 10
    local total = n * w + (n - 1) * gap
    for i, col in ipairs(self.Columns) do
        if not col.Moved then
            col.Home = UDim2.new(0.5, -total / 2 + (i - 1) * (w + gap), 0, 90)
            col.Frame.Position = col.Home
        end
    end
end

-- ── popup ──
function Lib:_openPopup(f)
    if self._popup and self._popup.Feature == f then
        return self:_closePopup()
    end
    self:_closePopup()
    local pop = f.Popup
    local bp, bs = f.Button.AbsolutePosition, f.Button.AbsoluteSize
    local screen = self.Gui.AbsoluteSize
    local x, y, dir = bp.X + bs.X + 10, bp.Y, -10
    if x + Lib.PopupWidth > screen.X - 5 then
        x, dir = bp.X - Lib.PopupWidth - 10, 10
    end
    x = math.max(5, x)

    pop.Position = UDim2.fromOffset(x + dir, y)
    pop.GroupTransparency = 1
    pop.Visible = true
    self._popup = { Feature = f, Frame = pop }
    Util.Tween(pop, 0.2, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) })

    task.delay(0.05, function() -- когда лейаут посчитан — не даём popup вылезти за экран
        if self._popup and self._popup.Frame == pop then
            local maxY = screen.Y - pop.AbsoluteSize.Y - 10
            if y > maxY then
                Util.Tween(pop, 0.1, { Position = UDim2.fromOffset(x, math.max(10, maxY)) })
            end
        end
    end)
end

function Lib:_closePopup()
    local cur = self._popup
    if not cur then return end
    self._popup = nil
    local pop = cur.Frame
    Util.Tween(pop, 0.15, { GroupTransparency = 1 })
    task.delay(0.15, function()
        if not self._popup or self._popup.Frame ~= pop then
            pop.Visible = false
        end
    end)
end

-- ── прослушка клавиши для биндов ──
function Lib:_stopListen()
    if self._listenConn then
        self._listenConn:Disconnect()
        self._listenConn = nil
        self._listenEnd = os.clock()
    end
end

function Lib:_listen(onKey)
    self:_stopListen()
    self._listenConn = S.UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        self:_stopListen()
        if input.KeyCode == Enum.KeyCode.Escape then
            onKey(nil)
        elseif input.KeyCode == Enum.KeyCode.Backspace then
            onKey("None")
        else
            onKey(input.KeyCode.Name)
        end
    end)
end

-- ── уведомления ──
function Lib:Notify(text, state, duration)
    if not self.NotifGui then
        self.NotifGui = New("ScreenGui", {
            Name = self.Name .. "_Notifications",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = 1000,
            Parent = Util.GuiParent(),
        })
    end
    local dotColor = state == true and Theme.On or (state == false and Theme.Bad or Theme.Accent)
    local n = {}
    n.Frame = New("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Size = UDim2.fromOffset(280, 40),
        Position = UDim2.new(1, -20, 1, 140),
        BackgroundColor3 = Theme.Window,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Parent = self.NotifGui,
    }, {
        Util.Corner(6),
        Util.Label({ Text = text, Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -40, 1, -10) }),
        New("Frame", {
            Position = UDim2.new(1, -15, 0.5, -4),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = dotColor,
            BorderSizePixel = 0,
        }, { Util.Corner(4) }),
    })
    table.insert(self._notifs, n)
    self:_layoutNotifs()

    task.delay(duration or 1.5, function()
        for i, v in ipairs(self._notifs) do
            if v == n then table.remove(self._notifs, i) break end
        end
        Util.Tween(n.Frame, 0.2, {
            Position = UDim2.new(1, -20, 1, 140),
            BackgroundTransparency = 1,
        }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.2, function()
            n.Frame:Destroy()
        end)
        self:_layoutNotifs()
    end)
end

function Lib:_layoutNotifs()
    for i, n in ipairs(self._notifs) do
        Util.Tween(n.Frame, 0.3, { Position = UDim2.new(1, -20, 1, -(20 + 48 * (i - 1))) },
            Enum.EasingStyle.Back)
    end
end

-- ── список активных биндов ──
function Lib:SetBindList(state)
    if not state then
        if self._bindList then
            self._bindList.Gui:Destroy()
            self._bindList = nil
        end
        return
    end
    if self._bindList then return end
    local gui = New("ScreenGui", {
        Name = self.Name .. "_Binds",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = Util.GuiParent(),
    })
    local frame = New("Frame", {
        Position = UDim2.fromOffset(15, 70),
        Size = UDim2.fromOffset(200, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Window,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Parent = gui,
    }, { Util.Corner(6), Util.Pad(8, 4, 8, 6), Util.List(2) })
    local title = Util.Label({ Text = "ACTIVE BINDS", TextSize = 12, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0, Parent = frame })
    local rows = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = frame,
    }, { Util.List(2) })
    Util.MakeDraggable(frame, title)
    self._bindList = { Gui = gui, Rows = rows }
    self:_refreshBindList()
end

function Lib:_refreshBindList()
    local bl = self._bindList
    if not bl then return end
    for _, c in ipairs(bl.Rows:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    local count = 0
    for _, f in ipairs(self.FeatureList) do
        if f.Enabled and f.Bind ~= "None" then
            count = count + 1
            New("Frame", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                LayoutOrder = count,
                Parent = bl.Rows,
            }, {
                Util.Label({ Text = f.Name, TextSize = 11, Size = UDim2.fromScale(0.7, 1) }),
                Util.Label({
                    Text = f.Bind, TextSize = 11,
                    Size = UDim2.fromScale(0.3, 1), Position = UDim2.fromScale(0.7, 0),
                    TextXAlignment = Enum.TextXAlignment.Right,
                }),
            })
        end
    end
    if count == 0 then
        Util.Label({
            Text = "No active binds", TextSize = 11, TextColor3 = Theme.SubText,
            Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, Parent = bl.Rows,
        })
    end
end

-- ── конфиги ──
function Lib:SaveConfig(name)
    name = name or "default"
    Util.FS.Folder(self.Folder)
    Util.FS.Folder(self.Folder .. "/config")
    local data = { Flags = {}, Features = {} }
    for flag, v in pairs(self.Flags) do data.Flags[flag] = Util.Encode(v) end
    for key, f in pairs(self.Features) do data.Features[key] = f.Enabled end
    local ok, json = pcall(S.HttpService.JSONEncode, S.HttpService, data)
    if not ok then return false end
    return Util.FS.Write(self.Folder .. "/config/" .. name .. ".json", json)
end

function Lib:LoadConfig(name)
    local raw = Util.FS.Read(self.Folder .. "/config/" .. (name or "default") .. ".json")
    if not raw then return false end
    local ok, data = pcall(S.HttpService.JSONDecode, S.HttpService, raw)
    if not ok or type(data) ~= "table" then return false end
    for flag, v in pairs(data.Flags or {}) do
        local el = self.Options[flag]
        if el then el:Set(Util.Decode(v)) end
    end
    for key, state in pairs(data.Features or {}) do
        local f = self.Features[key]
        if f then f:Set(state, true) end
    end
    return true
end

-- ════════════════════════════ HUD ════════════════════════════
local HUD = {}
HUD.__index = HUD
local HUD_LOGO = "100692582418599"
local HUD_ICONS = { USER = "122670473687992", FPS = "11322155020", PING = "110607563566552", COORDS = "101883294376981" }

function Lib:CreateHUD(opts)
    opts = Opts(opts)
    local hud = setmetatable({
        UI = self,
        Mode = (opts.Mode == "compact") and "compact" or "full",
        Title = opts.Title or self.Name,
        Logo = opts.Logo == nil and HUD_LOGO or opts.Logo, -- false → текстовый логотип "CL"
        Icons = opts.Icons or HUD_ICONS,
        Enabled = false,
        _conns = {},
    }, HUD)
    table.insert(self._huds, hud)
    return hud
end

function HUD:_clear()
    for _, c in ipairs(self._conns) do c:Disconnect() end
    self._conns = {}
    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end
end

function HUD:Set(enabled)
    self.Enabled = enabled == true
    if self.Enabled then self:_build() else self:_clear() end
end

function HUD:SetMode(mode)
    self.Mode = (tostring(mode):lower() == "compact") and "compact" or "full"
    if self.Enabled then self:_build() end
end

function HUD:Destroy()
    self.Enabled = false
    self:_clear()
end

function HUD:_build()
    self:_clear()
    local H, L = 45, 32
    local full = self.Mode == "full"
    local width = full and 540 or 250

    self.Gui = New("ScreenGui", {
        Name = "Catlavan_HUD",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = Util.GuiParent(),
    })
    local win = New("Frame", {
        Name = "Window",
        Position = UDim2.fromOffset(15, 15),
        Size = UDim2.fromOffset(0, H),
        BackgroundColor3 = Theme.Window,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = self.Gui,
    }, { Util.Corner(6) })

    if self.Logo then
        New("ImageLabel", {
            Position = UDim2.new(0, 5, 0.5, -L / 2),
            Size = UDim2.fromOffset(L, L),
            BackgroundTransparency = 1,
            Image = "rbxassetid://" .. self.Logo,
            ScaleType = Enum.ScaleType.Fit,
            Parent = win,
        }, { Util.Corner(6) })
    else
        Util.Label({
            Text = "CL", Font = Enum.Font.GothamBlack, TextSize = 16,
            Position = UDim2.new(0, 5, 0.5, -L / 2), Size = UDim2.fromOffset(L, L),
            TextXAlignment = Enum.TextXAlignment.Center, Parent = win,
        })
    end

    local lab = {}
    local player = S.Players.LocalPlayer
    if full then
        local sections = {
            { "USER", 57, player.DisplayName },
            { "FPS", 162, "0Fps" },
            { "PING", 287, "0ms" },
            { "COORDS", 412, "0,0,0" },
        }
        for _, s in ipairs(sections) do
            local sec = New("Frame", {
                Name = s[1] .. "_Section",
                Position = UDim2.fromOffset(s[2], 0),
                Size = UDim2.fromOffset(120, H),
                BackgroundTransparency = 1,
                Parent = win,
            })
            local icon = New("Frame", {
                Size = UDim2.new(0, 30, 1, 0),
                BackgroundColor3 = Theme.Popup,
                BorderSizePixel = 0,
                Parent = sec,
            }, { Util.Corner(4) })
            if self.Icons[s[1]] then
                New("ImageLabel", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(0.9, 0.9),
                    BackgroundTransparency = 1,
                    Image = "rbxassetid://" .. self.Icons[s[1]],
                    ScaleType = Enum.ScaleType.Fit,
                    Parent = icon,
                })
            else
                Util.Label({ Text = "•", Font = Enum.Font.GothamBlack, TextSize = 16,
                    Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = icon })
            end
            lab[s[1]] = Util.Label({
                Text = s[3],
                Position = UDim2.fromOffset(31, 3),
                Size = UDim2.new(1, -31, 1, -6),
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = sec,
            })
        end
    else
        Util.Label({
            Text = self.Title, TextSize = 14,
            Position = UDim2.fromOffset(L + 10, 0), Size = UDim2.fromOffset(60, H), Parent = win,
        })
        New("Frame", {
            Position = UDim2.new(0, L + 75, 0.2, 0),
            Size = UDim2.new(0, 1, 0.6, 0),
            BackgroundColor3 = Theme.Text,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Parent = win,
        })
        lab.USER = Util.Label({
            Text = player.DisplayName,
            Position = UDim2.fromOffset(L + 85, 0), Size = UDim2.fromOffset(120, H), Parent = win,
        })
    end

    -- одно подключение вместо трёх; текст обновляем только при изменении
    local frames, acc, lastCoords = 0, 0, ""
    table.insert(self._conns, S.RunService.Heartbeat:Connect(function(dt)
        frames, acc = frames + 1, acc + dt
        if full then
            local char = player.Character
            local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
            if root then
                local p = root.Position
                local txt = string.format("%d,%d,%d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
                if txt ~= lastCoords then
                    lastCoords = txt
                    lab.COORDS.Text = txt
                end
            end
        end
        if acc >= 0.25 then
            lab.USER.Text = player.DisplayName
            if full then
                lab.FPS.Text = math.floor(frames / acc + 0.5) .. "Fps"
                local ok, ping = pcall(function()
                    return S.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
                end)
                lab.PING.Text = (ok and tonumber(ping)) and (math.floor(ping + 0.5) .. "ms") or "0ms"
            end
            frames, acc = 0, 0
        end
    end))

    Util.Tween(win, 0.5, { BackgroundTransparency = 0.1, Size = UDim2.fromOffset(width, H) }, Enum.EasingStyle.Back)
end

-- ════════════════════════════ DESTROY ════════════════════════════
function Lib:Destroy()
    for _, c in ipairs(self._conns) do c:Disconnect() end
    self._conns = {}
    self:_stopListen()
    for _, h in ipairs(self._huds) do h:Destroy() end
    self:SetBindList(false)
    if self.NotifGui then self.NotifGui:Destroy() end
    if self.Gui then self.Gui:Destroy() end
end

return Lib
