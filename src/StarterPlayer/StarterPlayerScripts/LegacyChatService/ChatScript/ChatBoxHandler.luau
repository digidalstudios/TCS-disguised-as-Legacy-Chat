local TCS = game:GetService("TextChatService")
local UIS = game:GetService("UserInputService")

local connections = require(game:GetService("ReplicatedStorage").LegacyChatService.Modules.ChatCore)
local ChatSettings = require(TCS.LegacyChatService.ChatSettings)

local whisperEvent = game:GetService("ReplicatedStorage").LegacyChatService.RemoteFunctions.GetWhisperChannel

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

local module = {}

function module.run(Chat, plr)
	local chatBar = Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar

	local screenGui = chatBar.Parent.Parent.Parent.Parent.Parent.Parent
	local channelText = chatBar.ChannelText
	local realText = chatBar.RealText

	chatBar.Font = ChatSettings.ChatBarFont
	chatBar.Parent.TextLabel.Font = ChatSettings.ChatBarFont
	chatBar.TextSize = ChatSettings.ChatBarTextSize
	chatBar.Parent.TextLabel.TextSize = ChatSettings.ChatBarTextSize

	chatBar.Parent.Parent.Parent.BackgroundColor3 = ChatSettings.ChatBarBackGroundColor
	chatBar.Parent.Parent.BackgroundColor3 = ChatSettings.ChatBarBoxColor

	local PHONE_SCREEN_WIDTH = 648
	local TABLET_SCREEN_WIDTH = 1024

	local isMobile = false

	if (screenGui.AbsoluteSize.X <= PHONE_SCREEN_WIDTH) or (screenGui.AbsoluteSize.X <= TABLET_SCREEN_WIDTH) then
		isMobile = true
		chatBar.Parent.TextLabel.Text = "Tap here to chat"
	end

	chatBar:GetPropertyChangedSignal("Text"):Connect(function()
		local text = chatBar.Text
		text = chatBar.Text:sub(1,ChatSettings.MaximumMessageLength)
		realText.Value = (if channelText:GetAttribute("Command") then channelText:GetAttribute("Command") else "") .. text

		local commandModules = TCS.LegacyChatService.ChatCommands.Client
		local commands = commandModules:GetChildren()
		local commandUtil = require(commandModules:WaitForChild("Util"))
		for i = 1, #commands do
			if commands[i]:IsA("ModuleScript") and commands[i].Name ~= "Util" then
				local commandProcessor = require(commands[i])
				local processorType = commandProcessor[commandUtil.KEY_COMMAND_PROCESSOR_TYPE]
				local processorFunction = commandProcessor[commandUtil.KEY_PROCESSOR_FUNCTION]
				if processorType == commandUtil.IN_PROGRESS_MESSAGE_PROCESSOR then
					processorFunction(chatBar.Text)
				end
			end
		end

		local TextChannel = TCS.ChatInputBarConfiguration.TargetTextChannel

		if text == "" then
			local MessageMode = chatBar.Parent.MessageMode
			MessageMode.Size = UDim2.new(0,0,0,0)
			MessageMode.Text = ""
			MessageMode.TextColor3 = Color3.fromRGB(35, 76, 142)
			MessageMode.Visible = false

			chatBar.Position = UDim2.new(0, 0, 0, 0)
			chatBar.Size = UDim2.new(1, 0, 1, 0)

			channelText.Value = ""
			realText.Value = ""
			
			channelText:SetAttribute("Command", "")
		elseif string.sub(text, 1, 6) == "/team " or string.sub(text, 1, 3) == "/t " then

			if string.sub(text, 1, 5) == "/team" then
				chatBar.Text = " " .. string.sub(text, 7, #text)
				channelText:SetAttribute("Command", "/team")
			else
				chatBar.Text = " " .. string.sub(text, 4, #text)
				channelText:SetAttribute("Command", "/t")
			end

			channelText.Value = "[Team]"

			local MessageMode = chatBar.Parent.MessageMode
			MessageMode.Size = UDim2.new(0, 46, 1, 0)
			MessageMode.Text = channelText.Value
			MessageMode.TextColor3 = if plr.Team then plr.TeamColor.Color else Color3.fromRGB(35, 76, 142)
			MessageMode.Visible = true

			chatBar.Position = UDim2.new(0, 46, 0, 0)
			chatBar.Size = UDim2.new(1, -46, 1, 0)

			if not plr.Team then return end

			TCS.ChatInputBarConfiguration.TargetTextChannel = TCS.LegacyChatService.Channels.TeamChannels:FindFirstChild(plr.TeamColor.Name)
			TextChannel = TCS.ChatInputBarConfiguration.TargetTextChannel

		elseif string.sub(text, 1, 9) == "/whisper " or string.sub(text, 1, 3) == "/w " then

			local str = string.split(text, " ")

			if not str[2] then return end

			local plr2Str = str[2]
			local plr2: Player = findPlayerByName(plr2Str, {plr})
			if not plr2 then return end

			local channel = whisperEvent:InvokeServer(plr2)

			TCS.ChatInputBarConfiguration.TargetTextChannel = channel
			TextChannel = TCS.ChatInputBarConfiguration.TargetTextChannel

			if string.sub(text, 1, 8) == "/whisper" then
				chatBar.Text = " " .. string.sub(text, 10, #text)
				channelText:SetAttribute("Command", "/whisper")
			else
				chatBar.Text = " " .. string.sub(text, 4, #text)
				channelText:SetAttribute("Command", "/w")
			end

			channelText.Value = `[To {if ChatSettings.PlayerDisplayNamesEnabled then plr2.DisplayName else plr.Name}]`

			local MessageMode = chatBar.Parent.MessageMode
			MessageMode.Size = UDim2.new(0, 46, 1, 0)
			MessageMode.Text = channelText.Value
			MessageMode.TextColor3 = Color3.fromRGB(102, 14, 102)
			MessageMode.Visible = true

			chatBar.Position = UDim2.new(0, MessageMode.AbsoluteSize.X, 0, 0)
			chatBar.Size = UDim2.new(1, -MessageMode.AbsoluteSize.X, 1, 0)

		end
	end)

	local event
	if not isMobile then
		event = TCS.ChatInputBarConfiguration:GetPropertyChangedSignal("KeyboardKeyCode"):Connect(function()
			chatBar.Parent.TextLabel.Text = 'To chat click here or press "' .. UIS:GetStringForKeyCode(TCS.ChatInputBarConfiguration.KeyboardKeyCode) .. '" key'
		end)
	end

	chatBar.FocusLost:Connect(function(EnterPressed: boolean)
		if EnterPressed and chatBar.Text ~= "" then
			local TextChannel = TCS.ChatInputBarConfiguration.TargetTextChannel

			if TextChannel then
				local text = chatBar.Text
				chatBar.Text = ""

				local send = true

				if text == " " then return end

				if text:sub(1, 3) == "/w " and TextChannel.Parent ~= TCS.LegacyChatService.Channels.Whispers then
					TextChannel:DisplaySystemMessage("<font color='#f53232'>Speaker '" .. text:sub(4, #text) .. "' does not exist.</font>")
					chatBar.Parent.TextLabel.Visible = true
					return
				end

				if (realText.Value == "/t" or realText.Value:sub(1, 3) == "/t ") and not plr.Team then
					TextChannel:DisplaySystemMessage("<font color='#f53232'>You cannot team chat if you are not on a team!</font>")
					chatBar.Parent.TextLabel.Visible = true
					return
				end

				if not game:GetService("Chat"):CanUserChatAsync(plr.UserId) then return end
				
				local clearCommand: TextChatCommand
				if TCS:FindFirstChild("TextChatCommands") then
					clearCommand = TCS:FindFirstChild("TextChatCommands"):FindFirstChild("RBXClearCommand")
				end
				if clearCommand then
					clearCommand.Triggered:Connect(function(source, text)
						local chatLogs = chatBar.Parent.Parent.Parent.Parent.Parent.ChatChannelParentFrame.Frame_MessageLogDisplay.Scroller
						if not ChatSettings.ShowChannelsBar then
							local list = chatLogs.UIListLayout:Clone()
							chatLogs:ClearAllChildren()
							list.Parent = chatLogs
						else
							for i,v in pairs(chatLogs:GetChildren()) do
								if v:GetAttribute("IsChannel") == true then
									local list = v.UIListLayout:Clone()

									v:ClearAllChildren()

									list.Parent = chatLogs[TCS.ChatInputBarConfiguration.TargetTextChannel.Name]
								end
							end
						end
					end)
				end

				if string.sub(text, 1, 9) == "/channel " or string.sub(text, 1, 3) == "/c " then

					local str = string.split(text, " ")

					if not str[2] then return end

					local channelStr = str[2]

					local found = false

					if channelStr == "Team" then
						local channel = TCS.LegacyChatService.Channels.TeamChannels:FindFirstChild(plr.TeamColor.Name)
						if channel then
							found = channel
						end
					else
						for i,v in pairs(TCS.LegacyChatService.Channels.TextChannels:GetChildren()) do
							if v.Name == channelStr then
								found = v
							end
						end
					end

					if not found then
						TextChannel:DisplaySystemMessage("<font color='#f53232'>You are not in channel: '" .. channelStr .. "'</font>")
						chatBar.Parent.TextLabel.Visible = true
						return
					end

					TCS.ChatInputBarConfiguration.TargetTextChannel = found
					TextChannel = found

					if ChatSettings.ShowChannelsBar then
						chatBar.Text = ""
						chatBar.Parent.TextLabel.Visible = true
						return
					end

					if string.sub(text, 1, 8) == "/channel" then
						channelText:SetAttribute("Command", "/channel " .. channelStr)
					else
						channelText:SetAttribute("Command", "/c " .. channelStr)
					end

					chatBar.Text = " "

					if found.Parent == TCS.LegacyChatService.TeamChannels then
						channelText.Value = "[Team]"
					else
						channelText.Value = `[{found.Name}]`
					end

					local MessageMode = chatBar.Parent.MessageMode
					MessageMode.Size = UDim2.new(0, 0, 1, 0)
					MessageMode.Text = channelText.Value
					--MessageMode.TextColor3 = plr.TeamColor.Color
					MessageMode.Visible = true

					chatBar.Position = UDim2.new(0, MessageMode.AbsoluteSize.X, 0, 0)
					chatBar.Size = UDim2.new(1, -MessageMode.AbsoluteSize.X, 1, 0)

					chatBar.Parent.TextLabel.Position = UDim2.new(0, MessageMode.AbsoluteSize.X, 0, 0)
					chatBar.Parent.TextLabel.Size = UDim2.new(1, -MessageMode.AbsoluteSize.X, 1, 0)
					chatBar.Parent.TextLabel.Visible = true

					send = false

					task.spawn(function()
						task.wait()
						chatBar.Text = " "
					end)
				end

				if not send then return end

				TextChannel:SendAsync(text)
				-- Anything under SendAsync seems to not run
			end
			--if TCS.LegacyChatService:FindFirstChild("TextChannels") then
			--	local GeneralChannel = TCS.LegacyChatService.TextChannels:FindFirstChild("All")
			--	if GeneralChannel and not ChatSettings.ShowChannelsBar then
			--		TCS.ChatInputBarConfiguration.TargetTextChannel = GeneralChannel
			--	end
			--end
		end

		if chatBar.Text ~= "" then return end

		chatBar.Parent.TextLabel.Visible = true

	end)

	chatBar.Focused:Connect(function()
		chatBar.Parent.TextLabel.Visible = false
	end)

	UIS.InputBegan:Connect(function(Input: InputObject)
		local TextBoxFocused = UIS:GetFocusedTextBox()
		if TextBoxFocused then return end

		if Input.KeyCode ~= TCS.ChatInputBarConfiguration.KeyboardKeyCode then return end

		task.wait()

		screenGui.Enabled = true
		chatBar:CaptureFocus()
		chatBar.Parent.TextLabel.Visible = false
		connections:Fire("ChatWindow","VisibilityStateChanged", true)
		screenGui.Frame.ActiveBool.Value = true
	end)

	chatBar.Parent.MessageMode.MouseButton1Click:Connect(function()
		chatBar.Text = ""

		local generalChannel = TCS.LegacyChatService.TextChannels:FindFirstChild("All")
		if not generalChannel then return end

		TCS.ChatInputBarConfiguration.TargetTextChannel = generalChannel

		channelText.Value = ""

		local MessageMode = chatBar.Parent.MessageMode
		MessageMode.Size = UDim2.new(0,0,0,0)
		MessageMode.Text = ""
		MessageMode.TextColor3 = Color3.fromRGB(35, 76, 142)
		MessageMode.Visible = false

		chatBar.Position = UDim2.new(0, 0, 0, 0)
		chatBar.Size = UDim2.new(1, 0, 1, 0)

		channelText.Value = ""
		realText.Value = ""
		channelText:SetAttribute("Command", "")

		chatBar:CaptureFocus()
	end)
end

return module