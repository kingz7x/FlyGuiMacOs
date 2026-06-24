-- ============================================================
--                    SERVIÇOS E VARIÁVEIS
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")
local Character        = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid         = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local State = {
    flyActive        = false,
    noclipActive     = false,
    flySpeed         = 50,
    currentTab       = "SkinChanger",
    minimized        = false,
    originalDesc     = nil,   -- HumanoidDescription original salva
    flyConnection    = nil,
    noclipLoop       = nil,
    bodyGyro         = nil,
    bodyVelocity     = nil,
    selectedPlayer   = nil,   -- jogador selecionado na lista
    playerEntries    = {},    -- { frame, player } — referências dos cards
}

-- ============================================================
--                      UTILITÁRIOS
-- ============================================================

local function makeTween(obj, props, duration, style, dir)
    return TweenService:Create(obj,
        TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
        props)
end

-- Salva HumanoidDescription original do LocalPlayer para reset
local function saveOriginalDesc()
    local hum = LocalPlayer.Character and
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        local ok, desc = pcall(function()
            return hum:GetAppliedDescription()
        end)
        if ok and desc then
            State.originalDesc = desc
        end
    end
end
pcall(saveOriginalDesc)

-- ============================================================
--                    LÓGICA: FLY HACK
-- ============================================================

local FlyHack = {}

local function getFlyInputVector()
    local cam   = workspace.CurrentCamera
    local move  = Vector3.new(0, 0, 0)
    local speed = State.flySpeed

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        move = move + cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        move = move - cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        move = move - cam.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        move = move + cam.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        move = move + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
    or UserInputService:IsKeyDown(Enum.KeyCode.C) then
        move = move - Vector3.new(0, 1, 0)
    end

    if move.Magnitude > 0 then
        move = move.Unit * speed
    end
    return move
end

function FlyHack.start()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P         = 1e4
    bg.CFrame    = hrp.CFrame
    bg.Parent    = hrp
    State.bodyGyro = bg

    local bv = Instance.new("BodyVelocity")
    bv.Velocity  = Vector3.new(0, 0, 0)
    bv.MaxForce  = Vector3.new(1e6, 1e6, 1e6)
    bv.P         = 1e4
    bv.Parent    = hrp
    State.bodyVelocity = bv

    State.flyConnection = RunService.RenderStepped:Connect(function()
        if not State.flyActive then return end
        local hrpRef = LocalPlayer.Character and
                       LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrpRef then return end
        local vel = getFlyInputVector()
        bv.Velocity = vel
        if vel.Magnitude > 0 then
            bg.CFrame = workspace.CurrentCamera.CFrame
        else
            bg.CFrame = hrpRef.CFrame
        end
    end)
end

function FlyHack.stop()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    if State.flyConnection then State.flyConnection:Disconnect(); State.flyConnection = nil end
    if State.bodyGyro      then State.bodyGyro:Destroy();      State.bodyGyro = nil end
    if State.bodyVelocity  then State.bodyVelocity:Destroy();  State.bodyVelocity = nil end
end

local function startNoclip()
    State.noclipLoop = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

local function stopNoclip()
    if State.noclipLoop then State.noclipLoop:Disconnect(); State.noclipLoop = nil end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

-- ============================================================
--                     CONSTRUÇÃO DA UI
-- ============================================================

local oldGui = PlayerGui:FindFirstChild("BananaoHub")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "BananaoHub"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder   = 999
ScreenGui.Parent         = PlayerGui

-- ── JANELA PRINCIPAL ────────────────────────────────────────
local Window = Instance.new("Frame")
Window.Name             = "Window"
Window.Size             = UDim2.new(0, 460, 0, 560)
Window.Position         = UDim2.new(0.5, -230, 0.5, -280)

Window.BorderSizePixel  = 0
Window.ClipsDescendants = true
Window.Parent           = ScreenGui

-- RESIZE HANDLE
local ResizeHandle = Instance.new("Frame")
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.Size = UDim2.new(0, 20, 0, 20)
ResizeHandle.Position = UDim2.new(1, -20, 1, -20)
ResizeHandle.BackgroundColor3 = Color3.fromRGB(80,80,90)
ResizeHandle.BorderSizePixel = 0
ResizeHandle.Parent = Window

local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0,6)
rc.Parent = ResizeHandle

local resizing = false
local resizeStart
local startSize

ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true
        resizeStart = input.Position
        startSize = Window.Size
    end
end)

ResizeHandle.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - resizeStart

        local newWidth = math.clamp(
            startSize.X.Offset + delta.X,
            350,
            1000
        )

        local newHeight = math.clamp(
            startSize.Y.Offset + delta.Y,
            250,
            800
        )

        Window.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
end)

local WindowCorner = Instance.new("UICorner")
WindowCorner.CornerRadius = UDim.new(0, 12)
WindowCorner.Parent = Window

