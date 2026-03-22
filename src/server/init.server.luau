local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function readGeminiConfig(): string?
	local configModule = script.Parent:FindFirstChild("GeminiConfig")
	if not configModule then
		configModule = script:FindFirstChild("GeminiConfig")
	end

	if not configModule or not configModule:IsA("ModuleScript") then
		warn("GeminiConfig module not found. Using fallback prompts.")
		return nil
	end

	local ok, config = pcall(require, configModule)
	if not ok or type(config) ~= "table" then
		warn("Failed to load GeminiConfig. Using fallback prompts.")
		return nil
	end

	local apiKey = config.GEMINI_API_KEY
	if type(apiKey) ~= "string" or apiKey == "" then
		warn("Gemini API key missing in GeminiConfig. Using fallback prompts.")
		return nil
	end

	return apiKey
end

local GEMINI_API_KEY = readGeminiConfig()

local remoteName = "RequestPrompt"
local requestPromptRemote = ReplicatedStorage:FindFirstChild(remoteName) :: RemoteFunction?
if not requestPromptRemote then
	requestPromptRemote = Instance.new("RemoteFunction")
	requestPromptRemote.Name = remoteName
	requestPromptRemote.Parent = ReplicatedStorage
end

local fallbackPrompts = {
	"What would you do if you had a superpower? Explain why you would choose that power.",
	"If you could travel anywhere in the world, where would you go? What would you do there?",
	"What is something you are really good at? How did you get good at it?",
	"If you could have any job when you grow up, what would it be? Why does it interest you?",
	"What is your favorite book, movie, or video game? What do you like most about it?",
	"If you could invite anyone from history to dinner, who would it be? What would you ask them?",
	"What hobby or activity makes you happiest? How long have you been doing it?",
	"If you could change one thing about the world, what would it be? How would you fix it?",
	"What is a skill you want to learn? Why are you interested in learning it?",
	"Who is someone you admire or look up to? What qualities do you like about them?",
	"What would your ideal weekend be like? Walk me through what you would do.",
	"If you could create a new school subject, what would it be? What would students learn?",
	"What is your favorite sport or game to play? How did you first get interested in it?",
	"If you could have any animal as a pet, which would you choose? Why would it be a good pet?",
	"What is a historical event you find interesting? What would you want to know more about?",
	"If technology could solve one problem, what should it solve? How would that help the world?",
	"What is your favorite type of music or art? Why does it appeal to you?",
	"If you could live in any time period, when would it be? What would you do there?",
	"What food do you love eating? Can you describe why you enjoy it so much?",
	"If you had to teach someone a skill you know, what would it be? How would you explain it?",
	"What is the coolest invention you think exists? How does it make life better?",
	"If you could explore one place on Earth you haven't been, where would it be? What would you look for?",
	"What subject in school do you find most interesting? What specifically captures your attention?",
	"If you could start your own business, what would you sell or do? Who would you want as customers?",
	"What is something that makes you really proud? How did you accomplish or achieve it?",
	"If you could be friends with a famous person, who would you pick? What would you do together?",
	"What is a challenge you've faced and how did you overcome it? What did you learn?",
	"If you could create a new holiday, what would it celebrate? How would people celebrate it?",
	"What is your favorite way to spend time with family or friends? Why do you enjoy it?",
	"If you had to invent a new sport, what would the rules be? How would teams score points?",
	"What scares you the most and why? How do you deal with that fear?",
	"If you could live in any fictional world, which would you choose? What would you do there?",
	"What is something that really annoys you? Why do you think it bothers you so much?",
	"If you could have dinner with any historical figure, who would it be? What would you talk about?",
	"What is a goal you want to reach someday? What are you doing to work toward it?",
	"If you could change one rule at school, what would it be? How would that improve things?",
	"What animal do you think is the coolest? What makes it special or interesting?",
	"If you had unlimited money for one day, how would you spend it? Why would you choose that?",
	"What is something new you learned recently? How did learning it change your thinking?",
	"If you could have any superpower for a day, what would you do with it? Why that power?",
}

local rng = Random.new()
local disabledModels: {[string]: boolean} = {}
local nextGeminiAttemptTime = 0
local lastCooldownWarnTime = 0

