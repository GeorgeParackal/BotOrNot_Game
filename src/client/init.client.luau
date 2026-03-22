local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local function resolveRequestPromptRemote(): RemoteFunction?
	local directRemote = ReplicatedStorage:FindFirstChild("RequestPrompt")
	if directRemote and directRemote:IsA("RemoteFunction") then
		return directRemote
	end

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesFolder then
		local nestedRemote = remotesFolder:FindFirstChild("RequestPrompt")
		if nestedRemote and nestedRemote:IsA("RemoteFunction") then
			return nestedRemote
		end
	end

	local waitedRemote = ReplicatedStorage:WaitForChild("RequestPrompt", 5)
	if waitedRemote and waitedRemote:IsA("RemoteFunction") then
		return waitedRemote
	end

	return nil
end

local requestPromptRemote = resolveRequestPromptRemote()

local function resolveEvaluateAnswerRemote(): RemoteFunction?
	local directRemote = ReplicatedStorage:FindFirstChild("EvaluateAnswer")
	if directRemote and directRemote:IsA("RemoteFunction") then
		return directRemote
	end

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesFolder then
		local nestedRemote = remotesFolder:FindFirstChild("EvaluateAnswer")
		if nestedRemote and nestedRemote:IsA("RemoteFunction") then
			return nestedRemote
		end
	end

	local waitedRemote = ReplicatedStorage:WaitForChild("EvaluateAnswer", 5)
	if waitedRemote and waitedRemote:IsA("RemoteFunction") then
		return waitedRemote
	end

	return nil
end

local evaluateAnswerRemote = resolveEvaluateAnswerRemote()

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
	if not requestPromptRemote then
		return getRandomPrompt()
	end

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
local currentPromptText = ""
local requestVersion = 0
local hasHookedPlayButton = false
local getOrCreatePromptUi: () -> ScreenGui


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
		currentPromptText = promptText
	end)
end