local Shadow = Instance.new("ImageLabel")
Shadow.AnchorPoint        = Vector2.new(0.5, 0.5)
Shadow.BackgroundTransparency = 1
Shadow.Position           = UDim2.new(0.5, 0, 0.5, 0)
Shadow.Size               = UDim2.new(1, 40, 1, 40)
Shadow.ZIndex             = Window.ZIndex - 1
Shadow.Image              = "rbxassetid://5554236805"
Shadow.ImageColor3        = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency  = 0.55
Shadow.ScaleType          = Enum.ScaleType.Slice
Shadow.SliceCenter        = Rect.new(23, 23, 277, 277)
Shadow.Parent             = Window

local BgGradient = Instance.new("UIGradient")
BgGradient.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 38, 42)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 22, 26)),
})
BgGradient.Rotation = 135
BgGradient.Parent   = Window

-- ── BARRA DE TÍTULO ─────────────────────────────────────────
local TitleBar = Instance.new("Frame")
TitleBar.Name             = "TitleBar"
TitleBar.Size             = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
TitleBar.BorderSizePixel  = 0
TitleBar.Parent           = Window

do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,12); c.Parent = TitleBar
    local fix = Instance.new("Frame")
    fix.Size = UDim2.new(1,0,0,12); fix.Position = UDim2.new(0,0,1,-12)
    fix.BackgroundColor3 = Color3.fromRGB(38,38,42); fix.BorderSizePixel = 0; fix.Parent = TitleBar
end

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1,0,1,0); TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Bananao Hub"; TitleLabel.TextColor3 = Color3.fromRGB(242,242,247)
TitleLabel.TextSize = 14; TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Center; TitleLabel.Parent = TitleBar

local SubLabel = Instance.new("TextLabel")
SubLabel.Size = UDim2.new(1,0,1,0); SubLabel.BackgroundTransparency = 1
SubLabel.Text = "by 7xkng"; SubLabel.TextColor3 = Color3.fromRGB(130,130,140)
SubLabel.TextSize = 11; SubLabel.Font = Enum.Font.Gotham
SubLabel.TextXAlignment = Enum.TextXAlignment.Center
SubLabel.Position = UDim2.new(0,0,0,14); SubLabel.Parent = TitleBar

-- ── TRAFFIC LIGHTS ───────────────────────────────────────────
local TrafficFrame = Instance.new("Frame")
TrafficFrame.Size = UDim2.new(0,68,0,20); TrafficFrame.Position = UDim2.new(0,12,0.5,-10)
TrafficFrame.BackgroundTransparency = 1; TrafficFrame.Parent = TitleBar
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal; l.Padding = UDim.new(0,8)
    l.VerticalAlignment = Enum.VerticalAlignment.Center; l.Parent = TrafficFrame
end

local function makeTrafficBtn(color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,14,0,14); btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0; btn.Text = ""; btn.AutoButtonColor = false
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = btn
    btn.Parent = TrafficFrame
    return btn
end
local CloseBtn    = makeTrafficBtn(Color3.fromRGB(255,96,92))
local MinimizeBtn = makeTrafficBtn(Color3.fromRGB(255,189,46))
local MaximizeBtn = makeTrafficBtn(Color3.fromRGB(40,200,64))

CloseBtn.MouseButton1Click:Connect(function()
    makeTween(Window,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(0.5,0,0.5,0)},0.25):Play()
    task.wait(0.28); ScreenGui:Destroy()
end)
MinimizeBtn.MouseButton1Click:Connect(function()
    State.minimized = not State.minimized
    local h = State.minimized and 42 or 560
    makeTween(Window,{Size=UDim2.new(0,460,0,h)},0.3):Play()
end)

for _,t in ipairs({
    {CloseBtn,    Color3.fromRGB(255,96,92),   Color3.fromRGB(200,60,58)},
    {MinimizeBtn, Color3.fromRGB(255,189,46),  Color3.fromRGB(200,140,30)},
    {MaximizeBtn, Color3.fromRGB(40,200,64),   Color3.fromRGB(28,155,48)},
}) do
    local btn,norm,hov = t[1],t[2],t[3]
    btn.MouseEnter:Connect(function() makeTween(btn,{BackgroundColor3=hov},0.1):Play() end)
    btn.MouseLeave:Connect(function() makeTween(btn,{BackgroundColor3=norm},0.1):Play() end)
end

-- ── DRAG ────────────────────────────────────────────────────
local dragging, dragStart, startPos = false, nil, nil
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = i.Position; startPos = Window.Position
    end
end)
TitleBar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                    startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)

-- ── ABAS ─────────────────────────────────────────────────────
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"; TabBar.Size = UDim2.new(1,0,0,38)
TabBar.Position = UDim2.new(0,0,0,43); TabBar.BackgroundColor3 = Color3.fromRGB(32,32,36)
TabBar.BorderSizePixel = 0; TabBar.Parent = Window
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.VerticalAlignment = Enum.VerticalAlignment.Center
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.Padding = UDim.new(0,4); l.Parent = TabBar
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0,12); p.PaddingRight = UDim.new(0,12); p.Parent = TabBar
end

