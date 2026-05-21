local CombatService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatRemote = Remotes:WaitForChild("Combat")

local PlayerData = {}

local CONFIG = {
	ComboResetTime = 1.2,
	AttackCooldown = 0.42,
	AttackDuration = 0.55,
	HitDelay = 0.16,

	MaxCombo = 4,

	HitboxSize = Vector3.new(5, 5, 6),
	HitboxOffset = CFrame.new(0, 0, -3),

	MaxHitDistance = 7,
	MinDot = 0.35,

	StunTime = 0.45,
	FinisherStunTime = 0.8,

	KnockbackForce = 45,
	KnockbackUpForce = 12,

	EffectRange = 90,

	ParryWindow = 0.25,
	BlockDamageMultiplier = 0.25,
}

local DAMAGE = {
	[1] = 7,
	[2] = 7,
	[3] = 9,
	[4] = 14,
}

local function GetData(player)
	if not PlayerData[player] then
		PlayerData[player] = {
			Combo = 1,
			LastAttack = 0,
			LastComboTime = 0,
		}
	end

	return PlayerData[player]
end

local function GetCharacter(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 then return end
	if not root then return end

	return character, humanoid, root
end

local function IsStunned(humanoid)
	local stunEnd = humanoid:GetAttribute("StunEnd")
	return stunEnd and os.clock() < stunEnd
end

local function HasIFrames(humanoid)
	local iframeEnd = humanoid:GetAttribute("IFrameEnd")
	return iframeEnd and os.clock() < iframeEnd
end

local function IsBlocking(humanoid)
	return humanoid:GetAttribute("Blocking") == true
end

local function IsParrying(humanoid)
	local parryEnd = humanoid:GetAttribute("ParryEnd")
	return parryEnd and os.clock() < parryEnd
end

local function SameTeam(player, targetPlayer)
	if not player or not targetPlayer then
		return false
	end

	if player.Team ~= nil and targetPlayer.Team ~= nil and player.Team == targetPlayer.Team then
		return true
	end

	return false
end

local function FireNearby(originPosition, ...)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root and (root.Position - originPosition).Magnitude <= CONFIG.EffectRange then
			CombatRemote:FireClient(player, ...)
		end
	end
end

local function StunTarget(humanoid, duration)
	local now = os.clock()
	local newStunEnd = now + duration
	local currentStunEnd = humanoid:GetAttribute("StunEnd") or 0

	if newStunEnd <= currentStunEnd then
		return
	end

	humanoid:SetAttribute("StunEnd", newStunEnd)
	humanoid:SetAttribute("Stunned", true)

	if humanoid:GetAttribute("OriginalWalkSpeed") == nil then
		humanoid:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
	end

	if humanoid:GetAttribute("OriginalJumpPower") == nil then
		humanoid:SetAttribute("OriginalJumpPower", humanoid.JumpPower)
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	task.delay(duration, function()
		if not humanoid or not humanoid.Parent then
			return
		end

		local stunEnd = humanoid:GetAttribute("StunEnd") or 0

		if os.clock() < stunEnd then
			return
		end

		humanoid.WalkSpeed = humanoid:GetAttribute("OriginalWalkSpeed") or 16
		humanoid.JumpPower = humanoid:GetAttribute("OriginalJumpPower") or 50

		humanoid:SetAttribute("Stunned", false)
		humanoid:SetAttribute("StunEnd", nil)
		humanoid:SetAttribute("OriginalWalkSpeed", nil)
		humanoid:SetAttribute("OriginalJumpPower", nil)
	end)
end

local function ApplyKnockback(attackerRoot, targetRoot, combo)
	if combo ~= CONFIG.MaxCombo then
		return
	end

	local offset = targetRoot.Position - attackerRoot.Position

	if offset.Magnitude <= 0.01 then
		offset = attackerRoot.CFrame.LookVector
	end

	local direction = offset.Unit

	local attachment = Instance.new("Attachment")
	attachment.Parent = targetRoot

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = direction * CONFIG.KnockbackForce + Vector3.new(0, CONFIG.KnockbackUpForce, 0)
	velocity.Parent = targetRoot

	Debris:AddItem(velocity, 0.15)
	Debris:AddItem(attachment, 0.15)
end

local function IsValidTarget(attackerPlayer, attackerCharacter, attackerRoot, targetModel)
	if not targetModel or targetModel == attackerCharacter then
		return false
	end

	local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")

	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end

	if not targetRoot then
		return false
	end

	if HasIFrames(targetHumanoid) then
		return false
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)

	if SameTeam(attackerPlayer, targetPlayer) then
		return false
	end

	local offset = targetRoot.Position - attackerRoot.Position
	local distance = offset.Magnitude

	if distance > CONFIG.MaxHitDistance then
		return false
	end

	if distance <= 0.01 then
		return true, targetHumanoid, targetRoot, targetPlayer
	end

	local direction = offset.Unit
	local dot = attackerRoot.CFrame.LookVector:Dot(direction)

	if dot < CONFIG.MinDot then
		return false
	end

	return true, targetHumanoid, targetRoot, targetPlayer
