local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("Combat")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		CombatRemote:FireServer("Attack")
	end

	if input.KeyCode == Enum.KeyCode.F then
		CombatRemote:FireServer("Block", true)
	end

	if input.KeyCode == Enum.KeyCode.R then
		CombatRemote:FireServer("Parry")
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		CombatRemote:FireServer("Block", false)
	end
end)

CombatRemote.OnClientEvent:Connect(function(action, attacker, target, combo, blocked)
	if action == "Swing" then
		print(attacker.Name .. " swing combo " .. combo)

	elseif action == "Hit" then
		print(attacker.Name .. " hit", target, "combo:", combo, "blocked:", blocked)

	elseif action == "Parry" then
		print("Parry!")
	end
end)