do
    local d = Instance.new("Frame"); d.Size = UDim2.new(1,0,0,1)
    d.Position = UDim2.new(0,0,0,81); d.BackgroundColor3 = Color3.fromRGB(58,58,64)
    d.BorderSizePixel = 0; d.Parent = Window
end

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1,0,1,-83); ContentFrame.Position = UDim2.new(0,0,0,82)
ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true
ContentFrame.Parent = Window

local tabPages, tabButtons = {}, {}

local function makeTabButton(name, label)
    local btn = Instance.new("TextButton")
    btn.Name = name; btn.Size = UDim2.new(0,130,0,28)
    btn.BackgroundColor3 = Color3.fromRGB(50,50,56); btn.BorderSizePixel = 0
    btn.Text = label; btn.TextColor3 = Color3.fromRGB(160,160,170)
    btn.TextSize = 13; btn.Font = Enum.Font.GothamSemibold; btn.AutoButtonColor = false
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = btn
    btn.Parent = TabBar; return btn
end

local function makeTabPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name; page.Size = UDim2.new(1,0,1,0)
    page.BackgroundTransparency = 1; page.BorderSizePixel = 0
    page.ScrollBarThickness = 3; page.ScrollBarImageColor3 = Color3.fromRGB(80,80,90)
    page.CanvasSize = UDim2.new(0,0,0,0); page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false; page.Parent = ContentFrame
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0,18); pad.PaddingRight = UDim.new(0,18)
    pad.PaddingTop = UDim.new(0,14); pad.PaddingBottom = UDim.new(0,14); pad.Parent = page
    local lay = Instance.new("UIListLayout")
    lay.FillDirection = Enum.FillDirection.Vertical; lay.Padding = UDim.new(0,10)
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Center; lay.Parent = page
    return page
end

tabButtons["FlyHack"]     = makeTabButton("FlyHack",     "Fly Hack")
tabPages["FlyHack"]       = makeTabPage("FlyHack")

local function switchTab(name)
    State.currentTab = name
    for k, page in pairs(tabPages) do page.Visible = (k == name) end
    for k, btn in pairs(tabButtons) do
        if k == name then
            btn.BackgroundColor3 = Color3.fromRGB(10,132,255); btn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(50,50,56); btn.TextColor3 = Color3.fromRGB(160,160,170)
        end
    end
end

tabButtons["FlyHack"].MouseButton1Click:Connect(function()     switchTab("FlyHack")     end)

-- ============================================================
--                  COMPONENTES REUTILIZÁVEIS
-- ============================================================

local function makeCard(parent, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1,0,0,height or 80); card.BackgroundColor3 = Color3.fromRGB(44,44,48)
    card.BorderSizePixel = 0; card.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = card
    return card
end

local function makeSectionLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0,18); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = Color3.fromRGB(130,130,140)
    lbl.TextSize = 11; lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = parent
end

local function makeButton(parent, text, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,36); btn.BackgroundColor3 = color or Color3.fromRGB(10,132,255)
    btn.BorderSizePixel = 0; btn.Text = text; btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 13; btn.Font = Enum.Font.GothamSemibold; btn.AutoButtonColor = false
    btn.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = btn
    local orig = color or Color3.fromRGB(10,132,255)
    btn.MouseEnter:Connect(function()   makeTween(btn,{BackgroundColor3=orig:Lerp(Color3.new(1,1,1),0.12)},0.12):Play() end)
    btn.MouseLeave:Connect(function()   makeTween(btn,{BackgroundColor3=orig},0.12):Play() end)
    btn.MouseButton1Down:Connect(function() makeTween(btn,{BackgroundColor3=orig:Lerp(Color3.new(0,0,0),0.15)},0.08):Play() end)
    btn.MouseButton1Up:Connect(function()   makeTween(btn,{BackgroundColor3=orig},0.1):Play() end)
    return btn
end

local function makeToggle(parent, labelText, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,32); row.BackgroundTransparency = 1; row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-56,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = labelText; lbl.TextColor3 = Color3.fromRGB(220,220,228)
    lbl.TextSize = 13; lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0,48,0,26); track.Position = UDim2.new(1,-48,0.5,-13)
    track.BackgroundColor3 = Color3.fromRGB(60,60,67); track.BorderSizePixel = 0; track.Parent = row
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1,0); tc.Parent = track

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,20,0,20); knob.Position = UDim2.new(0,3,0.5,-10)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.BorderSizePixel = 0; knob.Parent = track
    local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(1,0); kc.Parent = knob

    local isOn = false
    local function setToggle(val)
        isOn = val
        if isOn then
            makeTween(track,{BackgroundColor3=Color3.fromRGB(52,199,89)},0.2):Play()
            makeTween(knob,{Position=UDim2.new(0,25,0.5,-10)},0.2):Play()
        else
            makeTween(track,{BackgroundColor3=Color3.fromRGB(60,60,67)},0.2):Play()
            makeTween(knob,{Position=UDim2.new(0,3,0.5,-10)},0.2):Play()
        end
        if onToggle then onToggle(isOn) end
    end

    local clickBtn = Instance.new("TextButton")
    clickBtn.Size = UDim2.new(1,0,1,0); clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""; clickBtn.Parent = track
    clickBtn.MouseButton1Click:Connect(function() setToggle(not isOn) end)

    return row, setToggle
