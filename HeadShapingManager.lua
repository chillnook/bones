local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Maid       = require(ReplicatedStorage.Flux.Shared.Maid)
local Lifecycle  = require(ReplicatedStorage.Flux.Client.AvatarCreationSystem.UI:WaitForChild("ManagerLifecycle"))

local ShapingFolder = ReplicatedStorage.Flux.Client.AvatarCreationSystem.UI.Categories.Shaping
local RigUtil   = require(ShapingFolder:WaitForChild("RigUtil"))
local Presets   = require(ShapingFolder:WaitForChild("Presets"))
local Sym       = require(ShapingFolder:WaitForChild("Symmetry"))
local SliderUI  = require(ShapingFolder:WaitForChild("SliderUI"))

local _sliderTouched: { [string]: { [string]: boolean } } = {}

local M = {}

local TARGET_POS        = Vector3.new(-67.5, 2.3, 159.5)
local TARGET_YAW_DEG    = 180
local CAM_TWEEN_INFO    = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local BONE_MAP = {
	LeftEye      = "Left_Eye",
	RightEye     = "Right_Eye",
	Chin         = "Chin",
	Nose         = "Mid_Nose",
	LeftCheek    = "Left_Cheek",
	RightCheek   = "Right_Cheek",
	LeftEyebrow  = "Left_Eyebrow2",
	RightEyebrow = "Right_Eyebrow2",
	LeftEar      = "Left_EarShape0",
	RightEar     = "Right_EarShape0",
	Mouth        = "Tongue1",
}

local EXPANSION_MAP = {
	LeftEye = {"Left_Lo_EyeLid","Left_Up_EyeLid","Left_Up_EyeLid1","Left_Up_EyeLid2","Left_Up_EyeLid3","Left_Up_EyeLid4","Left_Up_EyeLid5","Left_Up_EyeLid6"},
	RightEye= {"Right_Lo_EyeLid","Right_Up_EyeLid","Right_Up_EyeLid1","Right_Up_EyeLid2","Right_Up_EyeLid3","Right_Up_EyeLid4","Right_Up_EyeLid5","Right_Up_EyeLid6"},
	LeftEyebrow  = {"Left_Eyebrow1","Left_Eyebrow2","Left_Eyebrow3","Left_Eyebrow4"},
	RightEyebrow = {"Right_Eyebrow1","Right_Eyebrow2","Right_Eyebrow3","Right_Eyebrow4"},
	LeftEar  = {"Left_EarShape0","Left_EarShape1","Left_EarShape2","Left_EarShape3"},
	RightEar = {"Right_EarShape0","Right_EarShape1","Right_EarShape2","Right_EarShape3"},
	LeftCheek  = {"Left_Cheek","Left_CheekBone1","Left_CheekBone2"},
	RightCheek = {"Right_Cheek","Right_CheekBone1","Right_CheekBone2"},
	Nose = {"Mid_Nose","MidNoseShape","NoseBridge1","NoseBridge2","Left_Nose.001","Left_Nose.002","Left_Nose.003","Left_Nose.004","Left_Nose.005","Right_Nose.001","Right_Nose.002","Right_Nose.003","Right_Nose.004","Right_Nose.005"},
	Mouth = {"Up_LIP","Up_LIPShape","Lo_LIP","Lo_LIPShape","Left_LIP_Corner","Right_LIP_Corner","Left_Lo_LIP","Right_Lo_LIP","Left_Up_LIP","Right_Up_LIP","Left_Up_LIPShape","Right_Up_LIPShape","Tongue1","Tongue2","Tongue3"},
	Chin = {"Chin","Chin_Shape_L","Chin_Shape_R"},
}

local SECTION_COLORS = {
	Eyebrows = Color3.fromRGB(255, 59, 48),
	Eyes     = Color3.fromRGB(255, 149, 0),
	Ears     = Color3.fromRGB(255, 214, 10),
	Cheek    = Color3.fromRGB(52, 199, 89),
	Nose     = Color3.fromRGB(10, 132, 255),
	Lips     = Color3.fromRGB(191, 90, 242),
	Chin     = Color3.fromRGB(255, 102, 178),
}

