--不要乱动代码这个也可以执行否则会触发其他诡异的事
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local FireServer, InvokeServer, items, GetGuid
pcall(function()
    local devv = require(ReplicatedStorage.devv)
    local SignalModule = require(devv.client.Helpers.remotes.Signal)
    FireServer = SignalModule.FireServer
    InvokeServer = SignalModule.InvokeServer
    items = devv.load("v3item").inventory.items
    GetGuid = function(name)
        for _, v in pairs(items) do
            if v.name == name then return v.guid end
        end
    end
end)

local itemMap = {}
local function updateCache()
    local itemPickup = Workspace.Game.Entities:FindFirstChild("ItemPickup")
    if not itemPickup then
        itemMap = {}
        return
    end
    itemMap = {}
    for _, model in pairs(itemPickup:GetChildren()) do
        for _, v in pairs(model:GetChildren()) do
            if v:IsA("MeshPart") or v:IsA("Part") then
                local prompt = v:FindFirstChildOfClass("ProximityPrompt")
                if prompt and prompt.ObjectText then
                    itemMap[prompt.ObjectText] = { part = v, prompt = prompt }
                end
            end
        end
    end
end
updateCache()
local itemPickupFolder = Workspace.Game.Entities:FindFirstChild("ItemPickup")
if itemPickupFolder then
    itemPickupFolder.ChildAdded:Connect(updateCache)
    itemPickupFolder.ChildRemoved:Connect(updateCache)
end

local function Autoitem(itemName)
    local itemData = itemMap[itemName]
    if not itemData then return false end
    local char = Players.LocalPlayer.Character
    if not char then return false end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    rootPart.CFrame = itemData.part.CFrame
    itemData.prompt.RequiresLineOfSight = false
    itemData.prompt.HoldDuration = 0
    fireproximityprompt(itemData.prompt)
    return true
end

local collectItems = {
    "Bunny Balloon", "Ghost Balloon", "Clover Balloon", "Bat Balloon",
    "Gold Clover Balloon", "Golden Rose", "Black Rose", "Heart Balloon"
}

local function getCharAndRoot()
    local char = Players.LocalPlayer.Character
    if not char then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, hrp
end

local function hasForceField()
    local char = Players.LocalPlayer.Character
    if not char then return false end
    return char:FindFirstChildOfClass("ForceField") ~= nil
end

local function collectNearbyCash()
    local _, hrp = getCharAndRoot()
    if not hrp then return end
    local cb = Workspace:FindFirstChild("Game") and Workspace.Game.Entities and Workspace.Game.Entities.CashBundle
    if not cb then return end
    for _, bundle in pairs(cb:GetChildren()) do
        local cd = bundle:FindFirstChildOfClass("ClickDetector")
        if cd and (hrp.Position - bundle:GetPivot().Position).Magnitude <= cd.MaxActivationDistance then
            fireclickdetector(cd)
        end
    end
end

local function robBankOnce()
    local char, hrp = getCharAndRoot()
    if not char then return end
    local bankRobbery = Workspace:FindFirstChild("BankRobbery")
    if not bankRobbery then return end
    local cashContainer = bankRobbery:FindFirstChild("BankCash") and bankRobbery.BankCash:FindFirstChild("Cash")
    if not cashContainer then return end
    repeat task.wait() until #cashContainer:GetChildren() ~= 0
    pcall(function()
        hrp.CFrame = bankRobbery.BankCash.Pallet.CFrame
        fireproximityprompt(bankRobbery.BankCash.Main.Attachment.ProximityPrompt)
        task.wait(0.5)
    end)
end

local collectCompleted = false
local atmCompleted = false
local bankCompleted = false

local function hasAnyTargetItems()
    for _, name in ipairs(collectItems) do
        if itemMap[name] then
            return true
        end
    end
    return false
end

local function initialCollect()
    for _, name in ipairs(collectItems) do
        Autoitem(name)
    end
end

local function runCollectPhase(duration)
    if not hasAnyTargetItems() then
        collectCompleted = true
        return
    end
    local endTime = tick() + duration
    while tick() < endTime do
        for _, name in ipairs(collectItems) do
            if tick() >= endTime then break end
            Autoitem(name)
            task.wait(0.05)
        end
    end
    if not hasAnyTargetItems() then
        collectCompleted = true
    end
end