end

local function makeSlider(parent, labelText, minVal, maxVal, defaultVal, onChange)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,0,52); container.BackgroundTransparency = 1; container.Parent = parent

    local topRow = Instance.new("Frame")
    topRow.Size = UDim2.new(1,0,0,20); topRow.BackgroundTransparency = 1; topRow.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = labelText; lbl.TextColor3 = Color3.fromRGB(220,220,228)
    lbl.TextSize = 13; lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = topRow

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.3,0,1,0); valLbl.Position = UDim2.new(0.7,0,0,0)
    valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(defaultVal)
    valLbl.TextColor3 = Color3.fromRGB(10,132,255); valLbl.TextSize = 13
    valLbl.Font = Enum.Font.GothamBold; valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = topRow

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,0,0,6); track.Position = UDim2.new(0,0,0,30)
    track.BackgroundColor3 = Color3.fromRGB(58,58,66); track.BorderSizePixel = 0; track.Parent = container
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1,0); tc.Parent = track

    local initRatio = (defaultVal - minVal) / (maxVal - minVal)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initRatio,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(10,132,255)
    fill.BorderSizePixel = 0; fill.Parent = track
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1,0); fc.Parent = fill

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0,18,0,18); thumb.AnchorPoint = Vector2.new(0.5,0.5)
    thumb.Position = UDim2.new(initRatio,0,0.5,0); thumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
    thumb.BorderSizePixel = 0; thumb.Parent = track
    local thc = Instance.new("UICorner"); thc.CornerRadius = UDim.new(1,0); thc.Parent = thumb
    local ths = Instance.new("UIStroke"); ths.Color = Color3.fromRGB(0,0,0)
    ths.Thickness = 1; ths.Transparency = 0.7; ths.Parent = thumb

    local sliding = false
    local function updateSlider(inputX)
        local abs = track.AbsolutePosition; local sz = track.AbsoluteSize
        local ratio = math.clamp((inputX - abs.X) / sz.X, 0, 1)
        local value = math.floor(minVal + (maxVal - minVal) * ratio)
        fill.Size = UDim2.new(ratio,0,1,0); thumb.Position = UDim2.new(ratio,0,0.5,0)
        valLbl.Text = tostring(value); if onChange then onChange(value) end
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding=true; updateSlider(i.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    return container
end

local function makeStatusLabel(parent)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0,20); lbl.BackgroundTransparency = 1; lbl.Text = ""
    lbl.TextColor3 = Color3.fromRGB(130,130,140); lbl.TextSize = 12; lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Center; lbl.Parent = parent
    return lbl
end

local function flashStatus(lbl, msg, isError)
    lbl.Text = msg; lbl.TextTransparency = 0
    lbl.TextColor3 = isError and Color3.fromRGB(255,69,58) or Color3.fromRGB(52,199,89)
    task.delay(3, function()
        makeTween(lbl,{TextTransparency=1},0.5):Play()
        task.wait(0.5); lbl.Text = ""; lbl.TextTransparency = 0
    end)
end

-- ============================================================
--              CONTEÚDO: SKIN CHANGER (PLAYER LIST)
-- ============================================================

local skinPage = tabPages["SkinChanger"]

-- ── Header info ──────────────────────────────────────────────
makeSectionLabel(skinPage, "JOGADORES NO SERVIDOR")

-- Card informativo
local infoCard = makeCard(skinPage, 42)
local infoLbl  = Instance.new("TextLabel")
infoLbl.Size              = UDim2.new(1,-20,1,0)
infoLbl.Position          = UDim2.new(0,10,0,0)
infoLbl.BackgroundTransparency = 1
infoLbl.Text              = "Clique em um jogador para copiar a skin completa dele"
infoLbl.TextColor3        = Color3.fromRGB(160,160,170)
infoLbl.TextSize          = 12
infoLbl.Font              = Enum.Font.Gotham
infoLbl.TextWrapped       = true
infoLbl.TextXAlignment    = Enum.TextXAlignment.Left
infoLbl.Parent            = infoCard

-- Barra de busca + botão refresh
local searchCard = makeCard(skinPage, 44)
local searchInner = Instance.new("Frame")
searchInner.Size               = UDim2.new(1,-16,1,-16)
searchInner.Position           = UDim2.new(0,8,0,8)
searchInner.BackgroundTransparency = 1
searchInner.Parent             = searchCard

local searchLayout = Instance.new("UIListLayout")
searchLayout.FillDirection    = Enum.FillDirection.Horizontal
searchLayout.VerticalAlignment = Enum.VerticalAlignment.Center
searchLayout.Padding          = UDim.new(0,8)
searchLayout.Parent           = searchInner