local function getFallbackPrompt(): string
	return fallbackPrompts[rng:NextInteger(1, #fallbackPrompts)]
end

local function extractGeminiText(responseBody: {[string]: any}): string?
	local candidates = responseBody.candidates
	if type(candidates) ~= "table" or #candidates == 0 then
		return nil
	end

	local firstCandidate = candidates[1]
	if type(firstCandidate) ~= "table" then
		return nil
	end

	local content = firstCandidate.content
	if type(content) ~= "table" then
		return nil
	end

	local parts = content.parts
	if type(parts) ~= "table" or #parts == 0 then
		return nil
	end

	local firstPart = parts[1]
	if type(firstPart) ~= "table" then
		return nil
	end

	local text = firstPart.text
	if type(text) ~= "string" then
		return nil
	end

	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")

	if text == "" then
		return nil
	end

	if not string.find(text, "?") then
		return nil
	end

	if string.len(text) < 20 then
		return nil
	end

	return text
end

local function parseRetryDelaySeconds(responseBody: {[string]: any}): number?
	local details = responseBody.details
	if type(details) ~= "table" then
		return nil
	end

	for _, detail in details do
		if type(detail) == "table" then
			local retryDelay = detail.retryDelay
			if type(retryDelay) == "string" then
				local wholeSeconds = string.match(retryDelay, "^(%d+)s$")
				if wholeSeconds then
					local seconds = tonumber(wholeSeconds)
					if seconds then
						return seconds
					end
				end

				local fractionalSeconds = string.match(retryDelay, "^(%d+%.%d+)s$")
				if fractionalSeconds then
					local seconds = tonumber(fractionalSeconds)
					if seconds then
						return seconds
					end
				end
			end
		end
	end

	return nil
end

local function requestGeminiPrompt(): string?
	if not GEMINI_API_KEY then
		return nil
	end

	local now = os.clock()
	if now < nextGeminiAttemptTime then
		if now - lastCooldownWarnTime > 5 then
			lastCooldownWarnTime = now
			warn("Gemini cooldown active. Using fallback prompt.")
		end
		return nil
	end

	local candidateModels = {
		"gemini-2.5-flash",
		"gemini-3.1-flash-lite-preview",
		"gemini-3-flash-preview",
	}

	local payload = {
		contents = {
			{
				role = "user",
				parts = {
					{
						text = "Generate a prompt question for a middle school student. Pick a completely random topic like history, science, games, sports, animals, travel, food, art, school, hypotheticals, or culture. Return exactly 2 complete sentences that form a question with different wording each time. The question must be answerable by anyone without special knowledge. Always end with a question mark. Use varied sentence structures and never repeat the same topic or wording pattern.",
					},
				},
			},
		},
		generationConfig = {
			temperature = 1,
			maxOutputTokens = 60,
		},
	}

	local body = HttpService:JSONEncode(payload)

	for _, modelName in candidateModels do
		if disabledModels[modelName] then
			continue
		end

		local endpoint = "https://generativelanguage.googleapis.com/v1beta/models/" .. modelName .. ":generateContent?key=" .. HttpService:UrlEncode(GEMINI_API_KEY)

		local ok, response = pcall(function()
			return HttpService:RequestAsync({
				Url = endpoint,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
				},
				Body = body,
			})
		end)

		if not ok then
			warn("Gemini request failed for model " .. modelName .. ": " .. tostring(response))
			continue
		end

		if not response.Success then
			local parsedBody: {[string]: any}? = nil
			local decoded = pcall(function()
				parsedBody = HttpService:JSONDecode(response.Body)
			end)

			if response.StatusCode == 404 then
				disabledModels[modelName] = true
				warn("Gemini model unsupported and disabled for this session: " .. modelName)
				continue
			end

			if response.StatusCode == 429 then
				local cooldownSeconds = 30
				if decoded and parsedBody and type(parsedBody.error) == "table" then
					local retrySeconds = parseRetryDelaySeconds(parsedBody.error)
					if retrySeconds then
						cooldownSeconds = math.max(5, math.floor(retrySeconds + 0.5))
					end
				end

				nextGeminiAttemptTime = os.clock() + cooldownSeconds
				warn("Gemini quota/rate limit hit. Cooling down for " .. tostring(cooldownSeconds) .. "s and using fallback prompts.")
				continue
			end

			warn("Gemini request unsuccessful. Model " .. modelName .. ", status " .. tostring(response.StatusCode) .. ", body: " .. tostring(response.Body))
			continue
		end

		local decodeOk, responseBody = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)

		if not decodeOk then
			warn("Gemini response decode failed for model " .. modelName .. ".")
			continue
		end

		local text = extractGeminiText(responseBody)
		if text then
			return text
		end
	end

	return nil
end

requestPromptRemote.OnServerInvoke = function()
	local geminiPrompt = requestGeminiPrompt()
	if geminiPrompt then
		return geminiPrompt
	end

	return getFallbackPrompt()
end
