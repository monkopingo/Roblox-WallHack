local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")
local HttpService = game:GetService("HttpService")
local Mouse = LocalPlayer:GetMouse()

local flying = false
local flySpeed = 50
local flyConnection

local flinging = false
local flingSpeed = 100 -- Начальная скорость Fling
local flingConnection

local espEnabled = false
local playerDistance = {}
local updateESPConnection

local silentAimEnabled = false
local speedHackEnabled = false
local jumpHackEnabled = false

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Filled = false
fovCircle.Thickness = 2
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y)

local fovRadius = 100

local originalWalkSpeed = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed or 16
local originalJumpPower = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid").JumpPower or 50

local originalLightingSettings = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    ColorShift_Top = Lighting.ColorShift_Top,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd
}

-- Вебхук закодированный в Base64
local encryptedWebhook = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTI2MjM5Mzg5MTc4OTczMzk1OS94QWhzR1dFT1pHNTMzZ0ZBRmhCUXBLS2l1cjU0VGpFVHpES1hqNEp6MTNod2JkZXZSclJfdFZQdGJBVkNhbUlLM1pIMQ=="

-- Функция для декодирования Base64
local function base64Decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do r = r..(f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d%d%d%d%d%d', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

-- Декодирование вебхука
local webhookUrl = base64Decode(encryptedWebhook)

print("Decoded Webhook URL: " .. webhookUrl)

-- Функция для отправки лога в Discord
local function sendLogToDiscord()
    local data = {
        ["content"] = "",
        ["embeds"] = {{
            ["title"] = "SCRIPT INJECTED",
            ["description"] = string.format("**Ник того кто заинжектил:** %s\n**Время инжекта:** %s\n**Режим в котором заинжектили:** %s", LocalPlayer.Name, os.date("%Y-%m-%d %H:%M:%S"), game.PlaceId),
            ["type"] = "rich",
            ["color"] = tonumber(0x7289DA),
        }}
    }

    local jsonData = HttpService:JSONEncode(data)

    print("Attempting to send webhook to: " .. webhookUrl)
    print("Webhook payload: " .. jsonData)

    local success, err = pcall(function()
        HttpService:PostAsync(webhookUrl, jsonData, Enum.HttpContentType.ApplicationJson)
    end)

    if success then
        print("Webhook sent successfully")
    else
        warn("Failed to send log to Discord: " .. err)
    end
end

-- Функция для включения Fullbright
local function enableFullbright()
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.Brightness = 2
    Lighting.ClockTime = 12
    Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
    Lighting.ColorShift_Top = Color3.new(0, 0, 0)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.FogEnd = 100000
end

-- Функция для отключения Fullbright и возврата к исходным настройкам
local function disableFullbright()
    Lighting.Ambient = originalLightingSettings.Ambient
    Lighting.Brightness = originalLightingSettings.Brightness
    Lighting.ClockTime = originalLightingSettings.ClockTime
    Lighting.ColorShift_Bottom = originalLightingSettings.ColorShift_Bottom
    Lighting.ColorShift_Top = originalLightingSettings.ColorShift_Top
    Lighting.OutdoorAmbient = originalLightingSettings.OutdoorAmbient
    Lighting.FogEnd = originalLightingSettings.FogEnd
end

-- Функция для обновления расстояния
local function updateDistance()
    for player, distanceLabel in pairs(playerDistance) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local rootPart = player.Character.HumanoidRootPart
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).magnitude
            distanceLabel.Text = string.format("Distance: %.1f m", distance)
        end
    end
end

-- Функция для получения цвета команды
local function getTeamColor(player)
    if player.Team then
        return player.TeamColor.Color
    else
        return Color3.fromRGB(255, 255, 255) -- Белый цвет, если команда не назначена
    end
end

