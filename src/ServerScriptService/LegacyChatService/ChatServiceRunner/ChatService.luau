local module = {}

if game:GetService("TextChatService").ChatVersion ~= Enum.ChatVersion.TextChatService then
	module = require(game:GetService("ServerStorage")["Roblox's"].ChatService)
	return module
end

local RegisterProcessCommands = Instance.new("BindableEvent")
module.RegisterProcessCommands = RegisterProcessCommands.Event
local UnregisterProcessCommands = Instance.new("BindableEvent")
module.UnregisterProcessCommands = UnregisterProcessCommands.Event

local RegisterFilterMessage = Instance.new("BindableEvent")
module.RegisterFilterMessage = RegisterFilterMessage.Event
local UnregisterFilterMessage = Instance.new("BindableEvent")
module.UnregisterFilterMessage = UnregisterFilterMessage.Event

local ChannelAdded = Instance.new("BindableEvent")
module.ChannelAdded = ChannelAdded.Event
local ChannelRemoved = Instance.new("BindableEvent")
module.ChannelRemoved = ChannelRemoved.Event

local NAME_COLORS =
	{
		Color3.new(253/255, 41/255, 67/255), -- BrickColor.new("Bright red").Color,
		Color3.new(1/255, 162/255, 255/255), -- BrickColor.new("Bright blue").Color,
		Color3.new(2/255, 184/255, 87/255), -- BrickColor.new("Earth green").Color,
		BrickColor.new("Bright violet").Color,
		BrickColor.new("Bright orange").Color,
		BrickColor.new("Bright yellow").Color,
		BrickColor.new("Light reddish violet").Color,
		BrickColor.new("Brick yellow").Color,
	}

local function GetNameValue(pName)
	local value = 0
	for index = 1, #pName do
		local cValue = string.byte(string.sub(pName, index, index))
		local reverseIndex = #pName - index + 1
		if #pName%2 == 1 then
			reverseIndex = reverseIndex - 1
		end
		if reverseIndex%4 >= 2 then
			cValue = -cValue
		end
		value = value + cValue
	end
	return value
end

