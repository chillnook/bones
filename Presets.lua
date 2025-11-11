local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Bone = Bone

local Presets = {
	bones = { Maxxed={Female={},Male={}}, Midded={Female={},Male={}}, Minned={Female={},Male={}} },
	gender = nil :: ("Female"|"Male"|nil),
	localTriplets = { Female = {}, Male = {} }
}

local function locateRoot(model)
	return model:FindFirstChild("HumanoidRootPart")
		and model.HumanoidRootPart:FindFirstChild("LowerTorso")
		and model.HumanoidRootPart.LowerTorso:FindFirstChild("UpperTorso")
		and model.HumanoidRootPart.LowerTorso.UpperTorso:FindFirstChild("Neck")
end

local function findPresetBone(gender: string, preset: string, boneName: string): Bone?
	local flux = ReplicatedStorage:FindFirstChild("Flux")
	if not flux then return nil end
	local charPresets = flux:FindFirstChild("Assets")
		and flux.Assets:FindFirstChild("AvatarCreationSystem")
		and flux.Assets.AvatarCreationSystem:FindFirstChild("Character")
		and flux.Assets.AvatarCreationSystem.Character:FindFirstChild("HeadPresets")
	if not charPresets then return nil end

	local gFolder = charPresets:FindFirstChild(gender)
	if not gFolder then return nil end
	local presetFolder = gFolder:FindFirstChild(preset)
	if not presetFolder then return nil end
	local neck = locateRoot(presetFolder)
	if not neck then return nil end
	return neck:FindFirstChild(boneName, true)
end

local function cacheTripletsForGender(g: string)
	Presets.localTriplets[g] = {}
	for boneName, midB in pairs(Presets.bones.Midded[g]) do
		local minB = Presets.bones.Minned[g][boneName]
		local maxB = Presets.bones.Maxxed[g][boneName]
		if minB and maxB then
			local parent = midB.Parent
			local parentWorld = parent:IsA("Bone") and parent.WorldCFrame
				or (parent:IsA("Attachment") and parent.WorldCFrame or parent.CFrame)

			-- Store parent-local CFrames (position + rotation)
			local minLocal = parentWorld:ToObjectSpace(minB.WorldCFrame)
			local midLocal = parentWorld:ToObjectSpace(midB.WorldCFrame)
			local maxLocal = parentWorld:ToObjectSpace(maxB.WorldCFrame)

			Presets.localTriplets[g][boneName] = {
				parentCF = parentWorld,
				min = minLocal,
				mid = midLocal,
				max = maxLocal,
			}
		end
	end
end

function Presets.Ensure(wanted: {[string]: boolean})
	if Presets.gender and next(Presets.localTriplets.Female) ~= nil then return end

	Presets.bones = { Maxxed={Female={},Male={}}, Midded={Female={},Male={}}, Minned={Female={},Male={}} }

	for presetName, genders in pairs(Presets.bones) do
		for g,_ in pairs(genders) do
			for bn,_ in pairs(wanted) do
				local b = findPresetBone(g, presetName, bn)
				if b then Presets.bones[presetName][g][bn] = b end
			end
		end
	end

	local RigUtil = require(ReplicatedStorage.Flux.Client.AvatarCreationSystem.UI.Categories.Shaping:WaitForChild("RigUtil"))
	local stageRoot = RigUtil.GetBoneRoot()
	if stageRoot then
		local refs = {"Mid_Nose","Left_Eye","Right_Eye","Chin"}
		local function score(g: string)
			local s=0
			for _,r in ipairs(refs) do
				local live = stageRoot:FindFirstChild(r, true)
				local mid = Presets.bones.Midded[g][r]
				if live and mid then s += (live.WorldPosition - mid.WorldPosition).Magnitude end
			end
			return s
		end
		Presets.gender = (score("Male") < score("Female")) and "Male" or "Female"
	else
		Presets.gender = "Female"
	end

	cacheTripletsForGender("Female")
	cacheTripletsForGender("Male")
end

function Presets.GetTriplet(boneName: string)
	if not Presets.gender then return nil end
	return Presets.localTriplets[Presets.gender][boneName]
end

-- Sims-style piecewise interpolation
local function piecewise(minVal, midVal, maxVal, sliderValue: number)
	sliderValue = math.clamp(sliderValue, -1, 1)
	if sliderValue >= 0 then
		return midVal + sliderValue * (maxVal - midVal)
	else
		return midVal + sliderValue * (midVal - minVal)
	end
end

-- Build PURE TRANSLATION offset for ONE semantic direction
function Presets.BuildTranslationOffsetForDirection(boneName: string, direction: "LR"|"UD"|"FB", sliderValue: number): Vector3?
	local trip = Presets.GetTriplet(boneName)
	if not trip then return nil end

	local RigUtil = require(ReplicatedStorage.Flux.Client.AvatarCreationSystem.UI.Categories.Shaping:WaitForChild("RigUtil"))
	local head = RigUtil.GetHeadPart()
	if not head then return nil end

	-- Get semantic world direction
	local worldDir
	if direction == "LR" then
		worldDir = head.CFrame.RightVector
	elseif direction == "UD" then
		worldDir = head.CFrame.UpVector
	else -- "FB"
		worldDir = head.CFrame.LookVector
	end

	local localDir = trip.parentCF:VectorToObjectSpace(worldDir)

	local minDist = trip.min.Position:Dot(localDir)
	local midDist = trip.mid.Position:Dot(localDir)
	local maxDist = trip.max.Position:Dot(localDir)

	local targetDist = piecewise(minDist, midDist, maxDist, sliderValue)

	local delta = (targetDist - midDist) * localDir
	return delta