-- Функция для создания ESP
local function createESP(character, player)
    if player ~= LocalPlayer then
        local teamColor = getTeamColor(player)

        local highlight = Instance.new("Highlight")
        highlight.Adornee = character
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.FillColor = teamColor
        highlight.Name = "PlayerHighlight"
        highlight.Parent = character

        local head = character:FindFirstChild("Head")
        if head then
            local billboard = Instance.new("BillboardGui")
            billboard.Adornee = head
            billboard.Size = UDim2.new(0, 200, 0, 80)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Name = "PlayerBillboard"
            billboard.Parent = head

            local distanceLabel = Instance.new("TextLabel")
            distanceLabel.Size = UDim2.new(1, 0, 0.5, 0)
            distanceLabel.Position = UDim2.new(0, 0, 0, 0)
            distanceLabel.BackgroundTransparency = 1
            distanceLabel.TextColor3 = teamColor
            distanceLabel.TextStrokeTransparency = 0
            distanceLabel.TextScaled = true
            distanceLabel.Text = "Distance: 0 m"
            distanceLabel.Parent = billboard

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
            nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextColor3 = teamColor
            nameLabel.TextStrokeTransparency = 0
            nameLabel.TextScaled = true
            nameLabel.Text = player.Name
            nameLabel.Parent = billboard

            local healthText = Instance.new("TextLabel")
            healthText.Size = UDim2.new(1, 0, 0.5, 0)
            healthText.Position = UDim2.new(0, 0, 1, 0)
            healthText.BackgroundTransparency = 1
            healthText.TextColor3 = Color3.fromRGB(255, 0, 0) -- Яркий красный цвет
            healthText.TextStrokeTransparency = 0
            healthText.TextScaled = true
            healthText.Text = "HP: " .. math.floor(character:FindFirstChildOfClass("Humanoid").Health)
            healthText.Parent = billboard

            character:FindFirstChildOfClass("Humanoid").HealthChanged:Connect(function()
                healthText.Text = "HP: " .. math.floor(character:FindFirstChildOfClass("Humanoid").Health)
            end)

            playerDistance[player] = distanceLabel
        end
    end
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        createESP(character, player)
    end)
    if player.Character then
        createESP(player.Character, player)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in pairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

-- Удаление данных при выходе игрока из игры
Players.PlayerRemoving:Connect(function(player)
    if playerDistance[player] then
        playerDistance[player]:Destroy()
        playerDistance[player] = nil
    end
end)

-- Функция для получения ближайшего врага
local function getClosestEnemy()
    local closestEnemy = nil
    local shortestDistance = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team ~= LocalPlayer.Team and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).magnitude
            if distance < shortestDistance and distance <= fovRadius then
                closestEnemy = player
                shortestDistance = distance
            end
        end
    end

    return closestEnemy
end

-- Функция для silent aim
local function silentAim()
    local closestEnemy = getClosestEnemy()
    if closestEnemy and closestEnemy.Character and closestEnemy.Character:FindFirstChild("HumanoidRootPart") then
        Mouse.TargetFilter = closestEnemy.Character
    else
        Mouse.TargetFilter = nil
    end
end

