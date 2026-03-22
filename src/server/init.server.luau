local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JUDGE_TRIGGER_ENDPOINT = "http://127.0.0.1:8003/run_judges"
local DEFAULT_JUDGE_MESSAGES = {
	"Clinical note: the structure reads deliberate, but the emotional signal is still detectable.",
	"Hype meter says this answer has some robo flavor, but it needs more synthetic drama!",
	"Skeptic stance: not convinced yet; I still see human fingerprints in the wording.",
}

type GeminiKeys = {
	promptKey: string,
	analysisKey: string?,
}

type JudgeMessage = {
	name: string,
	rating: number,
	response: string,
}

local function readGeminiConfig(): GeminiKeys?
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

	local apiKey2 = config.GEMINI_API_KEY2
	if type(apiKey2) ~= "string" or apiKey2 == "" then
		warn("GEMINI_API_KEY2 missing in GeminiConfig. Answer analysis and judge scoring will be unavailable.")
		apiKey2 = nil
	end

	return {
		promptKey = apiKey,
		analysisKey = apiKey2,
	}
end

local GEMINI_KEYS = readGeminiConfig()

local remoteName = "RequestPrompt"
local requestPromptRemote = ReplicatedStorage:FindFirstChild(remoteName) :: RemoteFunction?
if not requestPromptRemote then
	requestPromptRemote = Instance.new("RemoteFunction")
	requestPromptRemote.Name = remoteName
	requestPromptRemote.Parent = ReplicatedStorage
end

local analysisRemoteName = "EvaluateAnswer"
local evaluateAnswerRemote = ReplicatedStorage:FindFirstChild(analysisRemoteName) :: RemoteFunction?
if not evaluateAnswerRemote then
	evaluateAnswerRemote = Instance.new("RemoteFunction")
	evaluateAnswerRemote.Name = analysisRemoteName
	evaluateAnswerRemote.Parent = ReplicatedStorage
end

local function ensureRobotRigPresent()
	local existing = ReplicatedStorage:FindFirstChild("RobotRig")
	if existing then
		return
	end

	-- Fallback placeholder so UI scripts that index ReplicatedStorage.RobotRig do not crash.
	local placeholder = Instance.new("Model")
	placeholder.Name = "RobotRig"
	placeholder.Parent = ReplicatedStorage

	warn("RobotRig was missing in ReplicatedStorage. Created placeholder Model named RobotRig.")
end

ensureRobotRigPresent()

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
local nextGeminiAnalysisAttemptTime = 0
local lastAnalysisCooldownWarnTime = 0

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

	return text
end

local function isValidPromptText(text: string): boolean
	if not string.find(text, "?") then
		return false
	end

	if string.len(text) < 20 then
		return false
	end

	local sentenceCount = 0
	for segment in string.gmatch(text, "[^%.%!%?]+") do
		local trimmed = string.gsub(segment, "^%s+", "")
		trimmed = string.gsub(trimmed, "%s+$", "")
		if trimmed ~= "" then
			sentenceCount += 1
		end
	end

	if sentenceCount < 2 or sentenceCount > 3 then
		return false
	end

	return true
end

