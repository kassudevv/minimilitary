-- RollingScheduler.lua
local RunService = game:GetService("RunService")

local RollingScheduler = {}
RollingScheduler.__index = RollingScheduler

local systems: { { interval: number, accum: number, fn: (number) -> () } } = {}

local cursor = 1

local FRAME_BUDGET_MS = 0.25 -- tune this (0.15–0.5 typical RTS range)

-- system format:
-- {
--   interval: number,
--   accum: number,
--   fn: (dt: number) -> (),
-- }

function RollingScheduler.add(interval: number, fn: (number) -> ())
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
				if i <= cursor then
					cursor -= 1
				end
				break
			end
		end
	end

	return handle
end

RunService.Heartbeat:Connect(function(dt)
	local start = os.clock()

	if #systems == 0 then
		return
	end

	-- rolling budget loop
	while (os.clock() - start) * 1000 < FRAME_BUDGET_MS do
		local system = systems[cursor]

		if not system then
			cursor = 1
			break
		end

		system.accum += dt

		if system.accum >= system.interval then
			local elapsed = system.accum
			system.accum = 0

			system.fn(elapsed)
		end

		cursor += 1

		if cursor > #systems then
			cursor = 1
		end
	end
end)

return RollingScheduler
