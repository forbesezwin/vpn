local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Event = game:GetService("ReplicatedStorage"):WaitForChild("ClanRemotes"):WaitForChild("InvitePlayer")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local isRunning = true -- Скрипт сразу активен при запуске
local inviteThread = nil

-- === НАСТРОЙКИ ===
local MAX_LOOPS = 3             -- Количество кругов приглашений на одном сервере
local DELAY_BETWEEN_INVITES = 0.4 -- Пауза между инвайтами игроков (в секундах)
local DELAY_BETWEEN_LOOPS = 10.0  -- Пауза между кругами (в секундах)
local AUTOHOP_DELAY = 5.0        -- Сколько секунд ждать перед авто-сменой сервера

-- Функция проверки игроков
local function canInvite(plr)
    if plr == LocalPlayer then return false end
    if not plr or not plr.Parent then return false end 
    return true
end

-- Получение списка игроков
local function getTargetPlayers()
    local targets = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if canInvite(plr) then
            table.insert(targets, plr)
        end
    end
    return targets
end

-- Функция для Server Hop
local function ServerHop()
    local success, result = pcall(function()
        local url = "https://roblox.com" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if success and result and result.data then
        local validServers = {}
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                table.insert(validServers, server)
            end
        end
        
        if #validServers > 0 then
            local targetServer = validServers[math.random(1, #validServers)]
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServer.id, LocalPlayer)
        else
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    else
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end

-- Создание интерфейса
local function CreateInterface()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoClanGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(0.18, 0.19)
    frame.Position = UDim2.fromScale(0.8, 0.7)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = frame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Thickness = 1.5
    frameStroke.Color = Color3.fromRGB(50, 50, 65)
    frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    frameStroke.Parent = frame

    -- Текст статуса и счетчика
    local counter = Instance.new("TextLabel")
    counter.Size = UDim2.fromScale(0.9, 0.2)
    counter.Position = UDim2.fromScale(0.05, 0.08)
    counter.BackgroundTransparency = 1
    counter.Font = Enum.Font.GothamBold
    counter.Text = "Подготовка..."
    counter.TextColor3 = Color3.fromRGB(200, 200, 210)
    counter.TextSize = 12
    counter.Parent = frame

    -- Кнопка Пауза/Старт (Изначально ВКЛЮЧЕНА)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromScale(0.9, 0.28)
    button.Position = UDim2.fromScale(0.05, 0.35)
    button.BackgroundColor3 = Color3.fromRGB(75, 180, 100) -- Сразу зеленый
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Text = "ВЫКЛЮЧИТЬ"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 13
    button.Parent = frame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = button

    -- Кнопка Server Hop (Для ручного пропуска, если сервер пустой)
    local hopButton = Instance.new("TextButton")
    hopButton.Size = UDim2.fromScale(0.9, 0.24)
    hopButton.Position = UDim2.fromScale(0.05, 0.68)
    hopButton.BackgroundColor3 = Color3.fromRGB(45, 120, 210)
    hopButton.BorderSizePixel = 0
    hopButton.Font = Enum.Font.GothamBold
    hopButton.Text = "ПРОПУСТИТЬ СЕРВЕР"
    hopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    hopButton.TextSize = 12
    hopButton.Parent = frame

    local hopCorner = Instance.new("UICorner")
    hopCorner.CornerRadius = UDim.new(0, 6)
    hopCorner.Parent = hopButton

    return button, hopButton, counter
end

local Button, HopButton, Counter = CreateInterface()

-- Цикл автоматической рассылки
local function StartInvitingLoop()
    local currentLoop = 1
    
    while isRunning and currentLoop <= MAX_LOOPS do
        local targets = getTargetPlayers()
        local total = #targets
        
        if total == 0 then
            Counter.Text = "Нет игроков. Авто-Hop через 5 сек..."
            task.wait(AUTOHOP_DELAY)
            if isRunning then ServerHop() end
            return
        else
            for index, plr in ipairs(targets) do
                if not isRunning then break end
                
                Counter.Text = string.format("Круг %d/%d | Приглашено: %d/%d", currentLoop, MAX_LOOPS, index, total)
                
                pcall(function()
                    if plr and plr.Parent then
                        Event:InvokeServer(tostring(plr.Name))
                    end
                end)
                
                task.wait(DELAY_BETWEEN_INVITES)
            end
            
            if isRunning then
                if currentLoop < MAX_LOOPS then
                    Counter.Text = string.format("Круг %d пройден. Ожидание...", currentLoop)
                    currentLoop = currentLoop + 1
                    task.wait(DELAY_BETWEEN_LOOPS)
                else
                    break
                end
            end
        end
    end
    
    -- Конец 3-го круга. Запуск таймера авто-телепортации
    if isRunning then
        Button.Text = "ТЕЛЕПОРТАЦИЯ..."
        Button.BackgroundColor3 = Color3.fromRGB(30, 80, 150)
        
        -- Обратный отсчет 5 секунд
        for i = AUTOHOP_DELAY, 1, -1 do
            if not isRunning then break end
            Counter.Text = string.format("Готово! Новый сервер через %d...", i)
            task.wait(1)
        end
        
        if isRunning then
            ServerHop()
        end
    end
end

-- Старт потока сразу при инжекте
inviteThread = task.spawn(StartInvitingLoop)

-- Ручное управление (Пауза/Продолжить)
Button.Activated:Connect(function()
    isRunning = not isRunning
    
    if isRunning then
        Button.Text = "ВЫКЛЮЧИТЬ"
        Button.BackgroundColor3 = Color3.fromRGB(75, 180, 100)
        inviteThread = task.spawn(StartInvitingLoop)
    else
        Button.Text = "ВКЛЮЧИТЬ"
        Button.BackgroundColor3 = Color3.fromRGB(235, 75, 75)
        Counter.Text = "Автоматика остановлена"
        if inviteThread then
            inviteThread = nil
        end
    end
end)

-- Кнопка принудительного Hop
HopButton.Activated:Connect(function()
    HopButton.Text = "ТЕЛЕПОРТАЦИЯ..."
    HopButton.BackgroundColor3 = Color3.fromRGB(30, 80, 150)
    ServerHop()
end)
