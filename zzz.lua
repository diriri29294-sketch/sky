local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer
local Remotes = RS:WaitForChild("Remotes", 10)
local ShootGun = Remotes and Remotes:FindFirstChild("ShootGun")
local Stab = Remotes and Remotes:FindFirstChild("Stab")
local ThrowStart = Remotes and Remotes:FindFirstChild("ThrowStart")
local ThrowHit = Remotes and Remotes:FindFirstChild("ThrowHit")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "MVSD | 살인자 대 보안관",
    LoadingTitle = "로딩중...",
    LoadingSubtitle = "하늘은 나의편",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local Config = {
    ESP = true,
    SilentAim = false,
    Trigger = false,
    Reach = false,
    InstantThrow = false,
    Speed = false,
    Jump = false,
    AntiAfk = true,
}
local REACH = 9
local lastShot, lastStab = 0, 0
local highlights = {}

local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "MVSD_ESP"
ESPFolder.Parent = CoreGui

local function headOrigin(char)
    local head = char and char:FindFirstChild("Head")
    if not head then return nil end
    return (head.CFrame * CFrame.new(0, head.Size.Y/2, head.Size.Z/2)).Position
end

local function myMatch() return lp:GetAttribute("Match") end

local function isGun(tool)
    if not tool:IsA("Tool") then return false end
    return CollectionService:HasTag(tool, "GunTool") or tool.Name:lower():find("gun") or tool.Name:lower():find("revolver")
end

local function isKnife(tool)
    if not tool:IsA("Tool") then return false end
    return CollectionService:HasTag(tool, "KnifeTool") or tool.Name:lower():find("knife") or tool.Name:lower():find("dagger")
end

local function roleOf(pl)
    local ch = pl.Character
    if not ch then return "?" end
    for _, t in ipairs(ch:GetChildren()) do
        if t:IsA("Tool") then
            if isKnife(t) then return "살인자" end
            if isGun(t) then return "보안관" end
        end
    end
    return "?"
end

local function aliveEnemies()
    local myM = myMatch()
    local list = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp and pl:GetAttribute("Match") == myM and myM then
            local ch = pl.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then
                table.insert(list, {pl = pl, char = ch, hum = hum, hrp = hrp})
            end
        end
    end
    return list
end

local function bestTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local camPos, camDir = cam.CFrame.Position, cam.CFrame.LookVector
    local best, bestScore
    for _, e in ipairs(aliveEnemies()) do
        local head = e.char:FindFirstChild("Head")
        local point = head and head.Position or e.hrp.Position
        local rel = point - camPos
        local dist = rel.Magnitude
        if dist < 800 then
            local dot = rel.Unit:Dot(camDir)
            if dot > 0.3 and (not bestScore or dot > bestScore) then
                best, bestScore = e, dot
            end
        end
    end
    return best
end

local function getMyTool(checkFunc)
    local ch = lp.Character
    if not ch then return nil end
    for _, t in ipairs(ch:GetChildren()) do
        if t:IsA("Tool") and checkFunc(t) then return t end
    end
    return nil
end

local function shootAt(target)
    if not ShootGun then return end
    local gun = getMyTool(isGun)
    local origin = headOrigin(lp.Character)
    if not gun or not origin then return end
    
    local head = target.char:FindFirstChild("Head")
    local point = head and head.Position or target.hrp.Position
    local cd = tonumber(gun:GetAttribute("Cooldown")) or 0.3
    
    pcall(function()
        ShootGun:FireServer(origin, point, head or target.hrp, point)
    end)
    lastShot = os.clock() + math.max(cd * 0.9, 0.05)
end

