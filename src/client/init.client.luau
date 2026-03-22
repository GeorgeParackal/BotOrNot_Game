local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local requestPromptRemote = ReplicatedStorage:WaitForChild("RequestPrompt") :: RemoteFunction

local rng = Random.new()

local prompts = {
	"Tell a story about a lost robot.",
	"Design a game level in one sentence.",
	"Name three powers for a new hero.",
	"Write a spooky message in five words.",
	"Pitch a movie idea in ten words.",
	"Invent a gadget for rainy days.",
}

local function getRandomPrompt(): string
	local index = rng:NextInteger(1, #prompts)
	return prompts[index]
end

local function getPromptFromServer(): string
	local ok, result = pcall(function()
		return requestPromptRemote:InvokeServer()
	end)

	if ok and type(result) == "string" and result ~= "" then
		return result
	end

	return getRandomPrompt()
end

local promptGui = playerGui:FindFirstChild("PromptUi") :: ScreenGui?
local promptValueLabel: TextLabel? = nil
local requestVersion = 0
local hasHookedPlayButton = false

local function requestAndSetPrompt(promptBox: TextLabel)
	requestVersion += 1
	local currentRequest = requestVersion

	promptBox.Text = "Generating..."

	task.spawn(function()
		-- Let one frame render so the loading text is visible before the network call blocks.
		task.wait()
		local promptText = getPromptFromServer()

		if currentRequest ~= requestVersion then
			return
		end

		promptBox.Text = promptText
	end)
end

local function getOrCreatePromptUi(): ScreenGui
	if promptGui then
		return promptGui
	end

	promptGui = Instance.new("ScreenGui")
	promptGui.Name = "PromptUi"
	promptGui.ResetOnSpawn = false
	promptGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "PromptPanel"
	panel.Size = UDim2.fromOffset(360, 170)
	panel.Position = UDim2.new(0.5, -180, 0.08, 0)
	panel.BackgroundColor3 = Color3.fromRGB(22, 26, 34)
	panel.BorderSizePixel = 0
	panel.Parent = promptGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -24, 0, 20)
	title.Position = UDim2.fromOffset(12, 8)
	title.BackgroundTransparency = 1
	title.Text = "Prompt"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(200, 200, 200)
	title.TextSize = 14
	title.Font = Enum.Font.Gotham
	title.Parent = panel

	local promptBox = Instance.new("TextButton")
	promptBox.Name = "PromptBox"
	promptBox.Size = UDim2.new(1, -24, 1, -44)
	promptBox.Position = UDim2.fromOffset(12, 36)
	promptBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	promptBox.BorderColor3 = Color3.fromRGB(100, 150, 255)
	promptBox.BorderSizePixel = 2
	promptBox.Text = ""
	promptBox.TextWrapped = true
	promptBox.TextColor3 = Color3.fromRGB(20, 20, 60)
	promptBox.TextSize = 18
	promptBox.TextXAlignment = Enum.TextXAlignment.Center
	promptBox.TextYAlignment = Enum.TextYAlignment.Center
	promptBox.Font = Enum.Font.GothamBold
	promptBox.Parent = panel

	local promptBoxCorner = Instance.new("UICorner")
	promptBoxCorner.CornerRadius = UDim.new(0, 10)
	promptBoxCorner.Parent = promptBox

	promptBox.Activated:Connect(function()
		requestAndSetPrompt(promptBox)
	end)

	promptValueLabel = promptBox

	return promptGui
end

local function showPromptUiAndGenerate()
	local ui = getOrCreatePromptUi()
	ui.Enabled = true

	if promptValueLabel then
		requestAndSetPrompt(promptValueLabel)
	end
end

local function isPlayButton(instance: Instance): boolean
	if not instance:IsA("TextButton") then
		return false
	end

	local lowerName = string.lower(instance.Name)
	return lowerName == "play" or lowerName == "playbutton"
end

local function hookPlayButton(button: TextButton)
	if button:GetAttribute("PromptHooked") == true then
		return
	end

	button:SetAttribute("PromptHooked", true)
	hasHookedPlayButton = true

	button.Activated:Connect(function()
		-- Defer so it runs after existing play-handler UI transitions.
		task.defer(showPromptUiAndGenerate)
	end)
end

for _, descendant in playerGui:GetDescendants() do
	if isPlayButton(descendant) then
		hookPlayButton(descendant)
	end
end

playerGui.DescendantAdded:Connect(function(instance)
	if isPlayButton(instance) then
		hookPlayButton(instance)
	end
end)

if not hasHookedPlayButton then
	showPromptUiAndGenerate()
end
