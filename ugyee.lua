-- ✅ UI и окна
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Neuublue/UILib/main/main.lua"))()
local Window = Library:CreateWindow("Bluu Hub | Swordburst 2")

local Player = Window:AddTab("Player")
local Misc = Window:AddTab("Misc")
local Main = Window:AddTab("Main")

-- ✅ Кнопки игрока
Player:AddButton("Walkspeed", function()
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 300
end)

Player:AddButton("Jump Power", function()
    game.Players.LocalPlayer.Character.Humanoid.JumpPower = 300
end)

Player:AddButton("Inf Jump", function()
    local InfiniteJumpEnabled = true
    game:GetService("UserInputService").JumpRequest:Connect(function()
        if InfiniteJumpEnabled then
            game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
        end
    end)
end)

Player:AddButton("Noclip", function()
    local noclip = true
    local player = game.Players.LocalPlayer
    local char = player.Character
    game:GetService('RunService').Stepped:Connect(function()
        if noclip then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide == true then
                    v.CanCollide = false
                end
            end
        end
    end)
end)

-- ✅ Основные функции
Main:AddButton("Auto Farm Mobs", function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Neuublue/Bluu/main/SB2Farm"))()
end)

Main:AddButton("Kill Aura", function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Neuublue/Bluu/main/SB2Aura"))()
end)

Main:AddButton("Equip Best Weapon", function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Neuublue/Bluu/main/SB2Best"))()
end)

-- ✅ Анти-АФК
Misc:AddButton("Anti AFK", function()
    local vu = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
        wait(1)
        vu:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    end)
end)

-- 🧨 InstaKill Feature 🧨
local InstaKillTab = Main:AddRightTabbox()
local InstaKillSettings = InstaKillTab:AddTab("InstaKill")

Toggles.InstaKillTouch = InstaKillSettings:AddToggle("InstaKillTouch", {
    Text = "Instakill mobs (touch)",
    Default = false
})

local function setupTouchKill()
    local plr = game.Players.LocalPlayer
    local function connectParts(character)
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Touched:Connect(function(hit)
                    if Toggles.InstaKillTouch.Value then
                        local mob = hit:FindFirstAncestorOfClass("Model")
                        if mob and mob:FindFirstChild("Entity") and mob.Entity:FindFirstChild("Health") then
                            mob.Entity.Health.Value = 0
                        elseif mob and mob:FindFirstChild("Humanoid") then
                            mob.Humanoid.Health = 0
                        end
                    end
                end)
            end
        end
    end

    local character = plr.Character or plr.CharacterAdded:Wait()
    connectParts(character)
    plr.CharacterAdded:Connect(function(char)
        wait(1)
        connectParts(char)
    end)
end

setupTouchKill()
Library:Notify("Script Loaded with InstaKill!", 5)