local function parseAiAnalysis(rawText: string): {percent: number, explanation: string}?
	local cleanedText = string.gsub(rawText, "^%s*```json%s*", "")
	cleanedText = string.gsub(cleanedText, "^%s*```%s*", "")
	cleanedText = string.gsub(cleanedText, "%s*```%s*$", "")
	cleanedText = string.gsub(cleanedText, "^%s+", "")
	cleanedText = string.gsub(cleanedText, "%s+$", "")

	local decodeOk, parsed = pcall(function()
		return HttpService:JSONDecode(cleanedText)
	end)

	if decodeOk and type(parsed) == "table" then
		local percent = parsed.ai_generated_percent
		local explanation = parsed.explanation
		if type(percent) == "number" and type(explanation) == "string" and explanation ~= "" then
			local clamped = math.clamp(math.floor(percent + 0.5), 0, 100)
			return {
				percent = clamped,
				explanation = explanation,
			}
		end
	end

	local extractedExplanation = string.match(cleanedText, '"explanation"%s*:%s*"(.-)"')
	if extractedExplanation then
		extractedExplanation = string.gsub(extractedExplanation, '\\n', ' ')
		extractedExplanation = string.gsub(extractedExplanation, '\\"', '"')
		extractedExplanation = string.gsub(extractedExplanation, '\\\\', '\\')
		extractedExplanation = string.gsub(extractedExplanation, "^%s+", "")
		extractedExplanation = string.gsub(extractedExplanation, "%s+$", "")
	end

	local numberText = string.match(cleanedText, '"ai_generated_percent"%s*:%s*(%d+%.?%d*)')
		or string.match(cleanedText, "ai_generated_percent%s*[:=]%s*(%d+%.?%d*)")
		or string.match(cleanedText, "AI%s*generated%s*likelihood%s*[:=]%s*(%d+%.?%d*)%%?")
	if numberText then
		local maybePercent = tonumber(numberText)
		if maybePercent then
			local clamped = math.clamp(math.floor(maybePercent + 0.5), 0, 100)
			return {
				percent = clamped,
				explanation = extractedExplanation or "Analysis complete.",
			}
		end
	end

	return nil
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
	if not GEMINI_KEYS then
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
		"gemini-2.5-flash-lite",  -- Cheapest stable
		"gemini-3.1-flash-lite-preview",  -- Newer preview option
		"gemini-2.5-flash",  -- Fallback
	}

	local payload = {
		contents = {
			{
				role = "user",
				parts = {
					{
						text = "Generate one very random writing prompt for a party game. Return only the prompt text as 2 to 3 complete sentences. Do not stick to a single topic domain and do not sound like school assignment topics. Use surprising combinations of ideas and vary sentence structure from previous outputs. The prompt must be answerable by anyone and include at least one direct question ending with a question mark.",
					},
				},
			},
		},
		generationConfig = {
			temperature = 1.4,
			topP = 0.95,
			maxOutputTokens = 100,
		},
	}

	local body = HttpService:JSONEncode(payload)

	for _, modelName in candidateModels do
		if disabledModels[modelName] then
			continue
		end

		local endpoint = "https://generativelanguage.googleapis.com/v1beta/models/" .. modelName .. ":generateContent?key=" .. HttpService:UrlEncode(GEMINI_KEYS.promptKey)

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
		if text and isValidPromptText(text) then
			return text
		end
	end

	return nil
end

local function requestAnswerEvaluation(answerText: string, promptText: string): {percent: number, explanation: string}?
	if not GEMINI_KEYS then
		return nil
	end

	if not GEMINI_KEYS.analysisKey then
		warn("Skipping answer analysis because GEMINI_API_KEY2 is not configured.")
		return nil
	end

	local now = os.clock()
	if now < nextGeminiAnalysisAttemptTime then
		if now - lastAnalysisCooldownWarnTime > 5 then
			lastAnalysisCooldownWarnTime = now
			warn("Gemini analysis cooldown active. Skipping analysis request.")
		end
		return nil
	end

	local candidateModels = {
		"gemini-2.5-flash-lite",  -- Cheapest stable option for analysis
		"gemini-3.1-flash-lite-preview",  -- Newer preview fallback
		"gemini-2.5-flash",  -- Last resort
	}

	local instruction = table.concat({
		"You are evaluating whether a student's answer looks AI-generated.",
		"Prompt shown to student: " .. promptText,
		"Student answer: " .. answerText,
		"Return STRICT JSON only with keys ai_generated_percent and explanation.",
		"ai_generated_percent must be a number 0-100.",
		"explanation must be one concise paragraph explaining your reasoning.",
	}, "\n")

	local payload = {
		contents = {
			{
				role = "user",
				parts = {
					{
						text = instruction,
					},
				},
			},
		},
		generationConfig = {
			temperature = 0.2,
			maxOutputTokens = 220,
			responseMimeType = "application/json",
		},
	}

	local body = HttpService:JSONEncode(payload)

	for _, modelName in candidateModels do
		if disabledModels[modelName] then
			continue
		end

		local endpoint = "https://generativelanguage.googleapis.com/v1beta/models/" .. modelName .. ":generateContent?key=" .. HttpService:UrlEncode(GEMINI_KEYS.analysisKey)

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
			warn("Gemini analysis request failed for model " .. modelName .. ": " .. tostring(response))
			continue
		end

		if not response.Success then
			if response.StatusCode == 404 then
				disabledModels[modelName] = true
				continue
			end

			if response.StatusCode == 429 then
				local cooldownSeconds = 30
				local parsedBody: {[string]: any}? = nil
				local decoded = pcall(function()
					parsedBody = HttpService:JSONDecode(response.Body)
				end)

				if decoded and parsedBody and type(parsedBody.error) == "table" then
					local retrySeconds = parseRetryDelaySeconds(parsedBody.error)
					if retrySeconds then
						cooldownSeconds = math.max(5, math.floor(retrySeconds + 0.5))
					end
				end

				nextGeminiAnalysisAttemptTime = os.clock() + cooldownSeconds
				warn("Gemini analysis quota/rate limit hit. Cooling down for " .. tostring(cooldownSeconds) .. "s.")
				continue
			end

			warn("Gemini analysis unsuccessful. Model " .. modelName .. ", status " .. tostring(response.StatusCode))
			continue
		end

		local decodeOk, responseBody = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)

		if not decodeOk then
			continue
		end

		local rawText = extractGeminiText(responseBody)
		if not rawText then
			continue
		end

		local analysis = parseAiAnalysis(rawText)
		if analysis then
			return analysis
		end
	end

	return nil
