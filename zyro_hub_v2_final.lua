-- Fluent UI Loader
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Roblox Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Control Variables: Movement
local TargetWalkSpeed = 16
local WalkSpeedEnabled = false
local InfJumpEnabled = false
local FlyEnabled = false
local FlySpeed = 50
local BodyVelocity = nil
local BodyGyro = nil
local NoclipEnabled = false
local NoclipConnection = nil

-- Control Variables: Ghost Mode
local GhostEnabled = false
local GhostClone = nil
local RealCharacter = nil
local RealHRP = nil
local PlayerModule = nil

pcall(function()
    PlayerModule = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
end)

local function ForceEnableControls()
    if PlayerModule then
        pcall(function()
            local controls = PlayerModule:GetControls()
            if controls then
                controls:Enable()
            end
        end)
    end
end

-- Control Variables: Combat
local HitboxEnabled = false
local HitboxSize = 10
local ESPEnabled = false
local ESPLineEnabled = false
local SilentAimEnabled = false
local FOV_RADIUS = 340
local PredictionFactor = 0.22
local ShootRemote = nil
local ESPLines = {}

-- Control Variables: Underplayer
local UnderplayerEnabled = false
local SurfacePosition = nil

-- Esperar pelo ShootRemote
pcall(function()
    ShootRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShootGun")
end)

-- Main Window Creation
local Window = Fluent:CreateWindow({
    Title = "Zyro hub",
    SubTitle = "creator:gomes.wqq",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Light",
    MinimizeKey = Enum.KeyCode.X
})

-- Tabs
local Tabs = {
    Main = Window:AddTab({ Title = "Movement", Icon = "plane" }),
    Combat = Window:AddTab({ Title = "Combat / TP", Icon = "crosshair" }),
    Under = Window:AddTab({ Title = "Underplayer", Icon = "shield" })
}

-- [[ HELPER FUNCTIONS ]] --

local function IsEnemy(player)
    if not player or player == LocalPlayer then return false end
    if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return false
    end
    return true
end

local function IsPlayerValid(player)
    if not player or not player.Character then return false end
    local char = player.Character
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    
    if not humanoid or not hrp or not head then return false end
    if humanoid.Health <= 0 then return false end
    
    return true
end

local function ResetPlayerHitbox(player)
    if player and player.Character then
        local char = player.Character
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Size = Vector3.new(2, 2, 1)
            hrp.CanCollide = true
        end
    end
end

local function CleanESPLines()
    for _, data in pairs(ESPLines) do
        if data and data.Line and data.Line.Parent then
            data.Line:Destroy()
        end
        if data and data.Connection then
            data.Connection:Disconnect()
        end
    end
    ESPLines = {}
end

local function ApplyHighlight(player)
    if not ESPEnabled or not IsEnemy(player) then return end
    local char = player.Character
    if char then
        local hl = char:FindFirstChild("ZyroHighlight")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "ZyroHighlight"
            hl.FillColor = Color3.fromRGB(255, 0, 0)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.Parent = char
        end
    end
end

local function RemoveHighlight(player)
    if player and player.Character then
        local hl = player.Character:FindFirstChild("ZyroHighlight")
        if hl then hl:Destroy() end
    end
end

-- [[ NOCLIP FUNCTION ]] --

local function ToggleNoclip(state)
    NoclipEnabled = state
    
    if NoclipEnabled then
        if NoclipConnection then
            NoclipConnection:Disconnect()
        end
        
        NoclipConnection = RunService.RenderStepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        
        Fluent:Notify({
            Title = "Zyro hub",
            Content = "Noclip Ativado!",
            Duration = 2
        })
    else
        if NoclipConnection then
            NoclipConnection:Disconnect()
            NoclipConnection = nil
        end
        
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        
        Fluent:Notify({
            Title = "Zyro hub",
            Content = "Noclip Desativado!",
            Duration = 2
        })
    end
end

-- [[ GHOST MODE FUNCTION - NOVA LÓGICA ]] --

