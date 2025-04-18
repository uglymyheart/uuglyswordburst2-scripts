if not game:IsLoaded() then
    game.Loaded:Wait()
end

if game.GameId ~= 212154879 then return end -- Swordburst 2

if getgenv().Bluu then return end
getgenv().Bluu = true

-- local queue_on_teleport = (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queue_on_teleport
-- if queue_on_teleport then
--     queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/Neuublue/Bluu/main/Swordburst2.lua'))()")
-- end

local sendWebhook = (function()
    local http_request = (syn and syn.request) or (fluxus and fluxus.request) or http_request or request
    local HttpService = game:GetService('HttpService')

    return function(url, body, ping)
        assert(typeof(url) == 'string')
        assert(typeof(body) == 'table')
        if not string.match(url, '^https://discord') then return end

        body.content = ping and '@everyone' or nil
        body.username = 'Bluu'
        body.avatar_url = 'https://raw.githubusercontent.com/Neuublue/Bluu/main/Bluu.png'
        body.embeds = body.embeds or {{}}
        body.embeds[1].timestamp = DateTime:now():ToIsoDate()
        body.embeds[1].footer = {
            text = 'Bluu',
            icon_url = 'https://raw.githubusercontent.com/Neuublue/Bluu/main/Bluu.png'
        }

        http_request({
            Url = url,
            Body = HttpService:JSONEncode(body),
            Method = 'POST',
            Headers = { ['content-type'] = 'application/json' }
        })
    end
end)()


local sendTestMessage = function(url)
    sendWebhook(
        url, {
            embeds = {{
                title = 'This is a test message',
                description = `You'll be notified to this webhook`,
                color = 0x00ff00
            }}
        }, (Toggles.PingInMessage and Toggles.PingInMessage.Value)
    )
end

local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal('LocalPlayer'):Wait()
    LocalPlayer = Players.LocalPlayer
end
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild('Humanoid')
local HumanoidRootPart = Character:WaitForChild('HumanoidRootPart')

local Entity = Character:WaitForChild('Entity')
local Stamina = Entity:WaitForChild('Stamina')

local Camera = workspace.CurrentCamera
if not Camera then
    workspace:GetPropertyChangedSignal('CurrentCamera'):Wait()
    Camera = workspace.CurrentCamera
end

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Profiles = ReplicatedStorage:WaitForChild('Profiles')
local Profile = Profiles:WaitForChild(LocalPlayer.Name)

local Inventory = Profile:WaitForChild('Inventory')
local AnimPacks = Profile:WaitForChild('AnimPacks')
local Equip = Profile:WaitForChild('Equip')

local Exp = Profile:WaitForChild('Stats'):WaitForChild('Exp')
local getLevel = function(value)
    return math.floor((value or Exp.Value) ^ (1/3))
end
local Vel = Exp.Parent:WaitForChild('Vel')

local Database = ReplicatedStorage:WaitForChild('Database')
local Items = Database:WaitForChild('Items')
local Skills = Database:WaitForChild('Skills')

local Event = ReplicatedStorage:WaitForChild('Event')
local Function = ReplicatedStorage:WaitForChild('Function')
local InvokeFunction = function(...)
    local args = {...}
    local success, result
    while not success do
        success, result = pcall(function()
            return Function:InvokeServer(table.unpack(args))
        end)
    end
    return result
end

local PlayerUI = LocalPlayer:WaitForChild('PlayerGui'):WaitForChild('CardinalUI'):WaitForChild('PlayerUI')
local Level = PlayerUI:WaitForChild('HUD'):WaitForChild('LevelBar'):WaitForChild('Level')
local Chat = PlayerUI:WaitForChild('Chat')

local Mobs = workspace:WaitForChild('Mobs')

local RunService = game:GetService('RunService')
local Stepped = RunService.Stepped

local UserInputService = game:GetService('UserInputService')
local MarketplaceService = game:GetService('MarketplaceService')
local StarterGui = game:GetService('StarterGui')

LocalPlayer.Idled:Connect(function()
    game:GetService('VirtualUser'):ClickButton2(Vector2.new())
end)

local MainModule = (function()
    for _, func in next, { getloadedmodules, getnilinstances } do
        if type(func) ~= 'function' then continue end
        for _, instance in next, select(2, pcall(func)) do
            if instance.Name == 'MainModule' and instance:FindFirstChild('Services') then
                return instance
            end
        end
    end
end)()

local success, RequiredServices = pcall(function()
    if not MainModule then return end
    local RequiredServices = require(MainModule).Services
    local UI = MainModule.Services.UI
    RequiredServices.InventoryUI = require(UI.Inventory)
    RequiredServices.StatsUI = require(UI.Stats)
    RequiredServices.TradeUI = require(UI.Trade)
    return RequiredServices
end)

if not (success and RequiredServices) then
    success, RequiredServices = pcall(function()
        for _, object in next, getreg() do
            if not (type(object) == 'table' and rawget(object, 'Services')) then
                continue
            end
            local UISafeInit = object.Services.UI.SafeInit
            RequiredServices.InventoryUI = debug.getupvalue(UISafeInit, 18)
            RequiredServices.StatsUI = debug.getupvalue(UISafeInit, 40)
            RequiredServices.TradeUI = debug.getupvalue(UISafeInit, 31)
            return object.Services
        end
    end)
    if not success then
        RequiredServices = nil
    end
end

local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/Neuublue/Bluu/main/LinoriaLib/Library.lua'))()

local Window = Library:CreateWindow({
    Title = 'Bluu 😳 Swordburst 2',
    Center = true,
    AutoShow = true,
    Resizable = true,
    ShowCustomCursor = false,
    TabPadding = 8,
    MenuFadeTime = 0.1
})

local Main = Window:AddTab('Main')

local Farming = Main:AddLeftTabbox()

local Autofarm = Farming:AddTab('Autofarm')

local linearVelocity = Instance.new('LinearVelocity')
linearVelocity.MaxForce = math.huge

local waypointIndex = 1

local KillauraSkill

local animateFunction
local animateConstantsModified = false

local setWalkingAnimation = function(value, force)
    if not animateFunction then return end
    if not force and animateConstantsModified == value then return end
    debug.setconstant(animateFunction, 18, value and 'TargetPoint' or 'MoveDirection')
    debug.setconstant(animateFunction, 19, value and 'X' or 'magnitude')
    animateConstantsModified = value
end

local awaitEventTimeout = function(event, callback, timeout)
    local signal = Instance.new('BoolValue')
    local connection
    connection = event:Connect(function(...)
        if callback and not callback(...) then return end
        signal.Value = true
    end)
    if timeout then
        task.delay(timeout, function()
            signal.Value = true
        end)
    else
        task.spawn(function()
            Function:InvokeServer('Test')
            signal.Value = true
        end)
    end
    signal:GetPropertyChangedSignal('Value'):Wait()
    connection:Disconnect()
    signal:Destroy()
end

local teleportToCFrame = (function(cframe)
    -- Event:FireServer('Checkpoints', { 'TeleportToSpawn' })
    -- AwaitEventTimeout(game:GetService('CollectionService').TagAdded, function(tag)
    --     return tag == 'Teleporting'
    -- end)
    -- HumanoidRootPart.CFrame = cframe

    local targetCFrame = cframe + Vector3.new(0, 1e6 - cframe.Position.Y, 0)
    local startTime = tick()
    while tick() - startTime < 0.5 do
        HumanoidRootPart.AssemblyLinearVelocity = Vector3.new()
        HumanoidRootPart.CFrame = targetCFrame
        Stepped:Wait()
    end
    HumanoidRootPart.CFrame = cframe
    -- while HumanoidRootPart.CFrame.Position.Y > 1e5 do
    --     HumanoidRootPart.AssemblyLinearVelocity = Vector3.new()
    --     HumanoidRootPart.CFrame = cframe
    --     Stepped:Wait()
    -- end
end)

local fastRespawn = function()
    Event:FireServer('Profile', { 'Respawn' })
end

local lastDeathCFrame

local swingDamageEnabled = true
local toggleSwingDamage = function(value)
    swingDamageEnabled = value

    local RightWeapon = Character:FindFirstChild('RightWeapon')
    if RightWeapon and RightWeapon:FindFirstChild('Tool') and RightWeapon.Tool:FindFirstChild('Blade') then
        RightWeapon.Tool.Blade.CanTouch = value
    else
        return
    end

    local LeftWeapon = Character:FindFirstChild('LeftWeapon')
    if LeftWeapon and LeftWeapon:FindFirstChild('Tool') and LeftWeapon.Tool:FindFirstChild('Blade') then
        LeftWeapon.Tool.Blade.CanTouch = value
    end
end

local onHumanoidAdded = function()
    Humanoid.Died:Connect(function()
        lastDeathCFrame = HumanoidRootPart.CFrame

        if Toggles.FastRespawns.Value then
            fastRespawn()
        end

        if Toggles.DisableOnDeath.Value then
            if Toggles.Autofarm.Value then
                Toggles.Autofarm:SetValue(false)
                if Toggles.Killaura.Value then
                    Toggles.Killaura:SetValue(false)
                end
            end
        end
    end)

    Humanoid.TargetPoint = Vector3.new(1, 100, 100)

    Humanoid.MoveToFinished:Connect(function()
        waypointIndex += 1
    end)

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

    HumanoidRootPart:GetPropertyChangedSignal('Anchored'):Connect(function()
        if HumanoidRootPart.Anchored then
            HumanoidRootPart.Anchored = false
        end
    end)

    linearVelocity.Attachment0 = HumanoidRootPart:WaitForChild('RootAttachment')

    task.spawn(InvokeFunction, 'Equipment', {
        'Wear', {
            Name = 'Blue Novice Armor',
            Value = Equip.Clothing.Value
        }
    })

    if Equip.Right.Value ~= 0 then
        task.spawn(InvokeFunction, 'Equipment', {
            'EquipWeapon', {
                Name = 'Steel Longsword',
                Value = Equip.Left.Value
            }, 'Left'
        })
    end

    toggleSwingDamage(swingDamageEnabled)
    Character.ChildAdded:Connect(function(child)
        if child.Name == 'RightWeapon' or child.Name == 'LeftWeapon' then
            child:WaitForChild('Tool'):WaitForChild('Blade').CanTouch = swingDamageEnabled
        end
    end)

    Stamina.Changed:Connect(function(value)
        if not Toggles.ResetOnLowStamina.Value then return end
        if not KillauraSkill.Active and value < KillauraSkill.Cost then
            fastRespawn()
        end
    end)

    animateFunction = (function()
        if not getconnections then return end
        for _, connection in next, getconnections(Stepped) do
            local func = connection.Function
            if func and debug.info(func, 's'):find('Animate') then
                return func
            end
        end
    end)()

    setWalkingAnimation(animateConstantsModified, true)

    if lastDeathCFrame and Toggles.ReturnOnDeath.Value then
        if Profile:FindFirstChild('Checkpoint') then
            awaitEventTimeout(game:GetService('CollectionService').TagRemoved, function(tag)
                return tag == 'Teleporting'
            end, 0.5)
        end
        teleportToCFrame(lastDeathCFrame)
    end
    lastDeathCFrame = nil
end

onHumanoidAdded()

LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    lastDeathCFrame = lastDeathCFrame or HumanoidRootPart.CFrame
    Character = newCharacter
    Humanoid = Character:WaitForChild('Humanoid')
    HumanoidRootPart = Character:WaitForChild('HumanoidRootPart')
    Entity = Character:WaitForChild('Entity', 2)
    if not Entity then
        return fastRespawn()
    end
    Stamina = Entity:WaitForChild('Stamina')
    onHumanoidAdded()
end)

local isDead = function(entity)
    return not (
        entity
        and entity.Parent
        and entity:FindFirstChild('HumanoidRootPart')
        and entity:FindFirstChild('Entity')
        and entity.Entity:FindFirstChild('Health')
        and entity.Entity.Health.Value > 0
        and (
            not entity.Entity:FindFirstChild('HitLives')
            or entity.Entity.HitLives.Value > 0
        )
    )
end

local toggleLerp = (function()
    local lerpToggles = {}
    return function(changedToggle)
        if not (changedToggle and changedToggle.Value) then
            linearVelocity.Parent = nil
            return
        end

        for _, Toggle in next, lerpToggles do
            if Toggle == changedToggle then continue end
            if not Toggle.Value then continue end
            Toggle:SetValue(false)
        end

        lerpToggles[changedToggle] = changedToggle

        linearVelocity.Parent = workspace
    end
end)()