end

local function getDefaultJudgeMessages(basePercent: number): {JudgeMessage}
	local clampedBase = math.clamp(math.floor(basePercent + 0.5), 0, 100)
	return {
		{
			name = "The Analyst",
			rating = clampedBase,
			response = DEFAULT_JUDGE_MESSAGES[1],
		},
		{
			name = "The Hype Host",
			rating = math.clamp(clampedBase + 10, 0, 100),
			response = DEFAULT_JUDGE_MESSAGES[2],
		},
		{
			name = "The Skeptic",
			rating = math.clamp(clampedBase - 10, 0, 100),
			response = DEFAULT_JUDGE_MESSAGES[3],
		},
	}
end

local function requestJudgeMessages(player: Player, answerText: string, promptText: string, analysis: {percent: number, explanation: string}): {JudgeMessage}
	local payload = {
		player_name = player.Name,
		player_user_id = player.UserId,
		prompt = promptText,
		answer = answerText,
		ai_generated_percent = analysis.percent,
		gemini_explanation = analysis.explanation,
	}

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)

	if not ok then
		warn("Failed to encode judge payload. Using defaults.")
		return getDefaultJudgeMessages(analysis.percent)
	end

	local requestOk, response = pcall(function()
		return HttpService:RequestAsync({
			Url = JUDGE_TRIGGER_ENDPOINT,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = encoded,
		})
	end)

	if not requestOk then
		warn("Judge message request failed: " .. tostring(response))
		return getDefaultJudgeMessages(analysis.percent)
	end

	if not response.Success then
		warn("Judge message endpoint returned status " .. tostring(response.StatusCode))
		return getDefaultJudgeMessages(analysis.percent)
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)

	if not decodeOk or type(decoded) ~= "table" then
		warn("Judge message response decode failed. Using defaults.")
		return getDefaultJudgeMessages(analysis.percent)
	end

	local analyst = decoded.analyst_result
	local hypeHost = decoded.hype_host_result
	local skeptic = decoded.skeptic_result
	local analystRating = decoded.analyst_rating
	local hypeHostRating = decoded.hype_host_rating
	local skepticRating = decoded.skeptic_rating

	if type(analyst) == "string" and analyst ~= ""
		and type(hypeHost) == "string" and hypeHost ~= ""
		and type(skeptic) == "string" and skeptic ~= ""
		and type(analystRating) == "number"
		and type(hypeHostRating) == "number"
		and type(skepticRating) == "number" then
		return {
			{
				name = "The Analyst",
				rating = math.clamp(math.floor(analystRating + 0.5), 0, 100),
				response = analyst,
			},
			{
				name = "The Hype Host",
				rating = math.clamp(math.floor(hypeHostRating + 0.5), 0, 100),
				response = hypeHost,
			},
			{
				name = "The Skeptic",
				rating = math.clamp(math.floor(skepticRating + 0.5), 0, 100),
				response = skeptic,
			},
		}
	end

	if type(analyst) == "string" and analyst ~= ""
		and type(hypeHost) == "string" and hypeHost ~= ""
		and type(skeptic) == "string" and skeptic ~= "" then
		local base = math.clamp(math.floor(analysis.percent + 0.5), 0, 100)
		return {
			{
				name = "The Analyst",
				rating = base,
				response = analyst,
			},
			{
				name = "The Hype Host",
				rating = math.clamp(base + 10, 0, 100),
				response = hypeHost,
			},
			{
				name = "The Skeptic",
				rating = math.clamp(base - 10, 0, 100),
				response = skeptic,
			},
		}
	end

	return getDefaultJudgeMessages(analysis.percent)
end

requestPromptRemote.OnServerInvoke = function()
	local geminiPrompt = requestGeminiPrompt()
	if geminiPrompt then
		return geminiPrompt
	end

	return getFallbackPrompt()
end

evaluateAnswerRemote.OnServerInvoke = function(player: Player, answerText: string, promptText: string)
	if type(answerText) ~= "string" or answerText == "" then
		return {
			percent = 0,
			explanation = "Please type an answer before submitting.",
		}
	end

	local safePrompt = ""
	if type(promptText) == "string" then
		safePrompt = promptText
	end

	local analysis = requestAnswerEvaluation(answerText, safePrompt)
	if analysis then
		local judgeMessages = requestJudgeMessages(player, answerText, safePrompt, analysis)
		return {
			percent = analysis.percent,
			explanation = analysis.explanation,
			judge_messages = judgeMessages,
		}
	end

	return {
		percent = 0,
		explanation = "Could not analyze with Gemini right now. Please try again.",
	}
end