-- Campo de busca
local searchFrame = Instance.new("Frame")
searchFrame.Size              = UDim2.new(1,-86,1,0)
searchFrame.BackgroundColor3  = Color3.fromRGB(30,30,34)
searchFrame.BorderSizePixel   = 0
searchFrame.Parent            = searchInner
local sfc = Instance.new("UICorner"); sfc.CornerRadius = UDim.new(0,8); sfc.Parent = searchFrame
local sfStroke = Instance.new("UIStroke"); sfStroke.Color = Color3.fromRGB(70,70,78)
sfStroke.Thickness = 1; sfStroke.Parent = searchFrame

local searchBox = Instance.new("TextBox")
searchBox.Size             = UDim2.new(1,-12,1,0)
searchBox.Position         = UDim2.new(0,8,0,0)
searchBox.BackgroundTransparency = 1
searchBox.PlaceholderText  = "Buscar jogador..."
searchBox.PlaceholderColor3 = Color3.fromRGB(90,90,100)
searchBox.Text             = ""
searchBox.TextColor3       = Color3.fromRGB(230,230,235)
searchBox.TextSize         = 13
searchBox.Font             = Enum.Font.Gotham
searchBox.TextXAlignment   = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent           = searchFrame
searchBox.Focused:Connect(function()   makeTween(sfStroke,{Color=Color3.fromRGB(10,132,255)},0.15):Play() end)
searchBox.FocusLost:Connect(function() makeTween(sfStroke,{Color=Color3.fromRGB(70,70,78)},0.15):Play()   end)

-- Botão refresh
local refreshBtn = Instance.new("TextButton")
refreshBtn.Size             = UDim2.new(0,78,1,0)
refreshBtn.BackgroundColor3 = Color3.fromRGB(50,50,56)
refreshBtn.BorderSizePixel  = 0
refreshBtn.Text             = "Atualizar"
refreshBtn.TextColor3       = Color3.fromRGB(200,200,210)
refreshBtn.TextSize         = 12
refreshBtn.Font             = Enum.Font.GothamSemibold
refreshBtn.AutoButtonColor  = false
refreshBtn.Parent           = searchInner
local rbc = Instance.new("UICorner"); rbc.CornerRadius = UDim.new(0,8); rbc.Parent = refreshBtn
refreshBtn.MouseEnter:Connect(function() makeTween(refreshBtn,{BackgroundColor3=Color3.fromRGB(65,65,72)},0.1):Play() end)
refreshBtn.MouseLeave:Connect(function() makeTween(refreshBtn,{BackgroundColor3=Color3.fromRGB(50,50,56)},0.1):Play() end)

-- ── LISTA DE JOGADORES ────────────────────────────────────────
-- Container fixo com altura para a lista
local listContainer = Instance.new("Frame")
listContainer.Name              = "ListContainer"
listContainer.Size              = UDim2.new(1,0,0,300)
listContainer.BackgroundColor3  = Color3.fromRGB(34,34,38)
listContainer.BorderSizePixel   = 0
listContainer.ClipsDescendants  = true
listContainer.Parent            = skinPage
local lcc = Instance.new("UICorner"); lcc.CornerRadius = UDim.new(0,10); lcc.Parent = listContainer

local playerList = Instance.new("ScrollingFrame")
playerList.Name              = "PlayerList"
playerList.Size              = UDim2.new(1,0,1,0)
playerList.BackgroundTransparency = 1
playerList.BorderSizePixel   = 0
playerList.ScrollBarThickness = 3
playerList.ScrollBarImageColor3 = Color3.fromRGB(80,80,90)
playerList.CanvasSize        = UDim2.new(0,0,0,0)
playerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerList.Parent            = listContainer

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection     = Enum.FillDirection.Vertical
listLayout.Padding           = UDim.new(0,2)
listLayout.Parent            = playerList

local listPadding = Instance.new("UIPadding")
listPadding.PaddingLeft   = UDim.new(0,6)
listPadding.PaddingRight  = UDim.new(0,6)
listPadding.PaddingTop    = UDim.new(0,6)
listPadding.PaddingBottom = UDim.new(0,6)
listPadding.Parent        = playerList

-- Status de cópia
local copyStatus = makeStatusLabel(skinPage)

-- ── Botão Reset ───────────────────────────────────────────────
makeSectionLabel(skinPage, "RESET")
local resetCard  = makeCard(skinPage, 50)
local resetInner = Instance.new("Frame")
resetInner.Size               = UDim2.new(1,-20,1,-16)
resetInner.Position           = UDim2.new(0,10,0,8)
resetInner.BackgroundTransparency = 1
resetInner.Parent             = resetCard
local resetBtn = makeButton(resetInner, "Restaurar Minha Skin Original", Color3.fromRGB(255,69,58))
resetBtn.Size  = UDim2.new(1,0,0,34)
local resetStatus = makeStatusLabel(skinPage)

resetBtn.MouseButton1Click:Connect(function()
    local ok, err = SkinChanger.resetSkin()
    flashStatus(resetStatus, ok and "Skin restaurada!" or (err or "Erro ao restaurar"), not ok)
end)

