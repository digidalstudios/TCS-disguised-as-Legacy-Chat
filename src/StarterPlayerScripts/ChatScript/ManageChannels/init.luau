local TCS = game:GetService("TextChatService")

local module = {}

function module.run(Chat, plr)
	local chatFrame = Chat.Frame.ChannelsBarParentFrame.Frame

	local ChatSettings = require(TCS.LegacyChatService.ChatSettings)
	local remote = game:GetService("ReplicatedStorage").LegacyChatService.RemoteEvents.ManageChannels

	local parent = chatFrame.ScrollingBase.ScrollerSizer.ScrollerFrame
	local messages = chatFrame.Parent.Parent.ChatChannelParentFrame.Frame_MessageLogDisplay

	local function onClick(frame, channelName, channel)
		if ChatSettings.ShowChannelsBar then
			for i,v in pairs(frame.Parent:GetChildren()) do
				v.BackgroundFrame.UnselectedFrame.Visible = true
				v.BackgroundFrame.SelectedFrame.Visible = false
			end

			frame.BackgroundFrame.SelectedFrame.Visible = true
			frame.BackgroundFrame.UnselectedFrame.Visible = false
		end

		local scroller = chatFrame.Parent.Parent.ChatChannelParentFrame.Frame_MessageLogDisplay.Scroller

		for i,v in pairs(scroller:GetChildren()) do
			if v:GetAttribute("IsChannel") then
				v.Parent = script.Channels
			end
		end

		for i,v in pairs(script.Channels:GetChildren()) do
			if v.Name == channelName then
				v.Parent = scroller
			end
		end

		TCS.ChatInputBarConfiguration.TargetTextChannel = channel
	end

	remote.OnClientEvent:Connect(function(mode: string, channel: TextChannel, details)
		local channelName = channel.Name
		if mode == "Add" then

			local frame

			if ChatSettings.ShowChannelsBar then
				frame = script.ChannelTemplate:Clone()
				frame.Name = "Frame_" .. channel.Name

				if details["DisplayName"] then
					frame.BackgroundFrame.UnselectedFrame.TextButton.Text = details["DisplayName"]
					frame.BackgroundFrame.SelectedFrame.TextButton.Text = details["DisplayName"]
				else
					frame.BackgroundFrame.UnselectedFrame.TextButton.Text = channel.Name
					frame.BackgroundFrame.SelectedFrame.TextButton.Text = channel.Name
				end

				frame.Position = UDim2.new(#parent:GetChildren(), 0, 0, 0)

				frame.Parent = parent
			end

			local folder = Instance.new("Frame")
			folder.Name = channelName
			folder.Size = UDim2.new(1,0,1,0)
			folder.BackgroundTransparency = 1
			folder.Visible = true
			folder.AutomaticSize = Enum.AutomaticSize.Y
			folder:SetAttribute("IsChannel", true)
			folder.Parent = script.Channels

			local listLayout = Instance.new("UIListLayout")
			listLayout.Padding = UDim.new(0, 0)
			listLayout.FillDirection = Enum.FillDirection.Vertical
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.Wraps = false
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			listLayout.HorizontalFlex = Enum.UIFlexAlignment.None
			listLayout.ItemLineAlignment = Enum.ItemLineAlignment.Automatic
			listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			listLayout.VerticalFlex = Enum.UIFlexAlignment.None

			listLayout.Parent = folder

			if ChatSettings.ShowChannelsBar then

				local size = 0.5

				if #parent:GetChildren() >= ChatSettings.ChannelsBarFullTabSize then
					size = 1 / ChatSettings.ChannelsBarFullTabSize
				else
					size = 1 / #parent:GetChildren()
				end

				----------------------------------------
				-- Round into the third decimal point --
				--                                    --
				size *= 1000                          --
				size = math.floor(size)               --
				size = size / 1000					  --
				--                                    --
				--									  --
				----------------------------------------

				parent.Parent.Size = UDim2.new(size, 0, 1, 0)

				frame.BackgroundFrame.SelectedFrame.Visible = false
				frame.BackgroundFrame.UnselectedFrame.Visible = true

				frame.BackgroundFrame.TextButton.MouseButton1Click:Connect(function()
					onClick(frame, channelName, channel)
				end)

			end

			if details["WelcomeMessage"] ~= "" then
				channel:DisplaySystemMessage(details["WelcomeMessage"], "WelcomeMessage")
			end

		elseif mode == "Remove" and ChatSettings.ShowChannelsBar then
			if parent:FindFirstChild("Frame_" .. channel.Name) then
				parent["Frame_" .. channel.Name]:Destroy()
			end

			local size = 0.5

			if #parent:GetChildren() >= ChatSettings.ChannelsBarFullTabSize then
				size = 1 /  ChatSettings.ChannelsBarFullTabSize
			else
				size = 1 / #parent:GetChildren()
			end

			----------------------------------------
			-- Round into the third decimal point --
			--                                    --
			size *= 1000                          --
			size = math.floor(size)               --
			size = size / 1000					  --
			--                                    --
			--									  --
			----------------------------------------

			parent.Parent.Size = UDim2.new(size, 0, 1, 0)
		elseif mode == "Select" then
			TCS.ChatInputBarConfiguration.TargetTextChannel = channel
			if ChatSettings.ShowChannelsBar then
				onClick(parent["Frame_" .. channel.Name], channel.Name, channel)
			else
				onClick(nil, channel.Name, channel)
			end
		end

		if ChatSettings.ShowChannelsBar then
			local frame = chatFrame.ScrollingBase.ScrollerSizer.ScrollerFrame
			local rightButton = chatFrame.PositionalHelper.PageRightButton
			local leftButton = chatFrame.PageLeftButton

			leftButton.Visible = (frame.Position.X.Scale ~= 0)
			rightButton.Visible = ((frame.Position.X.Scale) >= -(#frame:GetChildren() - ChatSettings.ChannelsBarFullTabSize))
		end	
	end)

	if ChatSettings.ShowChannelsBar then
		TCS.ChatInputBarConfiguration:GetPropertyChangedSignal("TargetTextChannel"):Connect(function()
			local channel = TCS.ChatInputBarConfiguration.TargetTextChannel

			if channel.Parent ~= TCS.LegacyChatService.Channels.TextChannels then return end

			onClick(parent["Frame_" .. channel.Name], channel.Name, channel)
		end)
	end

	local parent = Chat.Frame.ChannelsBarParentFrame.Frame.PageLeftButton
	local frame = parent.Parent.ScrollingBase.ScrollerSizer.ScrollerFrame

	parent.MouseButton1Click:Connect(function()
		if frame.Position.X.Scale == 0 then
			parent.Visible = false
			return
		end

		frame.Position = UDim2.new(frame.Position.X.Scale + 1, frame.Position.X.Offset, frame.Position.Y.Scale, frame.Position.Y.Offset)

		if frame.Position.X.Scale == 0 then
			parent.Visible = false
		end
		if (frame.Position.X.Scale) ~= -(#frame:GetChildren() - ChatSettings.ChannelsBarFullTabSize) then
			parent.Parent.PositionalHelper.PageRightButton.Visible = true
		end
	end)

	local parent = Chat.Frame.ChannelsBarParentFrame.Frame.PositionalHelper.PageRightButton
	local frame = parent.Parent.Parent.ScrollingBase.ScrollerSizer.ScrollerFrame

	parent.MouseButton1Click:Connect(function()
		if (frame.Position.X.Scale) <= -(#frame:GetChildren() - ChatSettings.ChannelsBarFullTabSize) then
			parent.Visible = false
			return
		end

		frame.Position = UDim2.new(frame.Position.X.Scale - 1, frame.Position.X.Offset, frame.Position.Y.Scale, frame.Position.Y.Offset)

		if (frame.Position.X.Scale) <= -(#frame:GetChildren() - ChatSettings.ChannelsBarFullTabSize) then
			parent.Visible = false
		end
		if frame.Position.X.Scale ~= 0 then
			parent.Parent.Parent.PageLeftButton.Visible = true
		end
	end)
end

return module