local HEAD_LOCAL_OFFSETS = {
	Chin = Vector3.new(0.0450, 0.2000, 0.0000),
	LeftCheek = Vector3.new(0.0400, 0.2200, 0.0000),
	LeftEar = Vector3.new(-0.0550, 0.2400, 0.0000),
	LeftEye = Vector3.new(0.0650, 0.2050, 0.0000),
	LeftEyebrow = Vector3.new(0.0600, 0.2250, 0.0000),
	Mouth = Vector3.new(0.0550, 0.1650, 0.0000),
	Nose = Vector3.new(0.0600, 0.1950, 0.0000),
	RightCheek = Vector3.new(0.0700, 0.2050, 0.0000),
	RightEar = Vector3.new(0.1850, 0.2650, 0.0000),
	RightEye = Vector3.new(0.1050, 0.1900, 0.0000),
	RightEyebrow = Vector3.new(0.1050, 0.2300, 0.0000),
}

local SLIDER_SPECS = {
	{ key="moveX", label="Move left/right",   flipSign=true },
	{ key="moveY", label="Move up/down",      flipSign=false },
	{ key="moveZ", label="Move back/forward", flipSign=false },
	{ key="rotY",  label="Tilt up/down",      flipSign=false },
	{ key="rotX",  label="Tilt left/right",   flipSign=false },
}

local BONES_WITH_ROTATION = {
	Right_Eyebrow1 = true,
	Left_Eyebrow1 = true,
	Lo_LIP = true,
	Left_Lo_LIP = true,
	Right_Lo_LIP = true,
	Right_Up_LIP = true,
	Left_Up_LIP = true,
	Up_LIP = true,
	Mid_Nose = true,
	Right_LIP_Corner = true,
	Left_LIP_Corner = true,
	Right_EarShape1 = true,
	Left_EarShape1 = true,
}

local SLIDER_RESPONSE = { gammaMove = 1.6, gammaRot = 1.8 }
local function shapedValue(v: number, isRotation: boolean): number
	local g = isRotation and SLIDER_RESPONSE.gammaRot or SLIDER_RESPONSE.gammaMove
	local s = math.sign(v); local a = math.abs(v)
	return s * (a ^ g)
end

local SMOOTH_HZ = 14

local maid
local _isOpen = false
local _prevCamCF: CFrame? = nil
local _panelFrame: Frame? = nil
local _dotsFrame: Frame? = nil
local _conn: RBXScriptConnection?
local _unregister: (() -> ())?

local _boneDots = {}
local _subDots = {}
local _cachedBones = {}

local _activeSelection: string? = nil
local _activeBoneName: string? = nil
local _activeBonePair = nil 

local _sliders = {}
local _sliderRawValues = { moveX=0, moveY=0, moveZ=0, rotX=0, rotY=0 }
local _sliderValues    = { moveX=0, moveY=0, moveZ=0, rotX=0, rotY=0 }
local _smoothedValues = {}
local _userHasAdjusted = false
local _didBaselineReset: { [string]: boolean } = {}

local function valueToScale(v: number): number return math.clamp((v + 1) * 0.5, 0, 1) end
local function scaleToValue(t: number): number return math.clamp(t * 2 - 1, -1, 1) end

local function sectionFor(boneName: string): string
	if boneName:find("Eyebrow") then return "Eyebrows" end
	if boneName:find("_Eye") then return "Eyes" end
	if boneName:find("Ear") then return "Ears" end
	if boneName:find("Cheek") then return "Cheek" end
	if boneName:find("Nose") or boneName == "Mid_Nose" or boneName == "MidNoseShape" or boneName:find("NoseBridge") then return "Nose" end
	if boneName:find("LIP") or boneName:find("Tongue") or boneName:find("Mouth") then return "Lips" end
	if boneName:find("Chin") then return "Chin" end
	return "Cheek"
end

local function applyDotStyle(dot: Instance, tagName: string)
	local color = SECTION_COLORS[sectionFor(tagName)] or Color3.new(1,1,1)
	local btn = dot:FindFirstChild("TextButton")
	if btn and btn:IsA("GuiObject") then
		pcall(function() btn.Visible = true end)
		pcall(function() btn.BackgroundTransparency = btn.Parent.BackgroundTransparency end)
		pcall(function() btn.BackgroundColor3 = color end)
		pcall(function() btn.ImageColor3 = color end)
		pcall(function() if btn:IsA("TextButton") then btn.TextColor3 = Color3.new(1,1,1) end end)
	end
end

