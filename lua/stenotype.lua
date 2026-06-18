local function output(text, env)
	local front_pad = " "

	env.engine:commit_text(front_pad..text)
end

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

local T = {}

function T.init(env)
	env.tran = Component.TableTranslator(env.engine, "translator", "table_translator")
end

function T.fini(env)
end

function T.func(input, seg, env)
	if not input:match("/$") then return end

	local strokes = input
	local extra = nil

	::query::
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
			env.engine.context:clear()
			return
		end
	end

	if #cands == 1 and cands[1].comment == "" then
		env.engine.context:clear()
		output(cands[1].text, env)
	else
		if extra then
			env.engine.context:clear()
			env.engine.context:push_input(extra)
		end
		for _, cand in ipairs(cands) do
			yield(cand)
		end
	end
end

return { tran=T }