-- ── Constrói uma entrada de jogador na lista ──────────────────
local function makePlayerEntry(player)
    local isLocal = (player == LocalPlayer)

    local entry = Instance.new("TextButton")
    entry.Name              = player.Name
    entry.Size              = UDim2.new(1,0,0,52)
    entry.BackgroundColor3  = isLocal
        and Color3.fromRGB(36,36,42)
        or  Color3.fromRGB(40,40,46)
    entry.BorderSizePixel   = 0
    entry.Text              = ""
    entry.AutoButtonColor   = false
    entry.Parent            = playerList
    local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0,8); ec.Parent = entry

    -- Avatar thumbnail
    local thumbFrame = Instance.new("Frame")
    thumbFrame.Size             = UDim2.new(0,38,0,38)
    thumbFrame.Position         = UDim2.new(0,8,0.5,-19)
    thumbFrame.BackgroundColor3 = Color3.fromRGB(55,55,62)
    thumbFrame.BorderSizePixel  = 0
    thumbFrame.Parent           = entry
    local tfc = Instance.new("UICorner"); tfc.CornerRadius = UDim.new(1,0); tfc.Parent = thumbFrame

    local thumb = Instance.new("ImageLabel")
    thumb.Size              = UDim2.new(1,0,1,0)
    thumb.BackgroundTransparency = 1
    thumb.ScaleType         = Enum.ScaleType.Crop
    thumb.Parent            = thumbFrame
    -- Carrega thumbnail de forma assíncrona
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(
                player.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size48x48
            )
        end)
        if ok and img then thumb.Image = img end
    end)

    -- Nome do jogador
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(1,-120,0,20)
    nameLbl.Position         = UDim2.new(0,54,0.5,-18)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = player.DisplayName
    nameLbl.TextColor3       = isLocal
        and Color3.fromRGB(130,130,140)
        or  Color3.fromRGB(230,230,238)
    nameLbl.TextSize         = 13
    nameLbl.Font             = Enum.Font.GothamSemibold
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.TextTruncate     = Enum.TextTruncate.AtEnd
    nameLbl.Parent           = entry

    -- Username @
    local userLbl = Instance.new("TextLabel")
    userLbl.Size             = UDim2.new(1,-120,0,16)
    userLbl.Position         = UDim2.new(0,54,0.5,2)
    userLbl.BackgroundTransparency = 1
    userLbl.Text             = "@" .. player.Name .. (isLocal and "  (você)" or "")
    userLbl.TextColor3       = Color3.fromRGB(100,100,110)
    userLbl.TextSize         = 11
    userLbl.Font             = Enum.Font.Gotham
    userLbl.TextXAlignment   = Enum.TextXAlignment.Left
    userLbl.TextTruncate     = Enum.TextTruncate.AtEnd
    userLbl.Parent           = entry

    -- Botão "Copiar"
    if not isLocal then
        local copyBtn = Instance.new("TextButton")
        copyBtn.Size             = UDim2.new(0,72,0,28)
        copyBtn.Position         = UDim2.new(1,-82,0.5,-14)
        copyBtn.BackgroundColor3 = Color3.fromRGB(10,132,255)
        copyBtn.BorderSizePixel  = 0
        copyBtn.Text             = "Copiar"
        copyBtn.TextColor3       = Color3.fromRGB(255,255,255)
        copyBtn.TextSize         = 12
        copyBtn.Font             = Enum.Font.GothamSemibold
        copyBtn.AutoButtonColor  = false
        copyBtn.Parent           = entry
        local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0,7); cbc.Parent = copyBtn

        copyBtn.MouseEnter:Connect(function()
            makeTween(copyBtn,{BackgroundColor3=Color3.fromRGB(30,152,255)},0.1):Play()
        end)
        copyBtn.MouseLeave:Connect(function()
            makeTween(copyBtn,{BackgroundColor3=Color3.fromRGB(10,132,255)},0.1):Play()
        end)

        -- Hover na linha toda
        entry.MouseEnter:Connect(function()
            if State.selectedPlayer ~= player then
                makeTween(entry,{BackgroundColor3=Color3.fromRGB(48,48,54)},0.1):Play()
            end
        end)
        entry.MouseLeave:Connect(function()
            if State.selectedPlayer ~= player then
                makeTween(entry,{BackgroundColor3=Color3.fromRGB(40,40,46)},0.1):Play()
            end
        end)

        -- Clique em qualquer lugar da linha OU no botão: copia
        local function doCopy()
            -- Feedback visual imediato
            copyBtn.Text = "..."
            copyBtn.BackgroundColor3 = Color3.fromRGB(50,50,56)

            -- Destaca selecionado
            if State.selectedPlayer then
                -- Reseta visual da entrada anterior
                for _, e in ipairs(playerList:GetChildren()) do
                    if e:IsA("TextButton") and e.Name == State.selectedPlayer.Name then
                        makeTween(e,{BackgroundColor3=Color3.fromRGB(40,40,46)},0.12):Play()
                    end
                end
            end
            State.selectedPlayer = player
            makeTween(entry,{BackgroundColor3=Color3.fromRGB(20,50,90)},0.15):Play()

            task.spawn(function()
                local ok, err = SkinChanger.copyFromPlayer(player)
                if ok then
                    copyBtn.Text = "Copiado!"
                    copyBtn.BackgroundColor3 = Color3.fromRGB(52,199,89)
                    flashStatus(copyStatus,
                        "Skin de " .. player.DisplayName .. " copiada!")
                else
                    copyBtn.Text = "Erro"
                    copyBtn.BackgroundColor3 = Color3.fromRGB(255,69,58)
                    flashStatus(copyStatus, err or "Falha ao copiar skin", true)
                end
                task.wait(2)
                copyBtn.Text = "Copiar"
                makeTween(copyBtn,{BackgroundColor3=Color3.fromRGB(10,132,255)},0.2):Play()
            end)
        end

        copyBtn.MouseButton1Click:Connect(doCopy)
        entry.MouseButton1Click:Connect(doCopy)
    end

    return entry