local function getGui(): ScreenGui?
	local ok, bridge = pcall(function()
		return require(ReplicatedStorage.Flux.Client.AvatarCreationSystem.UI:WaitForChild("AvatarUISessionBridge"))
	end)
	if not ok or not bridge then return nil end
	return bridge:GetGui()
end

local function dotsParent(): Frame?
	local gui = getGui()
	local candidate = gui
		and gui:FindFirstChild("PanelFrame")
		and gui.PanelFrame:FindFirstChild("InteractionFrame")
		and gui.PanelFrame.InteractionFrame:FindFirstChild("Categories")
		and gui.PanelFrame.InteractionFrame.Categories:FindFirstChild("Shaping")
		and gui.PanelFrame.InteractionFrame.Categories.Shaping:FindFirstChild("ShapingDotsFrame")
	if candidate and candidate:IsA("Frame") then return candidate end
	return _panelFrame
end

local function cacheBonesOnce()
	if next(_cachedBones) ~= nil then return end
	local root = RigUtil.GetBoneRoot()
	if not root then return end
	for label, boneName in pairs(BONE_MAP) do
		local b = root:FindFirstChild(boneName, true)
		if b and b:IsA("Bone") then
			_cachedBones[label] = b
		end
	end
end

local function updateSubDotPositions()
	if not _activeSelection then return end
	local head = RigUtil.GetHeadPart()
	local cam = RigUtil.CurrentCamera()
	if not (head and cam) then return end
	local parent = dotsParent()

	for boneName, dot in pairs(_subDots) do
		local root = RigUtil.GetBoneRoot()
		if not root then dot.Visible = false continue end
		local bone = root:FindFirstChild(boneName, true)
		if bone and bone:IsA("Bone") then
			local vp, vis = cam:WorldToViewportPoint(bone.WorldPosition)
			if vis and vp.Z > 0 then
				local px = RigUtil.ToLocalPixels(parent, vp)
				dot.Visible = true
				dot.Position = UDim2.fromOffset(math.floor(px.X+0.5), math.floor(px.Y+0.5))
			else
				dot.Visible = false
			end
		else
			dot.Visible = false
		end
	end
end

local function collectExpandedBones(primary: string): {string}
	return EXPANSION_MAP[primary] or {}
end

local function clearSubDots()
	for _, d in pairs(_subDots) do if d and d.Parent then d:Destroy() end end
	_subDots = {}
end

local function clearSliders()
	for _, s in pairs(_sliders) do if s.conn then s.conn:Disconnect() end end
	_sliders = {}
	_sliderValues = { moveX=0, moveY=0, moveZ=0, rotX=0, rotY=0 }
	if not _panelFrame then return end
	local container = _panelFrame:FindFirstChild("SlidersContainerFrame")
	if not (container and container:IsA("Frame")) then return end
	for _, child in ipairs(container:GetChildren()) do
		if child.Name == "SliderTemplateContainer" then
			child.Visible = false
		elseif child:IsA("Frame") and child:GetAttribute("IsSliderClone") then
			child:Destroy()
		end
	end
end

local function ensurePresetsForThisRig()
	local wanted: {[string]: boolean} = {}
	for _, name in pairs(BONE_MAP) do wanted[name] = true end
	for _, list in pairs(EXPANSION_MAP) do for _, n in ipairs(list) do wanted[n] = true end end
	Presets.Ensure(wanted)
end

local function recomputeDerivedSliderValues(activeBone: string)
	if not activeBone then return end
	for key, raw in pairs(_sliderRawValues) do
		local shaped = shapedValue(raw, key == "rotX" or key == "rotY")
		_sliderValues[key] = math.clamp(shaped, -1, 1)
	end
	_smoothedValues[activeBone] = _smoothedValues[activeBone] or {}
	for k,v in pairs(_sliderValues) do
		if _smoothedValues[activeBone][k] == nil then
			_smoothedValues[activeBone][k] = v
		end
	end
end

local function buildSlidersForBone(boneName: string)
	if not _panelFrame then return end
	local allowRotation = BONES_WITH_ROTATION[boneName] or false
	local filteredSpecs = {}
	for _, spec in ipairs(SLIDER_SPECS) do
		if spec.key:find("move") or (spec.key:find("rot") and allowRotation) then
			table.insert(filteredSpecs, spec)
		end
	end
	SliderUI.Build(_panelFrame, filteredSpecs,
		{ sliderRawValues = _sliderRawValues, sliders = _sliders, getActiveBoneName = function() return _activeBoneName end },
		{ recomputeDerived = recomputeDerivedSliderValues, onUserAdjust = function() _userHasAdjusted = true end }
	)
