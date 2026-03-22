local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local showPromptEvent = remotesFolder:WaitForChild("ShowPrompt")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PromptUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "PromptFrame"
frame.Size = UDim2.new(0.6, 0, 0.18, 0)
frame.Position = UDim2.new(0.2, 0, 0.05, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "Current Prompt"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local promptLabel = Instance.new("TextLabel")
promptLabel.Name = "PromptLabel"
promptLabel.Size = UDim2.new(1, -20, 1, -50)
promptLabel.Position = UDim2.new(0, 10, 0, 40)
promptLabel.BackgroundTransparency = 1
promptLabel.Text = "Waiting for prompt..."
promptLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
promptLabel.TextWrapped = true
promptLabel.TextScaled = true
promptLabel.Font = Enum.Font.Gotham
promptLabel.Parent = frame

showPromptEvent.OnClientEvent:Connect(function(promptText)
	promptLabel.Text = promptText
end)