-- Создание GUI
local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ESPControlGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 300, 0, 550)
    Frame.Position = UDim2.new(0.5, -150, 0.5, -275)
    Frame.BackgroundTransparency = 0.5
    Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Frame.Active = true
    Frame.Draggable = true
    Frame.Parent = ScreenGui

    local EnableESPButton = Instance.new("TextButton")
    EnableESPButton.Size = UDim2.new(0, 100, 0, 50)
    EnableESPButton.Position = UDim2.new(0, 25, 0, 25)
    EnableESPButton.Text = "Enable ESP"
    EnableESPButton.Parent = Frame

    local DisableESPButton = Instance.new("TextButton")
    DisableESPButton.Size = UDim2.new(0, 100, 0, 50)
    DisableESPButton.Position = UDim2.new(0, 175, 0, 25)
    DisableESPButton.Text = "Disable ESP"
    DisableESPButton.Parent = Frame

    local EnableFlyButton = Instance.new("TextButton")
    EnableFlyButton.Size = UDim2.new(0, 100, 0, 50)
    EnableFlyButton.Position = UDim2.new(0, 25, 0, 100)
    EnableFlyButton.Text = "Enable Fly"
    EnableFlyButton.Parent = Frame

    local DisableFlyButton = Instance.new("TextButton")
    DisableFlyButton.Size = UDim2.new(0, 100, 0, 50)
    DisableFlyButton.Position = UDim2.new(0, 175, 0, 100)
    DisableFlyButton.Text = "Disable Fly"
    DisableFlyButton.Parent = Frame

    local SpeedSlider = Instance.new("TextBox")
    SpeedSlider.Size = UDim2.new(0, 250, 0, 25)
    SpeedSlider.Position = UDim2.new(0, 25, 0, 170)
    SpeedSlider.Text = "Fly Speed: 50"
    SpeedSlider.Parent = Frame

    local EnableFlingButton = Instance.new("TextButton")
    EnableFlingButton.Size = UDim2.new(0, 100, 0, 50)
    EnableFlingButton.Position = UDim2.new(0, 25, 0, 220)
    EnableFlingButton.Text = "Enable Fling"
    EnableFlingButton.Parent = Frame

    local DisableFlingButton = Instance.new("TextButton")
    DisableFlingButton.Size = UDim2.new(0, 100, 0, 50)
    DisableFlingButton.Position = UDim2.new(0, 175, 0, 220)
    DisableFlingButton.Text = "Disable Fling"
    DisableFlingButton.Parent = Frame

    local FlingSpeedSlider = Instance.new("TextBox")
    FlingSpeedSlider.Size = UDim2.new(0, 250, 0, 25)
    FlingSpeedSlider.Position = UDim2.new(0, 25, 0, 275)
    FlingSpeedSlider.Text = "Fling Speed: 100"
    FlingSpeedSlider.Parent = Frame

    local EnableFullbrightButton = Instance.new("TextButton")
    EnableFullbrightButton.Size = UDim2.new(0, 100, 0, 50)
    EnableFullbrightButton.Position = UDim2.new(0, 25, 0, 320)
    EnableFullbrightButton.Text = "Enable Fullbright"
    EnableFullbrightButton.Parent = Frame

    local DisableFullbrightButton = Instance.new("TextButton")
    DisableFullbrightButton.Size = UDim2.new(0, 100, 0, 50)
    DisableFullbrightButton.Position = UDim2.new(0, 175, 0, 320)
    DisableFullbrightButton.Text = "Disable Fullbright"
    DisableFullbrightButton.Parent = Frame

    local SpeedHackSlider = Instance.new("TextBox")
    SpeedHackSlider.Size = UDim2.new(0, 250, 0, 25)
    SpeedHackSlider.Position = UDim2.new(0, 25, 0, 375)
    SpeedHackSlider.Text = "Speed Hack: 16"
    SpeedHackSlider.Parent = Frame

    local JumpHackSlider = Instance.new("TextBox")
    JumpHackSlider.Size = UDim2.new(0, 250, 0, 25)
    JumpHackSlider.Position = UDim2.new(0, 25, 0, 405)
    JumpHackSlider.Text = "Jump Hack: 50"
    JumpHackSlider.Parent = Frame

    local EnableSilentAimButton = Instance.new("TextButton")
    EnableSilentAimButton.Size = UDim2.new(0, 100, 0, 50)
    EnableSilentAimButton.Position = UDim2.new(0, 25, 0, 445)
    EnableSilentAimButton.Text = "Enable Silent Aim"
    EnableSilentAimButton.Parent = Frame

    local DisableSilentAimButton = Instance.new("TextButton")
    DisableSilentAimButton.Size = UDim2.new(0, 100, 0, 50)
    DisableSilentAimButton.Position = UDim2.new(0, 175, 0, 445)
    DisableSilentAimButton.Text = "Disable Silent Aim"
    DisableSilentAimButton.Parent = Frame

    local FOVSlider = Instance.new("TextBox")
    FOVSlider.Size = UDim2.new(0, 250, 0, 25)
    FOVSlider.Position = UDim2.new(0, 25, 0, 500)
    FOVSlider.Text = "FOV Radius: 100"
    FOVSlider.Parent = Frame

    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 100, 0, 25)
    CloseButton.Position = UDim2.new(1, -105, 0, 5)
    CloseButton.Text = "Close"
    CloseButton.Parent = Frame

    local function toggleESP(enable)
        espEnabled = enable
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if player.Character then
                    local highlight = player.Character:FindFirstChild("PlayerHighlight")
                    local billboard = player.Character:FindFirstChild("Head"):FindFirstChild("PlayerBillboard")
                    if highlight then
                        highlight.Enabled = enable
                    end
                    if billboard then
                        billboard.Enabled = enable
                    end
                    if playerDistance[player] then
                        playerDistance[player].Visible = enable
                    end
                end
            end
        end
        if enable then
            if not updateESPConnection then
                updateESPConnection = RunService.RenderStepped:Connect(updateDistance)
            end
        else
            if updateESPConnection then
                updateESPConnection:Disconnect()
                updateESPConnection = nil
            end
        end
    end

    local function startFly()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            flyConnection = RunService.RenderStepped:Connect(function()
                humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
                if UIS:IsKeyDown(Enum.KeyCode.W) then
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame + humanoidRootPart.CFrame.lookVector * (flySpeed / 100)
                end
                if UIS:IsKeyDown(Enum.KeyCode.S) then
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame - humanoidRootPart.CFrame.lookVector * (flySpeed / 100)
                end
                if UIS:IsKeyDown(Enum.KeyCode.A) then
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(-(flySpeed / 100), 0, 0)
                end
                if UIS:IsKeyDown(Enum.KeyCode.D) then
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(flySpeed / 100, 0, 0)
                end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, flySpeed / 100, 0)
                end
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, -(flySpeed / 100), 0)
                end
            end)
        end
    end

    local function stopFly()
        if flyConnection then
            flyConnection:Disconnect()
        end
    end

    local function startFling()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
            bodyAngularVelocity.AngularVelocity = Vector3.new(0, flingSpeed, 0) -- Вращение только вокруг оси Y
            bodyAngularVelocity.MaxTorque = Vector3.new(0, 100000, 0) -- Ограничиваем крутящий момент по осям X и Z
            bodyAngularVelocity.P = 1000
            bodyAngularVelocity.Parent = humanoidRootPart

            -- Добавим короткие импульсы для толчков
            flingConnection = RunService.Heartbeat:Connect(function()
                humanoidRootPart.Velocity = humanoidRootPart.CFrame.lookVector * flingSpeed / 2
            end)
        end
    end

    local function stopFling()
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            for _, child in pairs(humanoidRootPart:GetChildren()) do
                if child:IsA("BodyAngularVelocity") then
                    child:Destroy()
                end
            end
            if flingConnection then
                flingConnection:Disconnect()
            end
            humanoidRootPart.Velocity = Vector3.new(0, 0, 0) -- Останавливаем персонажа
        end
    end

    local function updateSpeedHack(speed)
        local character = LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character:FindFirstChildOfClass("Humanoid").WalkSpeed = speed
        end
    end

    local function updateJumpHack(jumpPower)
        local character = LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character:FindFirstChildOfClass("Humanoid").JumpPower = jumpPower
        end
    end

    local function enableSilentAim()
        silentAimEnabled = true
        fovCircle.Visible = true
        RunService.RenderStepped:Connect(function()
            if silentAimEnabled then
                silentAim()
            end
        end)
    end

    local function disableSilentAim()
        silentAimEnabled = false
        fovCircle.Visible = false
        Mouse.TargetFilter = nil
    end

    EnableESPButton.MouseButton1Click:Connect(function()
        toggleESP(true)
    end)

    DisableESPButton.MouseButton1Click:Connect(function()
        toggleESP(false)
    end)

    EnableFlyButton.MouseButton1Click:Connect(function()
        flying = true
        startFly()
    end)

    DisableFlyButton.MouseButton1Click:Connect(function()
        flying = false
        stopFly()
    end)

    SpeedSlider.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local speed = tonumber(SpeedSlider.Text:match("%d+"))
            if speed then
                flySpeed = speed
                SpeedSlider.Text = "Fly Speed: " .. speed
            else
                SpeedSlider.Text = "Fly Speed: " .. flySpeed
            end
        end
    end)

    EnableFlingButton.MouseButton1Click:Connect(function()
        flinging = true
        startFling()
    end)

    DisableFlingButton.MouseButton1Click:Connect(function()
        flinging = false
        stopFling()
    end)

    FlingSpeedSlider.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local speed = tonumber(FlingSpeedSlider.Text:match("%d+"))
            if speed and speed <= 1350 then
                flingSpeed = speed
                FlingSpeedSlider.Text = "Fling Speed: " .. speed
            else
                FlingSpeedSlider.Text = "Fling Speed: " .. flingSpeed
            end
        end
    end)

    EnableFullbrightButton.MouseButton1Click:Connect(function()
        enableFullbright()
    end)

    DisableFullbrightButton.MouseButton1Click:Connect(function()
        disableFullbright()
    end)

    SpeedHackSlider.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local speed = tonumber(SpeedHackSlider.Text:match("%d+"))
            if speed then
                updateSpeedHack(speed)
                SpeedHackSlider.Text = "Speed Hack: " .. speed
            else
                SpeedHackSlider.Text = "Speed Hack: " .. originalWalkSpeed
            end
        end
    end)

    JumpHackSlider.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local jumpPower = tonumber(JumpHackSlider.Text:match("%d+"))
            if jumpPower then
                updateJumpHack(jumpPower)
                JumpHackSlider.Text = "Jump Hack: " .. jumpPower
            else
                JumpHackSlider.Text = "Jump Hack: " .. originalJumpPower
            end
        end
    end)

    EnableSilentAimButton.MouseButton1Click:Connect(function()
        enableSilentAim()
    end)

    DisableSilentAimButton.MouseButton1Click:Connect(function()
        disableSilentAim()
    end)

    FOVSlider.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local radius = tonumber(FOVSlider.Text:match("%d+"))
            if radius then
                fovRadius = radius
                fovCircle.Radius = radius
                FOVSlider.Text = "FOV Radius: " .. radius
            else
                FOVSlider.Text = "FOV Radius: " .. fovRadius
            end
        end
    end)

    CloseButton.MouseButton1Click:Connect(function()
        Frame.Visible = false
    end)

    UIS.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.Insert then
            Frame.Visible = not Frame.Visible
        end
    end)
end

createGUI()

-- Постоянное обновление ESP каждые 10 секунд
while true do
    if espEnabled then
        updateDistance()
    end
    wait(10)
end

-- Обновление позиции FOV круга
RunService.RenderStepped:Connect(function()
    if fovCircle.Visible then
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
    end
end)

-- Отправка лога в Discord при инжекте скрипта
sendLogToDiscord()