end

local function setActiveBone(boneName: string)
	_activeBoneName = boneName
	local mirrored = Sym.ResolveMirrorBone(boneName, Presets.bones, Presets.gender)
	_activeBonePair = { boneName, mirrored }

	local normalized = Presets.DeriveNormalizedFromCurrent(boneName)
	if normalized then
		for k,v in pairs(normalized) do
			_sliderRawValues[k] = v
			_sliderValues[k] = v
		end
	else
		for k,_ in pairs(_sliderRawValues) do
			_sliderRawValues[k] = 0
			_sliderValues[k] = 0
		end
	end

	_smoothedValues[boneName] = {}
	for k,v in pairs(_sliderValues) do
		_smoothedValues[boneName][k] = v
	end

	if mirrored then
		local mirrorNorm = Presets.DeriveNormalizedFromCurrent(mirrored)
		_smoothedValues[mirrored] = {}
		if mirrorNorm then
			for k,v in pairs(mirrorNorm) do
				_smoothedValues[mirrored][k] = v
			end
		else
			for k,_ in pairs(_sliderValues) do
				_smoothedValues[mirrored][k] = 0
			end
		end
	end

	_userHasAdjusted = false
end

local function recomputeDerivedSliderValues(activeBone: string)
	if not activeBone then return end
	for key, raw in pairs(_sliderRawValues) do
		local shaped = shapedValue(raw, key == "rotX" or key == "rotY")
		_sliderValues[key] = math.clamp(shaped, -1, 1)
	end
	_smoothedValues[activeBone] = _smoothedValues[activeBone] or {}
	for k,v in pairs(_sliderValues) do
		if _smoothedValues[activeBone][k] == nil then
			_smoothedValues[activeBone][k] = v
		end
	end
end

local function baselineToMidded(boneName: string, exceptKey: string?)
	if not boneName or _didBaselineReset[boneName] then return end
	if not Presets.gender then return end
	local g = Presets.gender

	local root = RigUtil.GetBoneRoot()
	if not root then return end

	local function setMid(bn: string)
		local bone = root:FindFirstChild(bn, true)
		local bMid = Presets.bones.Midded[g][bn]
		if bone and bone:IsA("Bone") and bMid then bone.Transform = bMid.Transform end
	end
	setMid(boneName)
	local mirror = _activeBonePair and _activeBonePair[2] or nil
	if mirror then setMid(mirror) end

	for _, spec in ipairs(SLIDER_SPECS) do
		local k = spec.key
		if k ~= exceptKey then
			_sliderRawValues[k] = 0
			_sliderValues[k]    = 0
			local s = _sliders[k]
			if s and s.setValue then s.setValue(0) end
			_smoothedValues[boneName] = _smoothedValues[boneName] or {}
			_smoothedValues[boneName][k] = 0
			if mirror then
				_smoothedValues[mirror] = _smoothedValues[mirror] or {}
				_smoothedValues[mirror][k] = 0
			end
		end
	end

	recomputeDerivedSliderValues(boneName)
	_didBaselineReset[boneName] = true
end

local function stepSmoothing(boneName: string, dt: number)
	local store = _smoothedValues[boneName]
	if not store then return end
	local alpha = 1 - math.exp(-SMOOTH_HZ * dt)
	for _, spec in ipairs(SLIDER_SPECS) do
		local k = spec.key
		local target = _sliderValues[k] or 0
		store[k] = (store[k] or 0) + (target - (store[k] or 0)) * alpha
	end
end

