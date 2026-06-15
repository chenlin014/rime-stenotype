local T = {}

function T.init(env)
	local schema = Schema(env.engine.schema.schema_id or "")
	env.tran = Component.Translator(env.engine, schema, "translator", "table_translator")
end

function T.fini(env)
end

function T.func(input, seg, env)
	local t = env.tran:query(input, seg)
	if not t then return end
	for cand in t:iter() do
		yield(cand)
	end
end

return { tran=T }