local function ToggleGhostMode(state)
    local char = LocalPlayer.Character
    if not char then return end

    if state then
        if GhostEnabled then return end
        
        RealCharacter = char
        RealHRP = RealCharacter:FindFirstChild("HumanoidRootPart")
        local realHumanoid = RealCharacter:FindFirstChildOfClass("Humanoid")
        
        if not RealHRP or not realHumanoid then return end

        GhostEnabled = true

        -- 1. CLONA O PERSONAGEM PRIMEIRO
        RealCharacter.Archivable = true
        GhostClone = RealCharacter:Clone()
        RealCharacter.Archivable = false

        -- 2. ANCORA APENAS O PERSONAGEM REAL
        RealHRP.Anchored = true

        -- 3. GARANTE QUE O CLONE ESTÁ 100% DESANCORADO
        for _, part in ipairs(GhostClone:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = false
            end
        end

        GhostClone.Name = LocalPlayer.Name .. "_Ghost"
        GhostClone.Parent = Workspace

        -- Transparência opcional
        for _, part in ipairs(GhostClone:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = math.clamp(part.Transparency + 0.15, 0, 0.8)
            end
        end

        -- 4. VINCULA A CÂMERA E CONTROLES AO CLONE
        LocalPlayer.Character = GhostClone
        
        local cloneHumanoid = GhostClone:FindFirstChildOfClass("Humanoid")
        if cloneHumanoid then
            Camera.CameraSubject = cloneHumanoid
        end

        -- 5. FORÇA O RECARREGAMENTO DOS CONTROLES
        task.defer(function()
            ForceEnableControls()
        end)

        Fluent:Notify({
            Title = "Zyro hub",
            Content = "Ghost Mode Ativado!",
            Duration = 2
        })

    else
        if not GhostEnabled or not GhostClone then return end
        GhostEnabled = false

        -- Pega a posição final do clone
        local cloneHRP = GhostClone:FindFirstChild("HumanoidRootPart")
        local targetCFrame = cloneHRP and cloneHRP.CFrame or (RealHRP and RealHRP.CFrame)

        -- Devolve o controle para o personagem real
        if RealCharacter then
            LocalPlayer.Character = RealCharacter
            
            -- Desancora e teletransporta
            if RealHRP then
                RealHRP.Anchored = false
                if targetCFrame then
                    RealHRP.CFrame = targetCFrame
                end
            end

            -- Restaura a câmera
            local realHumanoid = RealCharacter:FindFirstChildOfClass("Humanoid")
            if realHumanoid then
                Camera.CameraSubject = realHumanoid
            end
        end

        -- Destroi o clone
        GhostClone:Destroy()
        GhostClone = nil

        -- Reativa controles
        task.defer(function()
            ForceEnableControls()
        end)

        Fluent:Notify({
            Title = "Zyro hub",
            Content = "Ghost Mode Desativado!",
            Duration = 2
        })
    end
end

-- [[ SILENT AIM FUNCTIONS ]] --

local function getClosestEnemy()
    local closestPart = nil
    local shortestDistance = math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in pairs(Players:GetPlayers()) do
        if IsEnemy(player) and IsPlayerValid(player) then
            local char = player.Character
            local head = char:FindFirstChild("Head")
            local screenPos = Camera:WorldToViewportPoint(head.Position)
            local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            
            if distFromCenter <= FOV_RADIUS then
                if distFromCenter < shortestDistance then
                    shortestDistance = distFromCenter
                    closestPart = head
                end
            end
        end
    end
    return closestPart
end

-- [[ ESP LINE FUNCTION - CORRIGIDA ]] --

local function CreateESPLine(player)
    if not ESPLineEnabled or not IsEnemy(player) or not IsPlayerValid(player) then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("Head") then return end
    
    if ESPLines[player] then return end
    
    local screenGui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("ESPLineGui")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ESPLineGui"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.Parent = LocalPlayer:FindFirstChild("PlayerGui")
    end
    
    local line = Instance.new("Frame")
    line.Name = "ESPLine_" .. player.Name
    line.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    line.BorderSizePixel = 0
    line.Parent = screenGui
    
    ESPLines[player] = {
        Line = line,
        Connection = nil,
        Player = player,
        Character = char
    }
    
    local lineData = ESPLines[player]
    
    local function updateLine()
        if not ESPLineEnabled or not lineData.Line or not lineData.Line.Parent then
            if lineData.Line and lineData.Line.Parent then 
                lineData.Line:Destroy() 
            end
            if lineData.Connection then
                lineData.Connection:Disconnect()
            end
            ESPLines[player] = nil
            return
        end
        
        if not lineData.Character or not IsPlayerValid(player) then
            if lineData.Line and lineData.Line.Parent then 
                lineData.Line:Destroy() 
            end
            if lineData.Connection then
                lineData.Connection:Disconnect()
            end
            ESPLines[player] = nil
            return
        end
        
        local screenSize = Camera.ViewportSize
        local screenCenter = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
        local headPos = lineData.Character:FindFirstChild("Head")
        
        if headPos then
            local headScreenPos = Camera:WorldToViewportPoint(headPos.Position)
            
            -- Apenas desenha se a cabeça está à frente da câmera
            if headScreenPos.Z > 0 then
                local headScreen2D = Vector2.new(headScreenPos.X, headScreenPos.Y)
                local distance = (screenCenter - headScreen2D).Magnitude
                
                if distance > 0 then
                    local angle = math.atan2(headScreen2D.Y - screenCenter.Y, headScreen2D.X - screenCenter.X)
                    
                    lineData.Line.Size = UDim2.new(0, distance, 0, 2)
                    lineData.Line.Position = UDim2.new(0, screenCenter.X, 0, screenCenter.Y)
                    lineData.Line.Rotation = math.deg(angle)
                    lineData.Line.AnchorPoint = Vector2.new(0, 0.5)
                end
            end
        end
    end
    
    lineData.Connection = RunService.RenderStepped:Connect(updateLine)
end

-- [[ MOVEMENT TAB ]] --

Tabs.Main:AddParagraph({
    Title = "Movement Controls",
    Content = "Hotkeys: F (Fly) | G (TP Up +40 studs) | Z (Ghost Mode) | X (Minimize UI)"
})

local SpeedToggle = Tabs.Main:AddToggle("SpeedToggle", {
    Title = "Enable WalkSpeed",
    Default = false
})

SpeedToggle:OnChanged(function(Value)
    WalkSpeedEnabled = Value
    if not Value then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
        end
    end
end)

Tabs.Main:AddSlider("WalkSpeedSlider", {
    Title = "WalkSpeed Value",
    Default = 16,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        TargetWalkSpeed = Value
    end
})

local NoclipToggle = Tabs.Main:AddToggle("NoclipToggle", {
    Title = "Enable Noclip",
    Default = false
})

NoclipToggle:OnChanged(function(Value)
    ToggleNoclip(Value)
end)

local GhostToggle = Tabs.Main:AddToggle("GhostToggle", {
    Title = "Enable Ghost Mode (Hotkey: Z)",
    Default = false
})

GhostToggle:OnChanged(function(Value)
    ToggleGhostMode(Value)
end)

local InfJumpToggle = Tabs.Main:AddToggle("InfJumpToggle", {
    Title = "Infinite Jump",
    Default = false
})

InfJumpToggle:OnChanged(function(Value)
    InfJumpEnabled = Value
end)

local function ToggleFly(state)
    FlyEnabled = state
    local char = LocalPlayer.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    if FlyEnabled then
        if not BodyGyro then
            BodyGyro = Instance.new("BodyGyro")
            BodyGyro.P = 9e4
            BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            BodyGyro.CFrame = hrp.CFrame
            BodyGyro.Parent = hrp
        end

        if not BodyVelocity then
            BodyVelocity = Instance.new("BodyVelocity")
            BodyVelocity.Velocity = Vector3.new(0, 0, 0)
            BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            BodyVelocity.Parent = hrp
        end

        humanoid.PlatformStand = true
    else
        if BodyGyro then 
            BodyGyro:Destroy() 
            BodyGyro = nil
        end
        if BodyVelocity then 
            BodyVelocity:Destroy() 
            BodyVelocity = nil
        end
        humanoid.PlatformStand = false
    end
end

local FlyToggle = Tabs.Main:AddToggle("FlyToggle", {
    Title = "Enable Fly",
    Default = false
})

FlyToggle:OnChanged(function(Value)
    ToggleFly(Value)
end)

Tabs.Main:AddSlider("FlySpeedSlider", {
    Title = "Fly Speed",
    Default = 50,
    Min = 10,
    Max = 300,
    Rounding = 0,
    Callback = function(Value)
        FlySpeed = Value
    end
})

local function TeleportUp()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    hrp.CFrame = hrp.CFrame * CFrame.new(0, 40, 0)

    Fluent:Notify({
        Title = "Zyro hub",
        Content = "Teleported 40 studs up!",
        Duration = 2
    })
end

Tabs.Main:AddButton({
    Title = "TP Up (+40 Studs)",
    Description = "Instant upward teleport (Hotkey: G)",
    Callback = function()
        TeleportUp()
    end
})

-- [[ COMBAT / TP TAB ]] --

Tabs.Combat:AddParagraph({
    Title = "Combat Utilities",
    Content = "Hotkey: T (Teleport to nearest enemy)"
})

local SilentAimToggle = Tabs.Combat:AddToggle("SilentAimToggle", {
    Title = "Enable Silent Aim",
    Default = false
})

SilentAimToggle:OnChanged(function(Value)
    SilentAimEnabled = Value
    if Value then
        Fluent:Notify({
            Title = "Zyro hub",
            Content = "Silent Aim Ativado!",
            Duration = 2
        })
    else
        Fluent:Notify({
            Title = "Zyro hub",
            Content = "Silent Aim Desativado!",
            Duration = 2
        })
    end
end)

Tabs.Combat:AddSlider("FOVSlider", {
    Title = "Silent Aim FOV",
    Default = 340,
    Min = 100,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        FOV_RADIUS = Value
    end
})

Tabs.Combat:AddSlider("PredictionSlider", {
    Title = "Silent Aim Prediction",
    Default = 0.22,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        PredictionFactor = Value
    end
})

local ESPLineToggle = Tabs.Combat:AddToggle("ESPLineToggle", {
    Title = "Enable ESP Line",
    Default = false
})

ESPLineToggle:OnChanged(function(Value)
    ESPLineEnabled = Value
    if not Value then
        CleanESPLines()
    else
        Fluent:Notify({
            Title = "Zyro hub",
            Content = "ESP Line Ativado!",
            Duration = 2
        })
    end
end)

local HitboxToggle = Tabs.Combat:AddToggle("HitboxToggle", {
    Title = "Enable Custom Hitbox",
    Default = false
})

HitboxToggle:OnChanged(function(Value)
    HitboxEnabled = Value
    if not Value and not UnderplayerEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                ResetPlayerHitbox(player)
            end
        end
    end
end)

Tabs.Combat:AddSlider("HitboxSlider", {
    Title = "Hitbox Size",
    Default = 10,
    Min = 2,
    Max = 50,
    Rounding = 0,
    Callback = function(Value)
        HitboxSize = Value
    end
})

local ESPToggle = Tabs.Combat:AddToggle("ESPToggle", {
    Title = "Enable ESP Highlight",
    Default = false
})

ESPToggle:OnChanged(function(Value)
    ESPEnabled = Value
    for _, player in pairs(Players:GetPlayers()) do
        if Value then
            ApplyHighlight(player)
        else
            RemoveHighlight(player)
        end
    end
end)

local function TeleportToNearestPlayer()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end

    local myHrp = myChar.HumanoidRootPart
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if IsEnemy(player) and IsPlayerValid(player) then
            local char = player.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local distance = (myHrp.Position - hrp.Position).Magnitude
            
            if distance < shortestDistance then
                shortestDistance = distance
                closestPlayer = hrp
            end
        end
    end

    if closestPlayer then
        myHrp.CFrame = closestPlayer.CFrame * CFrame.new(0, 0, 3)
        Fluent:Notify({ Title = "Zyro hub", Content = "Teleported!", Duration = 2 })
    else
        Fluent:Notify({ Title = "Zyro hub", Content = "No enemy found.", Duration = 2 })
    end
end

Tabs.Combat:AddButton({
    Title = "Teleport to Nearest Enemy (Hotkey: T)",
    Callback = function()
        TeleportToNearestPlayer()
    end
})

-- [[ UNDERPLAYER TAB ]] --

Tabs.Under:AddParagraph({
    Title = "Underplayer Mode",
    Content = "Hotkey: R"
})


local UnderToggle

local function ToggleUnderplayer(state)
    UnderplayerEnabled = state
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")

    if UnderplayerEnabled then
        if HitboxEnabled then
            HitboxToggle:SetValue(false)
        end

        SurfacePosition = hrp.CFrame
        hrp.CFrame = SurfacePosition * CFrame.new(0, -7, 0)
        hrp.Anchored = true

        Fluent:Notify({ Title = "Zyro hub", Content = "Underplayer Ativado!", Duration = 2 })
    else
        if SurfacePosition then
            hrp.CFrame = SurfacePosition
            SurfacePosition = nil
        end

        hrp.Anchored = false

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                ResetPlayerHitbox(player)
            end
        end

        Fluent:Notify({ Title = "Zyro hub", Content = "Underplayer Desativado!", Duration = 2 })
    end
end

UnderToggle = Tabs.Under:AddToggle("UnderToggle", {
    Title = "Enable Underplayer (Hotkey: R)",
    Default = false
})

UnderToggle:OnChanged(function(Value)
    if Value ~= UnderplayerEnabled then
        ToggleUnderplayer(Value)
    end
end)

-- [[ MAIN LOOP - OTIMIZADO ]] --

local lastESPUpdate = tick()
local lastHitboxUpdate = tick()

RunService.RenderStepped:Connect(function()
    -- WalkSpeed
    if WalkSpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = TargetWalkSpeed
    end

    -- Fly
    if FlyEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        local camera = Workspace.CurrentCamera
        local moveDir = Vector3.new()

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        if BodyVelocity and BodyGyro then
            BodyVelocity.Velocity = moveDir * FlySpeed
            BodyGyro.CFrame = camera.CFrame
        end
    end

    -- ESP (update a cada 0.1s)
    if tick() - lastESPUpdate > 0.1 then
        if ESPEnabled then
            for _, player in pairs(Players:GetPlayers()) do
                if IsEnemy(player) and player.Character then
                    ApplyHighlight(player)
                end
            end
        end
        lastESPUpdate = tick()
    end

    -- ESP Line
    if ESPLineEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if IsEnemy(player) and IsPlayerValid(player) then
                if not ESPLines[player] then
                    CreateESPLine(player)
                end
            end
        end
    end

    -- Hitbox (update a cada 0.1s)
    if tick() - lastHitboxUpdate > 0.1 then
        if HitboxEnabled and not UnderplayerEnabled then
            for _, player in pairs(Players:GetPlayers()) do
                if IsEnemy(player) and IsPlayerValid(player) then
                    local char = player.Character
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    
                    hrp.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                    hrp.Transparency = 0.7
                    hrp.BrickColor = BrickColor.new("Really red")
                    hrp.Material = Enum.Material.Neon
                    hrp.CanCollide = false
                end
            end
        end
        lastHitboxUpdate = tick()
    end

    -- Underplayer
    if UnderplayerEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if IsEnemy(player) and IsPlayerValid(player) then
                local char = player.Character
                local hrp = char:FindFirstChild("HumanoidRootPart")

                hrp.Size = Vector3.new(20, 20, 20)
                hrp.Transparency = 0.6
                hrp.BrickColor = BrickColor.new("Cyan")
                hrp.Material = Enum.Material.ForceField
                hrp.CanCollide = false
            end
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if InfJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Silent Aim
UserInputService.InputBegan:Connect(function(input, processed)
    if not SilentAimEnabled or processed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot or not ShootRemote then return end
        
        local targetPart = getClosestEnemy()
        
        if targetPart then
            local targetPos = targetPart.Position
            local targetChar = targetPart.Parent
            
            if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
                targetPos = targetPos + (targetChar.HumanoidRootPart.Velocity * PredictionFactor)
            end
            
            pcall(function()
                ShootRemote:FireServer(
                    myRoot.Position,
                    targetPos,
                    targetPart,
                    targetPos
                )
            end)
        end
    end
end)

-- Hotkeys
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.T then
        TeleportToNearestPlayer()
    elseif input.KeyCode == Enum.KeyCode.F then
        FlyToggle:SetValue(not FlyEnabled)
    elseif input.KeyCode == Enum.KeyCode.R then
        UnderToggle:SetValue(not UnderplayerEnabled)
    elseif input.KeyCode == Enum.KeyCode.G then
        TeleportUp()
    elseif input.KeyCode == Enum.KeyCode.Z then
        GhostToggle:SetValue(not GhostEnabled)
    end
end)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Zyro hub",
    Content = "Carregado com sucesso!",
    Duration = 3
})

print("[ZYRO HUB] Carregado!")