local function applySlidersToBoneWithValues(boneName: string, values: table, mirrorMode: boolean?)
	if not boneName then return end
	local root = RigUtil.GetBoneRoot()
	if not root then return end
	local bone = root:FindFirstChild(boneName, true)
	if not (bone and bone:IsA("Bone")) then return end

	local transLR = Presets.BuildTranslationOffsetForDirection(boneName, "LR", (mirrorMode and -(values.moveX or 0) or (values.moveX or 0)))
	local transUD = Presets.BuildTranslationOffsetForDirection(boneName, "UD", values.moveY or 0)
	local transFB = Presets.BuildTranslationOffsetForDirection(boneName, "FB", values.moveZ or 0)
	local totalTrans = (transLR or Vector3.zero) + (transUD or Vector3.zero) + (transFB or Vector3.zero)

	local totalRot = CFrame.new()
	if BONES_WITH_ROTATION[boneName] then
		local rotYaw   = Presets.BuildRotationOffsetForAxis(boneName, "Yaw", (mirrorMode and -(values.rotX or 0) or (values.rotX or 0)))
		local rotPitch = Presets.BuildRotationOffsetForAxis(boneName, "Pitch", values.rotY or 0)
		totalRot = (rotYaw or CFrame.new()) * (rotPitch or CFrame.new())
	end

	bone.Transform = CFrame.new(totalTrans) * totalRot
end

local function getTemplate(where: "Big"|"Small"): Instance?
	if not _panelFrame then return nil end
	if where == "Big" then return _panelFrame:FindFirstChild("BigDotTemplate") end
	return _panelFrame:FindFirstChild("DotTemplate")
end

local function updateMainDots()
	local cam = RigUtil.CurrentCamera()
	local head = RigUtil.GetHeadPart()
	if not (cam and head) then return end
	cacheBonesOnce()

	local parent = dotsParent()
	local bigTemplate = getTemplate("Big")
	if not (parent and bigTemplate) then return end

	local hide = _activeSelection ~= nil

	for featureName, _ in pairs(BONE_MAP) do
		local dot = _boneDots[featureName]
		if hide then if dot then dot.Visible = false end continue end

		local root = RigUtil.GetBoneRoot()
		local bone = root and root:FindFirstChild(BONE_MAP[featureName], true)
		if not (bone and bone:IsA("Bone")) then if dot then dot.Visible = false end continue end

		local off = HEAD_LOCAL_OFFSETS[featureName] or Vector3.new()
		local worldPos = bone.WorldPosition
		if off.Magnitude > 0 then
			local cf = head.CFrame
			worldPos = worldPos + cf.RightVector*off.X + cf.UpVector*off.Y + cf.LookVector*off.Z
		end

		local vp, visible = cam:WorldToViewportPoint(worldPos)
		if not (visible and vp.Z > 0) then if dot then dot.Visible = false end continue end

		local px = RigUtil.ToLocalPixels(parent, vp)

		if not dot then
			dot = bigTemplate:Clone()
			dot.Name = featureName .. "Dot"
			dot:SetAttribute("GroupName", featureName)
			dot.Parent = parent
			_boneDots[featureName] = dot
			applyDotStyle(dot, featureName)
			local btn = dot:FindFirstChild("TextButton")
			if btn and btn:IsA("GuiObject") then
				btn.Visible = true
				btn.Active = true
				btn.InputBegan:Connect(function(io)
					if io.UserInputType == Enum.UserInputType.MouseButton1 then
						_activeSelection = featureName
						for _, d in pairs(_boneDots) do d.Visible = false end

						clearSubDots()
						local smallTemplate = getTemplate("Small")
						if smallTemplate then
							for _, boneName in ipairs(collectExpandedBones(featureName)) do
								local sdot = smallTemplate:Clone()
								sdot.Name = ("Sub_%s_%s"):format(featureName, boneName)
								sdot:SetAttribute("BoneName", boneName)
								sdot.Parent = parent
								_subDots[boneName] = sdot
								applyDotStyle(sdot, boneName)
								local sb = sdot:FindFirstChild("TextButton")
								if sb and sb:IsA("GuiObject") then
									sb.Visible = true
									sb.InputBegan:Connect(function(io2)
										if io2.UserInputType == Enum.UserInputType.MouseButton1 then
											setActiveBone(boneName)
											clearSliders()
											buildSlidersForBone(boneName)
											_panelFrame.Visible = true
										end
									end)
								end
							end
						end
					end
				end)
			end
		else
			applyDotStyle(dot, featureName)
		end
		dot.Visible = true
		dot.Position = UDim2.fromOffset(math.floor(px.X+0.5), math.floor(px.Y+0.5))
	end
end