end

function CombatService:GetCombo(player)
	local data = GetData(player)
	local now = os.clock()

	if now - data.LastComboTime > CONFIG.ComboResetTime then
		data.Combo = 1
	end

	return data.Combo
end

function CombatService:CanAttack(player)
	local data = GetData(player)
	local now = os.clock()

	if now - data.LastAttack < CONFIG.AttackCooldown then
		return false
	end

	local character, humanoid = GetCharacter(player)

	if not character or not humanoid then
		return false
	end

	if IsStunned(humanoid) then
		return false
	end

	if humanoid:GetAttribute("Attacking") then
		return false
	end

	if humanoid:GetAttribute("Blocking") then
		return false
	end

	return true
end

function CombatService:CreateHitbox(player, combo)
	local character, humanoid, root = GetCharacter(player)
	if not character then return end

	local hitTargets = {}

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	local hitboxCFrame = root.CFrame * CONFIG.HitboxOffset
	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, CONFIG.HitboxSize, overlapParams)

	for _, part in ipairs(parts) do
		local targetModel = part:FindFirstAncestorOfClass("Model")

		if targetModel and not hitTargets[targetModel] then
			local valid, targetHumanoid, targetRoot = IsValidTarget(player, character, root, targetModel)

			if valid then
				hitTargets[targetModel] = true

				if IsParrying(targetHumanoid) then
					StunTarget(humanoid, 0.75)
					FireNearby(root.Position, "Parry", player, targetModel)
					continue
				end

				local damage = DAMAGE[combo] or 5
				local blocked = IsBlocking(targetHumanoid)

				if blocked then
					damage *= CONFIG.BlockDamageMultiplier
				end

				targetHumanoid:TakeDamage(damage)

				if not blocked then
					local stunDuration = combo == CONFIG.MaxCombo and CONFIG.FinisherStunTime or CONFIG.StunTime
					StunTarget(targetHumanoid, stunDuration)
					ApplyKnockback(root, targetRoot, combo)
				end

				FireNearby(root.Position, "Hit", player, targetModel, combo, blocked)
			end
		end
	end
end

function CombatService:IncrementCombo(player)
	local data = GetData(player)

	data.Combo += 1

	if data.Combo > CONFIG.MaxCombo then
		data.Combo = 1
	end
end

function CombatService:Attack(player)
	if not self:CanAttack(player) then
		return
	end

	local character, humanoid, root = GetCharacter(player)
	if not character then return end

	local data = GetData(player)
	local now = os.clock()

	data.LastAttack = now

	local combo = self:GetCombo(player)
	data.LastComboTime = now

	humanoid:SetAttribute("Attacking", true)

	FireNearby(root.Position, "Swing", player, combo)

	task.delay(CONFIG.HitDelay, function()
		local currentCharacter, currentHumanoid = GetCharacter(player)

		if not currentCharacter or not currentHumanoid then
			return
		end

		if currentHumanoid ~= humanoid then
			return
		end

		if not currentHumanoid:GetAttribute("Attacking") then
			return
		end

		self:CreateHitbox(player, combo)
	end)

	self:IncrementCombo(player)

	task.delay(CONFIG.AttackDuration, function()
		if humanoid and humanoid.Parent then
			humanoid:SetAttribute("Attacking", false)
		end
	end)
end

function CombatService:SetBlocking(player, state)
	local character, humanoid = GetCharacter(player)
	if not character then return end

	if IsStunned(humanoid) then
		humanoid:SetAttribute("Blocking", false)
		return
	end

	humanoid:SetAttribute("Blocking", state == true)
end

function CombatService:Parry(player)
	local character, humanoid = GetCharacter(player)
	if not character then return end

	if IsStunned(humanoid) then
		return
	end

	local now = os.clock()

	humanoid:SetAttribute("Blocking", true)
	humanoid:SetAttribute("ParryEnd", now + CONFIG.ParryWindow)

	task.delay(CONFIG.ParryWindow, function()
		if humanoid and humanoid.Parent then
			humanoid:SetAttribute("ParryEnd", nil)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData[player] = nil
end)

return CombatService