end

function Presets.BuildRotationOffsetForAxis(boneName: string, axis: "Yaw"|"Pitch", sliderValue: number): CFrame?
	local trip = Presets.GetTriplet(boneName)
	if not trip then return nil end

	local function pureRot(cf: CFrame): CFrame
		local _,_,_, r00,r01,r02,r10,r11,r12,r20,r21,r22 = cf:GetComponents()
		return CFrame.new(0,0,0, r00,r01,r02,r10,r11,r12,r20,r21,r22)
	end

	local minRot = pureRot(trip.min)
	local midRot = pureRot(trip.mid)
	local maxRot = pureRot(trip.max)

	local RigUtil = require(ReplicatedStorage.Flux.Client.AvatarCreationSystem.UI.Categories.Shaping:WaitForChild("RigUtil"))
	local head = RigUtil.GetHeadPart()
	if not head then return nil end

	local worldAxis
	if axis == "Yaw" then
		worldAxis = head.CFrame.UpVector
	else -- "Pitch"
		worldAxis = head.CFrame.RightVector
	end

	local localAxis = trip.parentCF:VectorToObjectSpace(worldAxis)

	local function signedAngle(fromRot: CFrame, toRot: CFrame, axisVec: Vector3): number
		local fromLook = fromRot.LookVector
		local toLook = toRot.LookVector
		local dot = math.clamp(fromLook:Dot(toLook), -1, 1)
		local ang = math.acos(dot)
		local cross = fromLook:Cross(toLook)
		local sign = math.sign(axisVec:Dot(cross))
		return ang * sign
	end

	local angleToMax = signedAngle(midRot, maxRot, localAxis)
	local angleToMin = signedAngle(minRot, midRot, localAxis)

	local targetAngle = piecewise(angleToMin, 0, angleToMax, sliderValue)

	return CFrame.fromAxisAngle(localAxis, targetAngle)
end

function Presets.DeriveNormalizedFromCurrent(boneName: string): {[string]: number}?
	local trip = Presets.GetTriplet(boneName)
	if not trip then return nil end

	local RigUtil = require(ReplicatedStorage.Flux.Client.AvatarCreationSystem.UI.Categories.Shaping:WaitForChild("RigUtil"))
	local root = RigUtil.GetBoneRoot()
	if not root then return nil end
	local bone = root:FindFirstChild(boneName, true)
	if not (bone and bone:IsA("Bone")) then return nil end

	local head = RigUtil.GetHeadPart()
	if not head then return nil end

	local currentLocal = trip.parentCF:ToObjectSpace(bone.WorldCFrame)

	local function invPiecewise(cur, minV, midV, maxV)
		if math.abs(cur - midV) < 1e-6 then return 0 end
		if cur > midV then
			local d = (maxV - midV)
			if math.abs(d) < 1e-6 then return 0 end
			return math.clamp((cur - midV)/d, 0, 1)
		else
			local d = (midV - minV)
			if math.abs(d) < 1e-6 then return 0 end
			return -math.clamp((midV - cur)/d, 0, 1)
		end
	end

	local function getDirSlider(dir: "LR"|"UD"|"FB")
		local worldDir
		if dir == "LR" then worldDir = head.CFrame.RightVector
		elseif dir == "UD" then worldDir = head.CFrame.UpVector
		else worldDir = head.CFrame.LookVector end

		local localDir = trip.parentCF:VectorToObjectSpace(worldDir)
		local curDist = currentLocal.Position:Dot(localDir)
		local minDist = trip.min.Position:Dot(localDir)
		local midDist = trip.mid.Position:Dot(localDir)
		local maxDist = trip.max.Position:Dot(localDir)
		return invPiecewise(curDist, minDist, midDist, maxDist)
	end

	local function getRotSlider(axis: "Yaw"|"Pitch")
		local function pureRot(cf: CFrame): CFrame
			local _,_,_, r00,r01,r02,r10,r11,r12,r20,r21,r22 = cf:GetComponents()
			return CFrame.new(0,0,0, r00,r01,r02,r10,r11,r12,r20,r21,r22)
		end

		local curRot = pureRot(currentLocal)
		local minRot = pureRot(trip.min)
		local midRot = pureRot(trip.mid)
		local maxRot = pureRot(trip.max)

		local worldAxis = (axis == "Yaw") and head.CFrame.UpVector or head.CFrame.RightVector
		local localAxis = trip.parentCF:VectorToObjectSpace(worldAxis)

		local function signedAngle(fromRot: CFrame, toRot: CFrame, axisVec: Vector3): number
			local fromLook = fromRot.LookVector
			local toLook = toRot.LookVector
			local dot = math.clamp(fromLook:Dot(toLook), -1, 1)
			local ang = math.acos(dot)
			local cross = fromLook:Cross(toLook)
			local sign = math.sign(axisVec:Dot(cross))
			return ang * sign
		end

		local angleToMax = signedAngle(midRot, maxRot, localAxis)
		local angleToMin = signedAngle(minRot, midRot, localAxis)
		local curAngle = signedAngle(midRot, curRot, localAxis)

		return invPiecewise(curAngle, angleToMin, 0, angleToMax)
	end

	return {
		moveX = getDirSlider("LR"),
		moveY = getDirSlider("UD"),
		moveZ = getDirSlider("FB"),
		rotX  = getRotSlider("Yaw"),
		rotY  = getRotSlider("Pitch"),
	}
end

return Presets