local toggleNoclip = (function()
    local noclipConnection
    local noclipToggles = {}
    return function(changedToggle)
        if changedToggle then
            noclipToggles[changedToggle] = noclipToggles[changedToggle] or changedToggle
        end

        for _, toggle in next, noclipToggles do
            if not toggle.Value then continue end
            if noclipConnection then return end
            noclipConnection = Stepped:Connect(function()
                for _, child in next, Character:GetChildren() do
                    if not child:IsA('BasePart') then continue end
                    child.CanCollide = false
                end
            end)
            return
        end

        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end)()

local waypoint = Instance.new('Part')
waypoint.Anchored = true
waypoint.CanCollide = false
waypoint.Transparency = 1
waypoint.Parent = workspace
local waypointBillboard = Instance.new('BillboardGui')
waypointBillboard.Size = UDim2.new(0, 200, 0, 200)
waypointBillboard.AlwaysOnTop = true
waypointBillboard.Parent = waypoint
local waypointLabel = Instance.new('TextLabel')
waypointLabel.BackgroundTransparency = 1
waypointLabel.Size = waypointBillboard.Size
waypointLabel.Font = Enum.Font.Arial
waypointLabel.TextSize = 16
waypointLabel.TextColor3 = Color3.new(1, 1, 1)
waypointLabel.TextStrokeTransparency = 0
waypointLabel.Text = 'Waypoint position'
waypointLabel.TextWrapped = false
waypointLabel.Parent = waypointBillboard

local controls = { W = 0, S = 0, D = 0, A = 0 }

UserInputService.InputBegan:Connect(function(key, gameProcessed)
    if gameProcessed or not controls[key.KeyCode.Name] then return end
    controls[key.KeyCode.Name] = 1
end)

UserInputService.InputEnded:Connect(function(key, gameProcessed)
    if gameProcessed or not controls[key.KeyCode.Name] then return end
    controls[key.KeyCode.Name] = 0
end)

local verticalRatio, horizontalRatio = 4, 1
local diagonalRatio = math.sqrt(verticalRatio ^ 2 + horizontalRatio ^ 2)
verticalRatio /= diagonalRatio
horizontalRatio /= diagonalRatio

Autofarm:AddToggle('Autofarm', { Text = 'Enabled' }):OnChanged(function()
    toggleLerp(Toggles.Autofarm)
    toggleNoclip(Toggles.Autofarm)
    local targetRefreshTick, target = 0, nil
    while Toggles.Autofarm.Value do
        local deltaTime = task.wait()

        if not (Humanoid.Health > 0) then continue end

        if not (controls.D - controls.A == 0 and controls.S - controls.W == 0) then
            local flySpeed = 80 -- math.max(Humanoid.WalkSpeed, 60)
            local targetPosition = Camera.CFrame.Rotation
                * Vector3.new(controls.D - controls.A, 0, controls.S - controls.W)
                * flySpeed * deltaTime
            HumanoidRootPart.CFrame += targetPosition
                * math.clamp(deltaTime * flySpeed / targetPosition.Magnitude, 0, 1)
            continue
        end

        if tick() - targetRefreshTick > 0.15 then
            target = nil
            local autofarmRadius = Options.AutofarmRadius.Value == 0 and math.huge or Options.AutofarmRadius.Value
            local distance = autofarmRadius
            local prioritizedDistance = distance
            for _, mob in next, Mobs:GetChildren() do
                if Options.IgnoreMobs.Value[mob.Name] then continue end
                if isDead(mob) then continue end
                if Toggles.UseWaypoint.Value and (mob.HumanoidRootPart.Position - waypoint.Position).Magnitude > autofarmRadius then continue end

                local newDistance = (mob.HumanoidRootPart.Position - HumanoidRootPart.Position).Magnitude
                if Options.PrioritizeMobs.Value[mob.Name] then
                    if newDistance < prioritizedDistance then
                        prioritizedDistance = newDistance
                        target = mob
                    end
                elseif not (target and Options.PrioritizeMobs.Value[target.Name]) then
                    if newDistance < distance then
                        distance = newDistance
                        target = mob
                    end
                end
            end
            targetRefreshTick = tick()
        end

        if not target then
            if not Toggles.UseWaypoint.Value then continue end
        elseif target ~= waypoint and isDead(target) or Options.IgnoreMobs.Value[target.Name] then
            targetRefreshTick = 0
            continue
        end

        local targetHumanoidRootPart = target and target.HumanoidRootPart or Toggles.UseWaypoint.Value and waypoint
        if not targetHumanoidRootPart then continue end

        local targetCFrame = targetHumanoidRootPart.CFrame
        local targetSize = targetHumanoidRootPart.Size

        local boundingRadius = math.sqrt(targetSize.X ^ 2 + targetSize.Z ^ 2) / 2
            + ((KillauraSkill.Active or Toggles.UseSkillPreemptively.Value) and 29 or 14)

        local verticalOffset = Options.AutofarmVerticalOffset.Value
        local horizontalOffset = Options.AutofarmHorizontalOffset.Value

        -- local yIsMax = verticalOffset == Options.AutofarmVerticalOffset.Max
        -- local yIsMin = verticalOffset == Options.AutofarmVerticalOffset.Min
        -- local xIsMax = horizontalOffset == Options.AutofarmHorizontalOffset.Max

        -- verticalOffset = math.clamp(verticalOffset, -boundingRadius, boundingRadius)
        -- horizontalOffset = math.clamp(horizontalOffset, -boundingRadius, boundingRadius)

        if verticalOffset == Options.AutofarmVerticalOffset.Max then
            if horizontalOffset == Options.AutofarmHorizontalOffset.Max then
                verticalOffset = boundingRadius * verticalRatio
                horizontalOffset = boundingRadius * horizontalRatio
            else
                local root = math.sqrt(boundingRadius ^ 2 - horizontalOffset ^ 2)
                verticalOffset = root == root and root or 0
            end
        elseif verticalOffset == Options.AutofarmVerticalOffset.Min then
            local minYOffset = -targetSize.Y / 2 - 2.9
            HumanoidRootPart.CFrame = CFrame.Angles(0, 0, math.pi) + HumanoidRootPart.CFrame.Position
            if horizontalOffset == Options.AutofarmHorizontalOffset.Max then
                verticalOffset = minYOffset
                horizontalOffset = math.sqrt(boundingRadius ^ 2 - verticalOffset ^ 2)
            else
                local root = -math.sqrt(boundingRadius ^ 2 - horizontalOffset ^ 2)
                verticalOffset = math.max(root == root and root or 0, minYOffset)
            end
        elseif horizontalOffset == Options.AutofarmHorizontalOffset.Max then
            horizontalOffset = math.sqrt(boundingRadius ^ 2 - verticalOffset ^ 2)
        end

        local targetPosition = targetCFrame.Position + Vector3.new(0, verticalOffset, 0)
        -- if targetHumanoidRootPart:FindFirstChild('BodyVelocity') then
        --     targetPosition += targetHumanoidRootPart.BodyVelocity.VectorVelocity * LocalPlayer:GetNetworkPing()
        -- end

        if horizontalOffset > 0 then
            local difference = HumanoidRootPart.CFrame.Position - targetCFrame.Position
            local horizontalDifference = Vector3.new(difference.X, 0, difference.Z)
            if horizontalDifference.Magnitude ~= 0 then
                targetPosition += horizontalDifference.Unit * horizontalOffset
            end
        end

        local difference = targetPosition - HumanoidRootPart.CFrame.Position
        local distance = difference.Magnitude

        if Options.AutofarmSpeed.Value == 0 then
            HumanoidRootPart.CFrame *= CFrame.Angles(0, math.pi / 4, 0)
        end

        local horizontalDifference = Vector3.new(difference.X, 0, difference.Z)
        if Options.TeleportThreshold.Value == 0 then
            if horizontalDifference.Magnitude > boundingRadius + 15 then
                teleportToCFrame(HumanoidRootPart.CFrame.Rotation + targetPosition)
                continue
            end
        elseif horizontalDifference.Magnitude > Options.TeleportThreshold.Value then
            teleportToCFrame(HumanoidRootPart.CFrame.Rotation + targetPosition)
            continue
        end

        difference = targetPosition - HumanoidRootPart.CFrame.Position
        distance = difference.Magnitude

        if distance == 0 then continue end

        HumanoidRootPart.CFrame += Vector3.new(0, targetPosition.Y - HumanoidRootPart.CFrame.Position.Y, 0)

        horizontalDifference = Vector3.new(difference.X, 0, difference.Z)
        local horizontalDistance = horizontalDifference.Magnitude
        if horizontalDistance == 0 then continue end

        local direction = horizontalDifference.Unit
        local speed = Options.AutofarmSpeed.Value
        speed = speed == 0 and math.huge or speed
        local alpha = math.clamp(deltaTime * speed / horizontalDistance, 0, 1)

        HumanoidRootPart.CFrame += direction * distance * alpha
    end
end)

Autofarm:AddSlider('AutofarmSpeed', { Text = 'Speed (0 = infinite = buggy)', Default = 100, Min = 0, Max = 300, Rounding = 0, Suffix = 'mps' })
Autofarm:AddSlider('TeleportThreshold', { Text = 'Teleport threshold (0 = auto)', Default = 0, Min = 0, Max = 1000, Rounding = 0, Suffix = 'm' })
Autofarm:AddSlider('AutofarmVerticalOffset', { Text = 'Vertical offset (min/max = auto)', Default = 60, Min = -20, Max = 60, Rounding = 1, Suffix = 'm' })
Autofarm:AddSlider('AutofarmHorizontalOffset', { Text = 'Horizontal offset (max = auto)', Default = 40, Min = 0, Max = 40, Rounding = 1, Suffix = 'm' })
Autofarm:AddSlider('AutofarmRadius', { Text = 'Radius (0 = infinite)', Default = 0, Min = 0, Max = 20000, Rounding = 0, Suffix = 'm' })
Autofarm:AddToggle('UseWaypoint', { Text = 'Use waypoint' }):OnChanged(function(value)
    waypoint.CFrame = HumanoidRootPart.CFrame
    waypointLabel.Visible = value
end)

