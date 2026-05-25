export type Status = "idle" | "neutralizing" | "capturing" | "contested"

export type Outpost = {
	read owner: string,
	read status: Status,
	read captureProgress: number,
}

export type OutpostSnapshot = {
	guid: string,
	root: Folder,
	colliders: { BasePart },
}

local outpostTemplate: Outpost = {
	owner = "pve",
	status = "idle",
	captureProgress = 2,
}

return { outpostTemplate = outpostTemplate }
