local RunService = game:GetService("RunService")
local rngs = { Random.new(), Random.new(), Random.new() }

RunService.Heartbeat:Connect(function()
	for _, rng in rngs do
		if math.random() < 0.5 then
			rng:NextInteger(1, 100)
		end
	end
end)

return {
	nextInteger = function(min: number, max: number): number
		return rngs[math.random(1, #rngs)]:NextInteger(min, max)
	end,
}
