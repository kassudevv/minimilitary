-- -- Tick.lua
-- local RunService = game:GetService("RunService")

-- local Tick = {}
-- Tick.__index = Tick

-- local systems: { { accum: number, interval: number, fn: (any, number) -> (), objects: { any } } } = {}

-- RunService.Heartbeat:Connect(function(dt)
-- 	for _, system in systems do
-- 		system.accum += dt

-- 		if system.accum < system.interval then
-- 			continue
-- 		end

-- 		local elapsed = system.accum
-- 		system.accum = 0

-- 		for _, obj in system.objects do
-- 			system.fn(obj, elapsed)
-- 		end
-- 	end
-- end)

-- function Tick.bind(interval: number, objects: { any }, fn: (any, number) -> ())
-- 	local system = {
-- 		interval = interval,
-- 		accum = 0,
-- 		objects = objects,
-- 		fn = fn,
-- 	}

-- 	table.insert(systems, system)

-- 	local handle = {}

-- 	function handle:stop()
-- 		for i, s in systems do
-- 			if s == system then
-- 				table.remove(systems, i)
-- 				break
-- 			end
-- 		end
-- 	end

-- 	return handle
-- end

-- return Tick
-- Tick.lua

local RunService = game:GetService("RunService")

local Tick = {}
Tick.__index = Tick

local systems: { { accum: number, interval: number, fn: (number) -> () } } = {}

-- internal shared loop (IMPORTANT: only one Heartbeat connection)
RunService.Heartbeat:Connect(function(dt)
	for _, system in systems do
		system.accum += dt

		if system.accum < system.interval then
			continue
		end

		local elapsed = system.accum
		system.accum = 0

		system.fn(elapsed)
	end
end)

function Tick.every(interval: number, fn: (number) -> ())
	local system = {
		interval = interval,
		accum = 0,
		fn = fn,
	}

	table.insert(systems, system)

	local handle = {}

	function handle:stop()
		for i, s in systems do
			if s == system then
				table.remove(systems, i)
				break
			end
		end
	end

	return handle
end

-- Optional helper for object arrays (your RTS case)
function Tick.bind(interval: number, objects: { any }, fn: (any, number) -> ())
	return Tick.every(interval, function(dt)
		for _, obj in objects do
			fn(obj, dt)
		end
	end)
end

return Tick