getOrCreatePromptUi = function(): ScreenGui
	if promptGui then
		return promptGui
	end

	promptGui = Instance.new("ScreenGui")
	promptGui.Name = "PromptUi"
	promptGui.ResetOnSpawn = false
	promptGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "PromptPanel"
	panel.Size = UDim2.fromOffset(420, 560)
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
	promptBox.Size = UDim2.new(1, -24, 0, 130)
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

	local answerTitle = Instance.new("TextLabel")
	answerTitle.Name = "AnswerTitle"
	answerTitle.Size = UDim2.new(1, -24, 0, 20)
	answerTitle.Position = UDim2.fromOffset(12, 176)
	answerTitle.BackgroundTransparency = 1
	answerTitle.Text = "Answer"
	answerTitle.TextXAlignment = Enum.TextXAlignment.Left
	answerTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
	answerTitle.TextSize = 14
	answerTitle.Font = Enum.Font.Gotham
	answerTitle.Parent = panel

	local answerBox = Instance.new("TextBox")
	answerBox.Name = "AnswerBox"
	answerBox.Size = UDim2.new(1, -24, 0, 76)
	answerBox.Position = UDim2.fromOffset(12, 202)
	answerBox.BackgroundColor3 = Color3.fromRGB(242, 246, 255)
	answerBox.BorderColor3 = Color3.fromRGB(136, 173, 255)
	answerBox.BorderSizePixel = 2
	answerBox.ClearTextOnFocus = false
	answerBox.MultiLine = true
	answerBox.TextWrapped = true
	answerBox.TextXAlignment = Enum.TextXAlignment.Left
	answerBox.TextYAlignment = Enum.TextYAlignment.Top
	answerBox.PlaceholderText = "Write your answer here..."
	answerBox.PlaceholderColor3 = Color3.fromRGB(96, 105, 132)
	answerBox.Text = ""
	answerBox.TextColor3 = Color3.fromRGB(20, 20, 60)
	answerBox.TextSize = 16
	answerBox.Font = Enum.Font.Gotham
	answerBox.Parent = panel

	local answerBoxCorner = Instance.new("UICorner")
	answerBoxCorner.CornerRadius = UDim.new(0, 10)
	answerBoxCorner.Parent = answerBox

	local submitButton = Instance.new("TextButton")
	submitButton.Name = "SubmitButton"
	submitButton.Size = UDim2.new(1, -24, 0, 40)
	submitButton.Position = UDim2.fromOffset(12, 290)
	submitButton.BackgroundColor3 = Color3.fromRGB(76, 132, 255)
	submitButton.BorderSizePixel = 0
	submitButton.Text = "Submit"
	submitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	submitButton.TextSize = 16
	submitButton.Font = Enum.Font.GothamBold
	submitButton.Parent = panel

	local submitButtonCorner = Instance.new("UICorner")
	submitButtonCorner.CornerRadius = UDim.new(0, 10)
	submitButtonCorner.Parent = submitButton

	local tabBar = Instance.new("Frame")
	tabBar.Name = "ResultsTabs"
	tabBar.Size = UDim2.new(1, -24, 0, 30)
	tabBar.Position = UDim2.fromOffset(12, 334)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = panel

	local overviewTabButton = Instance.new("TextButton")
	overviewTabButton.Name = "OverviewTab"
	overviewTabButton.Size = UDim2.fromOffset(120, 30)
	overviewTabButton.Position = UDim2.fromOffset(0, 0)
	overviewTabButton.BackgroundColor3 = Color3.fromRGB(76, 132, 255)
	overviewTabButton.BorderSizePixel = 0
	overviewTabButton.Text = "Overview"
	overviewTabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	overviewTabButton.TextSize = 14
	overviewTabButton.Font = Enum.Font.GothamBold
	overviewTabButton.Parent = tabBar

	local overviewTabCorner = Instance.new("UICorner")
	overviewTabCorner.CornerRadius = UDim.new(0, 8)
	overviewTabCorner.Parent = overviewTabButton

	local judgesTabButton = Instance.new("TextButton")
	judgesTabButton.Name = "JudgesTab"
	judgesTabButton.Size = UDim2.fromOffset(120, 30)
	judgesTabButton.Position = UDim2.fromOffset(126, 0)
	judgesTabButton.BackgroundColor3 = Color3.fromRGB(46, 54, 74)
	judgesTabButton.BorderSizePixel = 0
	judgesTabButton.Text = "Judges"
	judgesTabButton.TextColor3 = Color3.fromRGB(210, 220, 245)
	judgesTabButton.TextSize = 14
	judgesTabButton.Font = Enum.Font.GothamBold
	judgesTabButton.Parent = tabBar

	local judgesTabCorner = Instance.new("UICorner")
	judgesTabCorner.CornerRadius = UDim.new(0, 8)
	judgesTabCorner.Parent = judgesTabButton

	local analysisLabel = Instance.new("TextLabel")
	analysisLabel.Name = "AnalysisLabel"
	analysisLabel.Size = UDim2.new(1, -24, 0, 190)
	analysisLabel.Position = UDim2.fromOffset(12, 368)
	analysisLabel.BackgroundTransparency = 1
	analysisLabel.Text = ""
	analysisLabel.TextWrapped = true
	analysisLabel.TextXAlignment = Enum.TextXAlignment.Left
	analysisLabel.TextYAlignment = Enum.TextYAlignment.Top
	analysisLabel.TextColor3 = Color3.fromRGB(210, 220, 245)
	analysisLabel.TextSize = 13
	analysisLabel.Font = Enum.Font.Gotham
	analysisLabel.Parent = panel

	local judgesLabel = Instance.new("TextLabel")
	judgesLabel.Name = "JudgesLabel"
	judgesLabel.Size = UDim2.new(1, -24, 0, 190)
	judgesLabel.Position = UDim2.fromOffset(12, 368)
	judgesLabel.BackgroundTransparency = 1
	judgesLabel.Text = ""
	judgesLabel.TextWrapped = true
	judgesLabel.TextXAlignment = Enum.TextXAlignment.Left
	judgesLabel.TextYAlignment = Enum.TextYAlignment.Top
	judgesLabel.TextColor3 = Color3.fromRGB(210, 220, 245)
	judgesLabel.TextSize = 13
	judgesLabel.Font = Enum.Font.Gotham
	judgesLabel.Visible = false
	judgesLabel.Parent = panel

	local function showResultsTab(tabName: string)
		local showJudges = tabName == "judges"
		analysisLabel.Visible = not showJudges
		judgesLabel.Visible = showJudges

		if showJudges then
			overviewTabButton.BackgroundColor3 = Color3.fromRGB(46, 54, 74)
			overviewTabButton.TextColor3 = Color3.fromRGB(210, 220, 245)
			judgesTabButton.BackgroundColor3 = Color3.fromRGB(76, 132, 255)
			judgesTabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			overviewTabButton.BackgroundColor3 = Color3.fromRGB(76, 132, 255)
			overviewTabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			judgesTabButton.BackgroundColor3 = Color3.fromRGB(46, 54, 74)
			judgesTabButton.TextColor3 = Color3.fromRGB(210, 220, 245)
		end
	end

	showResultsTab("overview")

	overviewTabButton.Activated:Connect(function()
		showResultsTab("overview")
	end)

	judgesTabButton.Activated:Connect(function()
		showResultsTab("judges")
	end)

	submitButton.Activated:Connect(function()
		if answerBox.Text == "" then
			submitButton.Text = "Type an answer first"
			task.delay(1.2, function()
				submitButton.Text = "Submit"
			end)
			return
		end

		submitButton.Text = "Analyzing..."
		analysisLabel.Text = ""
		judgesLabel.Text = ""
		showResultsTab("overview")

		task.spawn(function()
			if not evaluateAnswerRemote then
				analysisLabel.Text = "Analysis remote unavailable right now."
				submitButton.Text = "Submit"
				return
			end

			local ok, result = pcall(function()
				return evaluateAnswerRemote:InvokeServer(answerBox.Text, currentPromptText)
			end)

			if not ok or type(result) ~= "table" then
				analysisLabel.Text = "Could not analyze right now. Please try again."
				submitButton.Text = "Submit"
				return
			end

			local percent = result.percent
			local explanation = result.explanation
			local judgeMessages = result.judge_messages

			if type(percent) ~= "number" then
				percent = 0
			end

			if type(explanation) ~= "string" or explanation == "" then
				explanation = "No explanation returned."
			end

			local sections = {
				"Your Answer:\n" .. answerBox.Text,
				"\nAI generated likelihood: " .. tostring(math.floor(percent + 0.5)) .. "%",
				"Reason: " .. explanation,
			}

			local judgeSections = {}
			local bubbleMessages = {}

			if type(judgeMessages) == "table" then
				for index, rawJudge in ipairs(judgeMessages) do
					if type(rawJudge) == "table" then
						local judgeName = rawJudge.name
						local judgeRating = rawJudge.rating
						local judgeResponse = rawJudge.response

						if type(judgeName) ~= "string" or judgeName == "" then
							judgeName = "Judge " .. tostring(index)
						end

						if type(judgeResponse) == "string" and judgeResponse ~= "" then
							local ratingText = "N/A"
							if type(judgeRating) == "number" then
								ratingText = tostring(math.floor(judgeRating + 0.5)) .. "%"
							end

							table.insert(judgeSections, "[" .. judgeName .. "] Rating: " .. ratingText .. "\n" .. judgeResponse)
							table.insert(bubbleMessages, {
								name = judgeName,
								response = judgeResponse,
							})
						end
					elseif type(rawJudge) == "string" and rawJudge ~= "" then
						table.insert(judgeSections, "[Judge " .. tostring(index) .. "]\n" .. rawJudge)
						table.insert(bubbleMessages, rawJudge)
					end
				end
			end

			analysisLabel.Text = table.concat(sections, "\n")
			if #judgeSections > 0 then
				judgesLabel.Text = table.concat(judgeSections, "\n\n")
			else
				judgesLabel.Text = "No judge feedback returned."
			end

			submitButton.Text = "Submit"
		end)
	end)

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
	warn("No Play button found to hook. Prompt UI will stay hidden until manually triggered.")
end
