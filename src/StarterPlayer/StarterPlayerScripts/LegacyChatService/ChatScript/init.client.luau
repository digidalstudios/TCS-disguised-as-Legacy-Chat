local plr = game:GetService("Players").LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()

local canChat = game:GetService("Chat"):CanUserChatAsync(plr.UserId)

if not canChat or game:GetService("TextChatService").ChatVersion ~= Enum.ChatVersion.TextChatService then
	warn("ur not on TextChatService lel\nChange it in game.TextChatService.ChatVersion")
	script:Destroy()
	return
end

local Chat = plr.PlayerGui:FindFirstChild("Chat")
if not Chat then return end

repeat
	local success = pcall(function()
		game:GetService("StarterGui"):GetCore("ChatBarDisabled")
	end)
	task.wait(1)
until
	success

local connections = require(game:GetService("ReplicatedStorage").LegacyChatService.Modules.ChatCore)
local ChatSettings = require(game:GetService("TextChatService").LegacyChatService.ChatSettings)

local PHONE_SCREEN_WIDTH = 648
local TABLET_SCREEN_WIDTH = 1024

local isPhone = false
local isTablet = false

if (Chat.AbsoluteSize.X <= PHONE_SCREEN_WIDTH) then
	isPhone = true
elseif (Chat.AbsoluteSize.X <= TABLET_SCREEN_WIDTH) then
	isTablet = true
end

Chat.Enabled = true
Chat.DisplayOrder = ChatSettings.ScreenGuiDisplayOrder
Chat.Frame.Position = ChatSettings.DefaultWindowPosition
if isPhone then
	Chat.Frame.Size = ChatSettings.DefaultWindowSizePhone
elseif isTablet then
	Chat.Frame.Size = ChatSettings.DefaultWindowSizeTablet
--else
--	Chat.Frame.Size = ChatSettings.DefaultWindowSizeDesktop
end

if ChatSettings.ShowChannelsBar then
	Chat.Frame.ChannelsBarParentFrame.Visible = true
	Chat.Frame.ChatChannelParentFrame.Size = UDim2.new(1, 0, 1, -80)
	Chat.Frame.ChatChannelParentFrame.Position = UDim2.new(0, 0, 0, 36)
end

local chatOpenState = true

local toggleChatState = function()
	chatOpenState = not chatOpenState
	connections:Fire("ChatWindow","VisibilityStateChanged",(chatOpenState))
	Chat.Enabled = chatOpenState
end

Chat:GetPropertyChangedSignal("Enabled"):Connect(function()
	connections:Fire("ChatWindow","VisibilityStateChanged",(Chat.Enabled))
end)

connections:Connect("ChatWindow","ToggleVisibility",toggleChatState)

local TweenService = game:GetService("TweenService")

local active = Chat.Frame.ActiveBool

local function activeFunc()	
	local tweenInfo = TweenInfo.new(ChatSettings.ChatDefaultFadeDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)

	TweenService:Create(Chat.Frame.ChatChannelParentFrame, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(Chat.Frame.ImageButton, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(Chat.Frame.ImageButton.ImageLabel, tweenInfo, {ImageTransparency = 1}):Play()
	TweenService:Create(Chat.Frame.ChatBarParentFrame.Frame, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(Chat.Frame.ChatBarParentFrame.Frame.BoxFrame, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar, tweenInfo, {TextTransparency = 1}):Play()
	TweenService:Create(Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.TextLabel, tweenInfo, {TextTransparency = 1}):Play()
end

local activeSpawn
local focused = false

Chat.Frame.MouseLeave:Connect(function()
	if focused then return end
	active.Value = false
end)

Chat.Frame.MouseEnter:Connect(function()
	active.Value = true
end)

active:GetPropertyChangedSignal("Value"):Connect(function()
	if active.Value then
		if activeSpawn then
			task.cancel(activeSpawn)
		end
		activeSpawn = nil

		local tweenInfo = TweenInfo.new(ChatSettings.ChatDefaultFadeDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)

		TweenService:Create(Chat.Frame.ChatChannelParentFrame, tweenInfo, {BackgroundTransparency = 0.6}):Play()
		TweenService:Create(Chat.Frame.ImageButton, tweenInfo, {BackgroundTransparency = 0.6}):Play()
		TweenService:Create(Chat.Frame.ImageButton.ImageLabel, tweenInfo, {ImageTransparency = 0.6}):Play()
		TweenService:Create(Chat.Frame.ChatBarParentFrame.Frame, tweenInfo, {BackgroundTransparency = 0.6}):Play()
		TweenService:Create(Chat.Frame.ChatBarParentFrame.Frame.BoxFrame, tweenInfo, {BackgroundTransparency = 0.6}):Play()
		TweenService:Create(Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar, tweenInfo, {TextTransparency = 0.4}):Play()
		TweenService:Create(Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.TextLabel, tweenInfo, {TextTransparency = 0.4}):Play()
		
	else
		task.wait(ChatSettings.ChatWindowBackgroundFadeOutTime)
		
		if active.Value then return end
		
		if activeSpawn then
			task.cancel(activeSpawn)
		end
		activeSpawn = nil
		activeSpawn = task.spawn(activeFunc)
	end
end)

connections:Connect("ChatWindow", "CoreGuiEnabled", function(enabled)
	Chat.Frame.Visible = enabled
end)

local chatbar = Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar

chatbar.Focused:Connect(function()
	focused = true
end)

chatbar.FocusLost:Connect(function()
	focused = false
end)

for i,v in pairs(script:GetChildren()) do
	if not v:IsA("ModuleScript") then continue end

	require(v).run(Chat, plr)
end

local function offsetToScale(offset: UDim2): UDim2
	local viewportSize = workspace.CurrentCamera.ViewportSize
	return UDim2.fromScale(
		offset.X.Offset / viewportSize.X,
		offset.Y.Offset / viewportSize.Y
	)
end

connections:Connect("SetCore", "ChatWindowSize", function(size: UDim2)
	size = offsetToScale(size)
	
	local newSize = UDim2.fromScale(
		math.clamp(size.X.Scale, ChatSettings.MinimumWindowSize.X.Scale, ChatSettings.MaximumWindowSize.X.Scale),
		math.clamp(size.Y.Scale, ChatSettings.MinimumWindowSize.Y.Scale, ChatSettings.MaximumWindowSize.Y.Scale)
	)
	
	Chat.Frame.Size = newSize
end)
connections:Connect("SetCore", "ChatWindowPosition", function(position: UDim2)
	Chat.Frame.Position = position
end)