RunService.Heartbeat:Connect(function()
    if lp:GetAttribute("Frozen") then return end
    
    if Config.SilentAim or Config.Trigger then
        local target = bestTarget()
        if target then
            if Config.Trigger and os.clock() >= lastShot then
                shootAt(target)
            elseif Config.SilentAim and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and os.clock() >= lastShot then
                shootAt(target)
            end
        end
    end
    
    if Config.Reach and Stab then
        local knife = getMyTool(isKnife)
        if knife and os.clock() >= lastStab then
            local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if myHrp then
                for _, e in ipairs(aliveEnemies()) do
                    if (e.hrp.Position - myHrp.Position).Magnitude <= REACH then
                        local head = e.char:FindFirstChild("Head")
                        pcall(function()
                            knife:Activate()
                            Stab:FireServer(head or e.hrp)
                        end)
                        lastStab = os.clock() + 0.35
                        break
                    end
                end
            end
        end
    end
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.T and Config.InstantThrow and ThrowStart and ThrowHit then
        local knife = getMyTool(isKnife)
        local origin = headOrigin(lp.Character)
        local target = bestTarget()
        if knife and origin and target then
            local head = target.char:FindFirstChild("Head")
            local point = head and head.Position or target.hrp.Position
            local dir = (point - origin).Unit
            pcall(function()
                ThrowStart:FireServer(origin, dir)
                ThrowHit:FireServer(head or target.hrp, point)
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.4) do
        local myM = myMatch()
        for pl, hl in pairs(highlights) do
            local char = pl.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if not Config.ESP or not pl.Parent or not char or not hum or hum.Health <= 0 or (myM and pl:GetAttribute("Match") ~= myM) then
                pcall(function() hl.Box:Destroy() end)
                pcall(function() hl.Tag:Destroy() end)
                highlights[pl] = nil
            end
        end
        
        if Config.ESP then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= lp and pl.Character then
                    local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                    local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                    
                    if hum and hum.Health > 0 and hrp then
                        if myM and pl:GetAttribute("Match") ~= myM then continue end
                        
                        local role = roleOf(pl)
                        if not highlights[pl] then
                            local box = Instance.new("Highlight")
                            box.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            box.FillTransparency = 0.65
                            box.Adornee = pl.Character
                            box.Parent = ESPFolder
                            
                            local tag = Instance.new("BillboardGui")
                            tag.Size = UDim2.new(0, 120, 0, 24)
                            tag.StudsOffset = Vector3.new(0, 3.2, 0)
                            tag.AlwaysOnTop = true
                            tag.Adornee = hrp
                            
                            local tl = Instance.new("TextLabel")
                            tl.Size = UDim2.new(1, 0, 1, 0)
                            tl.BackgroundTransparency = 1
                            tl.Font = Enum.Font.GothamBold
                            tl.TextSize = 13
                            tl.TextStrokeTransparency = 0.2
                            tl.Parent = tag
                            tag.Parent = ESPFolder
                            
                            highlights[pl] = {Box = box, Tag = tag, Label = tl}
                        else
                            highlights[pl].Box.Adornee = pl.Character
                            highlights[pl].Tag.Adornee = hrp
                        end
                        
                        local h = highlights[pl]
                        if h then
                            h.Box.FillColor = role == "살인자" and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 140, 255)
                            h.Box.OutlineColor = Color3.new(1, 1, 1)
                            h.Label.Text = pl.Name .. " [" .. role .. "]"
                            h.Label.TextColor3 = h.Box.FillColor
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.4) do
        local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            if Config.Speed then hum.WalkSpeed = 28 end
            if Config.Jump then hum.UseJumpPower = true; hum.JumpPower = 70 end
        end
    end
end)

lp.Idled:Connect(function()
    if Config.AntiAfk then
        VirtualUser:CaptureController(); VirtualUser:Start2()
        task.wait(1); VirtualUser:Stop2()
    end
end)

local CombatTab = Window:CreateTab("전투", nil)

CombatTab:CreateToggle({ Name = "에임봇 (좌클릭 조준)", CurrentValue = false, Flag = "SilentAim", Callback = function(v) Config.SilentAim = v end })
CombatTab:CreateToggle({ Name = "트리거봇 (보이면 자동 사격)", CurrentValue = false, Flag = "Trigger", Callback = function(v) Config.Trigger = v end })
CombatTab:CreateToggle({ Name = "칼 리치 (자동 찌르기)", CurrentValue = false, Flag = "Reach", Callback = function(v) Config.Reach = v end })
CombatTab:CreateSlider({ Name = "칼 리치 거리", Range = {9, 20}, Increment = 1, Suffix = "스터드", CurrentValue = 9, Flag = "ReachDist", Callback = function(v) REACH = v end })
CombatTab:CreateToggle({ Name = "즉시 투척 (T키)", CurrentValue = false, Flag = "InstantThrow", Callback = function(v) Config.InstantThrow = v end })

local ESPTab = Window:CreateTab("ESP", nil)
ESPTab:CreateToggle({ Name = "ESP 켜기 (역할 표시)", CurrentValue = true, Flag = "ESP", Callback = function(v) Config.ESP = v end })

local MiscTab = Window:CreateTab("설정", nil)
MiscTab:CreateToggle({ Name = "속도핵 (28)", CurrentValue = false, Flag = "Speed", Callback = function(v) Config.Speed = v end })
MiscTab:CreateToggle({ Name = "점프핵 (70)", CurrentValue = false, Flag = "Jump", Callback = function(v) Config.Jump = v end })
MiscTab:CreateToggle({ Name = "안티 AFK", CurrentValue = true, Flag = "AntiAfk", Callback = function(v) Config.AntiAfk = v end })

Rayfield:Notify({
    Title = "MVSD | 로드 완료",
    Content = "하늘이나의편 이 자체제작했습니다.",
    Duration = 4,
})

print("=========================================")
print("하늘의 나의편 이 자체제작했습니다.")
print("=========================================")
