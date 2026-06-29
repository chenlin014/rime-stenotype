keycode_map = require("input_event_codes")

local function get_keycode(key)
	if type(key) == "number" then
		return key
	elseif type(key) == "string" then
		return keycode_map[key:upper()]
	end

	return nil
end

local M = {}

function M.press_key(key)
	local code = get_keycode(key)

	if not code then return false end

	os.execute(string.format("ydotool key %d:1 %d:0", code, code))
	return true
end

return M