end

-- ── Popula / atualiza lista ───────────────────────────────────
local function refreshPlayerList(filter)
    filter = (filter or ""):lower()

    -- Limpa entradas existentes
    for _, child in ipairs(playerList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    State.playerEntries = {}
    State.selectedPlayer = nil

    local list = Players:GetPlayers()
    -- LocalPlayer primeiro
    table.sort(list, function(a, b)
        if a == LocalPlayer then return true end
        if b == LocalPlayer then return false end
        return a.DisplayName:lower() < b.DisplayName:lower()
    end)

    local count = 0
    for _, player in ipairs(list) do
        local name = player.Name:lower()
        local display = player.DisplayName:lower()
        if filter == "" or name:find(filter, 1, true) or display:find(filter, 1, true) then
            makePlayerEntry(player)
            count = count + 1
        end
    end

    -- Mensagem se lista vazia
    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1,0,0,40); empty.BackgroundTransparency = 1
        empty.Text = "Nenhum jogador encontrado"
        empty.TextColor3 = Color3.fromRGB(90,90,100); empty.TextSize = 13
        empty.Font = Enum.Font.Gotham; empty.Parent = playerList
    end
end

-- Chama ao iniciar
refreshPlayerList()

-- Botão refresh
refreshBtn.MouseButton1Click:Connect(function()
    refreshBtn.Text = "..."
    task.spawn(function()
        refreshPlayerList(searchBox.Text)
        refreshBtn.Text = "Atualizar"
    end)
end)

-- Busca em tempo real
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    refreshPlayerList(searchBox.Text)
end)

-- Atualiza quando jogador entra/sai
Players.PlayerAdded:Connect(function()
    task.wait(0.5) -- pequeno delay para o personagem carregar
    refreshPlayerList(searchBox.Text)
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.1)
    refreshPlayerList(searchBox.Text)
end)

-- ============================================================
--                   CONTEÚDO: FLY HACK
-- ============================================================

local flyPage = tabPages["FlyHack"]

local flyCard  = makeCard(flyPage, 100)
local flyInner = Instance.new("Frame")
flyInner.Size               = UDim2.new(1,-20,1,-16)
flyInner.Position           = UDim2.new(0,10,0,8)
flyInner.BackgroundTransparency = 1
flyInner.Parent             = flyCard

local statusRow = Instance.new("Frame")
statusRow.Size              = UDim2.new(1,0,0,22)
statusRow.BackgroundTransparency = 1
statusRow.Parent            = flyInner

local statusDot = Instance.new("Frame")
statusDot.Size              = UDim2.new(0,10,0,10)
statusDot.Position          = UDim2.new(0,0,0.5,-5)
statusDot.BackgroundColor3  = Color3.fromRGB(90,90,95)
statusDot.BorderSizePixel   = 0
statusDot.Parent            = statusRow
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = statusDot end

local statusText = Instance.new("TextLabel")
statusText.Size             = UDim2.new(1,-20,1,0)
statusText.Position         = UDim2.new(0,18,0,0)
statusText.BackgroundTransparency = 1
statusText.Text             = "Fly is DISABLED"
statusText.TextColor3       = Color3.fromRGB(160,160,170)
statusText.TextSize         = 13; statusText.Font = Enum.Font.Gotham
statusText.TextXAlignment   = Enum.TextXAlignment.Left
statusText.Parent           = statusRow

local flyToggleRow, setFlyToggle = makeToggle(flyInner, "Enable Fly Hack", function(val)
    State.flyActive = val
    if val then
        FlyHack.start()
        statusDot.BackgroundColor3 = Color3.fromRGB(52,199,89)
        statusText.Text            = "Fly is ENABLED"
        statusText.TextColor3      = Color3.fromRGB(52,199,89)
    else
        FlyHack.stop()
        statusDot.BackgroundColor3 = Color3.fromRGB(90,90,95)
        statusText.Text            = "Fly is DISABLED"
        statusText.TextColor3      = Color3.fromRGB(160,160,170)
    end
end)
flyToggleRow.Position = UDim2.new(0,0,0,30)
flyToggleRow.Parent   = flyInner