local function stepPairAndApply(dt: number)
	if not _activeBonePair then return end
	local primary, mirrorBone = _activeBonePair[1], _activeBonePair[2]
	if not primary then return end

	recomputeDerivedSliderValues(primary)

	if not _userHasAdjusted then return end

	stepSmoothing(primary, dt)
	if mirrorBone then
		_smoothedValues[mirrorBone] = _smoothedValues[mirrorBone] or {}
		for _, spec in ipairs(SLIDER_SPECS) do
			local k = spec.key
			local target = _sliderValues[k] or 0
			local store = _smoothedValues[mirrorBone]
			store[k] = (store[k] or target) + (target - (store[k] or target)) * (1 - math.exp(-SMOOTH_HZ * dt))
		end
	end

	applySlidersToBoneWithValues(primary, _smoothedValues[primary], false)
	if mirrorBone then
		applySlidersToBoneWithValues(mirrorBone, _smoothedValues[mirrorBone], true)
	end
end

local function updateAll(dt: number?)
	if not _isOpen then return end
	ensurePresetsForThisRig()
	updateMainDots()
	updateSubDotPositions()
	stepPairAndApply(dt or 1/60)
end

local function tweenCameraTo(cf: CFrame)
	local cam = RigUtil.CurrentCamera()
	if cam then TweenService:Create(cam, CAM_TWEEN_INFO, { CFrame = cf }):Play() end
end

local function hookBackButton()
	if not _panelFrame then return end
	local backBtn = _panelFrame:FindFirstChild("BackButton")
	if not (backBtn and backBtn:IsA("ImageButton")) then return end
	backBtn.MouseButton1Click:Connect(function()
		_activeSelection = nil
		_activeBoneName = nil
		_activeBonePair = nil
		_userHasAdjusted = false
		clearSubDots()
		clearSliders()
		if _panelFrame then _panelFrame.Visible = false end
	end)
end

local function findFrame(path: string, timeout: number?): Frame?
	timeout = timeout or 2
	local gui = getGui()
	if not gui then return nil end
	local segs = path:split(".")
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local node: Instance = gui
		local ok = true
		for _, s in ipairs(segs) do
			local c = node:FindFirstChild(s)
			if not c then ok = false break end
			node = c
		end
		if ok and node:IsA("Frame") then return node end
		task.wait()
	end
	return nil
end

local function internalOpen(): boolean
	if _isOpen then return true end

	_panelFrame = findFrame("PanelFrame.InteractionFrame.Categories.Shaping.ShapingContainerFrame")
	local dotsOverlay = findFrame("PanelFrame.InteractionFrame.Categories.Shaping.ShapingDotsFrame")
	_dotsFrame = dotsOverlay or _panelFrame

	if not (_panelFrame and _dotsFrame) then
		warn("[HeadShapingManager] Required frames not found; aborting.")
		return false
	end

	_panelFrame.Visible = false
	_dotsFrame.Visible = true

	local cam = RigUtil.CurrentCamera()
	if cam then _prevCamCF = cam.CFrame end
	local targetCF = CFrame.new(TARGET_POS) * CFrame.Angles(0, math.rad(TARGET_YAW_DEG), 0)
	tweenCameraTo(targetCF)

	hookBackButton()

	_conn = RunService.RenderStepped:Connect(function(dt)
		updateAll(dt)
	end)
	_unregister = Lifecycle.RegisterManager("HeadShaping", M.Close)

	_isOpen = true
	return true
end

local function cleanup()
	if _conn then _conn:Disconnect() _conn = nil end
	for _, d in pairs(_boneDots) do d:Destroy() end
	for _, d in pairs(_subDots) do d:Destroy() end
	_boneDots, _subDots, _cachedBones = {}, {}, {}
	_activeSelection, _activeBoneName, _activeBonePair = nil, nil, nil
	_userHasAdjusted = false
	clearSliders()
end

function M.Open() return internalOpen() end

function M.Close()
	if not _isOpen then return true end
	cleanup()
	if _prevCamCF then tweenCameraTo(_prevCamCF) _prevCamCF = nil end
	if _panelFrame then _panelFrame.Visible = false end
	if _dotsFrame then _dotsFrame.Visible = false end
	if _unregister then _unregister() _unregister = nil end
	_isOpen = false
	return true
end

function M.Init(_ctx)
	maid = Maid.new()
	return M
end

function M.Attach(_frame: Frame?)
	internalOpen()
	return M
end

function M.Detach()
	M.Close()
	return true
end

function M.Destroy()
	M.Close()
	if maid then maid:DoCleaning() end
end

return M
