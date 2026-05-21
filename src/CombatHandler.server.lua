local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatService = require(script.Parent:WaitForChild("CombatService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatRemote = Remotes:WaitForChild("Combat")

CombatRemote.OnServerEvent:Connect(function(player, action, state)
	if action == "Attack" then
		CombatService:Attack(player)

	elseif action == "Block" then
		CombatService:SetBlocking(player, state)

	elseif action == "Parry" then
		CombatService:Parry(player)
	end
end)