local keyInfo = Instance.new("TextLabel")
keyInfo.Size              = UDim2.new(1,0,0,16); keyInfo.Position = UDim2.new(0,0,0,66)
keyInfo.BackgroundTransparency = 1
keyInfo.Text              = "W/A/S/D = Move   Space = Up   C/Ctrl = Down"
keyInfo.TextColor3        = Color3.fromRGB(90,90,100); keyInfo.TextSize = 11
keyInfo.Font              = Enum.Font.Gotham; keyInfo.TextXAlignment = Enum.TextXAlignment.Left
keyInfo.Parent            = flyInner

local speedCard  = makeCard(flyPage, 72)
local speedInner = Instance.new("Frame")
speedInner.Size = UDim2.new(1,-20,1,-16); speedInner.Position = UDim2.new(0,10,0,8)
speedInner.BackgroundTransparency = 1; speedInner.Parent = speedCard
makeSlider(speedInner, "Fly Speed", 10, 300, 50, function(val)
    State.flySpeed = val
end)

local tpCard  = makeCard(flyPage, 58)
local tpInner = Instance.new("Frame")
tpInner.Size = UDim2.new(1,-20,1,-16); tpInner.Position = UDim2.new(0,10,0,8)
tpInner.BackgroundTransparency = 1; tpInner.Parent = tpCard
do
    local l = Instance.new("UIListLayout"); l.FillDirection = Enum.FillDirection.Horizontal
    l.Padding = UDim.new(0,8); l.VerticalAlignment = Enum.VerticalAlignment.Center; l.Parent = tpInner
end

local function makeTpBtn(label, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.48,0,0,36); b.BackgroundColor3 = color
    b.BorderSizePixel = 0; b.Text = label; b.TextColor3 = Color3.fromRGB(255,255,255)
    b.TextSize = 12; b.Font = Enum.Font.GothamSemibold; b.AutoButtonColor = false; b.Parent = tpInner
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = b
    return b
end
local tpUp   = makeTpBtn("Up +50",  Color3.fromRGB(48,209,88))
local tpDown = makeTpBtn("Down -50", Color3.fromRGB(255,149,0))
tpUp.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = hrp.CFrame + Vector3.new(0,50,0) end
    end
end)
tpDown.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = hrp.CFrame - Vector3.new(0,50,0) end
    end
end)

local noclipCard  = makeCard(flyPage, 50)
local noclipInner = Instance.new("Frame")
noclipInner.Size = UDim2.new(1,-20,1,-16); noclipInner.Position = UDim2.new(0,10,0,8)
noclipInner.BackgroundTransparency = 1; noclipInner.Parent = noclipCard
makeToggle(noclipInner, "Enable NoClip (walk through walls)", function(val)
    State.noclipActive = val
    if val then startNoclip() else stopNoclip() end
end)

local warnCard = makeCard(flyPage, 56)
local warnLbl  = Instance.new("TextLabel")
warnLbl.Size = UDim2.new(1,-20,1,-12); warnLbl.Position = UDim2.new(0,10,0,6)
warnLbl.BackgroundTransparency = 1
warnLbl.Text = "Use responsibly. Abuse may result in account suspension."
warnLbl.TextColor3 = Color3.fromRGB(255,149,0); warnLbl.TextSize = 11
warnLbl.Font = Enum.Font.Gotham; warnLbl.TextWrapped = true
warnLbl.TextXAlignment = Enum.TextXAlignment.Left; warnLbl.Parent = warnCard

-- ============================================================
--                    INICIALIZAÇÃO
-- ============================================================

switchTab("FlyHack")

-- Reconecta ao trocar de personagem
LocalPlayer.CharacterAdded:Connect(function(char)
    Character        = char
    Humanoid         = char:WaitForChild("Humanoid")
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    pcall(saveOriginalDesc)

    if State.flyActive then
        State.flyActive = false
        FlyHack.stop()
        setFlyToggle(false)
        statusDot.BackgroundColor3 = Color3.fromRGB(90,90,95)
        statusText.Text            = "Fly is DISABLED"
        statusText.TextColor3      = Color3.fromRGB(160,160,170)
    end
end)

-- Animação de entrada
Window.Size     = UDim2.new(0,0,0,0)
Window.Position = UDim2.new(0.5,0,0.5,0)
makeTween(Window,
    {Size = UDim2.new(0,460,0,560), Position = UDim2.new(0.5,-230,0.5,-280)},
    0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()

print("[Bananao Hub v2.0] Carregado. Jogadores no servidor: " .. #Players:GetPlayers())

local uiVisible = true

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.LeftAlt
    or input.KeyCode == Enum.KeyCode.RightAlt then

        uiVisible = not uiVisible

        if uiVisible then
            ScreenGui.Enabled = true

            Window.Size = UDim2.new(0,0,0,0)

            makeTween(
                Window,
                {Size = UDim2.new(0,460,0,560)},
                0.25
            ):Play()

        else
            local tween = makeTween(
                Window,
                {Size = UDim2.new(0,0,0,0)},
                0.25
            )

            tween:Play()

            tween.Completed:Wait()
            ScreenGui.Enabled = false
        end
    end
end)