local mobList = (function()
    if RequiredServices then
        local mobList = {}
        local MobDataCache = RequiredServices.StatsUI.MobDataCache
        if type(MobDataCache) ~= 'table' then
            MobDataCache = {}
        end
        for mobName, _ in next, MobDataCache do
            table.insert(mobList, mobName)
        end
        table.sort(mobList, function(mobName1, mobName2)
            return MobDataCache[mobName1].HealthValue > MobDataCache[mobName2].HealthValue
        end)
        return mobList
    end

    return ({
        [540240728] = { -- Arcadia
            'Tremor',
            'Iris Dominus Dummy',
            'Dywane',
            'Nightmare Kobold Lord',
            'Platemail',
            'Statue',
            'Dummy'
        },
        [542351431] = { -- Floor 1 / Virhst Woodlands
            'Tremor',
            'Rahjin the Thief King',
            'Ruined Kobold Lord',
            'Dire Wolf',
            'Dementor',
            'Ruined Kobold Knight',
            'Ruin Kobold Knight',
            'Ruin Knight',
            'Draconite',
            'Bear',
            'Earthen Crab',
            'Earthen Boar',
            'Wolf',
            'Hermit Crab',
            'Frenzy Boar',
            'Item Crystal',
            'Iron Chest',
            'Wood Chest'
        },
        [737272595] = { -- Battle Arena
            'Tremor'
        },
        [548231754] = { -- Floor 2 / Redveil Grove
            'Tremor',
            'Gorrock the Grove Protector',
            'Borik the BeeKeeper',
            'Pearl Guardian',
            'Redthorn Tortoise',
            'Bushback Tortoise',
            'Giant Ruins Hornet',
            'Wasp',
            'Pearl Keeper',
            'Leafray',
            'Leaf Ogre',
            'Leaf Beetle',
            'Dementor',
            'Iron Chest',
            'Wood Chest'
        },
        [555980327] = { -- Floor 3 / Avalanche Expanse
            'Tremor',
            `Ra'thae the Ice King`,
            'Qerach the Forgotten Golem',
            'Alpha Icewhal',
            'Ice Elemental',
            'Ice Walker',
            'Icewhal',
            'Angry Snowman',
            'Snowhorse',
            'Snowgre',
            'Dementor',
            'Iron Chest',
            'Wood Chest'
        },
        [572487908] = { -- Floor 4 / Hidden Wilds
            'Tremor',
            'Irath the Lion',
            'Rotling',
            'Lion Protector',
            'Dungeon Dweller',
            'Bamboo Spider',
            'Boneling',
            'Birchman',
            'Treeray Old',
            'Treeray',
            'Bamboo Spiderling',
            'Treehorse',
            'Wattlechin Crocodile',
            'Dementor',
            'Ancient Chest',
            'Gold Chest',
            'Iron Chest',
            'Wood Chest'
        },
        [580239979] = { -- Floor 5 / Desolate Dunes
            'Tremor',
            `Sa'jun the Centurian Chieftain`,
            'Fire Scorpion',
            'Centaurian Defender',
            'Patrolman Elite',
            'Sand Scorpion',
            'Giant Centipede',
            'Green Patrolman',
            'Desert Vulture',
            'Angry Cactus',
            'Girdled Lizard',
            'Dementor',
            'Gold Chest',
            'Iron Chest',
            'Wood Chest'
        },
        [566212942] = { -- Floor 6 / Helmfirth
            'Tremor',
            'Rekindled Unborn'
        },
        [582198062] = { -- Floor 7 / Entoloma Gloomlands
            'Tremor',
            'Smashroom the Mushroom Behemoth',
            'Frogazoid',
            'Snapper',
            'Blightmouth',
            'Horned Sailfin Iguana',
            'Gloom Shroom',
            'Shroom Back Clam',
            'Firefly',
            'Jelly Wisp',
            'Dementor',
            'Gold Chest',
            'Iron Chest'
        },
        [548878321] = { -- Floor 8 / Blooming Plateau
            'Tremor',
            'Formaug the Jungle Giant',
            'Hippogriff',
            'Dungeon Crusader',
            'Wingless Hippogriff',
            'Forest Wanderer',
            'Sky Raven',
            'Leaf Rhino',
            'Petal Knight',
            'Giant Praying Mantis',
            'Dementor',
            'Gold Chest',
            'Iron Chest'
        },
        [573267292] = { -- Floor 9 / Va' Rok
            'Tremor',
            'Mortis the Flaming Sear',
            'Polyserpant',
            'Gargoyle Reaper',
            'Ent',
            'Undead Berserker',
            'Reptasaurus',
            'Undead Warrior',
            'Enraged Lingerer',
            'Fishrock Spider',
            'Lingerer',
            'Batting Eye',
            'Dementor',
            'Gold Chest',
            'Iron Chest'
        },
        [2659143505] = { -- Floor 10 / Transylvania
            'Tremor',
            'Grim, The Overseer',
            'Baal, The Tormentor',
            'Undead Servant',
            'Wendigo',
            'Clay Giant',
            'Guard Hound',
            'Grunt',
            'Winged Minion',
            'Shady Villager',
            'Minion',
            'Dementor',
            'Gold Chest',
            'Iron Chest'
        },
        [5287433115] = { -- Floor 11 / Hypersiddia
            'Tremor',
            'Saurus, the All-Seeing',
            'Za, the Eldest',
            'Da, the Demeanor',
            'Duality Reaper',
            'Duality Reaper (Old)',
            'Ka, the Mischief',
            'Ra, the Enlightener',
            'Neon Chest',
            'Wa, the Curious',
            'Meta Figure',
            'Rogue Android',
            '???????',
            'Shadow Figure',
            'DJ Reaper',
            'Armageddon Eagle',
            'Elite Reaper',
            'Watcher',
            'Command Falcon',
            'Soul Eater',
            'Reaper',
            'Sentry',
            'Dementor',
            'OG Duality Reaper',
            'OG Za, the Eldest',
            'Cybold',
            'Diamond Chest'
        },
        [6144637080] = { -- Floor 12 / Sector-235
            'Tremor',
            'Suspended Unborn',
            'Limor The Devourer',
            'Warlord',
            'Radioactive Experiment',
            'Ancient Wood Chest',
            'C-618 Uriotol, The Forgotten Hunter',
            'Bat',
            'Elite Scav',
            'Newborn Abomination',
            'Scav',
            'Radio Slug',
            'Crystal Lizard',
            'Orange Failed Experiment',
            'Failed Experiment',
            'Blue Failed Experiment',
            'Dementor',
            'Ancient Chest'
        },
        [13965775911] = { -- Atheon
            'Tremor',
            'Atheon',
            'Dementor'
        },
        [16810524216] = { -- Floor 12.5 / Eternal Garden
            'Azeis, Spirit of the Eternal Blossom',
            'Tworz, The Ancient',
            'Tremor',
            'Eternal Blossom Knight',
            'Ancient Blossom Knight',
            'Dementor'
        },
        [18729767954] = { -- Floor 12.5 / Glutton's Lair
            'Tremor',
            'Ramseis, Chef of Souls',
            'Meatball Abomination',
            'The Waiter',
            'Jelly Slime',
            'Rapapouillie',
            'Burger Mimic',
            'Cheese-Dip Slime',
            'Dementor'
        },
        [11331145451] = { -- Event Floor / Spooky Hollow
            'Tremor',
            'Tremor (Old)',
            'Terror Incarnate',
            'Enraged Wendigo',
            'Count Dracula, Vlad Tepes',
            'Watcher',
            'Cursed Giant',
            'Crumbling Gargoyle',
            'Rotten Brute',
            'Decayed Warrior',
            'Dark Spirit',
            'Abyssal Spider',
            'Vampiric Bat',
            'Dementor'
        },
        [15716179871] = { -- Event Floor / Frosty Fields
            'Tremor',
            'Vyroth, The Frostflame',
            'Ghost of the Future',
            'Krampus',
            'Kloff, Marauder of the Frost',
            'Ghost of the Present',
            'Ghost of the Past',
            'Rat',
            'Frostgre',
            'Icy Imp',
            'Dark Frost Goblin',
            'Crystalite',
            'Gemulite',
            'Glacius Howler',
            'Icy Snowman',
            'Dementor'
        }
    })[game.PlaceId] or {}
end)()

-- Autofarm:AddButton({ Text = 'Copy moblist', Func = function()
--     if #mobList == 0 then
--         return setclipboard(`[{game.PlaceId}] = \{\}`)
--     end
--     setclipboard(`[{game.PlaceId}] = \{\n'{table.concat(mobList, `',\n'`)}'\n\}`)
-- end })

Autofarm:AddDropdown('PrioritizeMobs', { Text = 'Prioritize mobs', Values = mobList, Multi = true, AllowNull = true })
Autofarm:AddDropdown('IgnoreMobs', { Text = 'Ignore mobs', Values = mobList, Multi = true, AllowNull = true })

Autofarm:AddToggle('DisableOnDeath', { Text = 'Disable on death' })

animateFunction = (function()
    if not getconnections then return end
    for _, connection in next, getconnections(Stepped) do
        local func = connection.Function
        if func and debug.info(func, 's'):find('Animate') then
            return func
        end
    end
end)()

local Autowalk = Farming:AddTab('Autowalk')

Autowalk:AddToggle('Autowalk', { Text = 'Enabled' }):OnChanged(function()
    toggleLerp(Toggles.Autowalk)
    linearVelocity.Parent = nil
    local path, waypoints = game:GetService('PathfindingService'):CreatePath({ AgentRadius = 3, AgentHeight = 6 }), {}
    local targetRefreshTick, target = 0, false
    while Toggles.Autowalk.Value do
        task.wait()

        if not (Humanoid.Health > 0) then continue end

        if not (controls.D - controls.A == 0 and controls.S - controls.W == 0) then
            setWalkingAnimation(false)
            continue
        end

        if tick() - targetRefreshTick > 0.15 then
            target = nil
            local radius = Options.AutofarmRadius.Value == 0 and math.huge or Options.AutofarmRadius.Value
            local distance = radius
            local prioritizedDistance = distance
            for _, mob in next, Mobs:GetChildren() do
                if Options.IgnoreMobs.Value[mob.Name] then continue end
                if isDead(mob) then continue end
                if Toggles.UseWaypoint.Value and (mob.HumanoidRootPart.Position - waypoint.Position).Magnitude > radius then continue end

                local newDistance = (mob.HumanoidRootPart.Position - HumanoidRootPart.Position).Magnitude
                if Options.PrioritizeMobs.Value[mob.Name] then
                    if newDistance < prioritizedDistance then
                        prioritizedDistance = newDistance
                        target = mob
                    end
                elseif not (target and Options.PrioritizeMobs.Value[target.Name]) then
                    if newDistance < distance then
                        distance = newDistance
                        target = mob
                    end
                end
            end

            waypointIndex = 1
            waypoints = {}

            if target then
                local targetHumanoidRootPart = target.HumanoidRootPart
                local targetPosition = targetHumanoidRootPart.CFrame.Position
                if targetHumanoidRootPart:FindFirstChild('BodyVelocity') then
                    targetPosition += targetHumanoidRootPart.BodyVelocity.VectorVelocity * LocalPlayer:GetNetworkPing()
                end

                local horizontalOffset = Options.AutowalkHorizontalOffset.Value

                local myPosition = HumanoidRootPart.CFrame.Position

                if horizontalOffset == Options.AutowalkHorizontalOffset.Max then
                    local targetSize = targetHumanoidRootPart.Size
                    local boundingRadius = math.sqrt(targetSize.X ^ 2 + targetSize.Z ^ 2) / 2
                        + ((KillauraSkill.Active or Toggles.UseSkillPreemptively.Value) and 29 or 14)
                    local targetY, myY = targetPosition.Y, myPosition.Y
                    local verticalOffset = targetY > myY and targetY - myY or myY - targetY
                    horizontalOffset = math.sqrt(boundingRadius ^ 2 - verticalOffset ^ 2)
                end

                if horizontalOffset > 0 then
                    local difference = myPosition - targetPosition
                    difference -= Vector3.new(0, difference.Y, 0)
                    if difference.Magnitude ~= 0 then
                        targetPosition += difference.Unit * horizontalOffset
                    end
                end

                waypoints = { HumanoidRootPart.CFrame, { Position = targetPosition } }

                if Toggles.Pathfind.Value then
                    path:ComputeAsync(myPosition, targetPosition)
                    if path.Status == Enum.PathStatus.Success then
                        waypoints = path:GetWaypoints()
                    end
                end
            end

            targetRefreshTick = tick()
        end

        if not target then
            setWalkingAnimation(false)
            continue
        end

        if isDead(target) or Options.IgnoreMobs.Value[target.Name] then
            setWalkingAnimation(false)
            targetRefreshTick = 0
            continue
        end

        setWalkingAnimation(waypoints[waypointIndex + 1])

        if waypoints[waypointIndex + 1] then
            Humanoid:MoveTo(waypoints[waypointIndex + 1].Position)
        end
    end
    setWalkingAnimation(false)
end)

Autowalk:AddToggle('Pathfind', { Text = 'Pathfind', Default = true })
Autowalk:AddSlider('AutowalkHorizontalOffset', { Text = 'Horizontal offset (max = auto)', Default = 40, Min = 0, Max = 40, Rounding = 1, Suffix = 'm' })
Autowalk:AddLabel('Remaining settings in Autofarm')

local Killaura = Main:AddRightGroupbox('Killaura')

local getItemById = function(id)
    if id == 0 then return end
    for _, item in next, Inventory:GetChildren() do
        if item.Value == id then
            return item
        end
    end
end

local getItemStat = (function()
    local maxUpgrades = {
        Common = 10,
        Uncommon = 10,
        Rare = 15,
        Legendary = 20,
        Tribute = 20,
        Burst = 25
    }

    local maxUpgradeMultipliers = {
        [10] = 0.4,
        [15] = 0.6,
        [20] = 1,
        [25] = 1.5
    }

    return function(item)
        local itemInDatabase = Items[item.Name]

        local Stats = itemInDatabase:FindFirstChild('Stats')
        if not Stats then return end

        local Stat = Stats:FindFirstChild('Damage') or Stats:FindFirstChild('Defense')
        if not Stat then return end

        local baseStat = Stat.Value

        local ScaleByLevel = itemInDatabase:FindFirstChild('ScaleByLevel')
        if ScaleByLevel then
            baseStat = baseStat * ScaleByLevel.Value * getLevel()
        end

        local Upgrade = item:FindFirstChild('Upgrade') and item.Upgrade.Value or 0
        if Upgrade == 0 then
            return baseStat
        end

        local Rarity = itemInDatabase.Rarity.Value

        local maxUpgrade = maxUpgrades[Rarity]

        local maxUpgradeAmount = 0.4

        if Stat.Name == 'Damage' then
            maxUpgradeAmount = maxUpgradeMultipliers[maxUpgrade]

            if Stats:FindFirstChild('DamageUpgrade') then
                maxUpgradeAmount = Stats.DamageUpgrade.Value or maxUpgradeAmount
            end
        end

        return math.floor(baseStat + (maxUpgrade and Upgrade / maxUpgrade * maxUpgradeAmount * baseStat or 0))
    end
end)()

local rightSword = getItemById(Equip.Right.Value)
local leftSword = getItemById(Equip.Left.Value)

