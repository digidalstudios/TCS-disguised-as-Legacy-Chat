local module = {}

local COMMAND_MODULES_VERSION = 1

local KEY_COMMAND_PROCESSOR_TYPE = "ProcessorType"
local KEY_PROCESSOR_FUNCTION = "ProcessorFunction"

---Command types.
---Process a command as it is being typed. This allows for manipulation of the chat bar.
local IN_PROGRESS_MESSAGE_PROCESSOR = 0
---Simply process a completed message.
local COMPLETED_MESSAGE_PROCESSOR = 1

function module.new()
	local obj = {}

	obj.COMMAND_MODULES_VERSION = COMMAND_MODULES_VERSION

	obj.KEY_COMMAND_PROCESSOR_TYPE = KEY_COMMAND_PROCESSOR_TYPE
	obj.KEY_PROCESSOR_FUNCTION = KEY_PROCESSOR_FUNCTION

	obj.IN_PROGRESS_MESSAGE_PROCESSOR = IN_PROGRESS_MESSAGE_PROCESSOR
	obj.COMPLETED_MESSAGE_PROCESSOR = COMPLETED_MESSAGE_PROCESSOR
	
	return obj
end

return module.new()