local function runATMPhase()
    local atms = workspace:FindFirstChild("ATMs")
    local hasActive = false
    if atms then
        for _, atm in ipairs(atms:GetChildren()) do
            if atm:IsA("Model") and (atm:GetAttribute("health") or 0) ~= 0 then
                hasActive = true
                break
            end
        end
    end
    if not hasActive then
        atmCompleted = true
        return
    end

    local endTime = tick() + 12
    while tick() < endTime do
        local char, hrp = getCharAndRoot()
        if not char then task.wait(1); continue end
        if not atms then task.wait(1); continue end

        local targetFound = false
        for _, atm in ipairs(atms:GetChildren()) do
            if atm:IsA("Model") and (atm:GetAttribute("health") or 0) ~= 0 then
                for _, part in ipairs(atm:GetChildren()) do
                    if part.Name == "Main" and part:IsA("BasePart") then
                        hrp.CFrame = part.CFrame
                        task.wait(0.1)
                        atm:SetAttribute("health", 0)
                        targetFound = true
                        break
                    end
                end
                if targetFound then break end
            end
        end

        if targetFound then
            if tick() < endTime then
                task.wait(0.9)
                collectNearbyCash()
            end
        else
            task.wait(1)
        end
    end

    local stillActive = false
    if atms then
        for _, atm in ipairs(atms:GetChildren()) do
            if atm:IsA("Model") and (atm:GetAttribute("health") or 0) ~= 0 then
                stillActive = true
                break
            end
        end
    end
    if not stillActive then atmCompleted = true end
end

local function runBankPhase()
    local bank = Workspace:FindFirstChild("BankRobbery")
    if not bank then
        bankCompleted = true
        return
    end
    local cash = bank:FindFirstChild("BankCash") and bank.BankCash:FindFirstChild("Cash")
    if not cash then
        bankCompleted = true
        return
    end
    if #cash:GetChildren() == 0 then
        task.wait(3)
        if #cash:GetChildren() == 0 then
            bankCompleted = true
            return
        end
    end

    local endTime = tick() + 10
    while tick() < endTime do
        robBankOnce()
        task.wait(0.2)
    end
end

local function mainLoop()
    while not (collectCompleted and atmCompleted and bankCompleted) do
        if not collectCompleted then
            runCollectPhase(4)
        end
        if not atmCompleted then
            runATMPhase()
        end
        if not bankCompleted then
            runBankPhase()
        end
    end
end

local function cashAura()
    while true do
        local _, hrp = getCharAndRoot()
        if hrp then
            local cb = Workspace:FindFirstChild("Game") and Workspace.Game.Entities and Workspace.Game.Entities.CashBundle
            if cb then
                for _, bundle in pairs(cb:GetChildren()) do
                    local cd = bundle:FindFirstChildOfClass("ClickDetector")
                    if cd and (hrp.Position - bundle:GetPivot().Position).Magnitude <= cd.MaxActivationDistance then
                        fireclickdetector(cd)
                    end
                end
            end
        end
        task.wait(0.25)
    end
end

local function itemAura()
    while true do
        local _, hrp = getCharAndRoot()
        if hrp then
            local ip = Workspace:FindFirstChild("Game") and Workspace.Game.Entities and Workspace.Game.Entities.ItemPickup
            if ip then
                for _, item in pairs(ip:GetChildren()) do
                    pcall(function()
                        local cd = item:FindFirstChildWhichIsA("ClickDetector", true)
                        if cd and (hrp.Position - item:GetPivot().Position).Magnitude <= cd.MaxActivationDistance then
                            fireclickdetector(cd)
                        end
                    end)
                end
            end
        end
        task.wait(0.25)
    end
end

local function autoSellLoop()
    local Signal = require(ReplicatedStorage.devv).load("Signal")
    local itemModule = require(ReplicatedStorage.devv).load("v3item")
    while true do
        for _, v in pairs(itemModule.inventory.items) do
            pcall(function()
                Signal.FireServer("equip", v.guid)
                Signal.FireServer("sellItem", v.guid)
            end)
        end
        task.wait(1)
    end
end

local switched = false
function switchServer()
    if switched then return end
    switched = true
    local requestFunc = http_request or syn.request or request
    if not requestFunc then return end
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local response = requestFunc({Url = url, Method = "GET"})
    if response.StatusCode == 200 then
        local data = HttpService:JSONDecode(response.Body)
        if data and data.data and #data.data > 0 then
            TeleportService:TeleportToPlaceInstance(
                game.PlaceId,
                data.data[math.random(1, #data.data)].id,
                Players.LocalPlayer
            )
        end
    end
end

repeat task.wait(0.5) until Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

task.wait(3)

initialCollect()

task.spawn(cashAura)
task.spawn(itemAura)
task.spawn(mainLoop)
task.spawn(autoSellLoop)

task.spawn(function()
    local shieldTimer = nil
    local lastHadShield = false
    local shieldLostTime = nil

    while true do
        task.wait(0.1)
        local ff = hasForceField()
        local allDone = collectCompleted and atmCompleted and bankCompleted

        if ff then
            if not shieldTimer then
                shieldTimer = tick()
            elseif tick() - shieldTimer >= 9 then
                switchServer()
                break
            end
        else
            if lastHadShield then
                shieldLostTime = tick()
            end

            if shieldLostTime and tick() - shieldLostTime >= 4 then
                switchServer()
                break
            end

            if allDone then
                switchServer()
                break
            end

            shieldTimer = nil
        end

        lastHadShield = ff
    end
end)

task.delay(15, switchServer)

while true do task.wait(10) end