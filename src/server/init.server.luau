local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PromptGenerator = require(ReplicatedStorage:WaitForChild("PromptGenerator"))
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local showPrompt = remotesFolder:FindFirstChild("ShowPrompt")
if not showPrompt then
	showPrompt = Instance.new("RemoteEvent")
	showPrompt.Name = "ShowPrompt"
	showPrompt.Parent = remotesFolder
end

local submitResponse = remotesFolder:FindFirstChild("SubmitResponse")
if not submitResponse then
	submitResponse = Instance.new("RemoteEvent")
	submitResponse.Name = "SubmitResponse"
	submitResponse.Parent = remotesFolder
end

print("Remotes ready")

task.wait(2)

local HttpService = game:GetService("HttpService")

local url = "http://127.0.0.1:8002/prompt?theme=general"

local success, result = pcall(function()
	return HttpService:GetAsync(url)
end)

local prompt = "Failed to load prompt."

if success then
	local data = HttpService:JSONDecode(result)
	prompt = data.prompt or prompt
else
	warn("HTTP failed:", result)
end
showPrompt:FireAllClients(prompt)
print("Prompt sent:", prompt)