KillauraSkill = {
    Active = false,
    OnCooldown = false,
    LastHit = false
}

KillauraSkill.GetSword = function(class)
    class = class or KillauraSkill.Class
    if rightSword and Items[rightSword.Name].Class.Value == class then
        KillauraSkill.Sword = rightSword
        return rightSword
    elseif KillauraSkill.Sword and KillauraSkill.Sword.Parent and Items[KillauraSkill.Sword.Name].Class.Value == class then
        return KillauraSkill.Sword
    end
    for _, item in next, Inventory:GetChildren() do
        local itemInDatabase = Items[item.Name]
        if itemInDatabase.Type.Value == 'Weapon' and itemInDatabase.Class.Value == class then
            KillauraSkill.Sword = item
            return item
        end
    end
end

local swordDamage = 0
local updateSwordDamage = function()
    if leftSword then
        swordDamage = math.floor(getItemStat(rightSword) * 0.6 + getItemStat(leftSword) * 0.4)
    elseif rightSword then
        swordDamage = getItemStat(rightSword)
    else
        swordDamage = 0
    end
end

updateSwordDamage()

Equip.Right.Changed:Connect(function(id)
    rightSword = getItemById(id)
    updateSwordDamage()
end)

Equip.Left.Changed:Connect(function(id)
    leftSword = getItemById(id)
    updateSwordDamage()
end)

local getKillauraThreads = (function()
    local skillMultipliers = {
        ['Sweeping Strike'] = 3,
        ['Leaping Slash'] = 3.3,
        ['Summon Pistol'] = 4.35,
        ['Meteor Shot'] = 3.1
    }

    local skillBaseDamages = {
        ['Summon Pistol'] = 35000,
        ['Meteor Shot'] = 55000
    }

    return function(entity)
        if not entity.Health:FindFirstChild(LocalPlayer.Name) then
            return 1
        end

        if Options.KillauraThreads.Value ~= 0 then
            return Options.KillauraThreads.Value
        end

        if KillauraSkill.LastHit then
            return 3
        end

        if entity:FindFirstChild('HitLives') and entity.HitLives.Value <= 3 then
            return entity.HitLives.Value
        end

        local damage = swordDamage

        if KillauraSkill.Name and KillauraSkill.Active then
            damage = swordDamage * skillMultipliers[KillauraSkill.Name]
            damage = math.max(damage, skillBaseDamages[KillauraSkill.Name] or 0)
        end

        if entity:FindFirstChild('MaxDamagePercent') then
            local maxDamage = entity.Health.MaxValue * entity.MaxDamagePercent.Value / 100
            damage = math.min(damage, maxDamage)
        end

        local hitsLeft = math.ceil(entity.Health.Value / damage)
        if hitsLeft <= 3 then
            return hitsLeft
        end

        return 1
    end
end)()

local onCooldown = {}

local useSkill = function(skill)
    if not (Humanoid.Health > 0) then return end
    if not skill.Name then return end
    if skill.OnCooldown then return end
    if skill.Cost > Stamina.Value then return end

    skill.OnCooldown = true
    skill.Active = true

    if not skill.Class then
        Event:FireServer('Skills', { 'UseSkill', skill.Name })
    elseif skill.GetSword() then
        if skill.Sword == rightSword and not leftSword then
            Event:FireServer('Skills', { 'UseSkill', skill.Name })
        else
            local rightSwordOld = rightSword
            local leftSwordOld = leftSword
            InvokeFunction('Equipment', { 'EquipWeapon', { Name = 'Steel Katana', Value = skill.Sword.Value }, 'Right' })
            Event:FireServer('Skills', { 'UseSkill', skill.Name })
            if rightSwordOld then
                local staminaOld = Stamina.Value
                awaitEventTimeout(Stamina.Changed, function(value)
                    if staminaOld - value == skill.Cost then
                        return true
                    end
                    staminaOld = value
                end, 0.1)
                InvokeFunction('Equipment', { 'EquipWeapon', { Name = 'Steel Longsword', Value = rightSwordOld.Value }, 'Right' })
                if leftSwordOld then
                    InvokeFunction('Equipment', { 'EquipWeapon', { Name = 'Steel Longsword', Value = leftSwordOld.Value }, 'Left' })
                end
            end
        end
    else
        Library:Notify(`Get a {skill.Class:lower()} first`)
        Options.SkillToUse:SetValue()
    end

    task.spawn(function()
        task.wait(2.39)
        skill.LastHit = true
        task.wait(0.61)
        skill.LastHit = false
        skill.Active = false
        if Toggles.ResetOnLowStamina.Value and Stamina.Value < KillauraSkill.Cost then
            fastRespawn()
        end
        if skill.Name == 'Summon Pistol' then
            task.wait(1)
        elseif skill.Name == 'Meteor Shot' then
            task.wait(12)
        end
        skill.OnCooldown = false
    end)
end

local dealDamage = (function()
    if RequiredServices then
        return RequiredServices.Combat.DealDamage
    end

    local RPCKey = Function:InvokeServer('RPCKey', {})
    return function(target, attackName)
        Event:FireServer('Combat', RPCKey, { 'Attack', target, attackName, '2' })
    end
end)()

local attack = function(target)
    if isDead(target) then return end

    if Toggles.UseSkillPreemptively.Value or target.Entity.Health:FindFirstChild(LocalPlayer.Name) then
        useSkill(KillauraSkill)
    end

    if isDead(target) then return end

    local threads = Toggles.InstaKill.Value and 10 or getKillauraThreads(target.Entity)

    for _ = 1, threads do
        dealDamage(target, KillauraSkill.Active and KillauraSkill.Name)
    end

    onCooldown[target] = true
    task.delay(threads * Options.KillauraDelay.Value, function()
        onCooldown[target] = nil
    end)
end

local swingFunction = (function()
    if not getgc then return end
    for _, func in next, getgc() do
        if type(func) == 'function' and debug.info(func, 'n') == 'Swing' then
            return func
        end
    end
end)()

Killaura:AddToggle('Killaura', { Text = 'Enabled' }):OnChanged(function()
    toggleSwingDamage(false)
    while Toggles.Killaura.Value do
        task.wait(0.01)

        if not (Humanoid.Health > 0) then continue end

        for _, target in next, Mobs:GetChildren() do
            if onCooldown[target] then continue end
            if isDead(target) then continue end
            local targetHumanoidRootPart = target.HumanoidRootPart
            if Options.KillauraRange.Value == 0 then
                local targetCFrame = targetHumanoidRootPart.CFrame
                local targetSize = targetHumanoidRootPart.Size
                if (HumanoidRootPart.Position - targetCFrame.Position).Magnitude >
                    math.sqrt(targetSize.X ^ 2 + targetSize.Z ^ 2) / 2
                    + ((KillauraSkill.Active or Toggles.UseSkillPreemptively.Value) and 30 or 15)
                then
                    continue
                elseif HumanoidRootPart.Position.Y < targetCFrame.Y - targetSize.Y / 2 - 3 then
                    continue
                end
            elseif (targetHumanoidRootPart.Position - HumanoidRootPart.Position).Magnitude > Options.KillauraRange.Value then
                continue
            end
            attack(target)
        end

        if Toggles.AttackPlayers.Value then
            for _, player in next, Players:GetPlayers() do
                if player == LocalPlayer then continue end
                if Options.IgnorePlayers.Value[player.Name] then continue end
                local target = player.Character
                if not target then continue end
                if onCooldown[target] then continue end
                if isDead(target) then continue end
                local targetHumanoidRootPart = target.HumanoidRootPart
                if Options.KillauraRange.Value == 0 then
                    local targetCFrame = targetHumanoidRootPart.CFrame
                    local targetSize = targetHumanoidRootPart.Size
                    if (HumanoidRootPart.Position - targetCFrame.Position).Magnitude >
                        math.sqrt(targetSize.X ^ 2 + targetSize.Z ^ 2) / 2
                        + ((KillauraSkill.Active or Toggles.UseSkillPreemptively.Value) and 30 or 15)
                    then
                        continue
                    elseif HumanoidRootPart.Position.Y < targetCFrame.Y - targetSize.Y / 2 - 3 then
                        continue
                    end
                elseif (targetHumanoidRootPart.Position - HumanoidRootPart.Position).Magnitude > Options.KillauraRange.Value then
                    continue
                end
                attack(target)
            end
        end

        if swingFunction then
            -- this is preferred since it ignores the swinging state
            if next(onCooldown) then
                task.spawn(swingFunction)
            end
        elseif RequiredServices then
            if next(onCooldown) then
                task.spawn(RequiredServices.Actions.StartSwing)
            else
                task.spawn(RequiredServices.Actions.StopSwing)
            end
        end
    end
    toggleSwingDamage(true)
end)


Killaura:AddToggle('InstaKill', { Text = 'Insta Kill' })
Killaura:AddSlider('KillauraDelay', { Text = 'Delay (breaks damage under 0.3)', Default = 0.3, Min = 0, Max = 2, Rounding = 2, Suffix = 's' })
Killaura:AddSlider('KillauraThreads', { Text = 'Threads (0 = auto)', Default = 0, Min = 0, Max = 3, Rounding = 0, Suffix = ' attack(s)' })
Killaura:AddSlider('KillauraRange', { Text = 'Range (0 = auto)', Default = 0, Min = 0, Max = 200, Rounding = 0, Suffix = 'm' })
Killaura:AddToggle('AttackPlayers', { Text = 'Attack players' })
Killaura:AddDropdown('IgnorePlayers', { Text = 'Ignore players', Values = {}, Multi = true, SpecialType = 'Player' })

Killaura:AddDropdown('SkillToUse', { Text = 'Skill to use', Default = 1, Values = {}, AllowNull = true })
:OnChanged(function(value)
    if not value then
        KillauraSkill.Class = nil
        KillauraSkill.Name = nil
        KillauraSkill.Cost = 0
        return
    end

    local skillName = value:gsub(' [(].+$', '')
    local skillInDatabase = Skills[skillName]
    local class = skillInDatabase:FindFirstChild('Class') and skillInDatabase.Class.Value
    if class then
        class = class == 'SingleSword' and '1HSword' or class

        if not KillauraSkill.GetSword(class) then
            Library:Notify(`Get a {class} first`)
            return Options.SkillToUse:SetValue()
        end
    end

    KillauraSkill.Class = class
    KillauraSkill.Name = skillName
    KillauraSkill.Cost = skillInDatabase.Cost.Value
end)

if getLevel() >= 21 then
    -- table.insert(Options.SkillToUse.Values, 'Sweeping Strike (x3)')
    table.insert(Options.SkillToUse.Values, 'Leaping Slash (x3.3)')
    Options.SkillToUse:SetValues()
else
    local LevelConnection
    LevelConnection = Level.Changed:Connect(function()
        if getLevel() < 21 then return end
        -- table.insert(Options.SkillToUse.Values, 'Sweeping Strike (x3)')
        table.insert(Options.SkillToUse.Values, 'Leaping Slash (x3.3)')
        Options.SkillToUse:SetValues()
        LevelConnection:Disconnect()
    end)
end

if getLevel() >= 60 and Profile.Skills:FindFirstChild('Summon Pistol') then
    table.insert(Options.SkillToUse.Values, 'Summon Pistol (x4.35) (35k base)')
    Options.SkillToUse:SetValues()
else
    local SkillConnection
    SkillConnection = Profile.Skills.ChildAdded:Connect(function(skill)
        if getLevel() < 60 then return end
        if skill.Name ~= 'Summon Pistol' then return end
        table.insert(Options.SkillToUse.Values, 'Summon Pistol (x4.35) (35k base)')
        Options.SkillToUse:SetValues()
        SkillConnection:Disconnect()
    end)
end

-- if GetLevel() >= 200 and Profile.Skills:FindFirstChild('Meteor Shot') then
--     table.insert(Options.SkillToUse.Values, 'Meteor Shot (x3.1) (55k base)')
--     Options.SkillToUse:SetValues()
-- else
--     local SkillConnection
--     SkillConnection = Profile.Skills.ChildAdded:Connect(function(skill)
--         if GetLevel() < 200 then return end
--         if skill.Name ~= 'Meteor Shot' then return end
--         table.insert(Options.SkillToUse.Values, 'Meteor Shot (x3.1) (55k base)')
--         Options.SkillToUse:SetValues()
--         SkillConnection:Disconnect()
--     end)
-- end

Killaura:AddToggle('UseSkillPreemptively', { Text = 'Use skill preemptively' })

local AdditionalCheats = Main:AddRightGroupbox('Additional cheats')

