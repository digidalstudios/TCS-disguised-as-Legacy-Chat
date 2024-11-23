if game:GetService("TextChatService").ChatVersion ~= Enum.ChatVersion.TextChatService then
	script.Parent:Destroy()
	return
end

local folder = script.Parent
script.Parent = game:GetService("ServerScriptService")
folder:Destroy()

local module = require(script.ChatService)
local TCS = game:GetService("TextChatService")

local blockCommands = game:GetService("ReplicatedStorage").LegacyChatService.RemoteFunctions.BlockCommands
local getWhisper = game:GetService("ReplicatedStorage").LegacyChatService.RemoteFunctions.GetWhisperChannel

local msgRemote = game:GetService("ReplicatedStorage").LegacyChatService.RemoteEvents.SystemMessages

local teamChannels = TCS.LegacyChatService.Channels.TeamChannels
local whisperChannels = TCS.LegacyChatService.Channels.Whispers

local commands = {}
local filters = {}

module.RegisterProcessCommands:Connect(function(funcId, func)
	commands[funcId] = func
end)

module.UnregisterProcessCommands:Connect(function(funcId)
	if commands[funcId] then
		commands[funcId] = nil
	end
end)

module.RegisterFilterMessage:Connect(function(funcId, func)
	filters[funcId] = func
end)

module.UnregisterFilterMessage:Connect(function(funcId)
	if filters[funcId] then
		filters[funcId] = nil
	end
end)

for i,v in pairs(TCS.LegacyChatService.ChatCommands.Server:GetChildren()) do
	local command = require(v)
	command(module)
end

local channelRemote = game:GetService("ReplicatedStorage").LegacyChatService.RemoteEvents.ManageChannels

module.SpeakerAdded:Connect(function(speakerName: string)
	local Speaker = module:GetSpeaker(speakerName)
	local plr = Speaker.PlayerObj
	if not plr then return end
	local char = plr.Character or plr.CharacterAdded:Wait()
	for i,channel in pairs(module:GetAutoJoinChannelList()) do
		Speaker:JoinChannel(channel)
	end
	if plr.Team then
		local teamColour = plr.TeamColor
		if teamChannels:FindFirstChild(teamColour.Name) then
			teamChannels[teamColour.Name]:AddUserAsync(plr.UserId)
			channelRemote:FireClient(plr, "Add", teamChannels[teamColour.Name], {WelcomeMessage = "This is a private channel between you and your team members.", DisplayName = "Team"})
		end
	end
	plr:GetPropertyChangedSignal("Team"):Connect(function()
		if plr.Team == nil then return end

		local teamColour = plr.TeamColor
		if teamChannels:FindFirstChild(teamColour.Name) then
			teamChannels[teamColour.Name]:AddUserAsync(plr.UserId)
			channelRemote:FireClient(plr, "Add", teamChannels[teamColour.Name], {WelcomeMessage = "This is a private channel between you and your team members.", DisplayName = "Team"})
		end
	end)
end)

local function getPlayerWhisperChannels(plr: Player)
	local channelsFound = {}

	for _,textChannel: TextChannel in whisperChannels:GetChildren() do
		local split = string.split(textChannel.Name, "|")
		local playerId1 = split[1]
		local playerId2 = split[2]

		if playerId1 == plr.UserId or playerId2 == plr.UserId then
			table.insert(channelsFound, textChannel)
		end
	end

	return channelsFound
end

local function getWhisperChannel(plr1: Player, plr2: Player)
	local textChannel = whisperChannels:FindFirstChild(`{plr1.UserId}|{plr2.UserId}`)
	if not textChannel then
		textChannel = whisperChannels:FindFirstChild(`{plr2.UserId}|{plr1.UserId}`)
	end
	return textChannel
end

blockCommands.OnServerInvoke = function(plr: Player, id, msgText, msgSourceId, msgChannel: TextChannel)
	local msgPlr = game:GetService("Players"):GetPlayerByUserId(msgSourceId)
	local speaker = module:GetSpeaker(msgPlr.Name)

	if (msgChannel.Parent ~= whisperChannels and msgChannel.Parent ~= teamChannels) and (not module:GetChannel(msgChannel.Name) or module:GetChannel(msgChannel.Name).Mutes[string.lower(msgPlr.Name)] == 0) then -- If muted from channel or channel is not in data
		msgRemote:FireClient(msgPlr, msgChannel, "You are muted and cannot talk in this channel")
		return false
	end

	local result = false
	for i,v in pairs(commands) do
		local cmdResult = v(msgPlr.Name, msgText, msgChannel.Name)
		if cmdResult == true then
			result = true
		end
	end
	if result == true then
		return not result
	end

	local timeEpoch = os.time()
	local messageObject = {ExtraData = speaker.ExtraData, Time = timeEpoch, Message = msgText, MessageLength = #msgText, MessageLengthUtf8 = utf8.len(msgText), SpeakerUserId = msgSourceId, SpeakerDisplayName = msgPlr.DisplayName, FromSpeaker = msgPlr.Name, MessageType = "Message", OriginalChannel = msgChannel.Name, ID = id}

	for i,v in pairs(filters) do
		v(msgPlr.Name, messageObject, msgChannel.Name)
	end

	messageObject.Message = game:GetService("TextService"):FilterStringAsync(messageObject.Message, msgPlr.UserId):GetChatForUserAsync(plr.UserId)

	return not result, messageObject
end

getWhisper.OnServerInvoke = function(plr1: Player, plr2: Player)
	--if plr1.UserId == plr2.UserId then warn("You cannot whisper to yourself") return end

	local whisperChannel: TextChannel = getWhisperChannel(plr1, plr2)

	if not TCS:CanUsersChatAsync(plr1.UserId, plr2.UserId) or #TCS:CanUsersDirectChatAsync(plr1.UserId, {plr2.UserId}) <= 0 then
		if whisperChannel then
			whisperChannel:Destroy()
		end
		return
	end

	if not whisperChannel then
		whisperChannel = Instance.new("TextChannel")
		whisperChannel.Name = `{plr1.UserId}|{plr2.UserId}`
		whisperChannel.Parent = whisperChannels
		
		whisperChannel:SetDirectChatRequester(plr1)
		
		whisperChannel:AddUserAsync(plr1.UserId)
		whisperChannel:AddUserAsync(plr2.UserId)
	end

	return whisperChannel
end

for i,v in pairs(game:GetService("Teams"):GetChildren()) do
	if not v:IsA("Team") then continue end
	if teamChannels:FindFirstChild(v.TeamColor.Name) then return end

	local teamChannel = Instance.new("TextChannel")
	teamChannel.Name = v.TeamColor.Name
	teamChannel.Parent = teamChannels
end

game:GetService("Teams").ChildAdded:Connect(function(v)
	if not v:IsA("Team") then return end
	if teamChannels:FindFirstChild(v.TeamColor.Name) then return end

	local teamChannel = Instance.new("TextChannel")
	teamChannel.Name = v.TeamColor.Name
	teamChannel.Parent = teamChannels
end)