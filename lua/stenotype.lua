local key_sim = require("ydotool")

local function query_w_limit(trans, input, seg, limit)
	limit = limit or 1

	local t = trans:query(input, seg)
	if not t then return {} end

	local cands = {}
	local cand_count = 0
	for cand in t:iter() do
		table.insert(cands, cand)
		cand_count = cand_count + 1
		if cand_count >= limit then break end
	end

	return cands
end

local function format_output(text, env)
	local out = text:gsub("\\\\", "\0")
	                :gsub("\\n", "\n")
	                :gsub("\\t", "\t")
	                :gsub("\\r", "\r")
	                :gsub("\0", "\\")

	local front_pad = ""
	if env.space_before then front_pad = " " end

	local back_pad = ""
	if env.space_after then back_pad = " " end

	env.space_before = env.engine.context:get_option("space_before")
	env.space_after = env.engine.context:get_option("space_after")

	out = front_pad .. out .. back_pad

	return out
end

local output_funcs = {}

output_funcs["{#[^(]+}"] = function(text, env)
	local key = text:gsub("^{#", ""):gsub("}$", "")
	env.engine.context:set_option("sending_key", true)
	key_sim.press_key(key)
end

output_funcs["{^[^^]+}"] = function(text, env)
	if env.prev_output:match(" $") then
		key_sim.press_key("backspace")
	end

	env.space_before = false
	return format_output(text:gsub("^{^", ""):gsub("}$", ""), env)
end

output_funcs["{[^^]+^}"] = function(text, env)
	env.space_after = false
	local out = format_output(text:gsub("^{", ""):gsub("%^}$", ""), env)
	env.space_before = false
	return out
end

local function output(text, env)
	env.outputting = true

	env.prev_text = text
	local out = text

	if output_funcs[text] then
		out = output_funcs[text](text, env)
		goto output
	end

	for pat, func in pairs(output_funcs) do
		if text:match(pat) then
			out = func(text, env)
			goto output
		end
	end

	out = format_output(out, env)

	::output::
	env.outputting = false

	if not out then
		env.prev_output = ""
		return
	end

	env.prev_output = out
	env.engine:commit_text(out)
end

local T = {}

function T.init(env)
	env.tran = Component.TableTranslator(env.engine, "translator", "table_translator")
	env.prev_text = ""
	env.prev_output = ""
	env.space_before = env.engine.context:get_option("space_before")
	env.space_after = env.engine.context:get_option("space_after")
	env.outputting = false
end

function T.fini(env)
end

function T.func(input, seg, env)
	if not input:match("/$") then return end
	if env.outputting then return end

	local context = env.engine.context

	local strokes = input
	local extra = nil

	local cands = query_w_limit(env.tran, strokes, seg, 9)
	if #cands == 0 then
		strokes = input:gsub("/[^/]+/$", "/")
		extra = input:match("/[^/]+/$")
		extra = extra and extra:gsub("^/", "")
		cands = query_w_limit(env.tran, strokes, seg, 9)

		if #cands == 0 then return end

		output(cands[1].text, env)

		if extra then
			cands = query_w_limit(env.tran, extra, seg, 9)
		else
			context:clear()
			return
		end
	end

	if #cands == 1 and cands[1].comment == "" then
		output(cands[1].text, env)
		context:clear()
	else
		if extra then
			context:clear()
			context:push_input(extra)
		end
		for _, cand in ipairs(cands) do
			yield(cand)
		end
	end
end

local P = {}

function P.init(env)
	env.sending_key = false
end

function P.fini(env)
end

function P.func(key, env)
	local sending_key = env.engine.context:get_option("sending_key")

	if sending_key then
		env.engine.context:set_option("sending_key", false)
		return 0
	end

	return 2
end

return { tran = T, proc = P }