if RequiredServices then
    local SetSprintingOld = RequiredServices.Actions.SetSprinting
    RequiredServices.Actions.SetSprinting = function(enabled)
        if not Toggles.NoSprintAndRollCost.Value then
            SetSprintingOld(enabled)
            enabled = Humanoid.WalkSpeed ~= Character:GetAttribute('Walkspeed')
        end

        Humanoid.WalkSpeed = enabled and Options.SprintSpeed.Value or 20

        if Toggles.NoSprintAndRollCost.Value then
            RequiredServices.Graphics.DoEffect('Sprint Trail', { Enabled = enabled, Character = Character })
            Event:FireServer('Actions', { 'Sprint', enabled and 'Enabled' or 'Disabled' })
        end
    end

    local rollSkillHandler = RequiredServices.Skills.skillHandlers.Roll
    local rollCost = Skills.Roll.Cost.Value

    AdditionalCheats:AddToggle('NoSprintAndRollCost', { Text = 'No sprint & roll cost' })
    :OnChanged(function(value)
        debug.setconstant(rollSkillHandler, 6, value and '' or 'UseSkill')
        Skills.Roll.Cost.Value = value and 0 or rollCost
    end)

    AdditionalCheats:AddSlider('SprintSpeed', { Text = 'Sprint speed', Default = 27, Min = 27, Max = 100, Rounding = 0, Suffix = 'mps' })
else
    UserInputService.InputEnded:Connect(function(key, gameProcessed)
        if gameProcessed or key.KeyCode.Name ~= Profile.Settings.SprintKey.Value then return end
        Humanoid.WalkSpeed = Options.WalkSpeed.Value
    end)

    AdditionalCheats:AddSlider('WalkSpeed', { Text = 'Walk speed', Default = 20, Min = 20, Max = 100, Rounding = 0, Suffix = 'mps' })
    :OnChanged(function(value)
        Humanoid.WalkSpeed = value
    end)
end

AdditionalCheats:AddToggle('Fly', { Text = 'Fly' }):OnChanged(function()
    toggleLerp(Toggles.Fly)
    while Toggles.Fly.Value do
        local deltaTime = task.wait()
        if not (controls.D - controls.A == 0 and controls.S - controls.W == 0) then
            local flySpeed = 80 -- math.max(Humanoid.WalkSpeed, 60)
            local targetPosition = Camera.CFrame.Rotation
                * Vector3.new(controls.D - controls.A, 0, controls.S - controls.W)
                * flySpeed * deltaTime
            HumanoidRootPart.CFrame += targetPosition
                * math.clamp(deltaTime * flySpeed / targetPosition.Magnitude, 0, 1)
            continue
        end
    end
end)

AdditionalCheats:AddToggle('Noclip', { Text = 'Noclip' }):OnChanged(function()
    toggleNoclip(Toggles.Noclip)
end)

AdditionalCheats:AddToggle('ClickTeleport', { Text = 'Click teleport' }):OnChanged((function()
    local mouse = LocalPlayer:GetMouse()
    local Button1DownConnection
    local teleporting = false
    local onButton1Down = function()
        if not Toggles.ClickTeleport.Value then return end
        if teleporting then return end
        teleporting = true
        teleportToCFrame(HumanoidRootPart.CFrame.Rotation + mouse.Hit.Position)
        -- AwaitEventTimeout(game:GetService('CollectionService').TagRemoved, function(tag)
        --     return tag == 'Teleporting'
        -- end)
        teleporting = false
    end
    return function(value)
        if value then
            if Button1DownConnection then return end
            Button1DownConnection = mouse.Button1Down:Connect(onButton1Down)
        elseif Button1DownConnection then
            Button1DownConnection:Disconnect()
            Button1DownConnection = nil
        end
    end
end)())

local mapTeleports = {}

AdditionalCheats:AddDropdown('MapTeleports', { Text = 'Map teleports', Values = { 'Spawn' }, AllowNull = true }):OnChanged(function(value)
    if not value then return end

    Options.MapTeleports:SetValue()

    if value == 'Spawn' then
        return Event:FireServer('Checkpoints', { 'TeleportToSpawn' })
    end

    firetouchinterest(HumanoidRootPart, mapTeleports[value], 0)
    firetouchinterest(HumanoidRootPart, mapTeleports[value], 1)
end)

