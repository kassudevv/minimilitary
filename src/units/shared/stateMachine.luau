local StateMachine = {}
StateMachine.__index = StateMachine

export type State = "idle" | "moving" | "targeting" | "dead"

type StateMachineData = {
	state: State,
	data: { [string]: any },

	handlers: { [string]: {
		onEnter: (string) -> (),
		tick: (number) -> (),
		onExit: (string) -> (),
	} },
}

export type StateMachine = setmetatable<StateMachineData, typeof(StateMachine)>

function StateMachine.new(initial: StateMachineData): StateMachine
	local self = setmetatable({} :: StateMachineData, StateMachine)

	self.state = initial.state
	self.data = initial.data
	self.handlers = initial.handlers

	return self
end

function StateMachine.tick(self: StateMachine, dt: number)
	self.handlers[self.state].tick(dt)
end

function StateMachine.transition(self: StateMachine, newState: State, data: { [string]: any })
	local prev = self.state

	-- run exit hook for current state
	local current = self.handlers[prev]
	if current and current.onExit then
		current.onExit(newState)
	end

	-- apply new state
	self.state = newState
	self.data = data

	-- run entry hook for new state
	local next = self.handlers[newState]
	if next and next.onEnter then
		next.onEnter(prev)
	end
end

return StateMachine
