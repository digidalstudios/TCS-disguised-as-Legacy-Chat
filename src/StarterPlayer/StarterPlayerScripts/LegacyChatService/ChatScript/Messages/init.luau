local TCS = game:GetService("TextChatService")
local ChatSettings = require(game:GetService("TextChatService").LegacyChatService.ChatSettings)
local ChatConstants = require(game:GetService("TextChatService").LegacyChatService.ChatConstants)

local module = {}

function module.run(Chat, plr)
	if not game:GetService("Chat"):CanUserChatAsync(plr.UserId) then return end
	
	local Frame = Chat.Frame.ChatChannelParentFrame.Frame_MessageLogDisplay

	Frame.Parent.BackgroundColor3 = ChatSettings.BackGroundColor

	local function removeRichText(str)
		return (str:gsub("(\\?)<[^<>]->", { [''] = '' }))
	end

	local function GetStringTextBounds(text, font, textSize, sizeBounds)
		sizeBounds = sizeBounds or Vector2.new(10000, 10000)
		return game:GetService("TextService"):GetTextSize(text, textSize, font, sizeBounds)
	end

	local function GetNumberOfSpaces(str, font, textSize)
		local strSize = GetStringTextBounds(str, font, textSize)
		local singleSpaceSize = GetStringTextBounds(" ", font, textSize)
		return math.ceil(strSize.X / singleSpaceSize.X)
	end

	local function hasProperty(inst: Instance, property: string)
		local success = pcall(function()
			local sigma = inst[property] -- these variable names are so bad
		end)
		return success
	end

	local remoteFunction: RemoteFunction = game:GetService("ReplicatedStorage").LegacyChatService.RemoteFunctions.BlockCommands
	local results = {}

	local generalChannel = TCS.LegacyChatService.Channels.TextChannels:FindFirstChild(ChatSettings.GeneralChannelName)

	TCS.OnIncomingMessage = function(msg: TextChatMessage)

		if not msg.TextSource then return end

		local props = Instance.new("TextChatMessageProperties")

		local player = if msg.TextSource
			then game:GetService("Players"):GetPlayerByUserId(msg.TextSource.UserId)
			else nil

		if player == plr and msg.Status ~= Enum.TextChatMessageStatus.Sending then 
			if results[msg.MessageId] == false then
				props.Text = ' '
				props.PrefixText = " "
			elseif results[msg.MessageId] then
				props.Text = results[msg.MessageId].Text
				props.PrefixText = results[msg.MessageId].PrefixText
			end
			return props
		end

		local commandModules = TCS.LegacyChatService.ChatCommands.Client
		local commands = commandModules:GetChildren()
		local commandUtil = require(commandModules:WaitForChild("Util"))
		for i = 1, #commands do
			if commands[i]:IsA("ModuleScript") then
				if commands[i].Name ~= "Util" then
					local commandProcessor = require(commands[i])
					local processorType = commandProcessor[commandUtil.KEY_COMMAND_PROCESSOR_TYPE]
					local processorFunction = commandProcessor[commandUtil.KEY_PROCESSOR_FUNCTION]
					if processorType == commandUtil.COMPLETED_MESSAGE_PROCESSOR then
						processorFunction()
					end
				end
			end
		end

		local send: boolean, messageObject = remoteFunction:InvokeServer(msg.MessageId, msg.Text, msg.TextSource.UserId, msg.TextChannel)
		if not send then
			props.Text = ' '
			props.PrefixText = " "
			results[msg.MessageId] = false

			return props
		end
		if messageObject then
			props.Text = messageObject.Message
		end

		if not generalChannel then return end

		if player then
			props.PrefixText = msg.PrefixText:gsub(player.DisplayName, "[" .. player.DisplayName .. "]")
		end

		local useDisplayNames = ChatSettings.PlayerDisplayNamesEnabled

		if (not useDisplayNames) and player then
			props.PrefixText = (props.PrefixText:gsub(player.DisplayName, player.Name))
		end

		local speakerConfig = player:FindFirstChild("Chat")
		if speakerConfig then
			local tags = speakerConfig:GetAttribute("Tags")
			if tags and typeof(tags) == "string" then
				local tagsTable = game:GetService("HttpService"):JSONDecode(tags)
				local tagsString = ""
				for i,v in pairs(tagsTable) do
					tagsString = tagsString .. "<font color='#" .. (if v["TagColor"] then v["TagColor"] else Color3.fromRGB(255, 0, 255):ToHex()) .. "'>" .. "[" .. v["TagText"] .. "]</font> "
				end
				if tagsString and tagsString ~= "" then
					props.PrefixText = `{tagsString}{if props.PrefixText ~= "" then props.PrefixText else msg.PrefixText}`
				end
			end

			local nameColor = speakerConfig:GetAttribute("NameColor")
			if nameColor and typeof(nameColor) == "Color3" then
				props.PrefixText = `<font color='#{nameColor:ToHex()}'>{if props.PrefixText ~= "" then props.PrefixText else msg.PrefixText}</font>`
			end
			
			if msg.TextChannel.Parent == TCS.LegacyChatService.Channels.TeamChannels then
				props.Text = `<font color='#{plr.TeamColor.Color:ToHex()}'>{if props.Text ~= "" then props.Text else msg.Text}</font>`
			else
				local chatColor = speakerConfig:GetAttribute("ChatColor")
				if chatColor and typeof(chatColor) == "Color3" then
					props.Text = `<font color='#{chatColor:ToHex()}'>{if props.Text ~= "" then props.Text else msg.Text}</font>`
				end
			end
		end

		if msg.TextChannel.Parent == TCS.LegacyChatService.Channels.Whispers then
			local split = string.split(msg.TextChannel.Name, "|")
			local playerId2
			for i,v in pairs(split) do
				if tonumber(v) ~= plr.UserId then
					playerId2 = v
				end
			end

			local player2 = game:GetService("Players"):GetPlayerByUserId(playerId2)

			local recipient = msg.TextChannel.Name
			if player ~= plr then -- i need better variable names
				props.PrefixText = `[From {if useDisplayNames then player.DisplayName else player.Name}] ` .. props.PrefixText
			else
				props.PrefixText = `[{tostring(ChatConstants.WhisperChannelPrefix)}{if useDisplayNames then player2.DisplayName else player2.Name}] ` .. props.PrefixText
			end
		end

		results[msg.MessageId] = props

		return props
	end

	local function findPlayerByName(Name, ignoreList)
		local PlayerCount = 0
		local PlayerFound

		for i, Player in ipairs(game:GetService("Players"):GetPlayers()) do
			if table.find(ignoreList, Player) then continue end
			if string.lower(Player.Name):match(string.lower(Name)) then
				PlayerCount += 1

				if PlayerCount > 1 then
					PlayerCount = 0
					PlayerFound = nil

					break
				else
					PlayerFound = Player
				end
			end
		end

		return PlayerFound
	end

	local whisperEvent = game:GetService("ReplicatedStorage").LegacyChatService.RemoteFunctions.GetWhisperChannel

	local chatbar = Frame.Parent.Parent.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar
	local channelText = chatbar.ChannelText
	local realText = chatbar.RealText

	TCS.MessageReceived:Connect(function(msg)
		if msg.Text == " " then return end
		local newUi = script.UserTemplate:Clone()
		newUi.Name = "Frame"

		newUi.TextLabel.TextButton.Text = msg.PrefixText

		newUi.TextLabel.Font = ChatSettings.DefaultFont
		newUi.TextLabel.TextButton.Font = ChatSettings.DefaultFont
		newUi.TextLabel.TextColor3 = ChatSettings.DefaultMessageColor
		newUi.TextLabel.TextButton.TextColor3 = ChatSettings.DefaultNameColor

		local numNeededSpaces = GetNumberOfSpaces(removeRichText(msg.PrefixText), newUi.TextLabel.Font, newUi.TextLabel.TextSize) + 1
		local spaces = string.rep(" ", numNeededSpaces + 1)

		newUi.TextLabel.Text = (if msg.PrefixText ~= "" then spaces else "") .. (msg.Text)

		local folderLocation = plr.PlayerScripts.LegacyChatService.ChatScript.ManageChannels.Channels
		local folder = folderLocation:FindFirstChild(msg.TextChannel.Name)
		if ChatSettings.ShowChannelsBar then
			if folder then
				newUi.Parent = folder
			else
				folder = Frame.Scroller:FindFirstChild(msg.TextChannel.Name)
				if folder then
					newUi.Parent = folder
				end
			end
		end
		if (msg.TextChannel ~= generalChannel and msg.Metadata ~= "WelcomeMessage") or (not ChatSettings.ShowChannelsBar and not (msg.TextChannel ~= generalChannel and msg.Metadata == "WelcomeMessage")) then
			local clone = newUi:Clone()

			local text = "{" .. msg.TextChannel.Name .. "} "
			if msg.TextChannel.Parent == TCS.LegacyChatService.Channels.TeamChannels then
				text = "<font color='#" .. plr.TeamColor.Color:ToHex() .. "'>{Team} </font>"
			end

			if msg.TextSource then
				local player = game:GetService("Players"):GetPlayerByUserId(msg.TextSource.UserId)
				local speakerConfig = player:FindFirstChild("Chat")
				if speakerConfig then
					local chatColor = speakerConfig:GetAttribute("ChatColor")
					if chatColor and typeof(chatColor) == "Color3" and msg.TextChannel.Parent ~= TCS.LegacyChatService.Channels.TeamChannels then
						text = "<font color='#" .. chatColor:ToHex() .. "'>" .. text .. "</font>"
					end
				end
			end

			if msg.TextChannel == generalChannel then text = "" end
			if msg.TextChannel.Parent == TCS.LegacyChatService.Channels.Whispers then text = "" end

			clone.TextLabel.TextButton.Text = text .. clone.TextLabel.TextButton.Text

			local numNeededSpaces = GetNumberOfSpaces(removeRichText(text .. msg.PrefixText), clone.TextLabel.TextButton.Font, clone.TextLabel.TextButton.TextSize) + 1
			local spaces = string.rep(" ", numNeededSpaces + 1)

			clone.TextLabel.Text = spaces .. (msg.Text)

			if folderLocation:FindFirstChild("All") then
				clone.Parent = folderLocation.All
			else
				if Frame.Scroller:FindFirstChild("All") then
					clone.Parent = Frame.Scroller.All
				else
					clone:Destroy()
				end
			end	
		end

		newUi.TextLabel.TextButton.MouseButton1Click:Connect(function()
			if msg.TextSource.UserId == plr.UserId then return end

			chatbar.Text = " "

			local TextChannel = TCS.ChatInputBarConfiguration.TargetTextChannel

			local plr2: Player = game:GetService("Players"):GetPlayerByUserId(msg.TextSource.UserId)
			if not plr2 then return end

			local channel = whisperEvent:InvokeServer(plr2)

			TCS.ChatInputBarConfiguration.TargetTextChannel = channel
			TextChannel = TCS.ChatInputBarConfiguration.TargetTextChannel

			channelText.Value = `[{plr2.DisplayName}]`

			local MessageMode = chatbar.Parent.MessageMode
			MessageMode.Size = UDim2.new(0, 46, 1, 0)
			MessageMode.Text = channelText.Value
			MessageMode.Visible = true

			chatbar.Position = UDim2.new(0, MessageMode.AbsoluteSize.X, 0, 0)
			chatbar.Size = UDim2.new(1, -MessageMode.AbsoluteSize.X, 1, 0)

			chatbar:CaptureFocus()
		end)
	end)

	local amount = Frame.Scroller.AbsoluteCanvasSize.Y

	Frame.Scroller.DescendantAdded:Connect(function(inst: Frame?)
		if not hasProperty(inst, "AbsoluteSize") then return end

		amount = Frame.Scroller.AbsoluteCanvasSize
		if Frame.Scroller.CanvasPosition.Y + 1 >= amount.Y - Frame.Scroller.AbsoluteSize.Y - inst.AbsoluteSize.Y then
			Frame.Scroller.CanvasPosition = amount
		end
	end)

	local connections = require(game:GetService("ReplicatedStorage").LegacyChatService.Modules.ChatCore)

	connections:Connect("SetCore", "ChatMakeSystemMessage", function(info)
		if not info.Text then return end

		local str = info.Text
		if info.Color and typeof(info.Color) == "Color3" then
			str = `<font color='#{info.Color:ToHex()}'>{str}</font>`
		end

		if info.Font and typeof(info.Font) == "EnumItem" then
			str = `<font face='{info.Font.Name}'>{str}</font>`
		end

		if info.TextSize and type(info.TextSize) == "number" then
			str = `<font size='{info.TextSize}'>{str}</font>`
		end

		generalChannel:DisplaySystemMessage(str)
	end)

	local remote = game:GetService("ReplicatedStorage").LegacyChatService.RemoteEvents.SystemMessages

	remote.OnClientEvent:Connect(function(channel: TextChannel, msg: string)
		channel:DisplaySystemMessage(msg)
	end)
end

return module