task.spawn(function()
    local mapTeleportLabels = ({
        [542351431] = { -- floor 1
            Boss = Vector3.new(-2942.51099, -125.638321, 336.995087),
            Portal = Vector3.new(-2940.8562, -207.597794, 982.687012),
            Miniboss = Vector3.new(139.343933, 225.040985, -132.926147)
        },
        [548231754] = { -- floor 2
            Boss = Vector3.new(-2452.30371, 411.394135, -8925.62598),
            Portal = Vector3.new(-2181.09204, 466.482727, -8955.31055)
        },
        [555980327] = { -- floor 3
            Boss = Vector3.new(448.331146, 4279.3374, -385.050385),
            Portal = Vector3.new(-381.196564, 4184.99902, -327.238312)
        },
        [572487908] = { -- floor 4
            Boss = Vector3.new(-2318.12964, 2280.41992, -514.067749),
            Portal = Vector3.new(-2319.54028, 2091.30078, -106.37648),
            Miniboss = Vector3.new(-1361.35596, 5173.21387, -390.738007)
        },
        [580239979] = { -- floor 5
            Boss = Vector3.new(2189.17822, 1308.125, -121.071182),
            Portal = Vector3.new(2188.29614, 1255.37036, -407.864594)
        },
        [582198062] = { -- floor 7
            Boss = Vector3.new(3347.78955, 800.043884, -804.310425),
            Portal = Vector3.new(3336.35645, 747.824036, -614.307983)
        },
        [548878321] = { -- floor 8
            Boss = Vector3.new(1848.35413, 4110.43945, 7723.38623),
            Portal = Vector3.new(1665.46252, 4094.20312, 7722.29443),
            Miniboss = Vector3.new(-811.7854, 3179.59814, -949.255676)
        },
        [573267292] = { -- floor 9
            Boss = Vector3.new(12241.4648, 461.776215, -3655.09009),
            Portal = Vector3.new(12357.0059, 439.948914, -3470.23218),
            Miniboss = Vector3.new(-255.197311, 3077.04272, -4604.19238),
            ['Second miniboss'] = Vector3.new(1973.94238, 2986.00952, -4486.8125)
        },
        [2659143505] = { -- floor 10
            Boss = Vector3.new(45.494194, 1003.77246, 25432.9902),
            Portal = Vector3.new(110.383698, 940.75531, 24890.9922),
            Miniboss = Vector3.new(-894.185791, 467.646698, 6505.85254)
        },
        [5287433115] = { -- floor 11
            Boss = Vector3.new(4916.49414, 2312.97021, 7762.28955),
            Portal = Vector3.new(5224.18994, 2602.94019, 6438.44678),
            Miniboss = Vector3.new(4801.12695, 1646.30347, 2083.19116),
            ['Za, the Eldest'] = Vector3.new(4001.55908, 421.515015, -3794.19727),
            ['Wa, the Curious'] = Vector3.new(4821.5874, 3226.32788, 5868.81787),
            ['Duality Reaper  '] = Vector3.new(4763.06934, 501.713593, -4344.83838),
            ['Neon chest       '] = Vector3.new(5204.35449, 2294.14502, 5778.00195)
        },
        [6144637080] = { -- floor 12
            ['Suspended Unborn'] = Vector3.new(-5324.62305, 427.934784, 3754.23682),
            ['Limor the Devourer'] = Vector3.new(-1093.02625, -169.141785, 7769.1875),
            ['Radioactive Experiment'] = Vector3.new(-4643.86816, 425.090515, 3782.8252)
        }
    })[game.PlaceId] or {}

    local unstreamedMapTeleports = ({
        [555980327] = { -- floor 3
            Vector3.new(-381, 4185, -327), Vector3.new(448, 4279, -385), Vector3.new(-375, 3938, 502), Vector3.new(1180, 6738, 1675)
        },
        [582198062] = { -- floor 7
            Vector3.new(3336, 748, -614), Vector3.new(3348, 800, -804), Vector3.new(1219, 1084, -274), Vector3.new(1905, 729, -327)
        },
        [5287433115] = { -- floor 11
            Vector3.new(5087, 217, 298), Vector3.new(5144, 1035, 298), Vector3.new(4510, 419, -2418), Vector3.new(3457, 465, -3474), Vector3.new(4632, 155, 950),
            Vector3.new(4629, 138, 1008), Vector3.new(5445, 2587, 6324), Vector3.new(5226, 2356, 6451), Vector3.new(5134, 1630, 2501), Vector3.new(5151, 1953, 4508),
            Vector3.new(5505, 1000, -5552), Vector3.new(4247, 507, -4774), Vector3.new(4977, 118, 1495), Vector3.new(5138, 416, 1676), Vector3.new(10827, 1565, -2375),
            Vector3.new(3633, 1767, 2662), Vector3.new(4208, 369, 939), Vector3.new(1029, 13, 686), Vector3.new(4835, 2543, 5275), Vector3.new(5204, 2294, 5778),
            Vector3.new(6054, 182, 965), Vector3.new(5354, 1001, -5465), Vector3.new(4626, 119, 960), Vector3.new(4617, 138, 1008), Vector3.new(521, 123, 346),
            Vector3.new(1034, 9, -345), Vector3.new(4801, 1646, 2083), Vector3.new(4846, 1640, 2091), Vector3.new(5182, 200, 1227), Vector3.new(5075, 127, 1287),
            Vector3.new(5174, 2035, 5702), Vector3.new(5205, 2259, 5684), Vector3.new(4684, 220, 215), Vector3.new(4476, 1245, -26), Vector3.new(3469, 405, -3555),
            Vector3.new(11911, 1572, -2100), Vector3.new(720, 139, 109), Vector3.new(3194, 1764, 647), Vector3.new(4642, 2337, 5969), Vector3.new(5161, 3230, 6034),
            Vector3.new(5208, 2290, 6370), Vector3.new(4916, 2400, 7751), Vector3.new(4655, 405, -3199), Vector3.new(4690, 462, -3423), Vector3.new(5209, 2350, 5915),
            Vector3.new(5334, 3231, 5589), Vector3.new(5225, 2602, 6434), Vector3.new(4916, 2310, 7764), Vector3.new(5224, 2603, 6438), Vector3.new(4916, 2313, 7762),
            Vector3.new(5542, 1001, -5465), Vector3.new(4565, 405, -2917), Vector3.new(4563, 405, -2621), Vector3.new(4528, 405, -2396), Vector3.new(4982, 2587, 6321),
            Vector3.new(5215, 2356, 6451), Vector3.new(4763, 502, -4345), Vector3.new(5900, 853, -4256), Vector3.new(4822, 3226, 5869), Vector3.new(5292, 3224, 6044),
            Vector3.new(5055, 3224, 5706), Vector3.new(5389, 3224, 5774), Vector3.new(4002, 422, -3794), Vector3.new(2094, 939, -6307)
        },
        [6144637080] = { -- floor 12
            Vector3.new(-182, 178, 6148), Vector3.new(-939, -171, 6885), Vector3.new(-714, 143, 4961), Vector3.new(-418, 183, 5650), Vector3.new(-1093, -169, 7769),
            Vector3.new(-301, -319, 7953), Vector3.new(-2290, 242, 3090), Vector3.new(-3163, 221, 3284), Vector3.new(-4268, 217, 3785), Vector3.new(-4644, 425, 3783),
            Vector3.new(-2446, 49, 4145), Vector3.new(-5325, 428, 3754), Vector3.new(-404, 198, 5562), Vector3.new(-419, 177, 5648)
        }
    })[game.PlaceId] or {}

    for _, position in next, unstreamedMapTeleports do
        LocalPlayer:RequestStreamAroundAsync(position)
    end

    local teleportSystems = {}
    for _, instance in next, workspace:GetChildren() do
        if instance.Name ~= 'TeleportSystem' then continue end
        table.insert(teleportSystems, {})
        for _, part in next, instance:GetChildren() do
            if part.Name ~= 'Part' then continue end
            table.insert(teleportSystems[#teleportSystems], part)
            local locationName = #mapTeleports + 1
            for name, position in next, mapTeleportLabels do
                if part.CFrame.Position ~= position then continue end
                locationName = name
                break
            end
            mapTeleports[locationName] = part
            table.insert(Options.MapTeleports.Values, locationName)
        end
    end

    if game.PlaceId == 6144637080 then -- floor 12
        LocalPlayer:RequestStreamAroundAsync(Vector3.new(-2415.14258, 128.760483, 6343.8584))
        mapTeleports['Atheon'] = workspace:WaitForChild('AtheonPortal')
        table.insert(Options.MapTeleports.Values, 'Atheon')
    end

    table.sort(Options.MapTeleports.Values, function(a, b)
        if type(a) == 'string' then
            if type(b) == 'string' then
                return #a < #b
            else
                return true
            end
        elseif type(b) == 'number' then
            return a < b
        end
    end)

    Options.MapTeleports:SetValues()
end)

AdditionalCheats:AddDropdown('PerformanceBoosters', {
    Text = 'Performance boosters',
    Values = {
        'No damage text',
        'No damage particles',
        'Delete dead mobs',
        'No vel obtained in chat',
        'Disable rendering',
        'Limit FPS'
    },
    Multi = true,
    AllowNull = true
}):OnChanged(function(values)
    RunService:Set3dRenderingEnabled(not values['Disable rendering'])
    if setfpscap then
        setfpscap(values['Limit FPS'] and 15 or UserSettings():GetService('UserGameSettings').FramerateCap)
    end
end)

workspace:WaitForChild('HitEffects').ChildAdded:Connect(function(hitPart)
    if not Options.PerformanceBoosters.Value['No damage particles'] then return end
    task.wait()
    hitPart:Destroy()
end)

if RequiredServices then
    local GraphicsServerEventOld = RequiredServices.Graphics.ServerEvent
    RequiredServices.Graphics.ServerEvent = function(...)
        local args = {...}
        if args[1][1] == 'Damage Text' then
            if Options.PerformanceBoosters.Value['No damage text'] then return end
        elseif args[1][1] == 'KillFade' then
            if Options.PerformanceBoosters.Value['Delete dead mobs'] then
                return args[1][2]:Destroy()
            end
        end
        return GraphicsServerEventOld(...)
    end

    local UIServerEventOld = RequiredServices.UI.ServerEvent
    RequiredServices.UI.ServerEvent = function(...)
        local args = {...}
        if args[1][2] == 'VelObtained' then
            if Options.PerformanceBoosters.Value['No vel obtained in chat'] then return end
        end
        return UIServerEventOld(...)
    end
else
    workspace.ChildAdded:Connect(function(part)
        if not Options.PerformanceBoosters.Value['Damage Text'] then return end
        if part:IsA('Part') then return end
        if not part:WaitForChild('DamageText', 1) then return end
        part:Destroy()
    end)

    Chat.ScrollContent.ChildAdded:Connect(function(frame)
        if not Options.PerformanceBoosters.Value['No vel obtained in chat'] then return end
        if frame.Name ~= 'ChatVelTemplate' then return end
        frame.Visible = false
        frame.Size = UDim2.fromOffset(0, -5)
        frame:GetPropertyChangedSignal('Position'):Wait()
        frame:Destroy()
    end)
end

local Miscs = Main:AddLeftTabbox()

local Misc1 = Miscs:AddTab('Misc')

local AnimPackNames = {}
for _, AnimPack in next, game:GetService('StarterPlayer').StarterCharacterScripts.Animate.Packs:GetChildren() do
    table.insert(AnimPackNames, AnimPack.Name)
end

local getCurrentAnimSetting = function()
    if leftSword then return 'DualWield' end
    local SwordClass = Items[rightSword.Name].Class.Value
    return SwordClass == '1HSword' and 'SingleSword' or SwordClass
end

Misc1:AddDropdown('ChangeAnimationPack', {
    Text = 'Change animation pack',
    Values = AnimPackNames,
    AllowNull = true
}):OnChanged(function(animPackName)
    if not animPackName then return end
    Options.ChangeAnimationPack:SetValue()
    Function:InvokeServer('CashShop', {
        'SetAnimPack', {
            Name = animPackName,
            Value = getCurrentAnimSetting(),
            Parent = AnimPacks
        }
    })
end)

local animPackAnimSettings = {
    Berserker = '2HSword',
    Ninja = 'Katana',
    Noble = 'SingleSword',
    Vigilante = 'DualWield',
    SwissSabre = 'Rapier',
    Swiftstrike = 'Spear'
}

local unownedAnimPacks = {}
for animPackName, swordClass in next, animPackAnimSettings do
    if AnimPacks:FindFirstChild(animPackName) then continue end
    local animPack = Instance.new('StringValue')
    animPack.Name = animPackName
    animPack.Value = swordClass
    unownedAnimPacks[animPackName] = animPack
end

Misc1:AddToggle('UnlockAllAnimationPacks', { Text = 'Unlock all animation packs' }):OnChanged(function(value)
    for _, animPack in next, unownedAnimPacks do
        animPack.Parent = value and AnimPacks or nil
    end
end)

PlayerUI.MainFrame.TabFrames.Settings.AnimPacks.ChildAdded:Connect(function(entry)
    entry.Activated:Connect(function()
        local animPackName = (function()
            for _, item in next, Database.CashShop:GetChildren() do
                if item.Icon.Texture ~= entry.Frame.Icon.Image then continue end
                return item.Name:gsub(' Animation Pack', ''):gsub(' ', '')
            end
        end)()
        if not unownedAnimPacks[animPackName] then return end
        local swordClass = animPackAnimSettings[animPackName]
        -- local animSetting = Profile.AnimSettings[swordClass]
        -- animSetting.Value = animSetting.Value == animPackName and '' or animPackName
        Function:InvokeServer('CashShop', {
            'SetAnimPack', {
                Name = animPackName,
                Value = swordClass,
                Parent = AnimPacks
            }
        })
    end)
end)

local chatPosition = Chat.Position
local chatSize = Chat.Size

Misc1:AddToggle('StretchChat', { Text = 'Stretch chat' }):OnChanged(function(value)
    Chat.Position = value and UDim2.new(0, -8, 1, -9) or chatPosition
    Chat.Size = value and UDim2.fromOffset(600, Camera.ViewportSize.Y - 177) or chatSize
end)

Camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
    if not Toggles.StretchChat.Value then return end
    Chat.Size = UDim2.new(0, 600, 0, Camera.ViewportSize.Y - 177)
end)

local defaultCameraMaxZoomDistance = LocalPlayer.CameraMaxZoomDistance

Misc1:AddToggle('InfiniteZoomDistance', { Text = 'Infinite zoom distance' })
:OnChanged(function(value)
    LocalPlayer.CameraMaxZoomDistance = value and math.huge or defaultCameraMaxZoomDistance
    LocalPlayer.DevCameraOcclusionMode = value and 1 or 0
end)

local Misc2 = Miscs:AddTab('More misc')

local equipBestWeaponAndArmor = function()
    if not (Toggles.EquipBestWeaponAndArmor and Toggles.EquipBestWeaponAndArmor.Value) then return end

    local highestDefense = 0
    local highestDamage = 0
    local bestArmor, bestWeapon

    for _, item in next, Inventory:GetChildren() do
        local itemInDatabase = Items[item.Name]

        if not Toggles.WeaponAndArmorLevelBypass.Value and (
            itemInDatabase:FindFirstChild('Level')
            and itemInDatabase.Level.Value or 0
        ) > getLevel() then
            continue
        end

        local itemType = itemInDatabase.Type.Value

        if itemType == 'Clothing' then
            local defense = getItemStat(item)
            if defense > highestDefense then
                highestDefense = defense
                bestArmor = item
            end
        elseif itemType == 'Weapon' then
            local damage = getItemStat(item)
            if damage > highestDamage then
                highestDamage = damage
                bestWeapon = item
            end
        end
    end

    if bestArmor and Equip.Clothing.Value ~= bestArmor.Value then
        task.spawn(InvokeFunction, 'Equipment', { 'Wear', { Name = 'Black Novice Armor', Value = bestArmor.Value } })
    end

    if bestWeapon and Equip.Right.Value ~= bestWeapon.Value then
        InvokeFunction('Equipment', { 'EquipWeapon', { Name = 'Steel Katana', Value = bestWeapon.Value }, 'Right' })
    end
end

Misc2:AddToggle('WeaponAndArmorLevelBypass', { Text = 'Weapon and armor level bypass' }):OnChanged(equipBestWeaponAndArmor)

if RequiredServices then
    local HasRequiredLevelOld = RequiredServices.InventoryUI.HasRequiredLevel
    RequiredServices.InventoryUI.HasRequiredLevel = function(...)
        if not Toggles.WeaponAndArmorLevelBypass.Value then
            return HasRequiredLevelOld(...)
        end

        local item = ...
        if item.Type.Value == 'Weapon' or item.Type.Value == 'Clothing' then
            return true
        end

        return HasRequiredLevelOld(...)
    end

    local ItemActionOld = RequiredServices.InventoryUI.itemAction
    RequiredServices.InventoryUI.itemAction = function(...)
        if not Toggles.WeaponAndArmorLevelBypass.Value then
            return ItemActionOld(...)
        end

        local itemContainer, action = ...
        if itemContainer.Type == 'Weapon' and (action == 'Equip Right' or action == 'Equip Left') then
            if itemContainer.class == '1HSword' then
                itemContainer.item = {
                    Name = 'Steel Longsword',
                    Value = itemContainer.item.Value
                }
            else
                itemContainer.item = {
                    Name = 'Steel Katana',
                    Value = itemContainer.item.Value
                }
            end
        elseif itemContainer.Type == 'Clothing' and action == 'Wear' then
            itemContainer.item = {
                Name = 'Black Novice Armor',
                Value = itemContainer.item.Value
            }
        end

        return ItemActionOld(...)
    end
end

Misc2:AddToggle('EquipBestWeaponAndArmor', { Text = 'Equip best weapon and armor' }):OnChanged(equipBestWeaponAndArmor)
Inventory.ChildAdded:Connect(equipBestWeaponAndArmor)
Level.Changed:Connect(equipBestWeaponAndArmor)

local resetBindable = Instance.new('BindableEvent')
resetBindable.Event:Connect(fastRespawn)
Misc2:AddToggle('FastRespawns', { Text = 'Fast respawns' }):OnChanged(function(value)
    StarterGui:SetCore('ResetButtonCallback', not value or resetBindable)
end)

Misc2:AddToggle('ReturnOnDeath', { Text = 'Return on death' })
Misc2:AddToggle('ResetOnLowStamina', { Text = 'Reset on low stamina' })

local Misc = Window:AddTab('Misc')

local ItemsBox = Misc:AddLeftGroupbox('Items')

if RequiredServices then
    local UIModule = RequiredServices.UI
    ItemsBox:AddButton({ Text = 'Open upgrade', Func = UIModule.openUpgrade })
    ItemsBox:AddButton({ Text = 'Open dismantle', Func = UIModule.openDismantle })
    ItemsBox:AddButton({ Text = 'Open forge', Func = UIModule.openCrystalForge })
end

local unboxableItems = {}
local unboxableItemNames = {}

local function addUnboxable(item, dontRefreshDropdown)
    if not unboxableItems[item.Name] and Items[item.Name]:FindFirstChild('Unboxable') then
        unboxableItems[item.Name] = item
        table.insert(unboxableItemNames, item.Name)
        if not dontRefreshDropdown then
            Options.UseItem:SetValues()
        end
    end
end

for _, item in Inventory:GetChildren() do
    addUnboxable(item, true)
end

Inventory.ChildAdded:Connect(addUnboxable)
Inventory.ChildRemoved:Connect(function(item)
    if unboxableItems[item.Name] then
        unboxableItems[item.Name] = nil
        table.remove(unboxableItemNames, table.find(unboxableItemNames, item.Name))
        Options.UseItem:SetValues()
    end
end)

ItemsBox:AddDropdown('UseItem', { Text = 'Use item(s)', Values = unboxableItemNames, AllowNull = true })
:OnChanged(function(itemName)
    if not itemName then return end
    Options.UseItem:SetValue()

    local item = unboxableItems[itemName]
    if not item then return end

    for _ = 1, item:FindFirstChild('Count') and item.Count.Value or 1 do
        Event:FireServer('Equipment', { 'UseItem', item })
    end
end)

local PlayersBox = Misc:AddRightGroupbox('Players')

local selectedPlayer

local bypassedViewingProfile = pcall(function()
    local signal = LocalPlayer:GetAttributeChangedSignal('ViewingProfile')
    getconnections(signal)[1]:Disable()
end)

PlayersBox:AddDropdown('PlayerList', { Text = 'Player list', Values = {}, SpecialType = 'Player' })
:OnChanged(function(playerName)
    selectedPlayer = playerName and Players[playerName]

    if bypassedViewingProfile and Toggles.ViewPlayersInventory and Toggles.ViewPlayersInventory.Value then
        LocalPlayer:SetAttribute('ViewingProfile', playerName)
    end
end)

PlayersBox:AddButton({ Text = "View player's stats", Func = function()
    if not Options.PlayerList.Value then return end

    pcall(function()
        local profile = Profiles:FindFirstChild(selectedPlayer.Name)

        if profile.Locations:FindFirstChild('1') then
            profile.Locations['1']:Destroy()
        end

        local stats = {
            AnimPacks = 'no',
            Gamepasses = 'no',
            Skills = 'no'
        }

        for statName, _ in next, stats do
            local statChildrenNames = {}
            for _, stat in next, profile[statName]:GetChildren() do
                table.insert(statChildrenNames, stat.Name)
            end
            if #statChildrenNames > 0 then
                stats[statName] = 'the ' .. table.concat(statChildrenNames, ', '):lower()
            end
        end

		Library:Notify(
			`{selectedPlayer.Name}'s account is {selectedPlayer.AccountAge} days old,\n`
				.. `level {getLevel(profile.Stats.Exp.Value)},\n`
				.. `has {profile.Stats.Vel.Value} vel,\n`
				.. `floor {#profile.Locations:GetChildren() - 2},\n`
				.. `{stats.AnimPacks} animation packs bought,\n`
				.. `{stats.Gamepasses} gamepasses bought,\n`
				.. `and {stats.Skills} special skills unlocked`,
			10
		)
    end)
end })

if bypassedViewingProfile then
    PlayersBox:AddToggle('ViewPlayersInventory', { Text = `View player's inventory` }):OnChanged(function(value)
        value = value and Options.PlayerList.Value or nil
        if LocalPlayer:GetAttribute('ViewingProfile') ~= value then
            LocalPlayer:SetAttribute('ViewingProfile', value)
        end
    end)
end

PlayersBox:AddToggle('ViewPlayer', { Text = 'View player' }):OnChanged(function(value)
    if not value then return end
    while Toggles.ViewPlayer.Value do
        if selectedPlayer and not isDead(selectedPlayer.Character) then
            Camera.CameraSubject = selectedPlayer.Character
        end
        task.wait(0.1)
    end
    Camera.CameraSubject = Character
end)

PlayersBox:AddToggle('GoToPlayer', { Text = 'Go to player' }):OnChanged(function(value)
    toggleLerp(Toggles.GoToPlayer)
    toggleNoclip(Toggles.GoToPlayer)
    if not value then return end
    while Toggles.GoToPlayer.Value do
        task.wait()

        if not selectedPlayer or isDead(selectedPlayer.Character) then continue end

        local targetHumanoidRootPart = selectedPlayer.Character.HumanoidRootPart
        local targetCFrame = targetHumanoidRootPart.CFrame +
            Vector3.new(Options.XOffset.Value, Options.YOffset.Value, Options.ZOffset.Value)

        local difference = targetCFrame.Position - HumanoidRootPart.CFrame.Position

        local horizontalDifference = Vector3.new(difference.X, 0, difference.Z)
        if horizontalDifference.Magnitude > 70 then
            teleportToCFrame(targetCFrame)
            continue
        end

        HumanoidRootPart.CFrame = targetCFrame
    end
end)

PlayersBox:AddSlider('XOffset', { Text = 'X offset', Default = 0, Min = -20, Max = 20, Rounding = 0 })
PlayersBox:AddSlider('YOffset', { Text = 'Y offset', Default = 5, Min = -20, Max = 20, Rounding = 0 })
PlayersBox:AddSlider('ZOffset', { Text = 'Z offset', Default = 0, Min = -20, Max = 20, Rounding = 0 })

local Drops = Misc:AddLeftGroupbox('Drops')

local Rarities = { 'Common', 'Uncommon', 'Rare', 'Legendary', 'Tribute' }

Drops:AddDropdown('AutoDismantle', { Text = 'Auto dismantle', Values = Rarities, Multi = true, AllowNull = true })

Drops:AddInput('DropWebhook', { Text = 'Drop webhook', Placeholder = 'https://discord.com/api/webhooks/' })
:OnChanged(sendTestMessage)

Drops:AddToggle('PingInMessage', { Text = 'Ping in message' })

Drops:AddDropdown('RaritiesForWebhook', { Text = 'Rarities for webhook', Values = Rarities, Default = Rarities, Multi = true, AllowNull = true })

local dropList = {}

Drops:AddDropdown('DropList', { Text = 'Drop list (select to dismantle)', Values = {}, AllowNull = true })
:OnChanged(function(dropName)
    if not dropName then return end
    Options.DropList:SetValue()
    Event:FireServer('Equipment', { 'Dismantle', { dropList[dropName] } })
    dropList[dropName] = nil
    table.remove(Options.DropList.Values, table.find(Options.DropList.Values, dropName))
end)

local rarityColors = {
    Empty = Color3.fromRGB(127, 127, 127),
    Common = Color3.fromRGB(255, 255, 255),
    Uncommon = Color3.fromRGB(64, 255, 102),
    Rare = Color3.fromRGB(25, 182, 255),
    Legendary = Color3.fromRGB(240, 69, 255),
    Tribute = Color3.fromRGB(255, 208, 98),
    Burst = Color3.fromRGB(81, 0, 1),
    Error = Color3.fromRGB(255, 255, 255)
}

Inventory.ChildAdded:Connect(function(item)
    local itemInDatabase = Items[item.Name]

    if item.Name:find('Novice') or item.Name:find('Aura') then return end

    local rarity = itemInDatabase.Rarity.Value

    if Options.AutoDismantle.Value[rarity] then
        return Event:FireServer('Equipment', { 'Dismantle', { item } })
    end

    if not Options.RaritiesForWebhook.Value[rarity] then return end

    local FormattedItem = os.date('[%I:%M:%S] ') .. item.Name
    dropList[FormattedItem] = item
    table.insert(Options.DropList.Values, 1, FormattedItem)
    Options.DropList:SetValues()
    sendWebhook(Options.DropWebhook.Value, {
        embeds = {{
            title = `You received {item.Name}!`,
            color = tonumber('0x' .. rarityColors[rarity]:ToHex()),
            fields = {
                {
                    name = 'User',
                    value = `||[{LocalPlayer.Name}](https://www.roblox.com/users/{LocalPlayer.UserId})||`,
                    inline = true
                }, {
                    name = 'Game',
                    value = `[{MarketplaceService:GetProductInfo(game.PlaceId).Name}](https://www.roblox.com/games/{game.PlaceId})`,
                    inline = true
                }, {
                    name = 'Item Stats',
                    value = `[Level {(itemInDatabase:FindFirstChild('Level') and itemInDatabase.Level.Value or 0)} {rarity}]`
                        .. `(https://swordburst2.fandom.com/wiki/{string.gsub(item.Name, ' ', '_')})`,
                    inline = true
                }
            }
        }}
    }, Toggles.PingInMessage.Value)
end)

local ownedSkillNames = {}

for _, skill in next, Profile.Skills:GetChildren() do
    table.insert(ownedSkillNames, skill.Name)
end

Profile.Skills.ChildAdded:Connect(function(skill)
    if table.find(ownedSkillNames, skill.Name) then return end
    table.insert(ownedSkillNames, skill.Name)

    local skillInDatabase = Skills[skill.Name]
    sendWebhook(Options.DropWebhook.Value, {
        embeds = {{
            title = `You received {skill.Name}!`,
            color = tonumber('0x' .. rarityColors.Burst:ToHex()),
            fields = {
                {
                    name = 'User',
                    value = `||[{LocalPlayer.Name}](https://www.roblox.com/users/{LocalPlayer.UserId})||`,
                    inline = true
                }, {
                    name = 'Game',
                    value = `[{MarketplaceService:GetProductInfo(game.PlaceId).Name}](https://www.roblox.com/games/{game.PlaceId})`,
                    inline = true
                }, {
                    name = 'Skill Stats',
                    value = `[Level {(skillInDatabase:FindFirstChild('Level') and skillInDatabase.Level.Value or 0)}]`
                        .. `(https://swordburst2.fandom.com/wiki/{string.gsub(skill.Name, ' ', '_')})`,
                    inline = true
                }
            }
        }}
    }, Toggles.PingInMessage.Value)
end)

local LevelsAndVelGained = Drops:AddLabel()

local levelsGained, velGained = 0, 0
local levelOld, velOld = getLevel(), Vel.Value

local UpdateLevelAndVel = function()
    local levelNew, velNew = getLevel(), Vel.Value
    levelsGained += levelNew > levelOld and levelNew - levelOld or 0
    velGained += velNew > velOld and velNew - velOld or 0
    LevelsAndVelGained:SetText(`{levelsGained} levels | {velGained} vel gained`)
    levelOld, velOld = levelNew, velNew
end

UpdateLevelAndVel()
Vel.Changed:Connect(UpdateLevelAndVel)
Level.Changed:Connect(UpdateLevelAndVel)

local KickBox = Misc:AddLeftTabbox()

local ModDetector = KickBox:AddTab('Mods')

local mods = {
    12671,
    4402987,
    7858636,
    13444058,
    24156180,
    35311411,
    38559058,
    45035796,
    48662268,
    50879012,
    51696441,
    55715138,
    57436909,
    59341698,
    60673083,
    62240513,
    66489540,
    68210875,
    72480719,
    75043989,
    76999375,
    81113783,
    90258662,
    93988508,
    101291900,
    102706901,
    104541778,
    109105759,
    111051084,
    121104177,
    129806297,
    151751026,
    154847513,
    154876159,
    161577703,
    161949719,
    163733925,
    167655046,
    167856414,
    173116569,
    184366742,
    194755784,
    220726786,
    225179429,
    269112100,
    271388254,
    309775741,
    349854657,
    354326302,
    357870914,
    358748060,
    367879806,
    371108489,
    373676463,
    429690599,
    434696913,
    440458342,
    448343431,
    454205259,
    455293249,
    461121215,
    478848349,
    500009807,
    533787513,
    542470517,
    571218846,
    575623917,
    630696850,
    810458354,
    852819491,
    874771971,
    918971121,
    1033291447,
    1033291716,
    1058240421,
    1099119770,
    1114937945,
    1190978597,
    1266604023,
    1379309318,
    1390415574,
    1416070243,
    1584345084,
    1607227678,
    1648776562,
    1650372835,
    1666720713,
    1728535349,
    1785469599,
    1794965093,
    1801714748,
    1868318363,
    1998442044,
    2034822362,
    2216826820,
    2324028828,
    2462374233,
    2787915712,
    1255771814,
    360470140,
    2475151189,
    3522932153,
    3772282131,
    7557087747
}

ModDetector:AddToggle('Autokick', { Text = 'Autokick' })
ModDetector:AddSlider('KickDelay', { Text = 'Kick delay', Default = 30, Min = 0, Max = 60, Rounding = 0, Suffix = 's', Compact = true })
ModDetector:AddToggle('Autopanic', { Text = 'Autopanic' })
ModDetector:AddSlider('PanicDelay', { Text = 'Panic delay', Default = 15, Min = 0, Max = 60, Rounding = 0, Suffix = 's', Compact = true })

local modCheck = function(player, leaving)
    if player == LocalPlayer or not table.find(mods, player.UserId) then return end
    Library:Notify(`Mod {player.Name} {leaving and 'left' or 'joined'} your game at {os.date('%I:%M:%S %p')}`, 60)

    if leaving then return end

    StarterGui:SetCore('PromptBlockPlayer', player)

    task.delay(Options.KickDelay.Value, function()
        if Toggles.Autokick.Value then
            LocalPlayer:Kick(`\n\n{player.Name} joined at {os.date('%I:%M:%S %p')}\n`)
        end
    end)

    task.delay(Options.PanicDelay.Value, function()
        if Toggles.Autopanic.Value then
            toggleLerp()
            Toggles.Killaura:SetValue(false)
            Event:FireServer('Checkpoints', { 'TeleportToSpawn' })
        end
    end)
end

for _, player in next, Players:GetPlayers() do
    task.spawn(modCheck, player)
end

Players.PlayerAdded:Connect(modCheck)

Players.PlayerRemoving:Connect(function(player)
    modCheck(player, true)
end)

local checkingModsIngame
ModDetector:AddButton({ Text = `Mods in game (don't use at spawn)`, Func = function()
    if checkingModsIngame then return end
    checkingModsIngame = {}
    Library:Notify('Checking profiles...')
    local counter = 0
    for _, userId in next, mods do
        task.spawn(function()
            local response = InvokeFunction('Teleport', { 'FriendTeleport', userId })
            if not response then return end

            if response:find('!$') and not response:find('error') then
                table.insert(checkingModsIngame, Players:GetNameFromUserIdAsync(userId))
            end

            counter += 1
            if counter ~= #mods then return end

            if #checkingModsIngame > 0 then
                Library:Notify('The mods that are currently in-game are: \n' .. table.concat(checkingModsIngame, ', \n'), 10)
            else
                Library:Notify('There are no mods in game')
            end

            checkingModsIngame = nil
        end)
    end
end })

local FarmingKicks = KickBox:AddTab('Kicks')

Level.Changed:Connect(function()
    local currentLevel = getLevel()
    if not (Toggles.LevelKick.Value and currentLevel == Options.KickLevel.Value) then return end
    LocalPlayer:Kick(`\n\nYou got to level {currentLevel} at {os.date('%I:%M:%S %p')}\n`)
end)

FarmingKicks:AddToggle('LevelKick', { Text = 'Level kick' })
FarmingKicks:AddSlider('KickLevel', { Text = 'Kick level', Default = 130, Min = 0, Max = 400, Rounding = 0, Compact = true })

Profile.Skills.ChildAdded:Connect(function(skill)
    if not Toggles.SkillKick.Value then return end
    LocalPlayer:Kick(`\n\n{skill.Name} acquired at {os.date('%I:%M:%S %p')}\n`)
end)

FarmingKicks:AddToggle('SkillKick', { Text = 'Skill kick' })

FarmingKicks:AddInput('KickWebhook', { Text = 'Kick webhook', Finished = true, Placeholder = 'https://discord.com/api/webhooks/' })
:OnChanged(function()
    sendTestMessage(Options.KickWebhook.Value)
end)

game:GetService('GuiService').ErrorMessageChanged:Connect(function(message)
    local Body = {
        embeds = {{
            title = 'You were kicked!',
            color = tonumber('0x' .. rarityColors.Error:ToHex()),
            fields = {
                {
                    name = 'User',
                    value = `||[{LocalPlayer.Name}](https://www.roblox.com/users/{LocalPlayer.UserId})||`,
                    inline = true
                }, {
                    name = 'Game',
                    value = `[{MarketplaceService:GetProductInfo(game.PlaceId).Name}](https://www.roblox.com/games/{game.PlaceId})`,
                    inline = true
                }, {
                    name = 'Message',
                    value = message,
                    inline = true
                },
            }
        }}
    }

    sendWebhook(Options.KickWebhook.Value, Body, Toggles.PingInMessage.Value)
end)

local SwingCheats = Misc:AddRightGroupbox('Swing cheats (can break damage)')

if RequiredServices then
    local Actions = RequiredServices.Actions
    local StopSwingOld = Actions.StopSwing

    SwingCheats:AddToggle('Autoswing', { Text = 'Autoswing' }):OnChanged(function(value)
        if value then
            Actions.StopSwing = function() end
            Actions.StartSwing()
        else
            Actions.StopSwing = StopSwingOld
            StopSwingOld()
        end
    end)

    local AttackRequestOld = RequiredServices.Combat.AttackRequest
    RequiredServices.Combat.AttackRequest = function(...)
        local args = {...}
        if Toggles.OverrideBurstState.Value then
            debug.setupvalue(args[3], 2, Options.BurstState.Value)
        end
        return AttackRequestOld(...)
    end

    SwingCheats:AddToggle('OverrideBurstState', { Text = 'Override burst state' })
    SwingCheats:AddSlider('BurstState', { Text = 'Burst state', Default = 0, Min = 0, Max = 10, Rounding = 0, Suffix = ' hits', Compact = true })

    SwingCheats:AddDivider()
end

if swingFunction then
    SwingCheats:AddSlider('SwingDelay', { Text = 'Swing delay', Default = 0.55, Min = 0.25, Max = 0.85, Rounding = 2, Suffix = 's' })
    :OnChanged(function()
        debug.setconstant(swingFunction, 13, Options.SwingDelay.Value)
    end)

    SwingCheats:AddSlider('BurstDelayReduction', { Text = 'Burst delay reduction', Default = 0.2, Min = 0, Max = 0.4, Rounding = 2, Suffix = 's' })
    :OnChanged(function()
        debug.setconstant(swingFunction, 14, Options.BurstDelayReduction.Value)
    end)

    SwingCheats:AddDivider()
end

if RequiredServices then
    SwingCheats:AddSlider('SwingThreads', { Text = 'Threads', Default = 1, Min = 1, Max = 3, Rounding = 0, Suffix = ' attack(s)' })

    RequiredServices.Combat.DealDamage = function(target, attackName)
        if Toggles.Killaura.Value or onCooldown[target] then return end

        for _ = 1, Options.SwingThreads.Value do
            dealDamage(target, attackName)
        end

        onCooldown[target] = true
        task.delay(Options.SwingThreads.Value * 0.25, function()
            onCooldown[target] = nil
        end)
    end
end

local inTrade = Instance.new('BoolValue')
local tradeLastSent = 0

local Crystals = Window:AddTab('Crystals')

local Trading = Crystals:AddLeftGroupbox('Trading')
Trading:AddDropdown('TargetAccount', { Text = 'Target account', Values = {}, SpecialType = 'Player' })
:OnChanged(function()
    tradeLastSent = 0
end)

local CrystalCounter
CrystalCounter = {
    Given = {
        Value = 0,
        ThisCycle = 0,
        Label = Trading:AddLabel(),
        Update = function()
            CrystalCounter.Given.Label:SetText(
                `{CrystalCounter.Given.Value} ({math.floor(CrystalCounter.Given.Value / 64 * 10 ^ 5) / 10 ^ 5} stacks) given`
            )
        end
    },
    Received = {
        Value = 0,
        Label = Trading:AddLabel(),
        Update = function()
            CrystalCounter.Received.Label:SetText(
                `{CrystalCounter.Received.Value} ({math.floor(CrystalCounter.Received.Value / 64 * 10 ^ 5) / 10 ^ 5} stacks) received`
            )
        end
    }
}

CrystalCounter.Given.Update()
CrystalCounter.Received.Update()

Trading:AddButton({ Text = 'Reset counter', Func = function()
        CrystalCounter.Given.Value = 0
        CrystalCounter.Received.Value = 0
        CrystalCounter.Given.Update()
        CrystalCounter.Received.Update()
end })

local Giving = Crystals:AddRightGroupbox('Giving')

Giving:AddToggle('SendTrades', { Text = 'Send trades', Default = false }):OnChanged(function()
    CrystalCounter.Given.ThisCycle = 0
    while Toggles.SendTrades.Value do
        local target = Options.TargetAccount.Value and Players:FindFirstChild(Options.TargetAccount.Value)
        if target and not inTrade.Value and tick() - tradeLastSent >= 0.5 then
            tradeLastSent = InvokeFunction('Trade', 'Request', { target }) and tick() or tick() - 0.4
        end
        task.wait()
    end
end)

Giving:AddInput('CrystalAmount', { Text = 'Crystal amount', Numeric = true, Finished = true, Placeholder = 1 })
:OnChanged(function(value)
    Options.CrystalAmount.Value = tonumber(value) or 1
end)

Giving:AddButton({ Text = 'Convert stacks to crystals', Func = function()
    Options.CrystalAmount:SetValue(math.ceil(Options.CrystalAmount.Value * 64))
end })

Giving:AddDropdown('CrystalType', { Text = 'Crystal type', Values = Rarities, AllowNull = true })
:OnChanged(function(crystalType)
    if not crystalType then return end
    Options.CrystalType:SetValue()
    if Inventory:FindFirstChild(crystalType .. ' Upgrade Crystal') then return end
    Library:Notify(`You need to have at least 1 {crystalType:lower()} upgrade crystal`)
end)

Giving:AddButton({
    Text = 'Add crystals to trade',
    Func = function()
        if not Options.CrystalType.Value then
            return Library:Notify('Select the crystal type first')
        end

        local item = Inventory:FindFirstChild(Options.CrystalType.Value .. ' Upgrade Crystal')

        if not item then
            return Library:Notify(`You need to have at least 1 {Options.CrystalType.Value:lower()} upgrade crystal`)
        end

        for value = 1, item:FindFirstChild('Count') and item.Count.Value or 1 do
            Event:FireServer('Trade', 'TradeAddItem', { item })
            if value == Options.AmountToAdd.Value then break end
        end
    end
})

Giving:AddSlider('AmountToAdd', { Text = 'Amount to add', Default = 128, Min = 0, Max = 128, Rounding = 0, Compact = true })

local Receiving = Crystals:AddRightGroupbox('Receiving')

Receiving:AddToggle('AcceptTrades', {
    Text = 'Accept trades',
    Default = false
})

inTrade.Changed:Connect(function(enteredTrade)
    if not enteredTrade then return end
    if not Toggles.SendTrades.Value then return end
    if not Options.CrystalType.Value then
        return Library:Notify('Select the crystal type first')
    end

    local item = Inventory:FindFirstChild(Options.CrystalType.Value .. ' Upgrade Crystal')

    if not item then
        Library:Notify(`You need to have at least 1 {Options.CrystalType.Value:lower()} upgrade crystal`)
        return Toggles.SendTrades:SetValue(false)
    end

    for _ = 1, (item:FindFirstChild('Count') and math.min(128, item.Count.Value, Options.CrystalAmount.Value - CrystalCounter.Given.ThisCycle) or 1) do
        Event:FireServer('Trade', 'TradeAddItem', { item })
    end

    Event:FireServer('Trade', 'TradeConfirm', {})
    Event:FireServer('Trade', 'TradeAccept', {})
end)

local lastTradeChange
Event.OnClientEvent:Connect(function(...)
    local args = {...}
    if not (args[1] == 'UI' and args[2][1] == 'Trade') then return end
    if args[2][2] == 'Request' then
        if not (Toggles.AcceptTrades.Value or Toggles.SendTrades.Value) then return end
        if Options.TargetAccount.Value == args[2][3].Name then
            Event:FireServer('Trade', 'RequestAccept', {})
            inTrade.Value = true
        else
            Event:FireServer('Trade', 'RequestDecline', {})
        end
    elseif args[2][2] == 'TradeChanged' then
        lastTradeChange = args[2][3]
        if not (Toggles.AcceptTrades.Value or Toggles.SendTrades.Value) then return end
        local targetRole = lastTradeChange.Requester == LocalPlayer and 'Partner' or 'Requester'
        local ourRole = targetRole == 'Partner' and 'Requester' or 'Partner'
        if not (lastTradeChange[targetRole .. 'Confirmed'] and not lastTradeChange[ourRole .. 'Accepted']) then return end
        Event:FireServer('Trade', 'TradeConfirm', {})
        Event:FireServer('Trade', 'TradeAccept', {})
    elseif args[2][2] == 'RequestAccept' then
        inTrade.Value = true
    elseif args[2][2] == 'RequestDecline' then
        tradeLastSent = 0
    elseif args[2][2] == 'TradeCompleted' then
        local targetRole = lastTradeChange.Requester == LocalPlayer and 'Partner' or 'Requester'
        local ourRole = targetRole == 'Partner' and 'Requester' or 'Partner'
        for _, itemData in next, lastTradeChange[targetRole .. 'Items'] do
            if not itemData.item.Name:find('Upgrade Crystal') then continue end
            CrystalCounter.Received.Value += 1
        end
        CrystalCounter.Received.Update()
        for _, itemData in next, lastTradeChange[ourRole .. 'Items'] do
            if not itemData.item.Name:find('Upgrade Crystal') then continue end
            CrystalCounter.Given.Value += 1
            if not Toggles.SendTrades.Value then continue end
            CrystalCounter.Given.ThisCycle += 1
            if CrystalCounter.Given.ThisCycle ~= Options.CrystalAmount.Value then continue end
            Toggles.SendTrades:SetValue(false)
        end
        CrystalCounter.Given.Update()
        inTrade.Value = false
    elseif args[2][2] == 'TradeCancel' then
        inTrade.Value = false
    end
end)

local Settings = Window:AddTab('Settings')

local Menu = Settings:AddLeftGroupbox('Menu')

Menu:AddLabel('Menu keybind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true })

Library.ToggleKeybind = Options.MenuKeybind

local ThemeManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/Neuublue/Bluu/main/LinoriaLib/addons/ThemeManager.lua'))()
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder('Bluu/Swordburst 2')
ThemeManager:ApplyToTab(Settings)

local SaveManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/Neuublue/Bluu/main/LinoriaLib/addons/SaveManager.lua'))()
SaveManager:SetLibrary(Library)
SaveManager:SetFolder('Bluu/Swordburst 2')
SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(Settings)
SaveManager:LoadAutoloadConfig()

local Credits = Settings:AddRightGroupbox('Credits')

Credits:AddLabel('de_Neuublue - Script')
Credits:AddLabel('Inori - UI library')
Credits:AddLabel('wally - UI addons')
