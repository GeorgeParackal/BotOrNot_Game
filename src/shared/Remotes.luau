local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

local showPrompt = folder:FindFirstChild("ShowPrompt")
if not showPrompt then
	showPrompt = Instance.new("RemoteEvent")
	showPrompt.Name = "ShowPrompt"
	showPrompt.Parent = folder
end

return folder