local color_offset = 0
local function ComputeNameColor(pName)
	return NAME_COLORS[((GetNameValue(pName) + color_offset) % #NAME_COLORS) + 1]
end

function module:RegisterProcessCommandsFunction(funcId: string, func, priority)
	RegisterProcessCommands:Fire(funcId, func)
end

function module:UnregisterProcessCommandsFunction(funcId: string)
	UnregisterProcessCommands:Fire(funcId)
end

function module:RegisterFilterMessageFunction(funcId: string, func, priority)
	RegisterFilterMessage:Fire(funcId, func)
end

function module:UnregisterFilterMessageFunction(funcId: string)
	UnregisterFilterMessage:Fire(funcId)
end

local channels = {}
local channelRemote = game:GetService("ReplicatedStorage").LegacyChatService.RemoteEvents.ManageChannels

function module:AddChannel(name: string)
	local channelInst: TextChannel = Instance.new("TextChannel")
	channelInst.Name = name
	channelInst.Parent = game:GetService("TextChatService").LegacyChatService.Channels.TextChannels

	local msgRemote = game:GetService("ReplicatedStorage").LegacyChatService.RemoteEvents.SystemMessages

	local dict = {
		Name = channelInst.Name,
		WelcomeMessage = "",
		Speakers = {},
		Private = false,
		ChannelObj = channelInst,
		SendSystemMessage = function(self, msg: string)
			for i,plr in pairs(game:GetService("Players"):GetPlayers()) do
				if channelInst:FindFirstChild(plr.Name) then
					msgRemote:FireClient(plr, channelInst, msg)
				end
			end
		end,
		GetSpeakerList = function(self)
			return self.Speakers
		end,
		Mutes = {},
		MuteSpeaker = function(self, speakerName)
			self.Mutes[string.lower(speakerName)] = 0
		end,
	}

	channels[channelInst.Name] = dict

	ChannelAdded:Fire(channelInst.Name)

	return channels[channelInst.Name]
end

local GeneralChannelName = require(game:GetService("TextChatService").LegacyChatService.ChatSettings).GeneralChannelName

local GeneralChannel = module:AddChannel(GeneralChannelName)
GeneralChannel.Private = false
GeneralChannel.WelcomeMessage = "Chat '/?' or '/help' for a list of chat commands."

local SystemChannel = module:AddChannel("System")
SystemChannel.WelcomeMessage = "This channel is for system and game notifications."

function module:RemoveChannel(name: string)
	local channelInst: TextChannel = game:GetService("TextChatService").LegacyChatService.Channels.TextChannels:FindFirstChild(name)
	if channelInst then
		channelInst:Destroy()
		ChannelRemoved:Fire(channelInst.Name)
	end
end

function module:GetChannel(name: string)
	local channelInst: TextChannel = game:GetService("TextChatService").LegacyChatService.Channels.TextChannels:FindFirstChild(name)
	if channelInst and channels[name] then
		return channels[name]
	else
		return nil
	end
end

function module:GetAutoJoinChannelList()
	local array = {}
	for i,channel in pairs(game:GetService("TextChatService").LegacyChatService.Channels.TextChannels:GetChildren()) do
		local func = module:GetChannel(channel.Name)
		if func and func["AutoJoin"] == true then
			table.insert(array, channel.Name)
		end
	end
	return array
end

function module:GetChannelList()
	local array = {}
	for i,channel in pairs(game:GetService("TextChatService").LegacyChatService.TextChannels:GetChildren()) do
		local func = module:GetChannel(channel.Name)
		if func and func["Private"] == false then
			table.insert(array, channel.Name)
		end
	end
	return array
end

function module:AddSpeaker()
	warn("Support for speakers which aren't players is coming soon. Sorry for now! - Legacy Chat on TextChatService")
end

local function from_hex(hex: string): Color3
	local r, g, b = string.match(hex, "^#?(%w%w)(%w%w)(%w%w)$")
	return Color3.fromRGB(tonumber(r, 16),
		tonumber(g, 16), tonumber(b, 16))
end

function module:GetSpeaker(speaker: string)
	local plrInstance: Player = game:GetService("Players")[speaker]
	local extradata = {}
	local config = plrInstance:WaitForChild("Chat")
	for i,v in pairs(plrInstance.Chat:GetAttributes()) do
		if i == "Tags" then
			local item = game:GetService("HttpService"):JSONDecode(v)
			for i,v in pairs(item) do
				for j, x in pairs(v) do
					local success = pcall(function()
						local sigma = from_hex(x)
					end)

					if success then
						item[i][j] = from_hex(x)
					end
				end
			end
			extradata[i] = item
		else
			extradata[i] = v
		end
	end
	return {ExtraData = extradata,
		PlayerObj = plrInstance,
		Name = speaker,
		SetExtraData = function(self, name: string, val: any)
			local config = plrInstance["Chat"]
			if name == "Tags" then
				for i,v in pairs(val) do
					for j, x in pairs(v) do
						local color3 = x.R

						if color3 then
							val[i][j] = x:ToHex()
						end
					end
				end

				local stringTable = game:GetService("HttpService"):JSONEncode(val)
				config:SetAttribute(name, stringTable)
			else
				config:SetAttribute(name, val)
			end
			extradata[name] = val
		end,
		GetExtraData = function(self, key: string)
			return extradata[key]
		end,
		GetPlayer = function(self)
			return self.PlayerObj
		end,
		JoinChannel = function(self, channelName: string)
			local textChannel: TextChannel = game:GetService("TextChatService").LegacyChatService.Channels.TextChannels:FindFirstChild(channelName)
			if not textChannel then
				return
			end

			if textChannel:FindFirstChild(self.PlayerObj.Name) then
				warn('Speaker is already in channel "' .. textChannel.Name .. '"')
			else
				textChannel:AddUserAsync(plrInstance.UserId)
				channelRemote:FireClient(plrInstance, "Add", textChannel, {WelcomeMessage = module:GetChannel(channelName).WelcomeMessage})
				--table.insert(channels[textChannel.Name].Speakers, plrInstance)
			end
		end,
		LeaveChannel = function(self, channelName: string)
			local textChannel: TextChannel = game:GetService("TextChatService").LegacyChatService.TextChannels:FindFirstChild(channelName)
			if not textChannel then return end

			local textSource: TextSource = textChannel:FindFirstChild(plrInstance.Name)
			if not textSource then return end

			textSource.CanSend = false
			textSource:Destroy()
			channelRemote:FireClient(plrInstance, "Remove", textChannel)
			--table.remove(channels[textChannel.Name], table.find(channels[textChannel.Name], plrInstance))
		end,
		IsInChannel = function(self, channelName: string)
			local textChannel: TextChannel = game:GetService("TextChatService").LegacyChatService.TextChannels:FindFirstChild(channelName)
			if not textChannel then return false end

			local textSource: TextSource = textChannel:FindFirstChild(plrInstance.Name)
			return if textSource then true else false
		end,
	}
end

local SpeakerAdded = Instance.new("BindableEvent")
module.SpeakerAdded = SpeakerAdded.Event

game:GetService("Players").PlayerAdded:Connect(function(plr: Player)
	local config = plr:FindFirstChild("Chat")
	if not config then
		config = Instance.new("Configuration")
		config.Name = "Chat"
		config.Parent = plr
		config:SetAttribute("Tags", "[]") -- empty table in JSON
		--config:SetAttribute("NameColor", )
	end
	local Speaker = module:GetSpeaker(plr.Name)
	if Speaker then
		if GeneralChannel then
			Speaker:JoinChannel(GeneralChannelName)
			local char = plr.Character or plr.CharacterAdded:Wait()
			channelRemote:FireClient(plr, "Select", GeneralChannel.ChannelObj, {WelcomeMessage = GeneralChannel.WelcomeMessage})
		end
		if SystemChannel then
			Speaker:JoinChannel(SystemChannel.Name)
			SystemChannel:MuteSpeaker(Speaker.Name)
		end
		Speaker:SetExtraData("NameColor", ComputeNameColor(Speaker.Name))
	end
	SpeakerAdded:Fire(plr.Name)
end)

return module