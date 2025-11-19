--------------------------------------------------------------------------------
-- Logistics phase
--------------------------------------------------------------------------------

local stlib = require("lib.core.strace")
local slib = require("lib.signal")
local nmlib = require("lib.core.math.numeric")
local tlib = require("lib.core.table")
local thread_lib = require("lib.core.thread")
local cs2 = _G.cs2

local pairs = _G.pairs
local next = _G.next
local table_size = _G.table_size
local add_workload = thread_lib.add_workload

---@class Cybersyn.LogisticsThread
---@field public frame_index uint
---@field public req_index int?
---@field public prov_index int?
---@field public train_index int?
---@field public requester Cybersyn.Order
---@field public allocations table
local LogisticsThread = _G.cs2.LogisticsThread

---@param requester Cybersyn.Order
---@param index int
function LogisticsThread:logistics_requester(requester, index)
	self.requester = requester
	self.allocations = {}
end

---@param provider Cybersyn.Order
---@param index int
function LogisticsThread:logistics_provider(provider, index) end

---@param train Cybersyn.Train
---@param index int
function LogisticsThread:logistics_train(train, index) end

--------------------------------------------------------------------------------
-- Init ops
--------------------------------------------------------------------------------

function LogisticsThread:logistics_enum_trains()
	local trains = {}
	local avail_trains = {}
	for _, veh in pairs(storage.vehicles) do
		trains[#trains + 1] = veh
		avail_trains[#avail_trains + 1] = true
	end
	self.trains = trains
	self.avail_trains = avail_trains
	add_workload(self.workload_counter, #avail_trains)
end

function LogisticsThread:logistics_enum_requesters()
	-- Requester sort
	table.sort(self.requesters, function(a, b)
		local a_prio, b_prio = a.priority, b.priority
		if a_prio > b_prio then return true end
		if a_prio < b_prio then return false end
		local a_last = a.starvation or 0
		local b_last = b.starvation or 0
		if a_last < b_last then return true end
		if a_last > b_last then return false end
		return a.busy_value < b.busy_value
	end)
	add_workload(self.workload_counter, #self.requesters)
end

function LogisticsThread:logistics_enum_providers()
	table.sort(self.providers, function(a, b) return a.priority <= b.priority end)
	add_workload(self.workload_counter, #self.providers)
end

--------------------------------------------------------------------------------
-- Thread handlers
--------------------------------------------------------------------------------

function LogisticsThread:enter_logistics()
	-- No-work early-out cases
	if
		not self.providers
		or not self.requesters
		or (not next(self.providers))
		or (not next(self.requesters))
	then
		self:set_state("init")
		return
	end

	self.frame_index = 0
end

function LogisticsThread:logistics()
	local frame_trains, frame_provs, frame_reqs = 0, 0, 0
	self.frame_index = self.frame_index + 1
	local frame_index = self.frame_index

	-- Init frames
	if frame_index == 1 then
		self:logistics_enum_requesters()
		return
	elseif frame_index == 2 then
		self:logistics_enum_providers()
		return
	elseif frame_index == 3 then
		self:logistics_enum_trains()
		return
	end

	while true do
		if self.train_index then
			self.train_index = self.train_index + 1
			local index = self.train_index --[[@as int]]
			local train = self.trains[index]
			local avail = self.trains[index]
			if not train then
				self.train_index = nil
			elseif avail then
				frame_trains = frame_trains + 1
				self:logistics_train(train, index)
			end
		elseif self.prov_index then
			self.prov_index = self.prov_index + 1
			local index = self.prov_index --[[@as int]]
			local prov = self.providers[index]
			if not prov then
				self.prov_index = nil
			else
				frame_provs = frame_provs + 1
				self:logistics_provider(prov, index)
			end
		elseif self.req_index then
			self.req_index = self.req_index + 1
			local index = self.req_index --[[@as int]]
			local req = self.requesters[index]
			if not req then
				-- This is the end of the logistics loop. All requests have been
				-- seen.
				self.req_index = nil
				self:set_state("init")
				break
			else
				frame_reqs = frame_reqs + 1
				self:logistics_requester(req, index)
			end
		else
			-- Should not reach here
			stlib.error("Reached a degenerate dispatch loop state. Aborting loop.")
			self:set_state("init")
			break
		end

		::checkpoint::
		if self.workload_counter.workload >= self.max_workload then break end
	end
end

function LogisticsThread:exit_logistics()
	self.req_index = nil
	self.prov_index = nil
	self.train_index = nil
end
