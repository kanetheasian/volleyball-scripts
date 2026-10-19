-- Volleyball: Rising Stars -- front/back set preview and manual-power aiming assist.
-- Shared launch function uses full body direction, including pitch while jumping.
-- Before contact: preview. After contact: briefly display confirmed server flight.
-- ld090812: F targets sippywippy, R targets KEDO_EV. nl223602 is the F court fallback.
-- Set targets sit 0.2 studs off the net on the setter's side; power remains manual.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
assert(RS:FindFirstChild("NG_TaraturaPalla") and RS:FindFirstChild("NG_Palla"), "This script requires Volleyball: Rising Stars")
local tuning = require(RS.NG_TaraturaPalla)
local physics = require(RS.NG_Palla)
local heightConfig
local customization = RS:FindFirstChild("CharacterCustomization")
local characterConfig = customization and customization:FindFirstChild("Config")
local heightModule = characterConfig and characterConfig:FindFirstChild("HeightConfig")
if heightModule then
    local ok, result = pcall(require, heightModule)
    if ok then heightConfig = result end
end
local setVolumes
local volumeModule = RS:FindFirstChild("NG_SfereColpo")
if volumeModule then
    local ok, result = pcall(require, volumeModule)
    if ok then setVolumes = result end
end
local env = getgenv and getgenv() or _G
local old = env.VRSSetAim
local savedCaptures = old and old.Captures or {}
local savedReplays = old and old.ReplaySamples or (env.VRSSetCapture and env.VRSSetCapture.Shots) or {}
local savedFreezeTrace = old and old.FreezeTrace
local savedAimEnabled = old and old.Config and old.Config.AimEnabled
local savedSetNetInset = old and old.Config and old.Config.SetNetInset
if old and ((old.Version == "1.8.1" and tonumber(savedSetNetInset) == 3)
    or (old.Version == "1.8.2" and tonumber(savedSetNetInset) == 1.5)) then
    savedSetNetInset = nil -- Replace previous defaults, while retaining other explicit tuning.
end
local savedAutoReceive = old and old.Config and old.Config.AutoReceive == true
local savedReceiveHistory = old and old.ReceiveHistory or {}
if old and old.Destroy then old.Destroy() end

local api = {
    Version = "1.10.2",
    Config = {Enabled = true, Mode = "Both", Segments = 40, UpdateHz = 60,
        RangeScale = 1, ContactHeight = 4.9, MaxLogEntries = 100, ConfirmedSeconds = 1.2,
        LagCompensation = true, ServerDirectionPreview = false, VisualSmoothingSeconds = 0.018,
        CollisionRadius = 1, AimEnabled = savedAimEnabled ~= false, AimHoldSeconds = 0.85, MaxAimHoldSeconds = 1.5,
        ShowSetHitbox = true, ShowOpponentServe = true, ServeFacingLength = 120,
        ServeFacingGraceSeconds = 2.5,
        AutoReceive = false, AutoDive = false, ReceiveCooldownPadding = 0.1, ReceiveManualPause = 1.1,
        ReceiveInBackground = true,
        ShowReceiveHitbox = true,
        ReceiveLeadSeconds = 0.08, ReceiveMaxLead = 0.24,
        ShowIncomingLanding = true, ShowPlayerPowers = true, StaminaRefill = true, LandingUpdateHz = 20, MaxLandingMarkers = 4,
        AllowOutsideCourtTargets = true,
        FrontTargetUserId = (player.UserId == 58427452 or player.UserId == 415710999) and 393832290 or 58427452,
        FrontTargetName = (player.UserId == 58427452 or player.UserId == 415710999) and "sippywippy" or "KEDO_EV",
        BackTargetUserId = player.UserId == 415710999 and 58427452 or 415710999,
        BackTargetName = player.UserId == 415710999 and "KEDO_EV" or "ld090812",
        FrontFallbackUserId = 130798382,
        TargetGraceSeconds = 0.18, TargetSmoothingSeconds = 0.025,
        SetLeadEnabled = true, SetLeadMaxSeconds = 0.85, SetLeadMaxStuds = 10,
        SetLeadMaxSpeed = 45, SetLeadEdgeMargin = 1.5,
        SetAimDeadzone = 0.65, SetAimMaxCorrection = 2, SetAimCorrectionSpeed = 4,
        SetNetInset = tonumber(savedSetNetInset) or 0.2,
        TargetUserIds = {
            [58427452] = true, -- KEDO_EV, F target when a friend runs this script
            [393832290] = true, -- sippywippy
            [130798382] = true, -- nl223602, F fallback when sippywippy is off this court
            [415710999] = true, -- ld090812
        }},
    Log = {}, Last = {}, Metrics = {Updates = 0, MeanMs = 0, Errors = 0},
    Captures = savedCaptures,
    ReplaySamples = savedReplays,
    FreezeTrace = savedFreezeTrace,
    ReceiveHistory = savedReceiveHistory,
    History = {},
}
env.VRSSetAim = api
-- This restricts target candidates, not access to the overlay.
function api.IsAllowedTarget(candidate)
    return candidate ~= nil and candidate ~= player and candidate:IsA("Player")
        and api.Config.TargetUserIds[candidate.UserId] == true
end

function api.GetTargetCandidates()
    local candidates = {}
    for _, candidate in ipairs(Players:GetPlayers()) do
        if api.IsAllowedTarget(candidate) then
            local character = candidate.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
                table.insert(candidates, candidate)
            end
        end
    end
    return candidates
end

local connections, alive = {}, true
local lastPress, confirmed
local aim, savedRotation, netCache = nil, nil, {}
local frontAimKey, backAimKey = Enum.KeyCode.F, Enum.KeyCode.R
local aimAction = "VRSSetAim_ManualPowerTarget"
local stopAim
local targetSnapshots = {}
local targetMessage, targetMessageUntil = nil, 0
local world = Instance.new("Folder")
world.Name = "VRS_SetAim_Local"
world.Parent = workspace
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
local function log(kind, data)
    table.insert(api.Log, {time = os.clock(), kind = kind, data = data})
    if #api.Log > api.Config.MaxLogEntries then table.remove(api.Log, 1) end
end
local function make(class, props, parent)
    local x = Instance.new(class)
    for k, v in pairs(props) do x[k] = v end
    x.Parent = parent
    return x
end
local frontColor, backColor = Color3.fromRGB(72, 230, 255), Color3.fromRGB(255, 161, 72)
-- PLAYER_POWER_COMPONENT_BEGIN
-- Generated by scripts/sync-vrs-player-powers.mjs.
-- Shared, read-only player power labels. Multiple script owners reuse one display.
local function createPlayerPowerDisplay(host)
    local env, owner = host.env, host.owner
    local service = env.VRSPlayerPowerDisplayService
    if not service then
        service = {Owners = {}, Tags = {}, Values = {}, NextUpdate = 0,
            Metrics = {Updates = 0, Visible = 0, Errors = 0}}
        service.Gui = host.make("ScreenGui", {Name = "VRS_PlayerPowers", ResetOnSpawn = false,
            DisplayOrder = 102}, host.player:WaitForChild("PlayerGui"))
        env.VRSPlayerPowerDisplayService = service
    end
    service.Owners[owner] = true
    owner.PowerMetrics, owner.PlayerPowers = service.Metrics, service.Values
    local closed = false
    local display = {}
    function display.Update()
        if closed or env.VRSPlayerPowerDisplayService ~= service then return end
        service.Owners[owner] = owner.Config.ShowPlayerPowers ~= false
        local now = host.clock()
        if now < service.NextUpdate then return end
        service.NextUpdate = now + 0.1
        local enabled = false
        for _, wanted in pairs(service.Owners) do if wanted then enabled = true; break end end
        local present, visible = {}, 0
        for _, candidate in ipairs(host.players:GetPlayers()) do
            present[candidate] = true
            local character = candidate.Character
            local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local power = character and character:FindFirstChild("Power")
            local value = power and (power:IsA("IntValue") or power:IsA("NumberValue")) and power.Value
            local valid = enabled and head and head:IsA("BasePart") and humanoid and humanoid.Health > 0
                and type(value) == "number" and value == value and math.abs(value) < 1e6
            local record = service.Tags[candidate]
            if valid then
                if not record then
                    local tag = host.make("BillboardGui", {Name = "PlayerPower_" .. tostring(candidate.UserId),
                        Size = UDim2.fromOffset(210, 28), AlwaysOnTop = true, MaxDistance = 250,
                        StudsOffset = Vector3.new(0, 3, 0), Enabled = false}, service.Gui)
                    local label = host.make("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(105, 230, 255),
                        TextStrokeTransparency = 0.25, Text = ""}, tag)
                    record = {tag = tag, label = label}
                    service.Tags[candidate] = record
                end
                record.tag.Adornee, record.tag.Enabled = head, true
                record.label.Text = "P" .. string.format("%g", value)
                service.Values[candidate.UserId] = {name = candidate.Name, power = value}
                visible += 1
            else
                if record then record.tag.Enabled, record.tag.Adornee = false, nil end
                service.Values[candidate.UserId] = nil
            end
        end
        for candidate, record in pairs(service.Tags) do
            if not present[candidate] then
                record.tag:Destroy()
                service.Tags[candidate], service.Values[candidate.UserId] = nil, nil
            end
        end
        service.Metrics.Visible, service.Metrics.Updates = visible, service.Metrics.Updates + 1
    end
    function display.SafeUpdate()
        local ok, err = pcall(display.Update)
        if not ok then service.Metrics.Errors += 1; service.Metrics.LastError = tostring(err) end
    end
    function display.Destroy()
        if closed then return end
        closed = true
        service.Owners[owner] = nil
        if next(service.Owners) == nil then
            service.Gui:Destroy()
            table.clear(service.Tags); table.clear(service.Values)
            service.Metrics.Visible = 0
            if env.VRSPlayerPowerDisplayService == service then env.VRSPlayerPowerDisplayService = nil end
        end
    end
    return display
end
-- PLAYER_POWER_COMPONENT_END
-- STAMINA_CONTROLLER_BEGIN
local function createStaminaController(host)
    local controller = {Enabled = false, Closed = false,
        Metrics = {Refills = 0, RefilledAmount = 0, Errors = 0, LastBefore = nil, LastAfter = nil}}
    function controller.SetEnabled(enabled)
        controller.Enabled = enabled == true and not controller.Closed
    end
    function controller.Tick()
        if controller.Closed or not controller.Enabled then return "OFF" end
        if not host.alive() then return "waiting for character" end
        local binding = host.binding()
        if not binding then return "calibration: sprint once" end
        if binding.input ~= host.input() then return "input changed: recalibrate" end
        local maximum = host.maximum()
        if type(maximum) ~= "number" or maximum < 1 or maximum > 20 then return "waiting for stamina meter" end
        local value = host.read(binding.fn, binding.index)
        if type(value) ~= "number" or value ~= value or value < 0 or value > maximum + 0.001 then
            error("Stamina binding no longer matches the native meter")
        end
        controller.Metrics.LastBefore = value
        if value < maximum then
            host.write(binding.fn, binding.index, maximum)
            local after = host.read(binding.fn, binding.index)
            if after ~= maximum then error("Native stamina refill was not accepted") end
            controller.Metrics.Refills += 1
            controller.Metrics.RefilledAmount += maximum - value
        end
        controller.Metrics.LastAfter = host.read(binding.fn, binding.index)
        host.show(controller.Metrics.LastAfter, maximum)
        return "ON / local stamina full"
    end
    function controller.SafeTick()
        local ok, result = pcall(controller.Tick)
        if not ok then
            controller.Enabled = false
            controller.Metrics.Errors += 1
            controller.Metrics.LastError = tostring(result)
            return "Stopped: " .. tostring(result)
        end
        return result
    end
    function controller.Destroy()
        controller.Enabled, controller.Closed = false, true
    end
    return controller
end
-- STAMINA_CONTROLLER_END
-- STAMINA_SERVICE_BEGIN
-- One calibrated native-counter refill engine shared by all script owners.
local function createStaminaService(host)
    local env, owner = host.env, host.owner
    local service = env.VRSStaminaService
    if not service then
        local legacy = env.VRSStaminaAssist
        local binding = host.seedBinding or env.VRSStaminaBindingCache
        local wanted = env.VRSStaminaPreference ~= false
        if legacy and legacy ~= owner and legacy.Controller and not legacy.Stamina then
            binding = legacy.Binding or binding
            wanted = legacy.Config.Enabled ~= false
            if legacy.Destroy then pcall(legacy.Destroy) end
        end
        service = {Version = "0.2.0", Owners = {}, Binding = binding, Candidates = {}, Enabled = wanted,
            Available = false, Status = "Starting", Metrics = {Refills = 0, RefilledAmount = 0, Errors = 0}}
        env.VRSStaminaService = service
        env.VRSStaminaPreference = wanted
        local function inputScript()
            local scripts = host.player:FindFirstChild("PlayerScripts")
            return scripts and scripts:FindFirstChild("Input")
        end
        local function meter()
            local screen = host.player.PlayerGui:FindFirstChild("ScreenGui")
            local frame = screen and screen:FindFirstChild("Frame")
            local energy = frame and frame:FindFirstChild("Energy")
            return energy, energy and energy:FindFirstChild("TextLabel")
        end
        local function maximum()
            local _, text = meter()
            return text and tonumber(text.Text:match("/%s*(%d+)%s*$"))
        end
        function service.Report()
            for activeOwner, record in pairs(service.Owners) do
                activeOwner.Config.StaminaRefill = service.Enabled
                activeOwner.StaminaMetrics = service.Metrics
                if record.report then pcall(record.report, service.Enabled, service.Status, service.Available) end
            end
        end
        function service.SetEnabled(enabled)
            service.Enabled = enabled == true and service.Available
            env.VRSStaminaPreference = service.Enabled
            if service.Controller then service.Controller.SetEnabled(service.Enabled) end
            service.Status = service.Enabled and (service.Binding and "ON / local stamina full" or "calibration: sprint once")
                or (service.Available and "OFF" or "Unavailable")
            service.Report()
            return service.Enabled
        end
        function service.BeginCalibration()
            service.Binding, service.Candidates = nil, {}
            env.VRSStaminaBindingCache = nil
            local input = inputScript()
            service.CalibrationInput = input
            service.NextDiscovery = os.clock() + 1
            if not input then return end
            for _, fn in ipairs(host.gc()) do
                if type(fn) == "function" then
                    local ok, context = pcall(host.environment, fn)
                    if ok and context.script == input then
                        local good, constants = pcall(host.constants, fn)
                        if good then
                            local endurance, regen = false, false
                            for _, value in pairs(constants) do
                                endurance = endurance or value == "Endurance"
                                regen = regen or value == "TraitStaminaRegen"
                            end
                            if endurance and not regen then
                                local initial = {}
                                for index, value in pairs(host.readUps(fn)) do
                                    if type(value) == "number" then initial[index] = value end
                                end
                                service.Candidates[#service.Candidates + 1] = {fn = fn, input = input, initial = initial}
                            end
                        end
                    end
                end
            end
        end
        local function observeCalibration()
            if service.Binding then return end
            local max = maximum()
            if not max then return end
            local options = {}
            for _, candidate in ipairs(service.Candidates) do
                for index, value in pairs(host.readUps(candidate.fn)) do
                    if candidate.initial[index] == max and type(value) == "number" and value >= 0
                        and value < max and value >= max - 5 then
                        options[#options + 1] = {fn = candidate.fn, index = index,
                            input = candidate.input, observed = value}
                    end
                end
            end
            if #options >= 2 then
                local value = options[1].observed
                for _, bindingOption in ipairs(options) do
                    if math.abs(bindingOption.observed - value) > 0.001 then return end
                end
                service.Binding, env.VRSStaminaBindingCache = options[1], options[1]
            end
        end
        function service.Tick()
            if not service.Available then return end
            local ok, err = pcall(function()
                if service.Binding and service.Binding.input ~= inputScript() then service.BeginCalibration() end
                if not service.Binding and service.CalibrationInput ~= inputScript() then service.BeginCalibration() end
                if not service.Binding and #service.Candidates < 2 and os.clock() >= (service.NextDiscovery or 0) then
                    service.BeginCalibration()
                end
                observeCalibration()
                service.Status = service.Controller.SafeTick()
                if not service.Controller.Enabled and service.Enabled then
                    service.Enabled, env.VRSStaminaPreference = false, false
                end
            end)
            if not ok then
                service.Metrics.Errors += 1; service.Metrics.LastError = tostring(err)
                service.Enabled, env.VRSStaminaPreference = false, false
                service.Controller.SetEnabled(false)
                service.Status = "Stopped: " .. tostring(err)
            end
            service.Report()
        end
        local ok, err = pcall(function()
            assert(type(host.gc) == "function" and type(host.constants) == "function"
                and type(host.readUps) == "function" and type(host.readUp) == "function"
                and type(host.writeUp) == "function", "Required executor inspection APIs unavailable")
            local probe = env.VRSStaminaProbe
            if probe and probe.connection then probe.connection:Disconnect(); probe.active = false end
            if probe and type(probe.bindings) == "table" and #probe.bindings >= 2 then
                for _, option in ipairs(probe.bindings) do
                    if option.input == inputScript() then service.Binding = option; break end
                end
            end
            env.VRSStaminaProbe = nil
            if service.Binding and service.Binding.input ~= inputScript() then service.Binding = nil end
            if not service.Binding then service.BeginCalibration() end
            if service.Binding then env.VRSStaminaBindingCache = service.Binding end
            service.Controller = host.createController({
                alive = function()
                    local character = host.player.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    return humanoid and humanoid.Health > 0
                end,
                binding = function() return service.Binding end, input = inputScript, maximum = maximum,
                read = host.readUp, write = host.writeUp,
                show = function(value, max)
                    local energy, text = meter()
                    if text then text.Text = tostring(math.floor(value)) .. "/" .. tostring(max) end
                    local bar = energy and energy:FindFirstChild("Frame")
                    if bar then bar.Size = UDim2.new(math.clamp(value / max, 0, 1), 0, 1, 0) end
                end})
            service.Metrics, service.Available = service.Controller.Metrics, true
            service.Controller.SetEnabled(wanted)
            service.Status = wanted and (service.Binding and "ON / local stamina full" or "calibration: sprint once") or "OFF"
            service.Connection = host.heartbeat:Connect(service.Tick)
        end)
        if not ok then
            service.Enabled, service.Available = false, false
            service.Status, service.UnavailableReason = "Unavailable", tostring(err)
            if service.Connection then service.Connection:Disconnect() end
        end
    end
    service.Owners[owner] = {report = host.report}
    local lease, closed = {}, false
    function lease.SetEnabled(enabled)
        if closed then return false end
        return service.SetEnabled(enabled)
    end
    function lease.IsEnabled() return not closed and service.Enabled end
    function lease.GetService() return service end
    function lease.Destroy()
        if closed then return end
        closed = true
        service.Owners[owner] = nil
        if next(service.Owners) == nil then
            if service.Connection then service.Connection:Disconnect() end
            if service.Controller then service.Controller.Destroy() end
            if service.Binding then env.VRSStaminaBindingCache = service.Binding end
            if env.VRSStaminaService == service then env.VRSStaminaService = nil end
        end
    end
    service.Report()
    return lease
end
-- STAMINA_SERVICE_END
-- JUMP_COMPONENT_BEGIN
-- Shared takeoff-pulse adjustment. Height factor -> sqrt(factor) JumpPower.
local function createJumpService(host)
    local env, owner = host.env, host.owner
    local service = env.VRSJumpService
    if not service then
        service = {Enabled = false, Multiplier = 1, Owners = {}, Revision = 0,
            Status = "OFF", Metrics = {Pulses = 0, Errors = 0}}
        env.VRSJumpService = service
        local humanoid, powerConnection, changing, applied, native
        local function restore()
            if humanoid and applied and humanoid.Parent and math.abs(humanoid.JumpPower - applied) < 0.001 then
                changing = true
                local ok, err = pcall(function() humanoid.JumpPower = native end)
                changing = false
                if not ok then error(err) end
            end
            applied, native = nil, nil
        end
        function service.Report()
            for activeOwner, record in pairs(service.Owners) do
                activeOwner.Config.JumpBoost = service.Enabled
                activeOwner.Config.JumpHeightMultiplier = service.Multiplier
                if record.report then pcall(record.report, service.Enabled, service.Multiplier, service.Status) end
            end
        end
        local function changed()
            service.Revision += 1
            for activeOwner in pairs(service.Owners) do
                if activeOwner.FullAssist and activeOwner.FullAssist.InvalidateCalibration then
                    activeOwner.FullAssist.InvalidateCalibration("Jump multiplier changed; recalibrate jumps and spikes")
                end
            end
        end
        local function fail(err)
            service.Metrics.Errors += 1; service.Metrics.LastError = tostring(err)
            service.Enabled = false
            pcall(restore)
            service.Status = "Stopped: " .. tostring(err)
            changed(); service.Report()
        end
        local function observePower()
            if changing or not humanoid then return end
            local ok, err = pcall(function()
                local value = humanoid.JumpPower
                -- Ignore our own synchronous OR deferred property signal.
                if applied and math.abs(value - applied) < 0.001 then return end
                applied, native = nil, nil
                if not service.Enabled or service.Multiplier == 1 or value <= 0
                    or humanoid.Health <= 0 or not humanoid.UseJumpPower
                    or humanoid.FloorMaterial == Enum.Material.Air then return end
                native, applied = value, value * math.sqrt(service.Multiplier)
                changing = true
                local wrote, message = pcall(function() humanoid.JumpPower = applied end)
                changing = false
                if not wrote then error(message) end
                service.Metrics.Pulses += 1
            end)
            if not ok then fail(err) end
        end
        function service.Tick()
            local ok, err = pcall(function()
                local character = host.player.Character
                local current = service.Enabled and character and character:FindFirstChildOfClass("Humanoid") or nil
                if current ~= humanoid then
                    if powerConnection then powerConnection:Disconnect(); powerConnection = nil end
                    restore(); humanoid = current
                    if humanoid then powerConnection = humanoid:GetPropertyChangedSignal("JumpPower"):Connect(observePower) end
                end
                -- Never rewrite a positive value that existed before this controller attached.
                if not service.Enabled then service.Status = "OFF"
                elseif not humanoid or humanoid.Health <= 0 then service.Status = "Waiting for character"
                elseif not humanoid.UseJumpPower then service.Status = "Unavailable: native JumpPower mode required"
                elseif service.Multiplier == 1 then service.Status = "ON / normal height (1x)"
                else service.Status = string.format("ON / %.3gx height / next takeoff", service.Multiplier) end
                service.Report()
            end)
            if not ok then fail(err) end
        end
        function service.SetEnabled(value)
            assert(type(value) == "boolean", "Expected a toggle")
            if value == service.Enabled then return value end
            restore(); service.Enabled = value; changed(); service.Tick()
            return service.Enabled
        end
        function service.SetMultiplier(value)
            assert(type(value) == "number" and value == value and value >= 0.1 and value <= 2,
                "Enter a height multiplier from 0.1 to 2")
            if value == service.Multiplier then return value end
            restore(); service.Multiplier = value; changed(); service.Tick()
            return value
        end
        function service.Close()
            if service.Connection then service.Connection:Disconnect() end
            if powerConnection then powerConnection:Disconnect() end
            restore()
            if env.VRSJumpService == service then env.VRSJumpService = nil end
        end
        service.Connection = host.heartbeat:Connect(service.Tick)
        service.Tick()
    end
    service.Owners[owner] = {report = host.report}
    local lease, closed = {}, false
    function lease.IsEnabled() return not closed and service.Enabled end
    function lease.GetMultiplier() return service.Multiplier end
    function lease.GetService() return service end
    function lease.SetEnabled(value) if not closed then return service.SetEnabled(value) end end
    function lease.SetMultiplier(value) if not closed then return service.SetMultiplier(value) end end
    function lease.Destroy()
        if closed then return end
        closed = true; service.Owners[owner] = nil
        if next(service.Owners) == nil then service.Close() end
    end
    service.Report()
    return lease
end

-- JUMP_COMPONENT_END
-- TILT_COMPONENT_BEGIN
-- Scale native airborne BodyGyro targets relative to their authored Origin.
local function createTiltService(host)
    local env, owner = host.env, host.owner
    local service = env.VRSTiltService
    if not service then
        service = {Enabled = false, Multiplier = 1, Owners = {}, Revision = 0,
            Status = "OFF", MaxDegrees = 80, Metrics = {Writes = 0, Errors = 0}}
        env.VRSTiltService = service
        local binding, native, applied, lastOrigin, observer, changing
        local function same(a, b)
            return a and b and (a.Position - b.Position).Magnitude < 0.00001
                and (a.LookVector - b.LookVector).Magnitude < 0.00001
                and (a.UpVector - b.UpVector).Magnitude < 0.00001
        end
        local function release()
            if observer then observer:Disconnect(); observer = nil end
            local old, baseline, last = binding, native, applied
            binding, native, applied, lastOrigin = nil, nil, nil, nil
            if old and last and old.gyro.Parent and same(old.gyro.CFrame, last) then
                changing = true
                local ok, err = pcall(function() old.gyro.CFrame = baseline end)
                changing = false
                if not ok then error(err) end
            end
        end
        function service.Report()
            for activeOwner in pairs(service.Owners) do
                activeOwner.Config.TiltBoost = service.Enabled
                activeOwner.Config.TiltMultiplier = service.Multiplier
            end
        end
        local function changed()
            service.Revision += 1
            for activeOwner in pairs(service.Owners) do
                if activeOwner.FullAssist and activeOwner.FullAssist.InvalidateCalibration then
                    activeOwner.FullAssist.InvalidateCalibration("Tilt multiplier changed; recalibrate jumps and spikes")
                end
            end
        end
        function service.ScaleTarget(origin, target, multiplier)
            if multiplier == 1 then return target end
            local relative = origin:ToObjectSpace(target)
            local pitch, yaw, roll = relative:ToEulerAnglesXYZ()
            local limit = math.rad(service.MaxDegrees)
            return origin * CFrame.new(relative.Position) * CFrame.Angles(
                math.clamp(pitch * multiplier, -limit, limit), yaw,
                math.clamp(roll * multiplier, -limit, limit))
        end
        local function fail(err)
            service.Metrics.Errors += 1
            service.Metrics.LastError = tostring(err)
            service.Enabled = false
            pcall(release)
            service.Status = "Stopped: " .. tostring(err)
            changed(); service.Report()
        end
        local function tick()
            if changing then return end
            if not service.Enabled then release(); service.Status = "OFF"; service.Report(); return end
            local character = host.player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local gyro = root and root:FindFirstChild("Tilt")
            local origin = gyro and gyro:FindFirstChild("Origin")
            local airborne = humanoid and (humanoid.FloorMaterial == Enum.Material.Air
                or host.player:GetAttribute("NG_InAria") == true)
            if not humanoid or humanoid.Health <= 0 or not airborne or not gyro
                or not gyro:IsA("BodyGyro") or not origin or not origin:IsA("CFrameValue")
                or gyro.MaxTorque.Magnitude <= 0 then
                release(); service.Status = "ON / waiting for native airborne tilt"; service.Report(); return
            end
            if not binding or binding.gyro ~= gyro or binding.origin ~= origin or binding.root ~= root then
                release()
                binding = {root = root, gyro = gyro, origin = origin}
                observer = gyro:GetPropertyChangedSignal("CFrame"):Connect(service.Tick)
            end
            local current, originFrame = gyro.CFrame, origin.Value
            if not applied or not same(current, applied) then
                native = current
            elseif lastOrigin and not same(lastOrigin, originFrame) then
                native = originFrame * lastOrigin:ToObjectSpace(native)
            end
            lastOrigin = originFrame
            local scaled = service.ScaleTarget(originFrame, native, service.Multiplier)
            if not same(current, scaled) then
                changing = true
                local ok, err = pcall(function() gyro.CFrame = scaled end)
                changing = false
                if not ok then error(err) end
                service.Metrics.Writes += 1
            end
            -- Read back the engine's stored CFrame to recognize deferred signals.
            applied = gyro.CFrame
            service.Status = string.format("ON / %.3gx native tilt", service.Multiplier)
            service.Report()
        end
        function service.Tick()
            local ok, err = pcall(tick)
            if not ok then fail(err) end
        end
        function service.SetEnabled(value)
            assert(type(value) == "boolean", "Expected a toggle")
            if value == service.Enabled then return value end
            service.Enabled = value; changed(); service.Tick()
            return service.Enabled
        end
        function service.SetMultiplier(value)
            assert(type(value) == "number" and value == value and value >= 0.1 and value <= 3,
                "Enter a tilt multiplier from 0.1 to 3")
            if value == service.Multiplier then return value end
            service.Multiplier = value; changed(); service.Tick()
            return service.Multiplier
        end
        function service.Close()
            if service.Connection then service.Connection:Disconnect() end
            release()
            if env.VRSTiltService == service then env.VRSTiltService = nil end
        end
        service.Connection = host.heartbeat:Connect(service.Tick)
        service.Tick()
    end
    service.Owners[owner] = true
    local lease, closed = {}, false
    function lease.IsEnabled() return not closed and service.Enabled end
    function lease.GetMultiplier() return service.Multiplier end
    function lease.GetService() return service end
    function lease.SetEnabled(value) if not closed then return service.SetEnabled(value) end end
    function lease.SetMultiplier(value) if not closed then return service.SetMultiplier(value) end end
    function lease.Destroy()
        if closed then return end
        closed = true; service.Owners[owner] = nil
        if next(service.Owners) == nil then service.Close() end
    end
    service.Report()
    return lease
end

-- TILT_COMPONENT_END
local gui = make("ScreenGui", {Name = "VRS_SetAim", ResetOnSpawn = false,
    DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local panel = make("Frame", {Size = UDim2.fromOffset(310, 354),
    Position = UDim2.new(0, 18, 1, -382), BackgroundColor3 = Color3.fromRGB(17, 21, 30),
    BackgroundTransparency = 0.12, BorderSizePixel = 0, Active = true}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)
make("UIStroke", {Color = Color3.fromRGB(63, 80, 103), Transparency = 0.3}, panel)
local function text(value, y, height, color)
    return make("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, y),
        Size = UDim2.new(1, -24, 0, height), Font = Enum.Font.Gotham,
        TextSize = 12, TextColor3 = color or Color3.fromRGB(219, 226, 239),
        TextXAlignment = Enum.TextXAlignment.Left, Text = value}, panel)
end
local title = text("SET AIM " .. api.Version .. " / estimated", 7, 22)
title.Font = Enum.Font.GothamBold
local status = text("Reading game state...", 33, 19)
local ranges = text("Cyan: front   |   Orange: back", 55, 19)
local details = text("", 75, 19, Color3.fromRGB(153, 170, 194))
local targetStatus = text("Aim: finding court...", 95, 19, Color3.fromRGB(153, 220, 194))
local hitboxStatus = text("Hitbox: reading game volume...", 222, 19)
local serveStatus = text("Serve: waiting for opposing server", 243, 19, Color3.fromRGB(255, 164, 221))
local receiveStatus = text("Auto Receive: OFF", 264, 19, Color3.fromRGB(151, 239, 174))
local function button(label, x, width, y)
    local b = make("TextButton", {Position = UDim2.fromOffset(x, y or 124), Size = UDim2.fromOffset(width, 26),
        BackgroundColor3 = Color3.fromRGB(38, 48, 65), BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), Text = label}, panel)
    make("UICorner", {CornerRadius = UDim.new(0, 5)}, b)
    return b
end
local toggle = button("Hide", 12, 65)
local mode = button("Both", 84, 65)
local aimToggle = button(api.Config.AimEnabled and "Aim ON" or "Aim OFF", 156, 68)
local close = button("Close", 232, 65)
local hitboxToggle = button("Set Box ON", 12, 91, 158)
local receiveBoxToggle = button("Recv Box ON", 109, 91, 158)
local serveToggle = button("Facing ON", 206, 91, 158)
local receiveToggle = button("Auto Receive OFF", 12, 140, 190)
local landingToggle = button("Landing ON", 156, 140, 190)
local staminaToggle = button("Stamina ON", 12, 284, 296)
text("F: " .. api.Config.FrontTargetName .. " / nl223602 | R: " .. api.Config.BackTargetName, 334, 15,
    Color3.fromRGB(132, 148, 172)).TextSize = 10

-- PLAYER_POWER_INTEGRATION_BEGIN
local playerPowerDisplay = createPlayerPowerDisplay({env = env, owner = api, players = Players,
    player = player, make = make, clock = os.clock})
api.PlayerPowerDisplay = playerPowerDisplay
connect(RunService.Heartbeat, function() playerPowerDisplay.SafeUpdate() end)
-- PLAYER_POWER_INTEGRATION_END
-- STAMINA_INTEGRATION_BEGIN
local stamina = createStaminaService({env = env, owner = api, player = player, heartbeat = RunService.Heartbeat,
    createController = createStaminaController, gc = getgc, environment = getfenv,
    constants = debug.getconstants or getconstants, readUps = debug.getupvalues or getupvalues,
    readUp = debug.getupvalue or getupvalue, writeUp = debug.setupvalue or setupvalue,
    report = function(enabled, state, available)
        staminaToggle.Text = not available and "Stamina unavailable" or state:match("^Stopped") and "Stamina error"
            or not enabled and "Stamina OFF" or state:find("sprint", 1, true) and "Stamina: sprint once" or "Stamina ON"
    end})
api.Stamina = stamina
function api.SetStaminaRefill(enabled) return stamina.SetEnabled(enabled) end
connect(staminaToggle.Activated, function() stamina.SetEnabled(not stamina.IsEnabled()) end)
-- STAMINA_INTEGRATION_END
-- JUMP_INTEGRATION_BEGIN
api.Jump = createJumpService({env=env,owner=api,player=player,heartbeat=RunService.Heartbeat})
function api.SetJumpBoost(value) return api.Jump.SetEnabled(value) end
function api.SetJumpHeightMultiplier(value) return api.Jump.SetMultiplier(value) end
-- JUMP_INTEGRATION_END
-- TILT_INTEGRATION_BEGIN
api.Tilt = createTiltService({env=env,owner=api,player=player,heartbeat=RunService.Heartbeat})
function api.SetTiltBoost(value) return api.Tilt.SetEnabled(value) end
function api.SetTiltMultiplier(value) return api.Tilt.SetMultiplier(value) end
-- TILT_INTEGRATION_END
function api.Destroy()
    if api.Jump then api.Jump.Destroy() end
    if not alive then return end
    if api.Interface then api.Interface.Destroy() end
    if api.Tilt then api.Tilt.Destroy() end
    if api.Defense then api.Defense.Destroy() end
    alive = false
    stamina.Destroy()
    playerPowerDisplay.Destroy()
    if api.SetAutoReceive then api.SetAutoReceive(false) end
    if stopAim then stopAim() end
    CAS:UnbindAction(aimAction)
    for _, c in ipairs(connections) do c:Disconnect() end
    world:Destroy()
    gui:Destroy()
    if env.VRSSetAim == api then env.VRSSetAim = nil end
end
connect(close.Activated, api.Destroy)
connect(player.CharacterAdded, function(character)
    if stopAim then stopAim() end
    if api.ResetAutoReceiveCharacter then api.ResetAutoReceiveCharacter(character) end
    api.History = {}
    confirmed, lastPress = nil, nil
end)
connect(player.CharacterRemoving, function()
    if api.ResetAutoReceiveCharacter then api.ResetAutoReceiveCharacter(nil) end
end)
connect(aimToggle.Activated, function()
    api.Config.AimEnabled = not api.Config.AimEnabled
    aimToggle.Text = api.Config.AimEnabled and "Aim ON" or "Aim OFF"
    if not api.Config.AimEnabled and stopAim then stopAim() end
end)
function api.SetAimEnabled(enabled)
    api.Config.AimEnabled = enabled == true
    if not api.Config.AimEnabled and stopAim then stopAim() end
    return api.Config.AimEnabled
end
connect(toggle.Activated, function() api.Config.Enabled = not api.Config.Enabled end)
connect(hitboxToggle.Activated, function()
    api.Config.ShowSetHitbox = not api.Config.ShowSetHitbox
    hitboxToggle.Text = api.Config.ShowSetHitbox and "Set Box ON" or "Set Box OFF"
end)
connect(receiveBoxToggle.Activated, function()
    api.Config.ShowReceiveHitbox = not api.Config.ShowReceiveHitbox
    receiveBoxToggle.Text = api.Config.ShowReceiveHitbox and "Recv Box ON" or "Recv Box OFF"
end)
connect(serveToggle.Activated, function()
    api.Config.ShowOpponentServe = not api.Config.ShowOpponentServe
    serveToggle.Text = api.Config.ShowOpponentServe and "Facing ON" or "Facing OFF"
end)
connect(receiveToggle.Activated, function()
    if api.SetAutoReceive then api.SetAutoReceive(not api.Config.AutoReceive) end
end)
connect(landingToggle.Activated, function()
    api.Config.ShowIncomingLanding = not api.Config.ShowIncomingLanding
    landingToggle.Text = api.Config.ShowIncomingLanding and "Landing ON" or "Landing OFF"
end)
connect(mode.Activated, function()
    api.Config.Mode = ({Both = "Front", Front = "Back", Back = "Both"})[api.Config.Mode] or "Both"
    mode.Text = api.Config.Mode
end)
connect(UIS.InputBegan, function(input, processed)
    if env.VRSKeyCapture then return end
    if not processed then
        if input.KeyCode == frontAimKey or input.KeyCode == backAimKey then
            lastPress = {time = workspace:GetServerTimeNow(), back = input.KeyCode == backAimKey}
            confirmed = nil
        end
    end
    if not api.Interface and not processed and input.KeyCode == Enum.KeyCode.Insert then
        api.Config.Enabled = not api.Config.Enabled
    end
end)
local dragStart, panelStart
connect(panel.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and input.Position.Y < panel.AbsolutePosition.Y + 30 then
        dragStart, panelStart = input.Position, panel.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if dragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        panel.Position = panelStart + UDim2.fromOffset(delta.X, delta.Y)
    end
end)
connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = nil end
end)

local function part(name, color, size)
    return make("Part", {Name = name, Anchored = true, CanCollide = false, CanTouch = false,
        CanQuery = false, CastShadow = false, Material = Enum.Material.Neon,
        Color = color, Size = size, Transparency = 1}, world)
end
local function pathVisual(name, color)
    local visual = {parts = {}, name = name}
    for i = 1, api.Config.Segments do
        visual.parts[i] = part(name .. i, color, Vector3.new(0.09, 0.09, 1))
    end
    visual.marker = part(name .. "Landing", color, Vector3.new(0.08, 3.3, 3.3))
    visual.marker.Shape = Enum.PartType.Cylinder
    local tag = make("BillboardGui", {Size = UDim2.fromOffset(140, 36), AlwaysOnTop = true,
        StudsOffset = Vector3.new(0, 1.6, 0), Adornee = visual.marker, Enabled = false}, visual.marker)
    visual.tag = tag
    visual.label = make("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = color,
        TextStrokeTransparency = 0.25, Text = name}, tag)
    return visual
end
local visuals = {Front = pathVisual("FRONT", frontColor), Back = pathVisual("BACK", backColor)}
local function hide(v)
    v.points, v.smoothingKey = nil, nil
    for _, p in ipairs(v.parts) do p.Transparency = 1 end
    v.marker.Transparency, v.tag.Enabled = 1, false
end

-- TARGET_MATH_BEGIN
local function flat(vector)
    return Vector3.new(vector.X, 0, vector.Z)
end

function api.CameraFacing(cameraFrame)
    if not cameraFrame then return nil end
    local direction = flat(cameraFrame.LookVector)
    -- A top-down camera has no useful horizontal look direction; use screen-up instead.
    if direction.Magnitude < 0.05 then direction = flat(cameraFrame.UpVector) end
    if direction.Magnitude < 0.001 then return nil end
    return direction.Unit
end

function api.InCourt(position, net)
    local offset = flat(position - net.courtCenter)
    return math.abs(offset:Dot(net.axis)) <= net.halfWidth
        and math.abs(offset:Dot(net.normal)) <= net.halfDepth
end

function api.NetPoint(position, net)
    local along = math.clamp(flat(position - net.center):Dot(net.axis), -net.halfWidth, net.halfWidth)
    return net.center + net.axis * along
end

function api.SetAimPoint(position, net, origin)
    local side = flat(origin - net.center):Dot(net.normal)
    if math.abs(side) < 0.15 then return nil end
    local inset = math.clamp(tonumber(api.Config.SetNetInset) or 0.2, 0, math.max(0, net.halfDepth - 1))
    -- Keep raw net geometry unchanged for court matching and serve/ball checks.
    return api.NetPoint(position, net) + net.normal * (side > 0 and inset or -inset)
end

function api.NearestNet(position, nets)
    local best, bestDistance = nil, math.huge
    for _, candidate in ipairs(nets) do
        local distance = flat(position - api.NetPoint(position, candidate)).Magnitude
        if distance < bestDistance then best, bestDistance = candidate, distance end
    end
    return best
end

function api.TargetNearNet(position, net, nets)
    if api.InCourt(position, net) then return true end
    if api.Config.AllowOutsideCourtTargets == false then return false end
    local nearest = api.NearestNet(position, nets or {net})
    -- Live net records refresh periodically; compare their actual instances as well.
    return nearest == net or (nearest ~= nil and nearest.part ~= nil and nearest.part == net.part
        and nearest.court == net.court)
end

function api.BoundTargetId(backward, frontPresent)
    if backward then return api.Config.BackTargetUserId end
    if frontPresent == false then return api.Config.FrontFallbackUserId end
    return api.Config.FrontTargetUserId
end

function api.SelectBoundCandidate(origin, entries, net, backward, nets, frontPresent)
    if not api.InCourt(origin, net) then return nil end
    local side = flat(origin - net.center):Dot(net.normal)
    if math.abs(side) < 0.15 then return nil end
    local id = api.BoundTargetId(backward, frontPresent)
    if api.Config.TargetUserIds[id] ~= true then return nil end
    for _, entry in ipairs(entries) do
        if entry.userId == id and api.TargetNearNet(entry.position, net, nets)
            and flat(entry.position - net.center):Dot(net.normal) * side > 0 then
            return entry
        end
    end
    return nil
end

function api.ReuseTargetSnapshot(snapshot, character, now)
    local grace = math.clamp(api.Config.TargetGraceSeconds, 0, 0.3)
    if snapshot and character and snapshot.character == character
        and now >= snapshot.time and now - snapshot.time <= grace then
        return snapshot.position
    end
    return nil
end

function api.SmoothTargetPoint(current, goal, dt)
    local seconds = math.clamp(api.Config.TargetSmoothingSeconds, 0, 0.1)
    if not current or not dt or seconds == 0 then return goal end
    return current:Lerp(goal, 1 - math.exp(-math.max(0, dt) / seconds))
end

-- Retained as a geometry helper for compatibility; live F/R selection is fixed-ID only.
function api.SelectCandidate(origin, look, entries, net, backward, nets)
    local facing = flat(look)
    if facing.Magnitude < 0.001 or not api.InCourt(origin, net) then return nil end
    local side = flat(origin - net.center):Dot(net.normal)
    if math.abs(side) < 0.15 then return nil end
    facing = facing.Unit * (backward and -1 or 1)
    local best, bestDot, bestDistance = nil, -math.huge, math.huge
    for _, entry in ipairs(entries) do
        local delta = flat(entry.position - origin)
        local distance = delta.Magnitude
        if api.Config.TargetUserIds[entry.userId] == true and distance > 0.2
            and api.TargetNearNet(entry.position, net, nets)
            and flat(entry.position - net.center):Dot(net.normal) * side > 0 then
            local dot = delta.Unit:Dot(facing)
            if dot > 0.05 and (dot > bestDot + 0.0001 or
                (math.abs(dot - bestDot) <= 0.0001 and (distance < bestDistance - 0.0001 or
                (math.abs(distance - bestDistance) <= 0.0001 and entry.userId < best.userId)))) then
                best, bestDot, bestDistance = entry, dot, distance
            end
        end
    end
    return best
end

function api.AimCFrame(current, point, backward)
    local direction = flat(point - current.Position)
    local oldFacing = flat(current.LookVector)
    if direction.Magnitude < 0.2 or oldFacing.Magnitude < 0.001 then return nil end
    direction = direction.Unit * (backward and -1 or 1)
    local previousYaw = CFrame.lookAt(Vector3.zero, oldFacing.Unit)
    local tilt = previousYaw:Inverse() * (current - current.Position)
    return CFrame.new(current.Position) * CFrame.lookAt(Vector3.zero, direction) * tilt
end
-- TARGET_MATH_END
-- SET_TARGET_LEAD_BEGIN
-- Generated by scripts/sync-vrs-set-target-lead.mjs.
-- Shared sideways receiver prediction. Pure helpers; no character or power writes.
local function installSetTargetLead(api)
    local function valid(v)
        return v and type(v.X) == "number" and type(v.Y) == "number" and type(v.Z) == "number"
            and v.X == v.X and v.Y == v.Y and v.Z == v.Z
            and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
    end
    local function flat(v) return Vector3.new(v.X, 0, v.Z) end
    function api.SampleSetTargetMotion(previous, character, position, reportedVelocity, now)
        local maximum = math.clamp(tonumber(api.Config.SetLeadMaxSpeed) or 45, 1, 100)
        local velocity = valid(reportedVelocity) and flat(reportedVelocity) or Vector3.zero
        if velocity.Magnitude > maximum then velocity = Vector3.zero end
        local samples = {}
        if previous and previous.character == character then
            local dt = now - previous.time
            if dt >= 1 / 240 and dt <= 0.3 then
                if flat(position - previous.position).Magnitude > math.max(8, maximum * dt * 2.5) then
                    return {character = character, position = position, velocity = Vector3.zero, time = now,
                        samples = {{position = position, time = now}}}
                end
                -- Replicated positions arrive in packets, not once per rendered frame.
                for _, sample in ipairs(previous.samples or {{position = previous.position, time = previous.time}}) do
                    if now - sample.time <= 0.12 then samples[#samples + 1] = sample end
                end
                local first = samples[1]
                if velocity.Magnitude < 0.5 and first and now - first.time >= 0.06 then
                    local measured = flat(position - first.position) / (now - first.time)
                    if measured.Magnitude <= maximum then velocity = measured end
                elseif velocity.Magnitude < 0.5 and first then
                    velocity = previous.velocity
                end
                local old = previous.velocity or Vector3.zero
                if velocity.Magnitude > 0.5 and old:Dot(velocity) > 0 then
                    velocity = old:Lerp(velocity, 1 - math.exp(-dt / 0.06))
                end
            elseif dt >= 0 and dt < 1 / 240 then
                return previous -- Two F/R lookups in one frame must not erase motion history.
            end
        end
        if velocity.Magnitude < 0.5 then velocity = Vector3.zero end
        samples[#samples + 1] = {position = position, time = now}
        return {character = character, position = position, velocity = velocity, time = now, samples = samples}
    end
    function api.NewSetAimPlan(point, position, velocity, net, now)
        return {point = point, anchor = point, position = position,
            velocity = valid(velocity) and flat(velocity) or Vector3.zero,
            net = net, started = now, updated = now}
    end
    function api.UpdateSetAimPlan(plan, position, now)
        local dt = math.clamp(now - plan.updated, 0, 0.05)
        plan.updated = now
        local axis, net = plan.net.axis, plan.net
        local expected = plan.position + plan.velocity * math.max(0, now - plan.started)
        local error = flat(position - expected):Dot(axis)
        local deadzone = math.clamp(tonumber(api.Config.SetAimDeadzone) or 0.65, 0, 2)
        local limit = math.clamp(tonumber(api.Config.SetAimMaxCorrection) or 2, 0, 5)
        local correction = math.sign(error) * math.clamp(math.abs(error) - deadzone, 0, limit)
        local along = flat(plan.anchor - net.center):Dot(axis)
        local edge = math.max(math.abs(along), net.halfWidth - (tonumber(api.Config.SetLeadEdgeMargin) or 1.5))
        local desired = math.clamp(along + correction, -edge, edge) - along
        local current = (plan.point - plan.anchor):Dot(axis)
        local rate = math.clamp(tonumber(api.Config.SetAimCorrectionSpeed) or 4, 0, 12)
        local step = (desired - current) * (1 - math.exp(-dt / 0.12))
        step = math.clamp(step, -rate * dt, rate * dt)
        plan.point = plan.anchor + axis * (current + step)
        return plan.point
    end
    function api.LeadSetPoint(position, velocity, net, origin, seconds)
        local base = api.SetAimPoint(position, net, origin)
        if not base then return nil end
        if api.Config.SetLeadEnabled == false or not valid(velocity) then return base, 0 end
        local lateral = flat(velocity):Dot(net.axis)
        if math.abs(lateral) < 0.5 then return base, 0 end
        local maximum = math.clamp(tonumber(api.Config.SetLeadMaxStuds) or 10, 0, 20)
        local horizon = math.clamp(tonumber(api.Config.SetLeadMaxSeconds) or 0.85, 0, 1.5)
        local shift = math.clamp(lateral * math.clamp(seconds or 0, 0, horizon), -maximum, maximum)
        local along = flat(base - net.center):Dot(net.axis)
        local edge = math.max(0, net.halfWidth - (tonumber(api.Config.SetLeadEdgeMargin) or 1.5))
        -- Never pull an existing near-line target inward merely because prediction is enabled.
        local limit = math.max(edge, math.abs(along))
        local predicted = math.clamp(along + shift, -limit, limit)
        return base + net.axis * (predicted - along), predicted - along
    end
    function api.SolveSetLead(position, velocity, net, origin, travelSeconds, extraSeconds)
        local point = api.SetAimPoint(position, net, origin)
        if not point then return nil end
        local info = {seconds = 0, shift = 0, estimated = true}
        if api.Config.SetLeadEnabled == false or not valid(velocity) then return point, info end
        for _ = 1, 3 do
            local flight = travelSeconds(point)
            if type(flight) ~= "number" or flight ~= flight or flight <= 0 or flight > 4 then
                return api.SetAimPoint(position, net, origin), {seconds = 0, shift = 0, unavailable = true}
            end
            local lead = math.clamp(flight + math.clamp(extraSeconds or 0, 0, 0.25), 0,
                math.clamp(tonumber(api.Config.SetLeadMaxSeconds) or 0.85, 0, 1.5))
            local shift
            point, shift = api.LeadSetPoint(position, velocity, net, origin, lead)
            if not point then return nil end
            info = {seconds = lead, flightSeconds = flight, shift = shift, estimated = true}
        end
        return point, info
    end
end
installSetTargetLead(api)
-- SET_TARGET_LEAD_END

-- VISUAL_MATH_BEGIN
function api.PointInSetShape(point, shape)
    if shape.kind == "ellipsoid" then
        local r = shape.radii
        if math.min(r.X, r.Y, r.Z) <= 0 then return false end
        local d = point - shape.center
        return (d.X / r.X)^2 + (d.Y / r.Y)^2 + (d.Z / r.Z)^2 <= 1
    end
    local d = shape.cframe:PointToObjectSpace(point)
    local half = shape.size * 0.5
    return math.abs(d.X) <= half.X and math.abs(d.Y) <= half.Y and math.abs(d.Z) <= half.Z
end

function api.IsOpposingServeSource(origin, source, net, ownTeam, sourceTeam, nets)
    if ownTeam and sourceTeam and ownTeam == sourceTeam then return false end
    if not api.TargetNearNet(source, net, nets) then return false end
    return flat(origin - net.center):Dot(net.normal) * flat(source - net.center):Dot(net.normal) < 0
end

function api.ServeFacingSegment(origin, source, look, net, floorY, maxLength)
    -- Project the character's facing onto the floor, regardless of which way they turn.
    local direction = flat(look)
    if direction.Magnitude < 0.001 or maxLength <= 0 then return nil end
    local start = Vector3.new(source.X, floorY + 0.13, source.Z)
    return start, start + direction.Unit * maxLength
end

function api.KeepServeFacing(lastReady, now, ready)
    return ready == true or (lastReady ~= nil and now >= lastReady
        and now - lastReady <= (api.Config.ServeFacingGraceSeconds or 2.5))
end

function api.ServeViewerNet(position, nets)
    for _, net in ipairs(nets) do
        if api.InCourt(position, net) then return net end
    end
    local net = api.NearestNet(position, nets)
    if not net then return nil end
    local offset = flat(position - net.courtCenter)
    if math.abs(offset:Dot(net.axis)) <= net.halfWidth + 20
        and math.abs(offset:Dot(net.normal)) <= net.halfDepth + 30 then return net end
    return nil
end
-- VISUAL_MATH_END

-- RECEIVE_MATH_BEGIN
function api.BuildReceiveCore(recPosition, recSize, headPosition, headSize, rootPosition, rootSize, hipHeight, options)
    local radius = recSize.X * 0.5 * (1 + (options.stack or 0) * (options.charge or 0))
    local bottom = rootPosition.Y - rootSize.Y * 0.5 - hipHeight + (options.belowFeet or 0)
    local top = headPosition.Y + headSize.Y * 0.5 + (options.aboveHead or 0) + (options.extraHeight or 0)
    top = bottom + (top - bottom) * (1 + (options.topScale or 0))
    if radius <= 0 or top <= bottom then return nil end
    -- Conservative core of the game's displayed receive cylinder; omit pity/head-only extensions.
    return {center = Vector3.new(recPosition.X, (top + bottom) * 0.5, recPosition.Z),
        radius = radius, bottom = bottom, top = top}
end

function api.PointInReceiveCore(point, shape)
    if not point or not shape then return false end
    return point.Y >= shape.bottom and point.Y <= shape.top
        and flat(point - shape.center).Magnitude <= shape.radius
end

function api.BuildReceiveArea(core, pity)
    if not core then return nil end
    local tolerance = 0
    if pity and pity.Enabled == true then
        tolerance = math.max(0, tonumber(pity.RaggioPalla) or 0) + math.max(0, tonumber(pity.Extra) or 0)
    end
    return {center = core.center, bottom = core.bottom, top = core.top,
        coreRadius = core.radius, radius = core.radius + tolerance, tolerance = tolerance}
end

function api.ReceiveContactBand(point, area)
    if not point or not area then return nil end
    local radial = flat(point - area.center).Magnitude
    if point.Y < area.bottom - 0.0001 or point.Y > area.top + 0.0001 or radial > area.radius + 0.0001 then return nil end
    return radial <= (area.coreRadius or area.radius) + 0.0001 and "core" or "tolerance"
end

function api.ReceiveLeadTime(ping, frameSeconds)
    local maximum = math.clamp(api.Config.ReceiveMaxLead or 0.24, 0.06, 0.35)
    return math.clamp((api.Config.ReceiveLeadSeconds or 0.08) + math.clamp(ping or 0, 0, 0.2)
        + 2 * math.clamp(frameSeconds or 1 / 60, 1 / 240, 0.05), 0.06, maximum)
end

function api.ReceiveSegmentEntry(a, b, shape)
    local delta, offset = b - a, a - shape.center
    local lo, hi = 0, 1
    if math.abs(delta.Y) < 1e-9 then
        if a.Y < shape.bottom or a.Y > shape.top then return nil end
    else
        local t1, t2 = (shape.bottom - a.Y) / delta.Y, (shape.top - a.Y) / delta.Y
        lo, hi = math.max(lo, math.min(t1, t2)), math.min(hi, math.max(t1, t2))
    end
    local aa = delta.X^2 + delta.Z^2
    local bb = 2 * (offset.X * delta.X + offset.Z * delta.Z)
    local cc = offset.X^2 + offset.Z^2 - shape.radius^2
    if aa < 1e-12 then
        if cc > 0 then return nil end
    else
        local discriminant = bb^2 - 4 * aa * cc
        if discriminant < 0 then return nil end
        local root = math.sqrt(discriminant)
        lo, hi = math.max(lo, (-bb - root) / (2 * aa)), math.min(hi, (-bb + root) / (2 * aa))
    end
    if lo <= hi then return lo end
    return nil
end

function api.ReceiveEntryTime(ball, shape, motion, horizon)
    if not ball.position or not ball.velocity or not shape then return nil end
    if api.PointInReceiveCore(ball.position, shape) then return 0, ball.position end
    horizon = math.clamp(horizon or 0, 0, 0.35)
    local position, velocity, spin = ball.position, ball.velocity, ball.spin or Vector3.zero
    local elapsed = 0
    while elapsed < horizon - 1e-8 do
        local dt = math.min(1 / 120, tuning.PASSO_MAX or 1 / 120, horizon - elapsed)
        local nextVelocity, nextPosition, nextSpin = physics.PassoValori(position, velocity, spin, dt,
            ball.side, ball.gravity, ball.rampFraction, ball.rampExponent, ball.rampMin)
        -- Continuous segment/cylinder entry catches fast balls that cross between integration samples.
        local fraction = api.ReceiveSegmentEntry(position - motion * elapsed, nextPosition - motion * (elapsed + dt), shape)
        if fraction then
            return elapsed + fraction * dt,
                (position - motion * elapsed):Lerp(nextPosition - motion * (elapsed + dt), fraction)
        end
        position, velocity, spin = nextPosition, nextVelocity, nextSpin
        elapsed = elapsed + dt
        if position.Y < shape.bottom and velocity.Y <= 0 then return nil end
    end
    return nil
end

function api.ShouldAutoReceive(context, ball, shape, attempt, now)
    if not context.enabled then return false, "OFF" end
    if not context.focused and not context.allowBackground then return false, "game unfocused" end
    if context.chat or context.menu or context.pointerBlocked then return false, "UI / typing" end
    if not context.alive or not context.grounded or context.sitting or context.anchored then return false, "grounded only" end
    if not context.court or context.inMatch == false or context.serving or context.commandsBlocked then return false, "waiting for play" end
    if context.manual or now < context.manualUntil then return false, "manual action" end
    if context.pending or now < context.nextAttempt then return false, "cooldown" end
    if not shape then return false, "receive volume unavailable" end
    if not ball.active or ball.ownTouch or not ball.ownHalf or not ball.sameCourt then return false, "waiting for incoming ball" end
    if not ball.velocity or ball.velocity.Magnitude < 0.1 then return false, "waiting for ball motion" end
    local approaching = (ball.position - shape.center):Dot(ball.velocity - context.motion) < -0.1
    if not approaching and ball.velocity.Y >= -0.5 then return false, "ball moving away" end
    if attempt then
        local eventKnown = ball.eventN ~= nil or ball.eventTime ~= nil
        local sameEvent = eventKnown and attempt.eventN == ball.eventN and attempt.eventTime == ball.eventTime
        if not attempt.sawOutside or sameEvent then return false, "already attempted" end
    end
    local entryTime, contact = api.ReceiveEntryTime(ball, shape, context.motion, context.lookahead)
    if entryTime == nil then return false, "armed" end
    return true, entryTime == 0 and "contact" or "pre-contact", entryTime, api.ReceiveContactBand(contact, shape)
end
-- RECEIVE_MATH_END

local aimMarker = part("AimTarget", Color3.fromRGB(121, 255, 177), Vector3.new(0.8, 0.8, 0.8))
aimMarker.Shape = Enum.PartType.Ball
local aimTag = make("BillboardGui", {Size = UDim2.fromOffset(190, 30), AlwaysOnTop = true,
    StudsOffset = Vector3.new(0, 1.1, 0), Adornee = aimMarker, Enabled = false}, aimMarker)
local aimLabel = make("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = aimMarker.Color,
    TextStrokeTransparency = 0.25, Text = "SET TARGET"}, aimTag)

local function refreshNets()
    netCache = {}
    local courts = workspace:FindFirstChild("InCourts")
    if not courts then return end
    -- The observed map has multiple same-named NetTop parts: match geometry, not FindFirstChild.
    for _, court in ipairs(courts:GetChildren()) do
        if court:IsA("BasePart") then
            for _, top in ipairs(workspace:GetChildren()) do
                if top.Name == "NetTop" and top:IsA("BasePart")
                    and flat(top.Position - court.Position).Magnitude < 2 then
                    local axis = flat(top.CFrame.RightVector)
                    if axis.Magnitude > 0.99 then
                        axis = axis.Unit
                        local alignedX = math.abs(axis:Dot(court.CFrame.RightVector)) > 0.99
                        local alignedZ = math.abs(axis:Dot(court.CFrame.LookVector)) > 0.99
                        if alignedX or alignedZ then
                            table.insert(netCache, {part = top, court = court, center = top.Position,
                                courtCenter = court.Position, axis = axis,
                                normal = Vector3.new(-axis.Z, 0, axis.X),
                                halfWidth = math.min(top.Size.X, alignedX and court.Size.X or court.Size.Z) * 0.5,
                                halfDepth = (alignedX and court.Size.Z or court.Size.X) * 0.5})
                        end
                    end
                end
            end
        end
    end
end

function api.GetNetAt(position)
    for _, net in ipairs(netCache) do
        if net.part.Parent and net.court.Parent and api.InCourt(position, net) then return net end
    end
    return nil
end

-- TARGET_LOOKUP_BEGIN
local function readTargetById(id, name)
    local candidate = Players:GetPlayerByUserId(id)
    if not candidate or not api.IsAllowedTarget(candidate) then
        targetSnapshots[id] = nil
        return nil, name .. ": not in this server"
    end
    local character = candidate.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or (humanoid and humanoid.Health <= 0) then
        targetSnapshots[id] = nil
        return nil, name .. ": respawning"
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    local now = os.clock()
    local position, velocity
    if root and root:IsA("BasePart") and humanoid then
        position = root.Position
        local snapshot = api.SampleSetTargetMotion(targetSnapshots[id], character, position, root.AssemblyLinearVelocity, now)
        targetSnapshots[id] = snapshot
        velocity = snapshot.velocity
    else
        position = api.ReuseTargetSnapshot(targetSnapshots[id], character, now)
        velocity = Vector3.zero -- Stale streamed characters cannot keep leading indefinitely.
    end
    if not position then return nil, name .. ": character not ready" end
    return {player = candidate, userId = id, position = position, velocity = velocity, character = character}
end
function api.ReadBoundTarget(backward, origin, net, candidates)
    if backward then return readTargetById(api.Config.BackTargetUserId, api.Config.BackTargetName or "ld090812") end
    local name = api.Config.FrontTargetName or "sippywippy"
    local primary, reason = readTargetById(api.Config.FrontTargetUserId, name)
    api.FrontTargetStatus = {primaryId = api.Config.FrontTargetUserId, fallbackId = api.Config.FrontFallbackUserId}
    if origin and net then
        if primary and api.InCourt(primary.position, net)
            and api.SelectBoundCandidate(origin, {primary}, net, false, candidates, true) then
            api.FrontTargetStatus.primaryReady = true
            return primary
        end
        if primary then
            if not api.InCourt(primary.position, net) then reason = name .. ": outside this court"
            elseif math.abs(flat(origin - net.center):Dot(net.normal)) < 0.15 then reason = "Move away from net center"
            else reason = name .. ": opposite net side" end
        end
        local fallback, fallbackReason = readTargetById(api.Config.FrontFallbackUserId, "nl223602")
        api.FrontTargetStatus.primaryReason, api.FrontTargetStatus.fallbackReason = reason, fallbackReason
        if not fallback then return nil, reason or fallbackReason end
        if api.InCourt(fallback.position, net)
            and api.SelectBoundCandidate(origin, {fallback}, net, false, candidates, false) then
            api.FrontTargetStatus.fallbackReady = true
            return fallback
        end
        api.FrontTargetStatus.fallbackReason = "nl223602: different court/side"
        return nil, reason or api.FrontTargetStatus.fallbackReason
    end
    if Players:GetPlayerByUserId(api.Config.FrontTargetUserId) then return primary, reason end
    return readTargetById(api.Config.FrontFallbackUserId, "nl223602")
end
-- TARGET_LOOKUP_END

function api.ResolveTarget(backward)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil, "Waiting for character" end
    local net = api.GetNetAt(root.Position)
    if not net then return nil, "No verified court/net here" end
    local candidate, reason = api.ReadBoundTarget(backward, root.Position, net, netCache)
    if not candidate then return nil, reason end
    local entry = api.SelectBoundCandidate(root.Position, {candidate}, net, backward, netCache,
        backward or candidate.userId == api.Config.FrontTargetUserId)
    if not entry then return nil, candidate.player.Name .. ": different net/side" end
    return {player = entry.player, userId = entry.userId, net = net, backward = backward,
        point = api.SetAimPoint(entry.position, net, root.Position)}
end

stopAim = function()
    if savedRotation then
        if savedRotation.humanoid.Parent then savedRotation.humanoid.AutoRotate = savedRotation.value end
        savedRotation = nil
    end
    aim, api.Target = nil, nil
    aimMarker.Transparency, aimTag.Enabled = 1, false
end

function api.MovingSetAimPoint(target, net, backward)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local power = character and character:FindFirstChild("Power")
    if not root or not power then return nil end
    local previous = api.Last and api.Last.State
    if previous and (not previous.sampledAt or os.clock() - previous.sampledAt > 0.15) then previous = nil end
    local origin = previous and previous.origin or root.Position + Vector3.new(0, api.Config.ContactHeight, 0)
    if (origin - root.Position).Magnitude > 18 then origin = root.Position + Vector3.new(0, api.Config.ContactHeight, 0) end
    local function travel(point)
        local facing = api.AimCFrame(root.CFrame, point, backward)
        if not facing then return nil end
        local direction = facing.LookVector * (backward and -1 or 1)
        local velocity = tuning.Alzata({palla = origin, giocatore = root.Position,
            potenza = math.max(0, power.Value), direzione = direction, portata = 4 * api.Config.RangeScale})
        if not velocity then return nil end
        local distance, speed = (point - origin):Dot(net.normal), velocity:Dot(net.normal)
        if math.abs(speed) < 0.1 then return nil end
        return distance / speed
    end
    local point, info = api.SolveSetLead(target.position, target.velocity, net, root.Position, travel,
        (previous and previous.latency or 0) + 0.04)
    api.SetLead = info
    return point
end

local function applyAim(dt)
    if not aim then return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local target = root and api.ReadBoundTarget(aim.backward, root.Position, aim.net, netCache)
    local now = os.clock()
    if not api.Config.AimEnabled or not root or not humanoid or humanoid.Health <= 0 or root.Anchored
        or humanoid.Sit or not target or target.player ~= aim.player
        or aim.player.Parent ~= Players or not api.IsAllowedTarget(aim.player)
        or UIS:GetFocusedTextBox() or GuiService.MenuIsOpen
        or now >= aim.maxUntil or (now >= aim.holdUntil and not UIS:IsKeyDown(aim.key))
        or not aim.net.part.Parent or not aim.net.court.Parent
        or not api.InCourt(root.Position, aim.net) or not api.TargetNearNet(target.position, aim.net, netCache)
        or flat(root.Position - aim.net.center):Dot(aim.net.normal)
            * flat(target.position - aim.net.center):Dot(aim.net.normal) <= 0 then
        stopAim()
        return
    end
    local aimPoint = api.SetAimPoint(target.position, aim.net, root.Position)
    if not aimPoint then stopAim(); return end
    if not aim.plan then
        aimPoint = api.MovingSetAimPoint(target, aim.net, aim.backward) or aimPoint
        aim.plan = api.NewSetAimPlan(aimPoint, target.position, target.velocity, aim.net, now)
        aim.lead = api.SetLead or {}
    end
    aim.point = api.UpdateSetAimPlan(aim.plan, target.position, now)
    api.SetLead = aim.lead
    api.SetLead.committed = true
    api.SetLead.correction = (aim.point - aim.plan.anchor):Dot(aim.net.axis)
    local facing = api.AimCFrame(root.CFrame, aim.point, aim.backward)
    if not facing then stopAim(); return end
    if not savedRotation then savedRotation = {humanoid = humanoid, value = humanoid.AutoRotate} end
    humanoid.AutoRotate = false
    -- Only yaw changes: no teleport, velocity modification, pitch change, power change, or set call.
    root.CFrame = facing
    api.Target = aim
    aimMarker.Position = aim.point
    aimMarker.Transparency, aimTag.Enabled = 0.15, true
    aimLabel.Text = aim.player.Name .. " / SET"
end

function api.BeginAim(backward, key)
    stopAim()
    if not api.Config.AimEnabled or UIS:GetFocusedTextBox() or GuiService.MenuIsOpen then return false end
    local selection, reason = api.ResolveTarget(backward)
    if not selection then
        targetMessage, targetMessageUntil = reason, os.clock() + 1
        log("aim_unavailable", reason)
        return false
    end
    targetMessage = nil
    local now = os.clock()
    selection.key = key or (backward and backAimKey or frontAimKey)
    selection.holdUntil = now + math.clamp(api.Config.AimHoldSeconds, 0, 1)
    selection.maxUntil = now + math.clamp(api.Config.MaxAimHoldSeconds, 0.5, 2)
    aim = selection
    local ok, err = pcall(applyAim)
    if not ok then stopAim(); log("aim_error", tostring(err)); return false end
    if not aim then return false end
    log("aim_selected", {userId = aim.userId, back = backward, point = aim.point})
    return true
end

local function bindAimKeys()
    CAS:UnbindAction(aimAction)
    frontAimKey = Enum.KeyCode[api.Config.FrontAimKey or "F"]
    backAimKey = Enum.KeyCode[api.Config.BackAimKey or "R"]
    CAS:BindActionAtPriority(aimAction, function(_, inputState, input)
        if env.VRSKeyCapture then return Enum.ContextActionResult.Pass end
        if inputState == Enum.UserInputState.Begin then
            api.BeginAim(input.KeyCode == backAimKey, input.KeyCode)
        elseif inputState == Enum.UserInputState.Cancel then
            stopAim()
        end
        -- Let the game's normal key handler do the set; never synthesize a second input.
        return Enum.ContextActionResult.Pass
    end, false, Enum.ContextActionPriority.High.Value + 100, frontAimKey, backAimKey)
end

function api.RebindAimKeys()
    if stopAim then stopAim() end
    bindAimKeys()
end

refreshNets()
bindAimKeys()
connect(UIS.WindowFocusReleased, stopAim)
connect(UIS.TextBoxFocused, stopAim)
connect(player.CharacterRemoving, stopAim)
connect(Players.PlayerRemoving, function(leaving)
    targetSnapshots[leaving.UserId] = nil
    if aim and aim.player == leaving then stopAim() end
end)
local function watchTarget(candidate)
    if not api.IsAllowedTarget(candidate) then return end
    connect(candidate.CharacterRemoving, function()
        targetSnapshots[candidate.UserId] = nil
        if aim and aim.player == candidate then stopAim() end
    end)
end
for _, candidate in ipairs(Players:GetPlayers()) do watchTarget(candidate) end
connect(Players.PlayerAdded, watchTarget)
local netRefreshElapsed, targetRefreshElapsed = 0, 1

-- Parameters are pure values so prediction can also be checked without changing gameplay.
function api.Launch(s, backward)
    -- Preview uses actual body facing for launch accuracy; F/R target identities are fixed.
    -- Historical facing is useful for replay, but makes a live aiming line trail turns.
    local direction = (api.Config.LagCompensation and api.Config.ServerDirectionPreview and s.serverLook) or s.look
    if direction.Magnitude < 0.001 then direction = Vector3.new(0, 0, -1) end
    direction = direction.Unit * (backward and -1 or 1)
    -- Power zero is valid. Tilt is already contained in the body's LookVector;
    -- adding separate yaw/height multipliers would apply a different launch rule.
    local root = api.Config.LagCompensation and s.serverRoot or s.root
    if not s.serverRoot and api.Config.LagCompensation and s.motion and s.airborne and s.motion.Y < -0.5
        and root.Y > (s.floor or 0.408) + (s.standingHeight or 4.012) + 0.4 then
        local lag = math.clamp(s.latency or 0, 0, 0.2)
        -- Replicated set events use the server's delayed character transform.
        -- Reverse the local falling motion by the measured network delay.
        root = root - s.motion * lag - Vector3.new(0, 0.5 * workspace.Gravity * lag * lag, 0)
        root = Vector3.new(root.X, math.max(root.Y, (s.floor or 0.408) + (s.standingHeight or 4.012)), root.Z)
    end
    return tuning.Alzata({palla = s.origin, giocatore = root,
        potenza = math.max(0, s.power), direzione = direction, portata = 4 * api.Config.RangeScale})
end

-- FLIGHT_MATH_BEGIN
function api.Flight(origin, velocity, floor, options)
    options = options or {}
    local initialVelocity = velocity
    local pos, spin = origin, options.spin or Vector3.zero
    local nodes = {pos}
    -- The game's renderer/collision floor uses ground + 1, despite a 1.05 mesh radius.
    local floorY = floor + (options.radius or api.Config.CollisionRadius)
    local dt, time, apex = math.min(tuning.PASSO_MAX or 1 / 60, 1 / 60), 0, pos.Y
    local freezeAt, freezeGravity
    if options.freeze and tuning.GRAVITA.Y < 0 and type(tuning.SET_FREEZE_FRAZ) == "number"
        and type(tuning.SET_FREEZE_G) == "number" then
        -- Verified trace: normal rise, then increased gravity at a fraction of normal time-to-apex.
        freezeAt = math.max(0, initialVelocity.Y) / -tuning.GRAVITA.Y * tuning.SET_FREEZE_FRAZ
        freezeGravity = tuning.SET_FREEZE_G
    end
    local lastPos = pos
    for step = 1, 600 do
        lastPos = pos
        local gravity = options.gravity
        if freezeAt and time >= freezeAt then gravity = freezeGravity end
        velocity, pos, spin = physics.PassoValori(pos, velocity, spin, dt,
            options.side, gravity, options.rampFraction, options.rampExponent, options.rampMin)
        time = time + dt
        apex = math.max(apex, pos.Y)
        if pos.Y <= floorY and velocity.Y <= 0 then
            local alpha = math.clamp((lastPos.Y - floorY) / math.max(lastPos.Y - pos.Y, 0.00001), 0, 1)
            pos = lastPos:Lerp(pos, alpha)
            table.insert(nodes, pos)
            break
        end
        if step % 3 == 0 then table.insert(nodes, pos) end
    end
    if nodes[#nodes] ~= pos then table.insert(nodes, pos) end
    return {nodes = nodes, landing = pos, time = time, apex = apex, velocity = initialVelocity,
        freezeAt = freezeAt, freezeGravity = freezeGravity,
        distance = (Vector3.new(pos.X, origin.Y, pos.Z) - origin).Magnitude}
end
-- FLIGHT_MATH_END

-- LANDING_MATH_BEGIN
function api.IncomingLandingEligible(viewer, ball, net, nets)
    if not ball.active or not ball.position or not ball.velocity or ball.ownTouch or ball.ownServe then return false end
    if ball.velocity.Magnitude < 0.1 or ball.position.Y <= ball.floor + api.Config.CollisionRadius + 0.02 then return false end
    if not api.TargetNearNet(ball.position, net, nets) then return false end
    local ownSide = flat(viewer - net.center):Dot(net.normal)
    if math.abs(ownSide) < 0.15 then return false end
    local sign = ownSide > 0 and 1 or -1
    local ballSide = flat(ball.position - net.center):Dot(net.normal) * sign
    local incoming = flat(ball.velocity):Dot(net.normal) * sign > 0.1
    return incoming or (ballSide >= 0 and ball.velocity.Y < -0.1)
end

function api.PredictIncomingLanding(viewer, ball, net, nets)
    if not api.IncomingLandingEligible(viewer, ball, net, nets) then return nil end
    local flight = api.Flight(ball.position, ball.velocity, ball.floor, ball.options)
    if flight.landing.Y > ball.floor + api.Config.CollisionRadius + 0.05 then return nil end
    local side = flat(viewer - net.center):Dot(net.normal)
    if flat(flight.landing - net.center):Dot(net.normal) * side <= 0 then return nil end
    return {flight = flight, inCourt = api.InCourt(flight.landing, net), eventN = ball.eventN, eventTime = ball.eventTime}
end

function api.LandingTimeRemaining(flightTime, solvedAt, now)
    return math.max(0, flightTime - math.max(0, now - solvedAt))
end
-- LANDING_MATH_END

function api.Predict(s, backward)
    local velocity, target = api.Launch(s, backward)
    local flight = api.Flight(s.origin, velocity, s.floor, {freeze = s.freeze})
    flight.target = target
    flight.distance = (Vector3.new(flight.landing.X, s.root.Y, flight.landing.Z) - s.root).Magnitude
    return flight
end

local function draw(v, prediction, floorY, dt, smoothingKey)
    local nodes = prediction.nodes
    local count = #v.parts
    local key = prediction.confirmed and "confirmed" or smoothingKey
    local seconds = math.clamp(api.Config.VisualSmoothingSeconds, 0, 0.1)
    local blend = seconds > 0 and (1 - math.exp(-dt / seconds)) or 1
    if v.smoothingKey ~= key then v.points = nil end
    v.smoothingKey = key
    local points = v.points or {}
    local fresh = v.points == nil
    -- Fixed fractional sampling avoids segment jumps when flight duration changes.
    for i = 1, count + 1 do
        local index = 1 + (i - 1) * (#nodes - 1) / count
        local lower = math.floor(index)
        local point = nodes[lower]:Lerp(nodes[math.min(lower + 1, #nodes)], index - lower)
        points[i] = fresh and point or points[i]:Lerp(point, blend)
    end
    v.points = points
    for i, p in ipairs(v.parts) do
        if i <= count then
            local a, b = points[i], points[i + 1]
            local length = (b - a).Magnitude
            if length > 0.001 then
                p.Size = Vector3.new(0.1, 0.1, length)
                p.CFrame = CFrame.lookAt((a + b) * 0.5, b)
                p.Transparency = 0.15
            else p.Transparency = 1 end
        else p.Transparency = 1 end
    end
    local land = points[count + 1]
    v.marker.CFrame = CFrame.new(land.X, floorY + 0.1, land.Z) * CFrame.Angles(0, 0, math.pi / 2)
    v.marker.Transparency, v.tag.Enabled = 0.4, true
    v.label.Text = string.format("%s  %s%.1f studs", v.name or (v == visuals.Front and "FRONT" or "BACK"),
        prediction.confirmed and "" or "~", prediction.distance)
end

local trackedBalls, seenEvents = {}, setmetatable({}, {__mode = "k"})
local scanElapsed, elapsed, lastLog, lastState = 1, 1, 0, nil
local renderFront, renderBack, renderState
local standingHeight = 4.012
local function state()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local power = character and character:FindFirstChild("Power")
    if not root or not power then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local floorY = tonumber(workspace:GetAttribute("NG_QuotaSuolo")) or tuning.QUOTA_CAMPO or 0.408
    if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
        standingHeight = humanoid.HipHeight + root.Size.Y * 0.5
    end
    local origin = root.Position + Vector3.new(0, api.Config.ContactHeight, 0)
    local nearest, nearestPos, distance = nil, nil, 8
    for _, ball in ipairs(trackedBalls) do
        local p = ball.Parent and ball:FindFirstChild("Position")
        if p and ball.Name == "Ball" and not ball:GetAttribute("DeadAt") and not ball:GetAttribute("Settling") and p.Value.Y > floorY + 1.5 then
            local displayed = ball:FindFirstChild("Ball1")
            local pos = displayed and displayed:IsA("BasePart") and displayed.Position or p.Value
            local d = (pos - origin).Magnitude
            if d < distance then nearest, nearestPos, distance = ball, pos, d end
        end
    end
    if nearest then origin = nearestPos end
    local now = workspace:GetServerTimeNow()
    local latency = math.clamp(player:GetNetworkPing(), 0, 0.2)
    local history = api.History
    table.insert(history, {time = now, root = root.Position, look = root.CFrame.LookVector})
    while #history > 2 and now - history[2].time > 0.3 do table.remove(history, 1) end
    local delayed
    local targetTime = now - latency
    for i = 2, #history do
        local before, after = history[i - 1], history[i]
        if before.time <= targetTime and after.time >= targetTime then
            local alpha = math.clamp((targetTime - before.time) / math.max(after.time - before.time, 0.00001), 0, 1)
            local look = before.look:Lerp(after.look, alpha)
            delayed = {root = before.root:Lerp(after.root, alpha),
                look = look.Magnitude > 0.001 and look.Unit or after.look}
            break
        end
    end
    return {root = root.Position, look = root.CFrame.LookVector, origin = origin, sampledAt = os.clock(),
        serverRoot = delayed and delayed.root, serverLook = delayed and delayed.look,
        floor = floorY, power = power.Value, tilt = tostring(player:GetAttribute("TiltValue") or "None"),
        airborne = player:GetAttribute("NG_InAria") == true or
            (humanoid and humanoid.FloorMaterial == Enum.Material.Air) or false,
        contact = nearest ~= nil, ball = nearest, motion = root.AssemblyLinearVelocity,
        standingHeight = standingHeight, latency = latency,
        freeze = (tonumber(player:GetAttribute("TraitSetFreeze")) or 0) > 0}
end
local function scan()
    local cache = workspace:FindFirstChild("BallCache")
    trackedBalls = cache and cache:GetChildren() or {}
    for _, ball in ipairs(trackedBalls) do
        local event = ball:GetAttribute("NG_EvN")
        if event ~= seenEvents[ball] then
            if confirmed and confirmed.ball == ball then confirmed = nil end
            local wasSeen = seenEvents[ball] ~= nil
            seenEvents[ball] = event
            local owner = ball:GetAttribute("NG_ToccoUltimo") or ball:GetAttribute("NG_UltimoTocco") or ball:GetAttribute("NG_TutPalla")
            local pos, vel, when = ball:GetAttribute("NG_EvP"), ball:GetAttribute("NG_EvV"), ball:GetAttribute("NG_EvT")
            local recentPress = lastPress and type(when) == "number" and when - lastPress.time > -0.3 and when - lastPress.time < 1.2
            if ball.Name == "Ball" and not ball:GetAttribute("DeadAt") and not ball:GetAttribute("Settling")
                and typeof(pos) == "Vector3" and typeof(vel) == "Vector3" and pos.Y > 3
                and lastState and (pos - lastState.root).Magnitude < 18 and recentPress
                and ball:GetAttribute("NG_UltimoTipo") == "Set" then
                local flightOptions = {spin = ball:GetAttribute("NG_EvS"), freeze = lastState.freeze,
                    gravity = lastState.freeze and 1 or ball:GetAttribute("NG_GravFattore"), side = ball:GetAttribute("NG_SpinOltreRete"),
                    rampFraction = ball:GetAttribute("NG_SpinRampaFraz"), rampExponent = ball:GetAttribute("NG_SpinRampaEsp"),
                    rampMin = ball:GetAttribute("NG_SpinRampaMin")}
                local flight = api.Flight(pos, vel, lastState.floor, flightOptions)
                flight.confirmed = true
                confirmed = {flight = flight, back = lastPress.back, untilTime = os.clock() + api.Config.ConfirmedSeconds,
                    power = lastState.power, tilt = lastState.tilt, look = lastState.look, ball = ball}
                local shot = {position = pos, velocity = vel, power = ball:GetAttribute("NG_SetPotenza"),
                    back = lastPress.back, state = lastState, time = when, owner = owner, flightOptions = flightOptions}
                table.insert(api.Captures, shot)
                if #api.Captures > 50 then table.remove(api.Captures, 1) end
                log("observed_set", shot)
                lastPress = nil
                stopAim()
            end
        end
    end
end
local setVolumePart = part("SetVolume", Color3.fromRGB(90, 190, 255), Vector3.one)
local serveFacingPart = part("OpponentServeFacing", Color3.fromRGB(255, 104, 204), Vector3.new(0.12, 0.12, 1))
-- SERVE_FLIGHT_OWNERS_BEGIN
local function activeServeOwners(net)
    local owners = {}
    local cache = workspace:FindFirstChild("BallCache")
    local floor = tonumber(workspace:GetAttribute("NG_QuotaSuolo")) or tuning.QUOTA_CAMPO or 0.408
    for _, ball in ipairs(cache and cache:GetChildren() or {}) do
        local kind = ball:GetAttribute("NG_UltimoTipo")
        if ball.Name == "Ball" and ball.Parent and not ball:GetAttribute("DeadAt") and not ball:GetAttribute("Settling")
            and (kind == "Served" or kind == "Serve") then
            local pos, vel = ball:FindFirstChild("Position"), ball:FindFirstChild("Velocity")
            if pos and pos:IsA("Vector3Value") and vel and vel:IsA("Vector3Value")
                and pos.Value.Y > floor + api.Config.CollisionRadius + 0.02 and vel.Value.Magnitude >= 0.1 then
                local offset = flat(pos.Value - net.courtCenter)
                if math.abs(offset:Dot(net.axis)) <= net.halfWidth + 60
                    and math.abs(offset:Dot(net.normal)) <= net.halfDepth + 60 then
                    local owner = tonumber(ball:GetAttribute("NG_UltimoTocco") or ball:GetAttribute("NG_ToccoUltimo")
                        or ball:GetAttribute("NG_CreatoreId"))
                    if owner then owners[owner] = true end
                end
            end
        end
    end
    return owners
end
-- SERVE_FLIGHT_OWNERS_END
local opposingServer, serveCharacter, serveReadyAt, serveNet
local auxElapsed = 1
api.VisualMetrics = {Errors = 0, FacingUpdates = 0}

function api.GetSetShape()
    local character = player.Character
    local top = character and character:FindFirstChild("TopHitbox")
    local rec = character and character:FindFirstChild("RecHitbox")
    if not top or not rec or not top:IsA("BasePart") or not rec:IsA("BasePart") then
        return nil, "waiting for character hitboxes"
    end
    if not setVolumes or type(setVolumes.acceso) ~= "function" or type(setVolumes.set) ~= "function" then
        return nil, "game volume helper unavailable"
    end
    if setVolumes.acceso() then
        local center, radii = setVolumes.set(top, rec)
        return {kind = "ellipsoid", center = center, radii = radii, source = "NG_SfereColpo.set"}
    end
    return {kind = "box", cframe = top.CFrame, size = top.Size, source = "TopHitbox"}
end

local function hideServe()
    serveFacingPart.Transparency = 1
end

local function scanServe(root, net)
    local owners = activeServeOwners(net)
    local ownTeam = player:GetAttribute("NG_Squadra")
    local now = os.clock()
    if serveNet ~= net.part then
        opposingServer, serveCharacter, serveReadyAt = nil, nil, nil
        serveNet = net.part
    end
    for _, candidate in ipairs(Players:GetPlayers()) do
        local otherRoot = candidate.Character and candidate.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = candidate.Character and candidate.Character:FindFirstChildOfClass("Humanoid")
        if candidate ~= player and (candidate:GetAttribute("NG_PuoBattere") == true or owners[candidate.UserId]) and otherRoot
            and humanoid and humanoid.Health > 0 and api.IsOpposingServeSource(root.Position, otherRoot.Position,
                net, ownTeam, candidate:GetAttribute("NG_Squadra"), netCache) then
            opposingServer, serveCharacter, serveReadyAt = candidate, candidate.Character, now
            return
        end
    end
    -- Keep following the same live character briefly when readiness clears at toss/contact.
    -- Never cache the facing vector: it is read fresh on every rendered frame.
    if not api.KeepServeFacing(serveReadyAt, now, false) then
        opposingServer, serveCharacter, serveReadyAt = nil, nil, nil
    end
end

-- RECEIVE_VISUAL_BEGIN
local receiveCorePart = part("ReceiveCoreVolume", Color3.fromRGB(89, 255, 135), Vector3.one)
local receiveTolerancePart = part("ReceiveToleranceVolume", Color3.fromRGB(255, 187, 83), Vector3.one)
receiveCorePart.Shape, receiveTolerancePart.Shape = Enum.PartType.Cylinder, Enum.PartType.Cylinder
local receiveVolumeTag = make("BillboardGui", {Size = UDim2.fromOffset(245, 40), AlwaysOnTop = true,
    StudsOffset = Vector3.new(0, 2, 0), Adornee = receiveCorePart, Enabled = false}, receiveCorePart)
local receiveVolumeLabel = make("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = receiveCorePart.Color,
    TextStrokeTransparency = 0.15, Text = "RECEIVE ESTIMATE"}, receiveVolumeTag)

local function hideReceiveVisual()
    receiveCorePart.Transparency, receiveTolerancePart.Transparency = 1, 1
    receiveVolumeTag.Enabled = false
    api.LastReceiveArea = nil
end

local function updateReceiveVisual()
    local area = api.Config.ShowReceiveHitbox and api.GetReceiveArea()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not area or not humanoid or humanoid.Health <= 0 then hideReceiveVisual(); return end
    api.LastReceiveArea = area
    local height = area.top - area.bottom
    local frame = CFrame.new(area.center) * CFrame.Angles(0, 0, math.pi / 2)
    receiveCorePart.Size = Vector3.new(height, area.coreRadius * 2, area.coreRadius * 2)
    receiveTolerancePart.Size = Vector3.new(height, area.radius * 2, area.radius * 2)
    receiveCorePart.CFrame, receiveTolerancePart.CFrame = frame, frame
    receiveCorePart.Transparency = 0.9
    receiveTolerancePart.Transparency = area.tolerance > 0 and 0.95 or 1
    receiveVolumeTag.Enabled = true
    receiveVolumeLabel.Text = string.format("RECEIVE ESTIMATE\nGreen core / amber +%.2f studs", area.tolerance)
end
-- RECEIVE_VISUAL_END

local function updateAuxVisuals(dt)
    auxElapsed = auxElapsed + dt
    updateReceiveVisual()
    if api.Config.ShowSetHitbox then
        local shape, reason = api.GetSetShape()
        api.LastHitbox = shape
        if shape then
            if shape.kind == "ellipsoid" then
                setVolumePart.Shape = Enum.PartType.Ball
                setVolumePart.Size = shape.radii * 2
                setVolumePart.CFrame = CFrame.new(shape.center)
            else
                setVolumePart.Shape = Enum.PartType.Block
                setVolumePart.Size, setVolumePart.CFrame = shape.size, shape.cframe
            end
            local inside = false
            for _, ball in ipairs(trackedBalls) do
                local pos = ball:FindFirstChild("Position")
                if ball.Parent and ball.Name == "Ball" and not ball:GetAttribute("DeadAt")
                    and not ball:GetAttribute("Settling") and pos and api.PointInSetShape(pos.Value, shape) then inside = true; break end
            end
            shape.ballInside = inside
            setVolumePart.Color = inside and Color3.fromRGB(100, 255, 140) or Color3.fromRGB(90, 190, 255)
            setVolumePart.Transparency = 0.86
            hitboxStatus.Text = "Hitbox: " .. shape.kind .. (inside and " | ball inside" or " | client volume")
        else
            setVolumePart.Transparency = 1
            hitboxStatus.Text = "Hitbox: " .. reason
        end
    else
        setVolumePart.Transparency = 1
        api.LastHitbox = nil
        hitboxStatus.Text = "Hitbox: OFF"
    end

    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    -- Facing display also works just outside sidelines/baselines; setting/aim validation is unchanged.
    local net = root and api.ServeViewerNet(root.Position, netCache)
    if not api.Config.ShowOpponentServe or not root or not net then
        hideServe()
        api.LastServe = nil
        opposingServer, serveCharacter, serveReadyAt, serveNet = nil, nil, nil, nil
        auxElapsed = 1
        serveStatus.Text = not api.Config.ShowOpponentServe and "Serve: OFF" or "Serve: waiting for court"
        return
    end
    local floorY = tonumber(workspace:GetAttribute("NG_QuotaSuolo")) or tuning.QUOTA_CAMPO or 0.408
    if auxElapsed >= 0.1 then
        auxElapsed = 0
        scanServe(root, net)
    end
    local character = opposingServer and opposingServer.Character
    local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
    local otherHumanoid = character and character:FindFirstChildOfClass("Humanoid")
    local ready = opposingServer and (opposingServer:GetAttribute("NG_PuoBattere") == true
        or activeServeOwners(net)[opposingServer.UserId] == true)
    if ready then serveReadyAt = os.clock() end
    if opposingServer and opposingServer.Parent == Players and character == serveCharacter
        and serveNet == net.part and otherRoot and otherHumanoid and otherHumanoid.Health > 0
        and api.KeepServeFacing(serveReadyAt, os.clock(), ready)
        and api.IsOpposingServeSource(root.Position, otherRoot.Position, net, player:GetAttribute("NG_Squadra"),
            opposingServer:GetAttribute("NG_Squadra"), netCache) then
        local start, finish = api.ServeFacingSegment(root.Position, otherRoot.Position, otherRoot.CFrame.LookVector,
            net, floorY, math.clamp(api.Config.ServeFacingLength, 10, 200))
        if start then
            serveFacingPart.Size = Vector3.new(0.16, 0.16, (finish - start).Magnitude)
            serveFacingPart.CFrame = CFrame.lookAt((start + finish) * 0.5, finish)
            serveFacingPart.Transparency = 0.25
            serveStatus.Text = "Aim estimate: " .. opposingServer.Name
            api.LastServe = {kind = "character_facing", player = opposingServer, start = start, finish = finish}
            api.VisualMetrics.FacingUpdates = api.VisualMetrics.FacingUpdates + 1
            return
        end
    end
    hideServe()
    api.LastServe = nil
    serveStatus.Text = "Facing: waiting for opposing server"
end

-- LANDING_RUNTIME_BEGIN
local incomingMarkers = {}
local landingEvents = setmetatable({}, {__mode = "k"})
local landingElapsed, landingNet = 1, nil
api.IncomingLandings = {}
api.LandingMetrics = {Solves = 0, Visible = 0, Errors = 0, MeanSolveMs = 0, EventRefreshes = 0}

local function clearIncomingLandings()
    for ball, visual in pairs(incomingMarkers) do
        visual.group:Destroy()
        incomingMarkers[ball] = nil
    end
    api.IncomingLandings, api.LiveIncoming = {}, nil
    api.LandingMetrics.Visible = 0
end

local function hideIncomingVisual(visual)
    visual.marker.Transparency = 1
    for _, pool in ipairs({visual.segments, visual.groundSegments, visual.target}) do
        for _, segment in ipairs(pool) do segment.Transparency = 1 end
    end
end

local function landingReadout(viewer, point, net)
    local sign = flat(point - net.center):Dot(net.normal) >= 0 and 1 or -1
    local depth = flat(point - net.center):Dot(net.normal) * sign
    local baseline = net.halfDepth - flat(net.center - net.courtCenter):Dot(net.normal) * sign
    local width = math.abs(flat(point - net.courtCenter):Dot(net.axis))
    local long, wide = depth - baseline, width - net.halfWidth
    local label
    if long > 0.001 or wide > 0.001 then
        label = long >= wide and string.format("OUT LONG +%.1f st", long)
            or string.format("OUT WIDE +%.1f st", wide)
    else
        local fraction = depth / math.max(1, baseline)
        label = "IN / " .. (fraction <= 1/3 and "SHORT" or fraction <= 2/3 and "MID" or "DEEP")
    end
    return label, depth, flat(point - viewer).Magnitude
end

local function drawIncomingSegment(visual, pool, index, name, a, b, color, width, transparency)
    local segment = pool[index]
    if not segment then
        segment = part(name, color, Vector3.one)
        segment.Parent = visual.group
        pool[index] = segment
    end
    local length = (b - a).Magnitude
    segment.Color = color
    segment.Size = Vector3.new(width, width, math.max(length, 0.001))
    if length > 0.001 then segment.CFrame = CFrame.lookAt((a + b) * 0.5, b) end
    segment.Transparency = length > 0.001 and transparency or 1
end

local function liveFlightEligible(sample, net)
    return sample.active and sample.position and sample.velocity and sample.velocity.Magnitude >= 0.1
        and sample.position.Y > sample.floor + api.Config.CollisionRadius + 0.02
        and api.TargetNearNet(sample.position, net, netCache)
end

local function updateIncomingLandings(dt)
    landingElapsed += dt
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local net = root and api.ServeViewerNet(root.Position, netCache)
    if not api.Config.ShowIncomingLanding or not root or not humanoid or humanoid.Health <= 0 or not net then
        clearIncomingLandings()
        landingElapsed, landingNet = 1, nil
        return
    end
    -- New contacts bypass the polling interval. No old-direction path survives a new touch.
    local cache = workspace:FindFirstChild("BallCache")
    local floorY = tonumber(workspace:GetAttribute("NG_QuotaSuolo")) or tuning.QUOTA_CAMPO or 0.408
    local samples, eventChanged = {}, false
    for _, ball in ipairs(cache and cache:GetChildren() or {}) do
        local pos, vel, spin = ball:FindFirstChild("Position"), ball:FindFirstChild("Velocity"), ball:FindFirstChild("Spin")
        local owner = ball:GetAttribute("NG_UltimoTocco") or ball:GetAttribute("NG_ToccoUltimo")
        local sample = {active = ball.Parent ~= nil and ball.Name == "Ball" and not ball:GetAttribute("DeadAt")
                and not ball:GetAttribute("Settling"),
            position = pos and pos:IsA("Vector3Value") and pos.Value,
            velocity = vel and vel:IsA("Vector3Value") and vel.Value, floor = floorY,
            ownTouch = owner == player.UserId,
            ownServe = ball:GetAttribute("NG_Battuta") == true and (player:GetAttribute("NG_PuoBattere") == true
                or ball:GetAttribute("NG_CreatoreId") == player.UserId),
            eventN = ball:GetAttribute("NG_EvN"), eventTime = ball:GetAttribute("NG_EvT"),
            options = {spin = spin and spin:IsA("Vector3Value") and spin.Value or Vector3.zero,
                gravity = ball:GetAttribute("NG_GravFattore"), side = ball:GetAttribute("NG_SpinOltreRete"),
                rampFraction = ball:GetAttribute("NG_SpinRampaFraz"), rampExponent = ball:GetAttribute("NG_SpinRampaEsp"),
                rampMin = ball:GetAttribute("NG_SpinRampaMin")}}
        local eligible = liveFlightEligible(sample, net)
        local previous = landingEvents[ball]
        if not previous or previous.eventN ~= sample.eventN or previous.eventTime ~= sample.eventTime
            or previous.eligible ~= eligible then
            if eligible or incomingMarkers[ball] then eventChanged = true end
            landingEvents[ball] = {eventN = sample.eventN, eventTime = sample.eventTime, eligible = eligible}
        end
        if eligible then table.insert(samples, {ball = ball, sample = sample}) end
    end
    if landingNet ~= net.part then clearIncomingLandings(); landingNet = net.part; landingElapsed = 1 end
    if eventChanged or landingElapsed >= 1 / math.clamp(api.Config.LandingUpdateHz, 1, 30) then
        landingElapsed = 0
        local start, predictions = os.clock(), {}
        for _, entry in ipairs(samples) do
            -- This display covers both halves and our own shots. Receive eligibility stays separate.
            local sample = entry.sample
            local flight = api.Flight(sample.position, sample.velocity, floorY, sample.options)
            local prediction = flight and flight.landing.Y <= floorY + api.Config.CollisionRadius + 0.05
                and {flight = flight, inCourt = api.InCourt(flight.landing, net),
                    eventN = sample.eventN, eventTime = sample.eventTime}
            if prediction then
                prediction.ball, prediction.solvedAt, prediction.floor = entry.ball, os.clock(), floorY
                prediction.kind = entry.ball:GetAttribute("NG_UltimoTipo")
                table.insert(predictions, prediction)
            end
        end
        table.sort(predictions, function(a, b) return a.flight.time < b.flight.time end)
        local chosen = {}
        api.IncomingLandings = {}
        for index = 1, math.min(#predictions, math.clamp(api.Config.MaxLandingMarkers, 1, 8)) do
            local prediction = predictions[index]
            local ball = prediction.ball
            chosen[ball] = true
            local visual = incomingMarkers[ball]
            if not visual then
                local group = make("Folder", {Name = "IncomingFlight"}, world)
                local marker = part("IncomingLanding", Color3.fromRGB(109, 255, 142), Vector3.new(0.1, 5, 5))
                marker.Parent, marker.Shape = group, Enum.PartType.Cylinder
                visual = {group = group, marker = marker, segments = {}, groundSegments = {}, target = {}}
                incomingMarkers[ball] = visual
            end
            visual.prediction = prediction
            table.insert(api.IncomingLandings, prediction)
        end
        for ball, visual in pairs(incomingMarkers) do
            if not chosen[ball] then visual.group:Destroy(); incomingMarkers[ball] = nil end
        end
        api.LandingMetrics.Solves += 1
        if eventChanged then api.LandingMetrics.EventRefreshes += 1 end
        api.LandingMetrics.MeanSolveMs = api.LandingMetrics.MeanSolveMs * 0.9 + (os.clock() - start) * 1000 * 0.1
    end
    local focus, focusRemaining
    local visible = 0
    for ball, visual in pairs(incomingMarkers) do
        local prediction = visual.prediction
        local position = ball:FindFirstChild("Position")
        local remaining = api.LandingTimeRemaining(prediction.flight.time, prediction.solvedAt, os.clock())
        local valid = ball.Parent and ball.Name == "Ball" and not ball:GetAttribute("DeadAt") and not ball:GetAttribute("Settling")
            and ball:GetAttribute("NG_EvN") == prediction.eventN and ball:GetAttribute("NG_EvT") == prediction.eventTime
            and position and remaining > 0
        if not valid then
            hideIncomingVisual(visual)
            landingElapsed = 1
        else
            visible += 1
            if not focusRemaining or remaining < focusRemaining then focus, focusRemaining = prediction, remaining end
            local landing = prediction.flight.landing
            local point = Vector3.new(landing.X, prediction.floor + 0.16, landing.Z)
            local color = prediction.inCourt and Color3.fromRGB(109, 255, 142) or Color3.fromRGB(255, 108, 98)
            visual.marker.CFrame = CFrame.new(point) * CFrame.Angles(0, 0, math.pi / 2)
            visual.marker.Color, visual.marker.Transparency = color, 0.65
            -- An exact-center cross and ring distinguish the landing spot from the ball overhead.
            drawIncomingSegment(visual, visual.target, 1, "LandingCross", point - net.axis * 3.5,
                point + net.axis * 3.5, color, 0.26, 0.05)
            drawIncomingSegment(visual, visual.target, 2, "LandingCross", point - net.normal * 3.5,
                point + net.normal * 3.5, color, 0.26, 0.05)
            for i = 1, 12 do
                local a, b = (i - 1) * math.pi / 6, i * math.pi / 6
                drawIncomingSegment(visual, visual.target, i + 2, "LandingRing",
                    point + net.axis * (3.5 * math.cos(a)) + net.normal * (3.5 * math.sin(a)),
                    point + net.axis * (3.5 * math.cos(b)) + net.normal * (3.5 * math.sin(b)), color, 0.18, 0.1)
            end
            -- Reuse bounded curves from the current ball position to the exact predicted landing.
            local nodes = prediction.flight.nodes
            local elapsed = math.max(0, os.clock() - prediction.solvedAt)
            local first = math.clamp(math.floor(elapsed / (3 * math.min(tuning.PASSO_MAX or 1/60, 1/60))) + 2, 2, #nodes)
            local count = math.min(32, #nodes - first + 1)
            local previousPoint = position.Value
            for index = 1, count do
                local nextPoint = nodes[first + math.floor((#nodes - first) * index / count)]
                drawIncomingSegment(visual, visual.segments, index, "IncomingPath", previousPoint, nextPoint, color, 0.24, 0.08)
                previousPoint = nextPoint
            end
            for index = count + 1, #visual.segments do visual.segments[index].Transparency = 1 end
            local groundCount = math.min(16, count)
            previousPoint = Vector3.new(position.Value.X, point.Y, position.Value.Z)
            for index = 1, groundCount do
                local node = nodes[first + math.floor((#nodes - first) * index / groundCount)]
                local nextPoint = Vector3.new(node.X, point.Y, node.Z)
                drawIncomingSegment(visual, visual.groundSegments, index, "IncomingGroundPath",
                    previousPoint, nextPoint, color, 0.12, 0.55)
                previousPoint = nextPoint
            end
            for index = groundCount + 1, #visual.groundSegments do visual.groundSegments[index].Transparency = 1 end
        end
    end
    api.LandingMetrics.Visible = visible
    api.LiveIncoming = nil
    if focus then
        local label, depth, distance = landingReadout(root.Position, focus.flight.landing, net)
        serveStatus.Text = "Ball estimate: " .. label
        api.LiveIncoming = {ball = focus.ball, eventN = focus.eventN, eventTime = focus.eventTime,
            remaining = focusRemaining, depth = depth, distance = distance, label = label, inCourt = focus.inCourt}
    end
end
-- LANDING_RUNTIME_END

-- RECEIVE_RUNTIME_BEGIN
local receiveManager, receiveMouse
local receiveFocused, receiveManualUntil, receiveNextAttempt = true, 0, 0
if type(isrbxactive) == "function" then
    local ok, focused = pcall(isrbxactive)
    if ok then receiveFocused = focused == true end
end
local receivePing, receivePingAt = 0, -math.huge
local receiveAttempts = setmetatable({}, {__mode = "k"})
local receivePending = {}
local receiveCharacter = player.Character
local receiveRetryAt, receivePauseReason = 0, nil
api.ReceiveMetrics = {Checks = 0, Attempts = 0, Confirmed = 0, Errors = 0, Anticipated = 0,
    CoreAttempts = 0, ToleranceAttempts = 0, CoreConfirmed = 0, ToleranceConfirmed = 0, Unconfirmed = 0}
api.ReceiveHistory = api.ReceiveHistory or {}

local function recordReceive(kind, data)
    local entry = {kind = kind, time = workspace:GetServerTimeNow(), eventN = data.eventN,
        band = data.band, entryIn = data.entryIn, lookahead = data.lookahead,
        confirmationDelay = data.confirmationDelay, position = data.position, background = data.background, reason = data.reason}
    table.insert(api.ReceiveHistory, entry)
    while #api.ReceiveHistory > 80 do table.remove(api.ReceiveHistory, 1) end
    log(kind, data)
end

local function updateReceiveConfirmations(now)
    for attempt, ball in pairs(receivePending) do
        local owner = ball:GetAttribute("NG_UltimoTocco") or ball:GetAttribute("NG_ToccoUltimo")
        local kind = ball:GetAttribute("NG_UltimoTipo")
        if now - attempt.time <= 2 and owner == player.UserId and (kind == "Bump" or kind == "Receive") then
            attempt.confirmed = true
            api.ReceiveMetrics.Confirmed = api.ReceiveMetrics.Confirmed + 1
            local field = attempt.band == "tolerance" and "ToleranceConfirmed" or "CoreConfirmed"
            api.ReceiveMetrics[field] = api.ReceiveMetrics[field] + 1
            if api.LastReceive and api.LastReceive.ball == ball then api.LastReceive.status = "confirmed" end
            recordReceive("auto_receive_confirmed", {eventN = ball:GetAttribute("NG_EvN"), band = attempt.band,
                confirmationDelay = now - attempt.time, entryIn = attempt.entryIn, background = attempt.background})
            receivePending[attempt] = nil
        elseif now - attempt.time > 2 then
            api.ReceiveMetrics.Unconfirmed = api.ReceiveMetrics.Unconfirmed + 1
            recordReceive("auto_receive_unconfirmed", {eventN = attempt.eventN, band = attempt.band,
                entryIn = attempt.entryIn, background = attempt.background})
            receivePending[attempt] = nil
        end
    end
end

local function releaseReceiveMouse()
    local pending = receiveMouse
    if pending then
        local ok, err = pcall(function()
            pending.manager:SendMouseButtonEvent(pending.x, pending.y, 0, false, game, 0)
        end)
        if not ok then
            api.ReceiveMetrics.Errors = api.ReceiveMetrics.Errors + 1
            api.ReceiveMetrics.LastError = tostring(err)
            log("auto_receive_release_error", tostring(err))
            return false
        end
        if receiveMouse == pending then receiveMouse = nil end
    end
    return true
end

function api.PauseAutoReceive(reason, retrySeconds)
    releaseReceiveMouse()
    receivePauseReason, receiveRetryAt = reason, os.clock() + (retrySeconds or 2)
    if api.Config.AutoReceive then receiveStatus.Text = "Auto Receive: ON / paused: " .. reason end
end

function api.ResetAutoReceiveCharacter(character)
    local released = releaseReceiveMouse()
    receiveCharacter = character
    receiveAttempts = setmetatable({}, {__mode = "k"})
    receiveNextAttempt, receiveManualUntil = 0, os.clock() + 0.15
    receivePauseReason, receiveRetryAt = nil, 0
    if not released then api.PauseAutoReceive("input release failed") end
    if api.Config.AutoReceive then receiveStatus.Text = "Auto Receive: ON / waiting for character" end
end

function api.SetAutoReceive(enabled, reason)
    local released = releaseReceiveMouse()
    api.Config.AutoReceive = enabled == true
    receivePauseReason, receiveRetryAt = nil, 0
    if api.Config.AutoReceive then
        if not receiveManager then
            local ok, manager = pcall(function() return game:GetService("VirtualInputManager") end)
            if ok then receiveManager = manager end
        end
        receiveManualUntil = os.clock() + 0.2
    end
    receiveToggle.Text = api.Config.AutoReceive and "Auto Receive ON" or "Auto Receive OFF"
    receiveToggle.BackgroundColor3 = api.Config.AutoReceive and Color3.fromRGB(36, 94, 61) or Color3.fromRGB(38, 48, 65)
    receiveStatus.Text = "Auto Receive: " .. (api.Config.AutoReceive and "ON / armed" or ("OFF" .. (reason and " / " .. reason or "")))
    if api.Config.AutoReceive and (not released or not receiveManager) then
        api.PauseAutoReceive(not released and "input release failed" or "mouse input unavailable")
    end
    log("auto_receive_toggle", {enabled = api.Config.AutoReceive, reason = reason})
    return api.Config.AutoReceive
end

function api.GetReceiveCore()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")
    local rec = character and character:FindFirstChild("RecHitbox")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not head or not rec or not humanoid or not rec:IsA("BasePart") then return nil end
    local reach = heightConfig and heightConfig.Reach
    if not reach then return nil end
    local height = reach.RecAltezza or {}
    return api.BuildReceiveCore(rec.Position, rec.Size, head.Position, head.Size, root.Position, root.Size,
        humanoid.HipHeight, {aboveHead = height.SopraTesta, belowFeet = height.SottoPiedi,
            extraHeight = tonumber(workspace:GetAttribute("NG_RecAltezzaExtra")),
            stack = tonumber(player:GetAttribute("NG_NazTRecStack")), charge = tonumber(player:GetAttribute("NG_NazTRecCarica")),
            topScale = tonumber(player:GetAttribute("NG_NazTRecTop"))})
end

function api.GetReceiveArea()
    local reach = heightConfig and heightConfig.Reach
    return api.BuildReceiveArea(api.GetReceiveCore(), reach and reach.RecPity)
end

local function receiveActionKey(key)
    if key == frontAimKey or key == backAimKey or key == Enum.KeyCode.Space then return true end
    local binds = player:FindFirstChild("Keybinds")
    if not binds then return false end
    for _, attribute in ipairs({"BackSetKey", "FrontSetKey", "DiveKey", "DumpKey", "AutoServeKey", "StrongHitKey"}) do
        local name = binds:GetAttribute(attribute)
        if type(name) == "string" and key.Name == name then return true end
    end
    return false
end

connect(UIS.InputBegan, function(input, processed)
    if not processed and not receiveMouse and (receiveActionKey(input.KeyCode)
        or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2) then
        receiveManualUntil = os.clock() + api.Config.ReceiveManualPause
    end
end)
connect(UIS.WindowFocusReleased, function()
    receiveFocused = false
    if not releaseReceiveMouse() then api.PauseAutoReceive("input release failed") end
    if api.Config.AutoReceive then
        receiveStatus.Text = api.Config.ReceiveInBackground and "Auto Receive: ON / background" or "Auto Receive: ON / paused: focus"
    end
end)
connect(UIS.WindowFocused, function()
    receiveFocused = true
    receiveManualUntil = math.max(receiveManualUntil, os.clock() + 0.1)
end)

local function receivePointerBlocked(point)
    if not point then return true end
    local inset = GuiService:GetGuiInset()
    if point.X < 0 or point.Y <= inset.Y + 4 then return true end
    local camera = workspace.CurrentCamera
    if camera and (point.X >= camera.ViewportSize.X or point.Y >= camera.ViewportSize.Y) then return true end
    local ok, objects = pcall(function() return player.PlayerGui:GetGuiObjectsAtPosition(point.X, point.Y) end)
    if not ok then return true end
    for _, object in ipairs(objects) do
        if object.Visible and (object.Active or object:IsA("TextButton") or object:IsA("ImageButton") or object:IsA("TextBox")) then
            return true
        end
    end
    return false
end

local function receiveInputPoint()
    if receiveFocused then
        local point = UIS:GetMouseLocation()
        return point, receivePointerBlocked(point)
    end
    -- Engine-targeted input only. Never use desktop coordinates or executor mouse functions.
    local camera = workspace.CurrentCamera
    if not api.Config.ReceiveInBackground or not camera then return nil, true end
    local size = camera.ViewportSize
    for _, fraction in ipairs({{0.5, 0.55}, {0.5, 0.45}, {0.35, 0.55}, {0.65, 0.55}, {0.5, 0.7}, {0.8, 0.4}, {0.2, 0.4}}) do
        local point = Vector2.new(size.X * fraction[1], size.Y * fraction[2])
        if not receivePointerBlocked(point) then return point, false end
    end
    return nil, true
end

-- RECEIVE_INPUT_BEGIN
local function pressReceiveMouse(point)
    if not alive or not api.Config.AutoReceive or (not receiveFocused and not api.Config.ReceiveInBackground)
        or receiveMouse or not point then return false end
    local pending = {manager = receiveManager, x = math.floor(point.X), y = math.floor(point.Y)}
    receiveMouse = pending
    local ok, err = pcall(function()
        pending.manager:SendMouseButtonEvent(pending.x, pending.y, 0, true, game, 0)
    end)
    if not ok then
        releaseReceiveMouse()
        api.ReceiveMetrics.Errors = api.ReceiveMetrics.Errors + 1
        api.ReceiveMetrics.LastError = tostring(err)
        api.PauseAutoReceive("input unavailable")
        log("auto_receive_input_error", tostring(err))
        return false
    end
    task.delay(0.035, function()
        if receiveMouse == pending and not releaseReceiveMouse() then api.PauseAutoReceive("input release failed") end
    end)
    return true
end
-- RECEIVE_INPUT_END

local function updateAutoReceive(frameSeconds)
    if api.Defense then return end -- The shared controller owns receive/dive arbitration.
    updateReceiveConfirmations(os.clock())
    if not api.Config.AutoReceive then return end
    api.ReceiveMetrics.Checks = api.ReceiveMetrics.Checks + 1
    local now = os.clock()
    if receivePauseReason then
        if now < receiveRetryAt then
            receiveStatus.Text = "Auto Receive: ON / paused: " .. receivePauseReason
            return
        end
        if not releaseReceiveMouse() then api.PauseAutoReceive("input release failed"); return end
        receivePauseReason = nil
    end
    if not receiveManager then
        local ok, manager = pcall(function() return game:GetService("VirtualInputManager") end)
        if ok then receiveManager = manager end
        if not receiveManager then api.PauseAutoReceive("mouse input unavailable"); return end
    end
    if now - receivePingAt >= 0.25 then
        receivePingAt = now
        local ok, ping = pcall(function() return player:GetNetworkPing() end)
        if ok and type(ping) == "number" then receivePing = ping end
    end
    local character = player.Character
    if character ~= receiveCharacter then api.ResetAutoReceiveCharacter(character) end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        if not releaseReceiveMouse() then api.PauseAutoReceive("input release failed") end
        receiveStatus.Text = "Auto Receive: ON / waiting for character"
        return
    end
    local net = api.ServeViewerNet(root.Position, netCache)
    local shape = api.GetReceiveArea()
    local point, pointerBlocked = receiveInputPoint()
    local blocked = false
    for _, attribute in ipairs({"NG_StunLocale", "NG_BloccoComandi", "NG_MinigiocoBattuta"}) do
        local untilTime = tonumber(player:GetAttribute(attribute))
        if untilTime and now < untilTime then blocked = true end
    end
    local lastAction = tonumber(player:GetAttribute("NG_ColpoLocale"))
    if lastAction and now - lastAction < 0.15 then blocked = true end
    local manual = receiveFocused and (UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UIS:IsKeyDown(Enum.KeyCode.Space)
        or UIS:IsKeyDown(frontAimKey) or UIS:IsKeyDown(backAimKey))
    local context = {enabled = api.Config.AutoReceive, focused = receiveFocused, chat = UIS:GetFocusedTextBox() ~= nil,
        allowBackground = api.Config.ReceiveInBackground, menu = GuiService.MenuIsOpen, pointerBlocked = pointerBlocked, alive = humanoid.Health > 0,
        grounded = humanoid.FloorMaterial ~= Enum.Material.Air and player:GetAttribute("NG_InAria") ~= true,
        sitting = humanoid.Sit, anchored = root.Anchored, court = net ~= nil, inMatch = player:GetAttribute("NG_InMatch"),
        serving = player:GetAttribute("NG_PuoBattere") == true, commandsBlocked = blocked,
        manual = manual or aim ~= nil, manualUntil = receiveManualUntil, nextAttempt = receiveNextAttempt,
        pending = receiveMouse ~= nil, motion = root.AssemblyLinearVelocity,
        lookahead = api.ReceiveLeadTime(receivePing, frameSeconds)}
    api.ReceiveTiming = {leadSeconds = context.lookahead, pingSeconds = receivePing}
    local cache = workspace:FindFirstChild("BallCache")
    local selected, selectedSample, selectedEntry, selectedBand
    local reason = "waiting for ball"
    for _, ball in ipairs(cache and cache:GetChildren() or {}) do
        local position, velocity = ball:FindFirstChild("Position"), ball:FindFirstChild("Velocity")
        local pos = position and position:IsA("Vector3Value") and position.Value
        local vel = velocity and velocity:IsA("Vector3Value") and velocity.Value
        local owner = ball:GetAttribute("NG_UltimoTocco") or ball:GetAttribute("NG_ToccoUltimo")
        local sample = {active = ball.Name == "Ball" and not ball:GetAttribute("DeadAt") and not ball:GetAttribute("Settling"),
            position = pos, velocity = vel, ownTouch = owner == player.UserId,
            eventN = ball:GetAttribute("NG_EvN"), eventTime = ball:GetAttribute("NG_EvT"),
            ownHalf = net ~= nil and pos ~= nil and flat(pos - net.center):Dot(net.normal)
                * flat(root.Position - net.center):Dot(net.normal) > 0,
            sameCourt = net ~= nil and pos ~= nil and api.TargetNearNet(pos, net, netCache)}
        local spin = ball:FindFirstChild("Spin")
        sample.spin = spin and spin:IsA("Vector3Value") and spin.Value or Vector3.zero
        sample.gravity, sample.side = ball:GetAttribute("NG_GravFattore"), ball:GetAttribute("NG_SpinOltreRete")
        sample.rampFraction, sample.rampExponent, sample.rampMin = ball:GetAttribute("NG_SpinRampaFraz"),
            ball:GetAttribute("NG_SpinRampaEsp"), ball:GetAttribute("NG_SpinRampaMin")
        local attempt = receiveAttempts[ball]
        if attempt then
            if not api.PointInReceiveCore(pos, shape) then attempt.sawOutside = true end
        end
        local trigger, why, entryTime, band = api.ShouldAutoReceive(context, sample, shape, attempt, now)
        reason = why
        if trigger then
            if not selected or entryTime < selectedEntry then
                selected, selectedSample, selectedEntry, selectedBand = ball, sample, entryTime, band
            end
        end
    end
    if not selected then
        -- Report context even while there are no ball models.
        if not cache or #cache:GetChildren() == 0 then
            local _, why = api.ShouldAutoReceive(context, {active = false}, shape, nil, now)
            reason = why
        end
        receiveStatus.Text = "Auto Receive: ON / " .. reason .. (reason == "armed" and string.format(" / early %.0fms", context.lookahead * 1000) or "")
        return
    end
    if pressReceiveMouse(point) then
        for previous, ball in pairs(receivePending) do
            if ball == selected then
                api.ReceiveMetrics.Unconfirmed = api.ReceiveMetrics.Unconfirmed + 1
                recordReceive("auto_receive_unconfirmed", {eventN = previous.eventN, band = previous.band, reason = "new flight superseded attempt"})
                receivePending[previous] = nil
            end
        end
        local attempt = {time = now, eventN = selectedSample.eventN, eventTime = selectedSample.eventTime,
            sawOutside = false, band = selectedBand, entryIn = selectedEntry, background = not receiveFocused}
        receiveAttempts[selected], receivePending[attempt] = attempt, selected
        local waitTrait = tonumber(player:GetAttribute("TraitActionWait")) or 0
        receiveNextAttempt = now + math.max(0.1, 1 + waitTrait) + math.max(0, api.Config.ReceiveCooldownPadding)
        api.ReceiveMetrics.Attempts = api.ReceiveMetrics.Attempts + 1
        local field = selectedBand == "tolerance" and "ToleranceAttempts" or "CoreAttempts"
        api.ReceiveMetrics[field] = api.ReceiveMetrics[field] + 1
        if selectedEntry > 0 then api.ReceiveMetrics.Anticipated = api.ReceiveMetrics.Anticipated + 1 end
        api.LastReceive = {time = workspace:GetServerTimeNow(), ball = selected, position = selectedSample.position,
            eventN = selectedSample.eventN, entryIn = selectedEntry, lookahead = context.lookahead,
            band = selectedBand, radius = shape.radius, coreRadius = shape.coreRadius, tolerance = shape.tolerance,
            background = not receiveFocused, status = "attempted / awaiting game confirmation"}
        recordReceive("auto_receive_attempt", api.LastReceive)
        receiveStatus.Text = "Auto Receive: ON / " .. (selectedBand or "contact") .. " attempt"
    end
end

connect(RunService.Heartbeat, function(dt)
    local ok, err = pcall(updateAutoReceive, dt)
    if not ok then
        api.ReceiveMetrics.Errors = api.ReceiveMetrics.Errors + 1
        api.ReceiveMetrics.LastError = tostring(err)
        api.PauseAutoReceive("error / see log")
        log("auto_receive_error", tostring(err))
    end
end)
-- RECEIVE_RUNTIME_END

connect(RunService.RenderStepped, function(dt)
    elapsed, scanElapsed = elapsed + dt, scanElapsed + dt
    netRefreshElapsed, targetRefreshElapsed = netRefreshElapsed + dt, targetRefreshElapsed + dt
    local interval = 1 / math.clamp(api.Config.UpdateHz, 1, 120)
    local solve = elapsed >= interval
    if solve then elapsed = elapsed % interval end
    local start = os.clock()
    local ok, err = pcall(function()
        if netRefreshElapsed >= 1 then netRefreshElapsed = 0; refreshNets() end
        local visualOK, visualError = pcall(updateAuxVisuals, dt)
        if not visualOK then
            setVolumePart.Transparency = 1
            hideReceiveVisual()
            hideServe()
            api.LastHitbox, api.LastServe = nil, nil
            hitboxStatus.Text = "Hitbox: visualization unavailable"
            serveStatus.Text = "Serve: visualization unavailable"
            api.VisualMetrics.Errors = api.VisualMetrics.Errors + 1
            if api.VisualMetrics.Errors <= 3 then log("visual_error", tostring(visualError)); warn("[VRSSetAim] " .. tostring(visualError)) end
        end
        local landingOK, landingError = pcall(updateIncomingLandings, dt)
        if not landingOK then
            clearIncomingLandings()
            api.LandingMetrics.Errors = api.LandingMetrics.Errors + 1
            if api.LandingMetrics.Errors <= 3 then log("landing_error", tostring(landingError)) end
        end
        if aim then applyAim(dt) end
        if not aim and targetRefreshElapsed >= 0.1 then
            targetRefreshElapsed = 0
            if api.Config.AimEnabled then
                local front, frontReason = api.ResolveTarget(false)
                local back, backReason = api.ResolveTarget(true)
                api.TargetOptions = {Front = front, Back = back}
                api.TargetAvailability = {Front = {ready = front ~= nil, reason = frontReason},
                    Back = {ready = back ~= nil, reason = backReason}}
            else
                api.TargetOptions = {}
                api.TargetAvailability = {}
            end
        end
        local targetText = not api.Config.AimEnabled and "Aim OFF / power stays manual"
            or (targetMessage and os.clock() < targetMessageUntil and targetMessage)
            or (api.TargetOptions and api.TargetOptions.Front
                and (api.TargetOptions.Front.userId == api.Config.FrontFallbackUserId
                    and "F: nl223602 (fallback) | R: " .. api.Config.BackTargetName
                    or "F: " .. api.TargetOptions.Front.player.Name .. " | R: " .. api.Config.BackTargetName)
                or "F: " .. (api.TargetAvailability and api.TargetAvailability.Front and api.TargetAvailability.Front.reason
                    or "checking court / character"))
        if targetStatus.Text ~= targetText then targetStatus.Text = targetText end
        if not solve then
            if api.Config.Enabled and renderState then
                local key = tostring(renderState.power) .. ":" .. renderState.tilt
                if api.Config.Mode ~= "Back" then draw(visuals.Front, renderFront, renderState.floor, dt, key) else hide(visuals.Front) end
                if api.Config.Mode ~= "Front" then draw(visuals.Back, renderBack, renderState.floor, dt, key) else hide(visuals.Back) end
            end
            return
        end
        if scanElapsed >= 0.12 then scanElapsed = 0; scan() end
        toggle.Text = api.Config.Enabled and "Hide" or "Show"
        local s = state()
        lastState = s
        if not s then
            renderState = nil
            for _, v in pairs(visuals) do hide(v) end
            status.Text = "Waiting for your character..."
            return
        end
        status.Text = string.format("Power %g   |   Tilt %s   |   %s", s.power, s.tilt, s.airborne and "AIR" or "GROUND")
        if not api.Config.Enabled then
            for _, v in pairs(visuals) do hide(v) end
            details.Text = "Preview paused"
            return
        end
        local f, b = api.Predict(s, false), api.Predict(s, true)
        api.Last = {State = s, Front = f, Back = b}
        local showingConfirmed = confirmed and os.clock() < confirmed.untilTime and
            confirmed.power == s.power and confirmed.tilt == s.tilt and
            confirmed.look:Dot(s.look) >= math.cos(math.rad(5))
        if confirmed and not showingConfirmed then confirmed = nil end
        if showingConfirmed then
            if confirmed.back then b = confirmed.flight else f = confirmed.flight end
            api.Last.Confirmed = confirmed.flight
        end
        renderFront, renderBack, renderState = f, b, s
        local smoothingKey = tostring(s.power) .. ":" .. s.tilt
        if api.Config.Mode ~= "Back" then draw(visuals.Front, f, s.floor, dt, smoothingKey) else hide(visuals.Front) end
        if api.Config.Mode ~= "Front" then draw(visuals.Back, b, s.floor, dt, smoothingKey) else hide(visuals.Back) end
        ranges.Text = string.format("Front ~%.1f   |   Back ~%.1f studs", f.distance, b.distance)
        title.Text = showingConfirmed and "SET AIM  /  confirmed flight" or "SET AIM  /  preview"
        details.Text = showingConfirmed and "Server launch received; preview resumes shortly" or
            string.format("%s%s | contact Y %.1f", s.freeze and "Freeze | " or "",
                s.contact and "Live ball" or "Estimated hand", s.origin.Y)
        if os.clock() - lastLog >= 0.5 then
            lastLog = os.clock()
            log("preview", {power = s.power, tilt = s.tilt, airborne = s.airborne,
                contact = s.origin, front = f.landing, back = b.landing})
        end
    end)
    local cost = (os.clock() - start) * 1000
    api.Metrics.Updates = api.Metrics.Updates + 1
    api.Metrics.MeanMs = api.Metrics.MeanMs * 0.95 + cost * 0.05
    if not ok then
        stopAim()
        api.Metrics.Errors = api.Metrics.Errors + 1
        for _, v in pairs(visuals) do hide(v) end
        status.Text = "Preview error (see VRSSetAim.Log)"
        if api.Metrics.Errors <= 3 then warn("[VRSSetAim] " .. tostring(err)); log("error", tostring(err)) end
    end
end)
if savedAutoReceive then api.SetAutoReceive(true, "restored user toggle") end
log("started", {version = api.Version, place = game.PlaceId})
print("[VRSSetAim] v" .. api.Version .. " loaded: set target " .. tostring(api.Config.SetNetInset)
    .. " studs off net. Actual hitbox sizes, movement and power unchanged.")

-- DEFENSE_COMPONENT_BEGIN
-- Generated by scripts/sync-vrs-defense.mjs.
local function createDefenseEngine()
local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local RunService, UIS = game:GetService("RunService"), game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player, connections, alive, netCache = Players.LocalPlayer, {}, true, {}
local api = {Config = {AutoReceive = false, ReceiveInBackground = true, ReceiveCooldownPadding = 0.1,
        ReceiveManualPause = 0, ReceiveLeadSeconds = 0.08, ReceiveMaxLead = 0.24,
        ShowOpponentServe = true, ServeFacingLength = 120, ServeFacingGraceSeconds = 2.5,
        AllowOutsideCourtTargets = true, MaxLogEntries = 100, CollisionRadius = 1,
        ShowIncomingLanding = true, ShowPlayerPowers = true, StaminaRefill = true, LandingUpdateHz = 20, MaxLandingMarkers = 4, ShowReceiveHitbox = true,
        AutoDive = false, DiveMinSpeed = 55, DiveHorizon = 0.7, DiveUpdateHz = 60, DiveEveryHeartbeat = true,
        DiveLatencyPadding = 0.015, DiveMaxResponseLead = 0.16,
        DiveCooldown = 1.5, DiveAutoAim = true, AimBot = false, ReceiveTargetUserId = 58427452,
        ReceivePassShortBias = 0, ReceiveFeedbackMaxCorrection = 18, SkipOutBalls = true, ReceiveAimPreSeconds = 0.3,
        ReceiveContactMargin = 0.004,
        ReceiveAimSettleSeconds = 0.085, ReceiveAimMaxErrorDegrees = 2,
        ReceivePowerBonus = 1, ReceiveNetBuffer = 5, ReceiveFrontZoneFraction = 0.4,
        ReceiveAimMode = "Player"}, Startup = {Ready = false, FeatureErrors = {}}, Log = {}, Status = {}}
local tuning, physics, heightConfig
local world = Instance.new("Folder"); world.Name = "VRS_Defense_Local"; world.Parent = workspace
local receiveStatus, diveStatus, receiveToggle, diveToggle = {}, {}, {}, {}
local function connect(signal, callback)
 local c=signal:Connect(callback); connections[#connections+1]=c; return c
end
local function log(kind,data)
 api.Log[#api.Log+1]={kind=kind,data=data,time=os.clock()}
 if #api.Log>80 then table.remove(api.Log,1) end
end
local function reportStartupError(name,message)
 api.Startup.FeatureErrors[name]=tostring(message); log("defense_error",{name=name,message=tostring(message)})
end
function api.Destroy()
 if not alive then return end
 alive=false
 if api.SetAutoReceive then api.SetAutoReceive(false) end
 if api.SetAutoDive then api.SetAutoDive(false) end
 for _,c in ipairs(connections) do c:Disconnect() end
 world:Destroy()
end
local function flat(vector) return Vector3.new(vector.X, 0, vector.Z) end
function api.InCourt(position, net)
    local offset = flat(position - net.courtCenter)
    return math.abs(offset:Dot(net.axis)) <= net.halfWidth
        and math.abs(offset:Dot(net.normal)) <= net.halfDepth
end

function api.NetPoint(position, net)
    local along = math.clamp(flat(position - net.center):Dot(net.axis), -net.halfWidth, net.halfWidth)
    return net.center + net.axis * along
end

function api.NearestNet(position, nets)
    local best, bestDistance = nil, math.huge
    for _, candidate in ipairs(nets) do
        local distance = flat(position - api.NetPoint(position, candidate)).Magnitude
        if distance < bestDistance then best, bestDistance = candidate, distance end
    end
    return best
end

function api.TargetNearNet(position, net, nets)
    if api.InCourt(position, net) then return true end
    if api.Config.AllowOutsideCourtTargets == false then return false end
    local nearest = api.NearestNet(position, nets or {net})
    -- Live net records refresh periodically; compare their actual instances as well.
    return nearest == net or (nearest ~= nil and nearest.part ~= nil and nearest.part == net.part
        and nearest.court == net.court)
end
function api.IsOpposingServeSource(origin, source, net, ownTeam, sourceTeam, nets)
    if ownTeam and sourceTeam and ownTeam == sourceTeam then return false end
    if not api.TargetNearNet(source, net, nets) then return false end
    return flat(origin - net.center):Dot(net.normal) * flat(source - net.center):Dot(net.normal) < 0
end

function api.ServeFacingSegment(origin, source, look, net, floorY, maxLength)
    -- Project the character's facing onto the floor, regardless of which way they turn.
    local direction = flat(look)
    if direction.Magnitude < 0.001 or maxLength <= 0 then return nil end
    local start = Vector3.new(source.X, floorY + 0.13, source.Z)
    return start, start + direction.Unit * maxLength
end

function api.KeepServeFacing(lastReady, now, ready)
    return ready == true or (lastReady ~= nil and now >= lastReady
        and now - lastReady <= (api.Config.ServeFacingGraceSeconds or 2.5))
end

function api.ServeViewerNet(position, nets)
    for _, net in ipairs(nets) do
        if api.InCourt(position, net) then return net end
    end
    local net = api.NearestNet(position, nets)
    if not net then return nil end
    local offset = flat(position - net.courtCenter)
    if math.abs(offset:Dot(net.axis)) <= net.halfWidth + 20
        and math.abs(offset:Dot(net.normal)) <= net.halfDepth + 30 then return net end
    return nil
end

function api.BuildReceiveCore(recPosition, recSize, headPosition, headSize, rootPosition, rootSize, hipHeight, options)
    local radius = recSize.X * 0.5 * (1 + (options.stack or 0) * (options.charge or 0))
    local bottom = rootPosition.Y - rootSize.Y * 0.5 - hipHeight + (options.belowFeet or 0)
    local top = headPosition.Y + headSize.Y * 0.5 + (options.aboveHead or 0) + (options.extraHeight or 0)
    top = bottom + (top - bottom) * (1 + (options.topScale or 0))
    if radius <= 0 or top <= bottom then return nil end
    -- Conservative core of the game's displayed receive cylinder; omit pity/head-only extensions.
    return {center = Vector3.new(recPosition.X, (top + bottom) * 0.5, recPosition.Z),
        radius = radius, bottom = bottom, top = top}
end

function api.PointInReceiveCore(point, shape)
    if not point or not shape then return false end
    return point.Y >= shape.bottom and point.Y <= shape.top
        and flat(point - shape.center).Magnitude <= shape.radius
end

function api.BuildReceiveArea(core, pity)
    if not core then return nil end
    local tolerance = 0
    if pity and pity.Enabled == true then
        tolerance = math.max(0, tonumber(pity.RaggioPalla) or 0) + math.max(0, tonumber(pity.Extra) or 0)
    end
    return {center = core.center, bottom = core.bottom, top = core.top,
        coreRadius = core.radius, radius = core.radius + tolerance, tolerance = tolerance}
end

function api.ReceiveContactBand(point, area)
    if not point or not area then return nil end
    local radial = flat(point - area.center).Magnitude
    if point.Y < area.bottom - 0.0001 or point.Y > area.top + 0.0001 or radial > area.radius + 0.0001 then return nil end
    return radial <= (area.coreRadius or area.radius) + 0.0001 and "core" or "tolerance"
end

function api.ReceiveLeadTime(ping, frameSeconds)
    local maximum = math.clamp(api.Config.ReceiveMaxLead or 0.24, 0.06, 0.35)
    return math.clamp((api.Config.ReceiveLeadSeconds or 0.08) + math.clamp(ping or 0, 0, 0.2)
        + 2 * math.clamp(frameSeconds or 1 / 60, 1 / 240, 0.05), 0.06, maximum)
end

function api.ReceiveSegmentEntry(a, b, shape)
    local delta, offset = b - a, a - shape.center
    local lo, hi = 0, 1
    if math.abs(delta.Y) < 1e-9 then
        if a.Y < shape.bottom or a.Y > shape.top then return nil end
    else
        local t1, t2 = (shape.bottom - a.Y) / delta.Y, (shape.top - a.Y) / delta.Y
        lo, hi = math.max(lo, math.min(t1, t2)), math.min(hi, math.max(t1, t2))
    end
    local aa = delta.X^2 + delta.Z^2
    local bb = 2 * (offset.X * delta.X + offset.Z * delta.Z)
    local cc = offset.X^2 + offset.Z^2 - shape.radius^2
    if aa < 1e-12 then
        if cc > 0 then return nil end
    else
        local discriminant = bb^2 - 4 * aa * cc
        if discriminant < 0 then return nil end
        local root = math.sqrt(discriminant)
        lo, hi = math.max(lo, (-bb - root) / (2 * aa)), math.min(hi, (-bb + root) / (2 * aa))
    end
    if lo <= hi then return lo end
    return nil
end

function api.ReceiveEntryTime(ball, shape, motion, horizon)
    if not ball.position or not ball.velocity or not shape then return nil end
    if api.PointInReceiveCore(ball.position, shape) then return 0, ball.position end
    horizon = math.clamp(horizon or 0, 0, 0.35)
    local position, velocity, spin = ball.position, ball.velocity, ball.spin or Vector3.zero
    local elapsed = 0
    while elapsed < horizon - 1e-8 do
        local dt = math.min(1 / 120, tuning.PASSO_MAX or 1 / 120, horizon - elapsed)
        local nextVelocity, nextPosition, nextSpin = physics.PassoValori(position, velocity, spin, dt,
            ball.side, ball.gravity, ball.rampFraction, ball.rampExponent, ball.rampMin)
        -- Continuous segment/cylinder entry catches fast balls that cross between integration samples.
        local fraction = api.ReceiveSegmentEntry(position - motion * elapsed, nextPosition - motion * (elapsed + dt), shape)
        if fraction then
            return elapsed + fraction * dt,
                (position - motion * elapsed):Lerp(nextPosition - motion * (elapsed + dt), fraction)
        end
        position, velocity, spin = nextPosition, nextVelocity, nextSpin
        elapsed = elapsed + dt
        if position.Y < shape.bottom and velocity.Y <= 0 then return nil end
    end
    return nil
end

function api.ShouldAutoReceive(context, ball, shape, attempt, now)
    if not context.enabled then return false, "OFF" end
    if not context.focused and not context.allowBackground then return false, "game unfocused" end
    if context.chat or context.menu or context.pointerBlocked then return false, "UI / typing" end
    if not context.alive or not context.grounded or context.sitting or context.anchored then return false, "grounded only" end
    if not context.court or context.inMatch == false or context.serving or context.commandsBlocked then return false, "waiting for play" end
    if context.manual or now < context.manualUntil then return false, "manual action" end
    if context.pending or now < context.nextAttempt then return false, "cooldown" end
    if not shape then return false, "receive volume unavailable" end
    if not ball.active or ball.ownTouch or not ball.ownHalf or not ball.sameCourt then return false, "waiting for incoming ball" end
    if not ball.velocity or ball.velocity.Magnitude < 0.1 then return false, "waiting for ball motion" end
    local approaching = (ball.position - shape.center):Dot(ball.velocity - context.motion) < -0.1
    if not approaching and ball.velocity.Y >= -0.5 then return false, "ball moving away" end
    if attempt then
        local eventKnown = ball.eventN ~= nil or ball.eventTime ~= nil
        local sameEvent = eventKnown and attempt.eventN == ball.eventN and attempt.eventTime == ball.eventTime
        if not attempt.sawOutside or sameEvent then return false, "already attempted" end
    end
    local entryTime, contact = api.ReceiveEntryTime(ball, shape, context.motion, context.lookahead)
    if entryTime == nil then return false, "armed" end
    return true, entryTime == 0 and "contact" or "pre-contact", entryTime, api.ReceiveContactBand(contact, shape)
end

function api.Flight(origin, velocity, floor, options)
    options = options or {}
    local initialVelocity = velocity
    local pos, spin = origin, options.spin or Vector3.zero
    local nodes = {pos}
    -- The game's renderer/collision floor uses ground + 1, despite a 1.05 mesh radius.
    local floorY = floor + (options.radius or api.Config.CollisionRadius)
    local dt, time, apex = math.min(tuning.PASSO_MAX or 1 / 60, 1 / 60), 0, pos.Y
    local freezeAt, freezeGravity
    if options.freeze and tuning.GRAVITA.Y < 0 and type(tuning.SET_FREEZE_FRAZ) == "number"
        and type(tuning.SET_FREEZE_G) == "number" then
        -- Verified trace: normal rise, then increased gravity at a fraction of normal time-to-apex.
        freezeAt = math.max(0, initialVelocity.Y) / -tuning.GRAVITA.Y * tuning.SET_FREEZE_FRAZ
        freezeGravity = tuning.SET_FREEZE_G
    end
    local lastPos = pos
    for step = 1, 600 do
        lastPos = pos
        local gravity = options.gravity
        if freezeAt and time >= freezeAt then gravity = freezeGravity end
        velocity, pos, spin = physics.PassoValori(pos, velocity, spin, dt,
            options.side, gravity, options.rampFraction, options.rampExponent, options.rampMin)
        time = time + dt
        apex = math.max(apex, pos.Y)
        if pos.Y <= floorY and velocity.Y <= 0 then
            local alpha = math.clamp((lastPos.Y - floorY) / math.max(lastPos.Y - pos.Y, 0.00001), 0, 1)
            pos = lastPos:Lerp(pos, alpha)
            table.insert(nodes, pos)
            break
        end
        if step % 3 == 0 then table.insert(nodes, pos) end
    end
    if nodes[#nodes] ~= pos then table.insert(nodes, pos) end
    return {nodes = nodes, landing = pos, time = time, apex = apex, velocity = initialVelocity,
        freezeAt = freezeAt, freezeGravity = freezeGravity,
        distance = (Vector3.new(pos.X, origin.Y, pos.Z) - origin).Magnitude}
end

function api.DiveTravel(speed, holdSeconds, elapsed)
    local time = math.max(0, elapsed)
    local hold = math.max(0, holdSeconds)
    if time <= hold then return speed * time end
    local fraction = math.clamp((time - hold) / 0.4, 0, 1)
    return speed * (hold + 0.4 * (fraction - fraction * fraction + fraction * fraction * fraction / 3))
end

function api.DiveSegmentEntry(a, b, size, minimumAlpha, maximumAlpha)
    local delta = b - a
    local lo, hi = math.clamp(minimumAlpha or 0, 0, 1), math.clamp(maximumAlpha or 1, 0, 1)
    if lo > hi then return nil end
    for _, axis in ipairs({"X", "Y", "Z"}) do
        local half, position, change = size[axis] * 0.5, a[axis], delta[axis]
        if half <= 0 then return nil end
        if math.abs(change) < 0.000001 then
            if math.abs(position) > half then return nil end
        else
            local enter, leave = (-half - position) / change, (half - position) / change
            if enter > leave then enter, leave = leave, enter end
            lo, hi = math.max(lo, enter), math.min(hi, leave)
            if lo > hi then return nil end
        end
    end
    return lo
end

function api.DiveResponseLead(ping, frameSeconds)
    return math.clamp(math.clamp(tonumber(ping) or 0, 0, 0.2)
        + math.clamp(tonumber(frameSeconds) or 1 / 60, 1 / 240, 0.05)
        + math.max(0, tonumber(api.Config.DiveLatencyPadding) or 0.015),
        0.025, math.clamp(tonumber(api.Config.DiveMaxResponseLead) or 0.16, 0.025, 0.2))
end

function api.DiveOwnSideWindow(a, b, context)
    if not context.netCenter or not context.netNormal or not context.ownSide then return 0, 1 end
    local sideA = flat(a - context.netCenter):Dot(context.netNormal) * context.ownSide
    local sideB = flat(b - context.netCenter):Dot(context.netNormal) * context.ownSide
    local boundary = 0.05
    if sideA <= boundary and sideB <= boundary then return nil end
    local lo, hi = 0, 1
    if sideA <= boundary then lo = (boundary - sideA) / (sideB - sideA) end
    if sideB <= boundary then hi = (boundary - sideA) / (sideB - sideA) end
    return math.clamp(lo, 0, 1), math.clamp(hi, 0, 1)
end

function api.PlanAutoDive(context, ball, receiveArea, geometry, attempt, now)
    if not context.enabled then return nil, "OFF" end
    if not context.focused then return nil, "focus Roblox" end
    if context.chat or context.menu then return nil, "typing/menu" end
    if not context.alive or not context.grounded or context.sitting or context.anchored then return nil, "character unavailable" end
    if not context.court or context.inMatch == false then return nil, "waiting for court" end
    if context.serving or context.commandsBlocked then return nil, "game action blocked" end
    if context.manual or now < (context.manualUntil or 0) then return nil, "manual action" end
    if context.pending or now < (context.nextAttempt or 0) then return nil, "cooldown" end
    if not receiveArea or not geometry or not geometry.size or not geometry.offset then return nil, "hitboxes unavailable" end
    if not ball.active or ball.ownTouch or not ball.sameCourt then return nil, "waiting for incoming hit" end
    if not ball.position or not ball.velocity then return nil, "ball data unavailable" end
    local canCrossNet = context.netCenter and context.netNormal and context.ownSide
        and flat(ball.velocity):Dot(context.netNormal) * context.ownSide > 0.1
    if not ball.ownHalf and not canCrossNet then return nil, "waiting for incoming hit" end
    if ball.velocity.Magnitude < math.max(1, context.minSpeed or 55) then return nil, "not a hard hit" end
    if ball.kind == "Set" or ball.kind == "Bump" or ball.kind == "Receive" or ball.kind == "Dive" then return nil, "not a hard hit" end
    if attempt and (ball.eventN == nil and ball.eventTime == nil
        or attempt.eventN == ball.eventN and attempt.eventTime == ball.eventTime) then return nil, "already attempted" end
    local horizon = math.clamp(context.horizon or 0.7, 0.1, 1)
    -- Receive priority uses the entire dive planning window, not only this frame's overlap.
    local currentOwnSide = api.DiveOwnSideWindow(ball.position, ball.position, context)
    if currentOwnSide ~= nil and api.PointInReceiveCore(ball.position, receiveArea) then
        return nil, "receive can reach"
    end
    local speed, hold = geometry.speed, geometry.hold
    if type(speed) ~= "number" or speed <= 0 or type(hold) ~= "number" then return nil, "dive profile unavailable" end
    local activation = math.clamp(math.max(geometry.activation or 0.05, context.responseLead or 0), 0, 0.2)
    local pos, vel, spin, elapsed = ball.position, ball.velocity, ball.spin or Vector3.zero, 0
    local step = math.min(tuning.PASSO_MAX or 1 / 120, 1 / 120)
    if step <= 0 then return nil, "physics unavailable" end
    local floor = (ball.floor or 0.408) + (api.Config.CollisionRadius or 1)
    if pos.Y <= floor then return nil, "ball grounded" end
    local bestPlan, motion = nil, context.motion or Vector3.zero
    while elapsed < horizon do
        local dt = math.min(step, horizon - elapsed)
        local nextVel, nextPos, nextSpin = physics.PassoValori(pos, vel, spin, dt,
            ball.side, ball.gravity, ball.rampFraction, ball.rampExponent, ball.rampMin)
        local finish = elapsed + dt
        local grounded = nextPos.Y <= floor
        if grounded then
            local alpha = math.clamp((pos.Y - floor) / math.max(pos.Y - nextPos.Y, 0.000001), 0, 1)
            nextPos, finish = pos:Lerp(nextPos, alpha), elapsed + dt * alpha
        end
        if context.netTopY and context.netCenter and context.netNormal and context.ownSide then
            local sideA = flat(pos - context.netCenter):Dot(context.netNormal) * context.ownSide
            local sideB = flat(nextPos - context.netCenter):Dot(context.netNormal) * context.ownSide
            if sideA < 0 and sideB >= 0 then
                local cross = pos:Lerp(nextPos, -sideA / (sideB - sideA))
                local inNetWidth = not context.netAxis or not context.netHalfWidth
                    or math.abs(flat(cross - context.netCenter):Dot(context.netAxis)) <= context.netHalfWidth + (api.Config.CollisionRadius or 1)
                if inNetWidth and cross.Y <= context.netTopY + (api.Config.CollisionRadius or 1) then
                    return nil, "net blocks incoming hit"
                end
            end
        end
        local ownLo, ownHi = api.DiveOwnSideWindow(pos, nextPos, context)
        if ownLo ~= nil then
            local ownStart, ownFinish = elapsed + (finish - elapsed) * ownLo, elapsed + (finish - elapsed) * ownHi
            if api.ReceiveSegmentEntry(pos:Lerp(nextPos, ownLo) - motion * ownStart,
                pos:Lerp(nextPos, ownHi) - motion * ownFinish, receiveArea) ~= nil then
                return nil, "receive can reach"
            end
        end
        if ownLo ~= nil and not bestPlan and finish >= activation and finish > elapsed then
            local direction = context.autoAim == false and flat(context.facing or Vector3.zero)
                or flat(pos:Lerp(nextPos, (ownLo + ownHi) * 0.5) - context.rootPosition)
            if direction.Magnitude > 0.05 then
                direction = direction.Unit
                local frame = CFrame.lookAt(context.rootPosition, context.rootPosition + direction) * geometry.offset
                local localA = frame:PointToObjectSpace(pos - direction * api.DiveTravel(speed, hold, elapsed))
                local localB = frame:PointToObjectSpace(nextPos - direction * api.DiveTravel(speed, hold, finish))
                local minimum = math.max(ownLo, (activation - elapsed) / (finish - elapsed))
                local alpha = minimum <= ownHi and api.DiveSegmentEntry(localA, localB, geometry.size, minimum, ownHi)
                if alpha then
                    local eta = elapsed + (finish - elapsed) * alpha
                    bestPlan = {direction = direction, contact = pos:Lerp(nextPos, alpha), eta = eta,
                        distance = api.DiveTravel(speed, hold, eta), eventN = ball.eventN, eventTime = ball.eventTime,
                        responseLead = activation, predictedAcrossNet = not ball.ownHalf}
                end
            end
        end
        if grounded then break end
        pos, vel, spin, elapsed = nextPos, nextVel, nextSpin, finish
    end
    if bestPlan then return bestPlan, "intercept" end
    return nil, "outside dive reach"
end

function api.IncomingLandingEligible(viewer, ball, net, nets)
    if not ball.active or not ball.position or not ball.velocity or ball.ownTouch or ball.ownServe then return false end
    if ball.velocity.Magnitude < 0.1 or ball.position.Y <= ball.floor + api.Config.CollisionRadius + 0.02 then return false end
    if not api.TargetNearNet(ball.position, net, nets) then return false end
    local ownSide = flat(viewer - net.center):Dot(net.normal)
    if math.abs(ownSide) < 0.15 then return false end
    local sign = ownSide > 0 and 1 or -1
    local ballSide = flat(ball.position - net.center):Dot(net.normal) * sign
    local incoming = flat(ball.velocity):Dot(net.normal) * sign > 0.1
    return incoming or (ballSide >= 0 and ball.velocity.Y < -0.1)
end

function api.PredictIncomingLanding(viewer, ball, net, nets)
    if not api.IncomingLandingEligible(viewer, ball, net, nets) then return nil end
    local flight = api.Flight(ball.position, ball.velocity, ball.floor, ball.options)
    if flight.landing.Y > ball.floor + api.Config.CollisionRadius + 0.05 then return nil end
    local side = flat(viewer - net.center):Dot(net.normal)
    if flat(flight.landing - net.center):Dot(net.normal) * side <= 0 then return nil end
    return {flight = flight, inCourt = api.InCourt(flight.landing, net), eventN = ball.eventN, eventTime = ball.eventTime}
end

function api.LandingTimeRemaining(flightTime, solvedAt, now)
    return math.max(0, flightTime - math.max(0, now - solvedAt))
end

local ok,message=pcall(function()
 tuning=require(assert(RS:FindFirstChild("NG_TaraturaPalla"),"Game tuning unavailable"))
 physics=require(assert(RS:FindFirstChild("NG_Palla"),"Ball physics unavailable"))
 local customization=RS:FindFirstChild("CharacterCustomization")
 local config=customization and customization:FindFirstChild("Config")
 local module=config and config:FindFirstChild("HeightConfig")
 if module then heightConfig=require(module) end
local function refreshNets()
    netCache = {}
    local courts = workspace:FindFirstChild("InCourts")
    if not courts then return end
    -- The observed map has multiple same-named NetTop parts: match geometry, not FindFirstChild.
    for _, court in ipairs(courts:GetChildren()) do
        if court:IsA("BasePart") then
            for _, top in ipairs(workspace:GetChildren()) do
                if top.Name == "NetTop" and top:IsA("BasePart")
                    and flat(top.Position - court.Position).Magnitude < 2 then
                    local axis = flat(top.CFrame.RightVector)
                    if axis.Magnitude > 0.99 then
                        axis = axis.Unit
                        local alignedX = math.abs(axis:Dot(court.CFrame.RightVector)) > 0.99
                        local alignedZ = math.abs(axis:Dot(court.CFrame.LookVector)) > 0.99
                        if alignedX or alignedZ then
                            table.insert(netCache, {part = top, court = court, center = top.Position,
                                courtCenter = court.Position, axis = axis,
                                normal = Vector3.new(-axis.Z, 0, axis.X),
                                halfWidth = math.min(top.Size.X, alignedX and court.Size.X or court.Size.Z) * 0.5,
                                halfDepth = (alignedX and court.Size.Z or court.Size.X) * 0.5})
                        end
                    end
                end
            end
        end
    end
end

function api.GetNetAt(position)
    for _, net in ipairs(netCache) do
        if net.part.Parent and net.court.Parent and api.InCourt(position, net) then return net end
    end
    return nil
end
refreshNets()

local boundsCache = setmetatable({}, {__mode = "k"})
api.BoundsMetrics = {Solves = 0, CacheHits = 0, Errors = 0, ReceiveSkips = 0, DiveSkips = 0}
function api.ReceiveInputLead(ping)
    -- The native receive command needs contact near its arrival, not just the animation start.
    return math.clamp(math.max(0, tonumber(ping) or 0) + math.max(0, api.Config.ReceiveContactMargin or 0.004), 0.008, 0.12)
end
function api.IsLandingInOwnCourt(viewer, landing, net)
    if not viewer or not landing or not net then return false, "landing unavailable" end
    local side = flat(viewer - net.center):Dot(net.normal)
    if math.abs(side) < 0.15 then return false, "court side uncertain" end
    local across = flat(landing - net.courtCenter):Dot(net.axis)
    local depth = flat(landing - net.courtCenter):Dot(net.normal)
    local ownDepth = flat(landing - net.center):Dot(net.normal) * (side > 0 and 1 or -1)
    if math.abs(across) > net.halfWidth + 0.001 or math.abs(depth) > net.halfDepth + 0.001 or ownDepth < -0.001 then
        return false, "predicted out"
    end
    return true, "predicted in"
end
function api.CheckIncomingBounds(ball, sample, net, viewer)
    if not api.Config.SkipOutBalls then return true, "out filter OFF" end
    if not ball or not net or not sample or not sample.position or not sample.velocity then return false, "landing unavailable" end
    local now = os.clock()
    local ownSide = flat(viewer - net.center):Dot(net.normal) > 0 and 1 or -1
    local cached = boundsCache[ball]
    local floor = tonumber(workspace:GetAttribute("NG_QuotaSuolo")) or tuning.QUOTA_CAMPO or 0.408
    if cached and cached.net == net.part and cached.court == net.court and cached.ownSide == ownSide
        and cached.eventN == sample.eventN and cached.eventTime == sample.eventTime
        and cached.gravity == sample.gravity and cached.side == sample.side
        and cached.rampFraction == sample.rampFraction and cached.rampExponent == sample.rampExponent and cached.rampMin == sample.rampMin
        and now - cached.time < 1/30 and (sample.velocity - cached.velocity).Magnitude < 12
        and (sample.position - (cached.position + cached.velocity * (now-cached.time))).Magnitude < 2 then
        api.BoundsMetrics.CacheHits += 1
        return cached.allowed, cached.reason, cached
    end
    local ok, flight = pcall(api.Flight, sample.position, sample.velocity, floor, {spin = sample.spin or Vector3.zero,
        gravity = sample.gravity, side = sample.side, rampFraction = sample.rampFraction,
        rampExponent = sample.rampExponent, rampMin = sample.rampMin})
    local allowed, reason = false, "landing unavailable"
    if ok and flight.landing and flight.landing.Y <= floor + api.Config.CollisionRadius + 0.05 then
        allowed, reason = api.IsLandingInOwnCourt(viewer, flight.landing, net)
    elseif not ok then
        api.BoundsMetrics.Errors += 1
    end
    local skipped = cached and cached.eventN == sample.eventN and cached.eventTime == sample.eventTime and cached.skipped or {}
    cached = {time = now, net = net.part, court = net.court, ownSide = ownSide, eventN = sample.eventN, eventTime = sample.eventTime,
        position = sample.position, velocity = sample.velocity, gravity = sample.gravity, side = sample.side,
        rampFraction = sample.rampFraction, rampExponent = sample.rampExponent, rampMin = sample.rampMin,
        allowed = allowed, reason = reason, landing = ok and flight.landing or nil, skipped = skipped}
    boundsCache[ball] = cached
    api.BoundsMetrics.Solves += 1
    api.LastBoundsDecision = cached
    return allowed, reason, cached
end
function api.NoteOutSkip(action, decision)
    if not decision or decision.skipped[action] then return end
    decision.skipped[action] = true
    local field = action == "dive" and "DiveSkips" or "ReceiveSkips"
    api.BoundsMetrics[field] += 1
    log("auto_" .. action .. "_skipped", {reason = decision.reason, eventN = decision.eventN, landing = decision.landing})
end

local receiveManager, receiveMouse
local receiveFocused, receiveManualUntil, receiveNextAttempt = true, 0, 0
if type(isrbxactive) == "function" then
    local ok, focused = pcall(isrbxactive)
    if ok then receiveFocused = focused == true end
end
local receivePing, receivePingAt = 0, -math.huge
local receiveAttempts = setmetatable({}, {__mode = "k"})
local receivePending = {}
local receiveCharacter = player.Character
local receiveRetryAt, receivePauseReason = 0, nil
api.ReceiveMetrics = {Checks = 0, Attempts = 0, Confirmed = 0, Errors = 0, Anticipated = 0,
    CoreAttempts = 0, ToleranceAttempts = 0, CoreConfirmed = 0, ToleranceConfirmed = 0, Unconfirmed = 0}
api.ReceiveHistory = api.ReceiveHistory or {}

local function recordReceive(kind, data)
    local entry = {kind = kind, time = workspace:GetServerTimeNow(), eventN = data.eventN,
        band = data.band, entryIn = data.entryIn, lookahead = data.lookahead,
        confirmationDelay = data.confirmationDelay, position = data.position, background = data.background, reason = data.reason}
    table.insert(api.ReceiveHistory, entry)
    while #api.ReceiveHistory > 80 do table.remove(api.ReceiveHistory, 1) end
    log(kind, data)
end

local function updateReceiveConfirmations(now)
    for attempt, ball in pairs(receivePending) do
        local owner = ball:GetAttribute("NG_UltimoTocco") or ball:GetAttribute("NG_ToccoUltimo")
        local kind = ball:GetAttribute("NG_UltimoTipo")
        if now - attempt.time <= 2 and owner == player.UserId and (kind == "Bump" or kind == "Receive") then
            attempt.confirmed = true
            api.ReceiveMetrics.Confirmed = api.ReceiveMetrics.Confirmed + 1
            local field = attempt.band == "tolerance" and "ToleranceConfirmed" or "CoreConfirmed"
            api.ReceiveMetrics[field] = api.ReceiveMetrics[field] + 1
            if api.LastReceive and api.LastReceive.ball == ball then api.LastReceive.status = "confirmed" end
            recordReceive("auto_receive_confirmed", {eventN = ball:GetAttribute("NG_EvN"), band = attempt.band,
                confirmationDelay = now - attempt.time, entryIn = attempt.entryIn, background = attempt.background})
            receivePending[attempt] = nil
        elseif now - attempt.time > 2 then
            api.ReceiveMetrics.Unconfirmed = api.ReceiveMetrics.Unconfirmed + 1
            recordReceive("auto_receive_unconfirmed", {eventN = attempt.eventN, band = attempt.band,
                entryIn = attempt.entryIn, background = attempt.background})
            receivePending[attempt] = nil
        end
    end
end

local function releaseReceiveMouse()
    local pending = receiveMouse
    if pending then
        local ok, err = pcall(function()
            pending.manager:SendMouseButtonEvent(pending.x, pending.y, 0, false, game, 0)
        end)
        if not ok then
            api.ReceiveMetrics.Errors = api.ReceiveMetrics.Errors + 1
            api.ReceiveMetrics.LastError = tostring(err)
            log("auto_receive_release_error", tostring(err))
            return false
        end
        if receiveMouse == pending then receiveMouse = nil end
    end
    return true
end

function api.PauseAutoReceive(reason, retrySeconds)
    releaseReceiveMouse()
    receivePauseReason, receiveRetryAt = reason, os.clock() + (retrySeconds or 2)
    if api.Config.AutoReceive then receiveStatus.Text = "Auto Receive: ON / paused: " .. reason end
end

function api.ResetAutoReceiveCharacter(character)
    local released = releaseReceiveMouse()
    receiveCharacter = character
    receiveAttempts = setmetatable({}, {__mode = "k"})
    receiveNextAttempt, receiveManualUntil = 0, os.clock() + 0.15
    receivePauseReason, receiveRetryAt = nil, 0
    if not released then api.PauseAutoReceive("input release failed") end
    if api.Config.AutoReceive then receiveStatus.Text = "Auto Receive: ON / waiting for character" end
end

function api.SetAutoReceive(enabled, reason)
    local released = releaseReceiveMouse()
    api.Config.AutoReceive = enabled == true
    receivePauseReason, receiveRetryAt = nil, 0
    if api.Config.AutoReceive then
        if not receiveManager then
            local ok, manager = pcall(function() return game:GetService("VirtualInputManager") end)
            if ok then receiveManager = manager end
        end
        receiveManualUntil = os.clock() + 0.2
    end
    receiveToggle.Text = api.Config.AutoReceive and "Auto Receive ON" or "Auto Receive OFF"
    receiveToggle.BackgroundColor3 = api.Config.AutoReceive and Color3.fromRGB(36, 94, 61) or Color3.fromRGB(38, 48, 65)
    receiveStatus.Text = "Auto Receive: " .. (api.Config.AutoReceive and "ON / armed" or ("OFF" .. (reason and " / " .. reason or "")))
    if api.Config.AutoReceive and (not released or not receiveManager) then
        api.PauseAutoReceive(not released and "input release failed" or "mouse input unavailable")
    end
    log("auto_receive_toggle", {enabled = api.Config.AutoReceive, reason = reason})
    return api.Config.AutoReceive
end

function api.GetReceiveCore()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")
    local rec = character and character:FindFirstChild("RecHitbox")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not head or not rec or not humanoid or not rec:IsA("BasePart") then return nil end
    local reach = heightConfig and heightConfig.Reach
    if not reach then return nil end
    local height = reach.RecAltezza or {}
    return api.BuildReceiveCore(rec.Position, rec.Size, head.Position, head.Size, root.Position, root.Size,
        humanoid.HipHeight, {aboveHead = height.SopraTesta, belowFeet = height.SottoPiedi,
            extraHeight = tonumber(workspace:GetAttribute("NG_RecAltezzaExtra")),
            stack = tonumber(player:GetAttribute("NG_NazTRecStack")), charge = tonumber(player:GetAttribute("NG_NazTRecCarica")),
            topScale = tonumber(player:GetAttribute("NG_NazTRecTop"))})
end

function api.GetReceiveArea()
    local reach = heightConfig and heightConfig.Reach
    return api.BuildReceiveArea(api.GetReceiveCore(), reach and reach.RecPity)
end

local function receiveActionKey(key)
    if key == Enum.KeyCode.Space then return true end
    local binds = player:FindFirstChild("Keybinds")
    if not binds then return false end
    for _, attribute in ipairs({"BackSetKey", "FrontSetKey", "DiveKey", "DumpKey", "AutoServeKey", "StrongHitKey"}) do
        local name = binds:GetAttribute(attribute)
        if type(name) == "string" and key.Name == name then return true end
    end
    return false
end

connect(UIS.InputBegan, function(input, processed)
    if api.Config.ReceiveManualPause > 0 and not processed and not receiveMouse and (receiveActionKey(input.KeyCode)
        or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2) then
        receiveManualUntil = os.clock() + api.Config.ReceiveManualPause
    end
end)
connect(UIS.WindowFocusReleased, function()
    receiveFocused = false
    if not releaseReceiveMouse() then api.PauseAutoReceive("input release failed") end
    if api.Config.AutoReceive then
        receiveStatus.Text = api.Config.ReceiveInBackground and "Auto Receive: ON / background" or "Auto Receive: ON / paused: focus"
    end
end)
connect(UIS.WindowFocused, function()
    receiveFocused = true
    receiveManualUntil = math.max(receiveManualUntil, os.clock() + 0.1)
end)

local function receivePointerBlocked(point)
    if not point then return true end
    local inset = GuiService:GetGuiInset()
    if point.X < 0 or point.Y <= inset.Y + 4 then return true end
    local camera = workspace.CurrentCamera
    if camera and (point.X >= camera.ViewportSize.X or point.Y >= camera.ViewportSize.Y) then return true end
    local ok, objects = pcall(function() return player.PlayerGui:GetGuiObjectsAtPosition(point.X, point.Y) end)
    if not ok then return true end
    for _, object in ipairs(objects) do
        if object.Visible and (object.Active or object:IsA("TextButton") or object:IsA("ImageButton") or object:IsA("TextBox")) then
            return true
        end
    end
    return false
end

local function receiveInputPoint()
    if receiveFocused then
        local point = UIS:GetMouseLocation()
        return point, receivePointerBlocked(point)
    end
    -- Engine-targeted input only. Never use desktop coordinates or executor mouse functions.
    local camera = workspace.CurrentCamera
    if not api.Config.ReceiveInBackground or not camera then return nil, true end
    local size = camera.ViewportSize
    for _, fraction in ipairs({{0.5, 0.55}, {0.5, 0.45}, {0.35, 0.55}, {0.65, 0.55}, {0.5, 0.7}, {0.8, 0.4}, {0.2, 0.4}}) do
        local point = Vector2.new(size.X * fraction[1], size.Y * fraction[2])
        if not receivePointerBlocked(point) then return point, false end
    end
    return nil, true
end

-- RECEIVE_INPUT_BEGIN
local function pressReceiveMouse(point)
    if not alive or not api.Config.AutoReceive or (not receiveFocused and not api.Config.ReceiveInBackground)
        or receiveMouse or not point then return false end
    local pending = {manager = receiveManager, x = math.floor(point.X), y = math.floor(point.Y)}
    receiveMouse = pending
    local ok, err = pcall(function()
        pending.manager:SendMouseButtonEvent(pending.x, pending.y, 0, true, game, 0)
    end)
    if not ok then
        releaseReceiveMouse()
        api.ReceiveMetrics.Errors = api.ReceiveMetrics.Errors + 1
        api.ReceiveMetrics.LastError = tostring(err)
        api.PauseAutoReceive("input unavailable")
        log("auto_receive_input_error", tostring(err))
        return false
    end
    task.delay(0.035, function()
        if receiveMouse == pending and not releaseReceiveMouse() then api.PauseAutoReceive("input release failed") end
    end)
    return true
end
-- RECEIVE_INPUT_END

local function updateAutoReceive(frameSeconds)
    updateReceiveConfirmations(os.clock())
    if not api.Config.AutoReceive then return end
    if api.PauseForAttack and api.PauseForAttack() then releaseReceiveMouse(); receiveStatus.Text = "Auto Receive: waiting for attack to finish"; return end
    if os.clock() < (api.DiveBusyUntil or 0) then
        receiveStatus.Text = "Auto Receive: ON / dive recovery"
        return
    end
    api.ReceiveMetrics.Checks = api.ReceiveMetrics.Checks + 1
    local now = os.clock()
    if receivePauseReason then
        if now < receiveRetryAt then
            receiveStatus.Text = "Auto Receive: ON / paused: " .. receivePauseReason
            return
        end
        if not releaseReceiveMouse() then api.PauseAutoReceive("input release failed"); return end
        receivePauseReason = nil
    end
    if not receiveManager then
        local ok, manager = pcall(function() return game:GetService("VirtualInputManager") end)
        if ok then receiveManager = manager end
        if not receiveManager then api.PauseAutoReceive("mouse input unavailable"); return end
    end
    if now - receivePingAt >= 0.25 then
        receivePingAt = now
        local ok, ping = pcall(function() return player:GetNetworkPing() end)
        if ok and type(ping) == "number" then receivePing = ping end
    end
    local character = player.Character
    if character ~= receiveCharacter then api.ResetAutoReceiveCharacter(character) end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        if not releaseReceiveMouse() then api.PauseAutoReceive("input release failed") end
        receiveStatus.Text = "Auto Receive: ON / waiting for character"
        return
    end
    local net = api.ServeViewerNet(root.Position, netCache)
    local shape = api.GetReceiveArea()
    local point, pointerBlocked = receiveInputPoint()
    local blocked = false
    for _, attribute in ipairs({"NG_StunLocale", "NG_BloccoComandi", "NG_MinigiocoBattuta"}) do
        local untilTime = tonumber(player:GetAttribute(attribute))
        if untilTime and now < untilTime then blocked = true end
    end
    local lastAction = tonumber(player:GetAttribute("NG_ColpoLocale"))
    if lastAction and now - lastAction < 0.15 then blocked = true end
    local manual = api.Config.ReceiveManualPause > 0 and receiveFocused and (UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UIS:IsKeyDown(Enum.KeyCode.Space)
        )
    local context = {enabled = api.Config.AutoReceive, focused = receiveFocused, chat = UIS:GetFocusedTextBox() ~= nil,
        allowBackground = api.Config.ReceiveInBackground, menu = GuiService.MenuIsOpen, pointerBlocked = pointerBlocked, alive = humanoid.Health > 0,
        grounded = humanoid.FloorMaterial ~= Enum.Material.Air and player:GetAttribute("NG_InAria") ~= true,
        sitting = humanoid.Sit, anchored = root.Anchored, court = net ~= nil, inMatch = player:GetAttribute("NG_InMatch"),
        serving = player:GetAttribute("NG_PuoBattere") == true, commandsBlocked = blocked,
        manual = manual, manualUntil = receiveManualUntil, nextAttempt = receiveNextAttempt,
        pending = receiveMouse ~= nil, motion = root.AssemblyLinearVelocity,
        lookahead = api.ReceiveInputLead and api.ReceiveInputLead(receivePing) or api.ReceiveLeadTime(receivePing, frameSeconds)}
    api.ReceiveTiming = {leadSeconds = context.lookahead, pingSeconds = receivePing}
    local cache = workspace:FindFirstChild("BallCache")
    local selected, selectedSample, selectedEntry, selectedBand
    local preAimBall, preAimContact, preAimEntry
    local reason = "waiting for ball"
    for _, ball in ipairs(cache and cache:GetChildren() or {}) do
        local position, velocity = ball:FindFirstChild("Position"), ball:FindFirstChild("Velocity")
        local pos = position and position:IsA("Vector3Value") and position.Value
        local vel = velocity and velocity:IsA("Vector3Value") and velocity.Value
        local owner = ball:GetAttribute("NG_UltimoTocco") or ball:GetAttribute("NG_ToccoUltimo")
        local sample = {active = ball.Name == "Ball" and not ball:GetAttribute("DeadAt") and not ball:GetAttribute("Settling"),
            position = pos, velocity = vel, ownTouch = owner == player.UserId,
            eventN = ball:GetAttribute("NG_EvN"), eventTime = ball:GetAttribute("NG_EvT"),
            ownHalf = net ~= nil and pos ~= nil and flat(pos - net.center):Dot(net.normal)
                * flat(root.Position - net.center):Dot(net.normal) > 0,
            sameCourt = net ~= nil and pos ~= nil and api.TargetNearNet(pos, net, netCache)}
        local spin = ball:FindFirstChild("Spin")
        sample.spin = spin and spin:IsA("Vector3Value") and spin.Value or Vector3.zero
        sample.gravity, sample.side = ball:GetAttribute("NG_GravFattore"), ball:GetAttribute("NG_SpinOltreRete")
        sample.rampFraction, sample.rampExponent, sample.rampMin = ball:GetAttribute("NG_SpinRampaFraz"),
            ball:GetAttribute("NG_SpinRampaEsp"), ball:GetAttribute("NG_SpinRampaMin")
        local attempt = receiveAttempts[ball]
        if attempt then
            if not api.PointInReceiveCore(pos, shape) then attempt.sawOutside = true end
        end
        local trigger, why, entryTime, band = api.ShouldAutoReceive(context, sample, shape, attempt, now)
        if not trigger and why == "armed" and api.Config.AimBot and api.PrepareReceiveAim then
            local earlyEntry, contact = api.ReceiveEntryTime(sample, shape, context.motion,
                context.lookahead + math.max(0, api.Config.ReceiveAimPreSeconds or 0.09))
            if earlyEntry and (not preAimEntry or earlyEntry < preAimEntry)
                and api.CheckIncomingBounds(ball, sample, net, root.Position) then
                preAimBall, preAimContact, preAimEntry = ball, contact, earlyEntry
            end
        end
        if trigger and api.CheckIncomingBounds then
            local allowed, boundsReason, decision = api.CheckIncomingBounds(ball, sample, net, root.Position)
            if not allowed then
                trigger, why = false, boundsReason
                api.NoteOutSkip("receive", decision)
            end
        end
        reason = why
        if trigger then
            if not selected or entryTime < selectedEntry then
                selected, selectedSample, selectedEntry, selectedBand = ball, sample, entryTime, band
            end
        end
    end
    if not selected then
        if preAimBall then api.PrepareReceiveAim(preAimContact, preAimEntry, preAimBall) end
        -- Report context even while there are no ball models.
        if not cache or #cache:GetChildren() == 0 then
            local _, why = api.ShouldAutoReceive(context, {active = false}, shape, nil, now)
            reason = why
        end
        receiveStatus.Text = "Auto Receive: ON / " .. reason .. (reason == "armed" and string.format(" / early %.0fms", context.lookahead * 1000) or "")
        return
    end
    if api.Config.AimBot and api.CanCommitReceivePass and not api.CanCommitReceivePass(selected) then
        if api.CancelReceiveAim then api.CancelReceiveAim() end
        receiveStatus.Text = "Auto Receive: skipped / unsafe pass power"
        return
    end
    if api.AimReceive then
        local _, contact = api.ReceiveEntryTime(selectedSample, shape, context.motion, context.lookahead)
        if api.Config.AimBot and api.PrepareReceiveAim and api.IsReceiveFacingReady then
            api.PrepareReceiveAim(contact or selectedSample.position, selectedEntry, selected)
            local ready = api.IsReceiveFacingReady(selected)
            if not ready then
                receiveStatus.Text = "Auto Receive: waiting / facing settling"
                return
            end
        end
        local aimOk, aimed = pcall(api.AimReceive, contact or selectedSample.position, selectedEntry, selected)
        if api.Config.AimBot and (not aimOk or not aimed) then
            if not aimOk then log("receive_aim_error", tostring(aimed)) end
            if api.CancelReceiveAim then api.CancelReceiveAim() end
            receiveStatus.Text = "Auto Receive: skipped / aim unavailable"
            return
        end
    end
    local receivePressed = pressReceiveMouse(point)
    if not receivePressed and api.CancelReceiveAim then api.CancelReceiveAim() end
    if receivePressed then
        for previous, ball in pairs(receivePending) do
            if ball == selected then
                api.ReceiveMetrics.Unconfirmed = api.ReceiveMetrics.Unconfirmed + 1
                recordReceive("auto_receive_unconfirmed", {eventN = previous.eventN, band = previous.band, reason = "new flight superseded attempt"})
                receivePending[previous] = nil
            end
        end
        local attempt = {time = now, eventN = selectedSample.eventN, eventTime = selectedSample.eventTime,
            sawOutside = false, band = selectedBand, entryIn = selectedEntry, background = not receiveFocused}
        receiveAttempts[selected], receivePending[attempt] = attempt, selected
        local waitTrait = tonumber(player:GetAttribute("TraitActionWait")) or 0
        receiveNextAttempt = now + math.max(0.1, 1 + waitTrait) + math.max(0, api.Config.ReceiveCooldownPadding)
        api.ReceiveMetrics.Attempts = api.ReceiveMetrics.Attempts + 1
        local field = selectedBand == "tolerance" and "ToleranceAttempts" or "CoreAttempts"
        api.ReceiveMetrics[field] = api.ReceiveMetrics[field] + 1
        if selectedEntry > 0 then api.ReceiveMetrics.Anticipated = api.ReceiveMetrics.Anticipated + 1 end
        api.LastReceive = {time = workspace:GetServerTimeNow(), ball = selected, position = selectedSample.position,
            movementSpeed = flat(root.AssemblyLinearVelocity).Magnitude,
            eventN = selectedSample.eventN, entryIn = selectedEntry, lookahead = context.lookahead,
            band = selectedBand, radius = shape.radius, coreRadius = shape.coreRadius, tolerance = shape.tolerance,
            background = not receiveFocused, status = "attempted / awaiting game confirmation"}
        recordReceive("auto_receive_attempt", api.LastReceive)
        receiveStatus.Text = "Auto Receive: ON / " .. (selectedBand or "contact") .. " attempt"
    end
end

connect(RunService.Heartbeat, function(dt)
    local ok, err = pcall(updateAutoReceive, dt)
    if not ok then
        api.ReceiveMetrics.Errors = api.ReceiveMetrics.Errors + 1
        api.ReceiveMetrics.LastError = tostring(err)
        api.PauseAutoReceive("error / see log")
        log("auto_receive_error", tostring(err))
    end
end)

local diveHeld, diveNextAttempt, diveElapsed = nil, 0, 1
local diveAttempts = setmetatable({}, {__mode = "k"})
local divePending = {}
local diveCharacter = player.Character
local divePing, divePingAt = 0, -math.huge
api.DiveBusyUntil = 0
api.DiveMetrics = {Checks = 0, Attempts = 0, Confirmed = 0, Unconfirmed = 0, Errors = 0, EarlyNetAttempts = 0}
api.DiveHistory = {}

local function recordDive(kind, data)
    table.insert(api.DiveHistory, {kind = kind, time = os.clock(), data = data})
    while #api.DiveHistory > 80 do table.remove(api.DiveHistory, 1) end
    log(kind, data)
end

local function releaseDiveInput()
    local held = diveHeld
    if not held then return true end
    local released = held.released == true
    if not released then
        released = pcall(function() held.bridge:Fire("tasto", held.key, false) end)
        held.released = released
    end
    local restored = held.dynamic == nil
    if held.dynamic then
        restored = pcall(function()
            if held.dynamic.Parent and held.dynamic:GetAttribute("Active") == false then
                held.dynamic:SetAttribute("Active", held.originalDynamic)
            end
        end)
        if restored then held.dynamic = nil end
    end
    if released and restored then diveHeld = nil; return true end
    api.DiveMetrics.Errors = api.DiveMetrics.Errors + 1
    return false
end

function api.SetAutoDive(enabled)
    local released = releaseDiveInput()
    api.Config.AutoDive = enabled == true and released
    diveElapsed = 1
    diveToggle.Text = api.Config.AutoDive and "Auto Dive ON [4]" or "Auto Dive OFF [4]"
    diveToggle.BackgroundColor3 = api.Config.AutoDive and Color3.fromRGB(36, 76, 106) or Color3.fromRGB(38, 48, 65)
    diveStatus.Text = "Auto Dive: " .. (api.Config.AutoDive and "ON / armed" or "OFF")
    if api.Config.AutoDive then receiveManualUntil = math.max(receiveManualUntil, os.clock() + 0.2) end
    recordDive("auto_dive_toggle", {enabled = api.Config.AutoDive})
    return api.Config.AutoDive
end

local function diveGeometry(root, humanoid)
    local box = player.Character and player.Character:FindFirstChild("DiveHitbox")
    if not box or not box:IsA("BasePart") then return nil end
    local stats = player:FindFirstChild("Stats")
    local function trait(name)
        return tonumber(stats and stats:GetAttribute(name)) or tonumber(player:GetAttribute(name)) or 0
    end
    local speed = 38.25
    local modules = RS:FindFirstChild("Modules")
    local badgeModule = modules and modules:FindFirstChild("BadgeLib")
    if badgeModule then
        local ok, hasBadge = pcall(function() return require(badgeModule):GetBadge(player, "Hyperdrive") end)
        if ok and hasBadge then speed = 63.75 end
    end
    speed = speed * math.max(0.1, 1 + trait("TraitDiveReach"))
        * math.max(0.1, 1 + (tonumber(player:GetAttribute("NG_NazTuffo")) or 0))
        * math.max(0.1, 1 + (tonumber(player:GetAttribute("NG_NazTTuffo")) or 0))
    return {size = box.Size, offset = root.CFrame:ToObjectSpace(box.CFrame), speed = speed,
        hold = math.clamp(humanoid.WalkSpeed / 15, 0, 1.56) * 0.25,
        activation = tonumber(tuning.DIVE_RITARDO) or 0.05,
        cooldown = math.max(api.Config.DiveCooldown, 1.3 * math.max(0.1, 1 + trait("TraitDiveRise")) + 0.1)}
end

local function nativeDiveInput()
    local scripts = player:FindFirstChild("PlayerScripts")
    local input = scripts and scripts:FindFirstChild("Input")
    local bridge = input and input:FindFirstChild("NG_InputVirtuale")
    local binds = player:FindFirstChild("Keybinds")
    local key = binds and binds:GetAttribute("DiveKey")
    if not bridge or not bridge:IsA("BindableEvent") or type(key) ~= "string" or key == "" then return nil end
    local ok, code = pcall(function() return Enum.KeyCode[key] end)
    if not ok or not code or code == Enum.KeyCode.Unknown then return nil end
    return bridge, key
end

local function dispatchDive(root, plan, geometry, ball, now)
    local bridge, key = nativeDiveInput()
    if not bridge then diveStatus.Text = "Auto Dive: ON / native input unavailable"; return false end
    local character = player.Character
    if not alive or not api.Config.AutoDive or diveHeld or receiveMouse or now < receiveNextAttempt
        or not character or character:FindFirstChild("HumanoidRootPart") ~= root then return false end
    local net = api.ServeViewerNet(root.Position, netCache)
    if not net then return false end
    local destination = root.Position + plan.direction * plan.distance
    if flat(root.Position - net.center):Dot(net.normal) * flat(destination - net.center):Dot(net.normal) <= 0 then
        diveStatus.Text = "Auto Dive: ON / net blocks dive"; return false
    end
    local parameters = RaycastParams.new()
    parameters.FilterType = Enum.RaycastFilterType.Exclude
    parameters.FilterDescendantsInstances = {character, world}
    parameters.RespectCanCollide = true
    if plan.distance > 0.05 and workspace:Raycast(root.Position, plan.direction * plan.distance, parameters) then
        diveStatus.Text = "Auto Dive: ON / obstructed"; return false
    end
    local held = {bridge = bridge, key = key, releaseAt = now + 0.04}
    diveHeld = held
    local ok, err = pcall(function()
        if api.Config.DiveAutoAim then
            -- The native Dynamic Dives option would override this yaw using held movement.
            -- Suppress it only during this input pulse, then restore its previous value.
            local menu = player.PlayerGui:FindFirstChild("Menu")
            local main = menu and menu:FindFirstChild("MainFrame", true)
            local settings = main and main:FindFirstChild("Settings")
            local dynamic = settings and settings:FindFirstChild("DynamicDives")
            if dynamic and dynamic:GetAttribute("Active") == true then
                held.dynamic, held.originalDynamic = dynamic, true
                dynamic:SetAttribute("Active", false)
            end
            root.CFrame = CFrame.lookAt(root.Position, root.Position + plan.direction)
        end
        bridge:Fire("tasto", key, true)
    end)
    if not ok then
        releaseDiveInput()
        api.DiveMetrics.Errors = api.DiveMetrics.Errors + 1
        diveNextAttempt = now + 2
        recordDive("auto_dive_input_error", {error = tostring(err)})
        diveStatus.Text = "Auto Dive: ON / input error"
        return false
    end
    api.DiveBusyUntil = now + geometry.cooldown
    diveNextAttempt, receiveManualUntil = api.DiveBusyUntil, math.max(receiveManualUntil, api.DiveBusyUntil)
    diveAttempts[ball] = {eventN = plan.eventN, eventTime = plan.eventTime}
    local attempt = {time = now, ball = ball, eventN = plan.eventN, eta = plan.eta, contact = plan.contact,
        responseLead = plan.responseLead, predictedAcrossNet = plan.predictedAcrossNet}
    divePending[attempt] = true
    api.LastDive = attempt
    api.DiveMetrics.Attempts = api.DiveMetrics.Attempts + 1
    if plan.predictedAcrossNet then api.DiveMetrics.EarlyNetAttempts = api.DiveMetrics.EarlyNetAttempts + 1 end
    recordDive("auto_dive_attempt", attempt)
    diveStatus.Text = string.format("Auto Dive: ON / attempted ~%.0fms", plan.eta * 1000)
    task.delay(0.04, function()
        if diveHeld == held and not releaseDiveInput() then api.SetAutoDive(false) end
    end)
    return true
end

local function updateAutoDive(dt)
    local now = os.clock()
    if diveHeld and now >= diveHeld.releaseAt and not releaseDiveInput() then api.SetAutoDive(false); return end
    for attempt in pairs(divePending) do
        local ball = attempt.ball
        local owner = ball:GetAttribute("NG_UltimoTocco") or ball:GetAttribute("NG_ToccoUltimo")
        local kind = tostring(ball:GetAttribute("NG_UltimoTipo") or ""):lower()
        if now - attempt.time <= 2 and owner == player.UserId and (kind:find("dive", 1, true) or kind:find("tuff", 1, true)) then
            api.DiveMetrics.Confirmed = api.DiveMetrics.Confirmed + 1
            attempt.status = "confirmed"
            recordDive("auto_dive_confirmed", attempt)
            divePending[attempt] = nil
        elseif now - attempt.time > 2 then
            api.DiveMetrics.Unconfirmed = api.DiveMetrics.Unconfirmed + 1
            attempt.status = "unconfirmed"
            recordDive("auto_dive_unconfirmed", attempt)
            divePending[attempt] = nil
        end
    end
    if not alive or not api.Config.AutoDive then return end
    if api.PauseForAttack and api.PauseForAttack() then releaseDiveInput(); diveStatus.Text = "Auto Dive: waiting for attack to finish"; return end
    if receiveFocused then local _, blocked = receiveInputPoint(); if blocked then diveStatus.Text = "Auto Dive: interacting with UI"; return end end
    if player.Character ~= diveCharacter then
        diveCharacter = player.Character
        diveAttempts = setmetatable({}, {__mode = "k"})
        diveNextAttempt, api.DiveBusyUntil = now + 0.2, 0
    end
    diveElapsed = diveElapsed + (dt or 1 / 60)
    if api.Config.DiveEveryHeartbeat ~= true and diveElapsed < 1 / math.clamp(api.Config.DiveUpdateHz, 1, 60) then return end
    diveElapsed = 0
    api.DiveMetrics.Checks = api.DiveMetrics.Checks + 1
    if now - divePingAt >= 0.25 then
        divePingAt = now
        local ok, ping = pcall(function() return player:GetNetworkPing() end)
        if ok and type(ping) == "number" then divePing = math.clamp(ping, 0, 0.2) end
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then diveStatus.Text = "Auto Dive: ON / waiting for character"; return end
    local blocked = root:FindFirstChildOfClass("BodyVelocity") ~= nil
    for _, name in ipairs({"NG_StunLocale", "NG_BloccoComandi", "NG_MinigiocoBattuta"}) do
        local untilTime = tonumber(player:GetAttribute(name))
        if untilTime and now < untilTime then blocked = true end
    end
    local lastAction = tonumber(player:GetAttribute("NG_ColpoLocale"))
    if lastAction and now - lastAction < 0.15 then blocked = true end
    local net = api.ServeViewerNet(root.Position, netCache)
    local context = {enabled = api.Config.AutoDive, focused = receiveFocused, chat = UIS:GetFocusedTextBox() ~= nil,
        menu = GuiService.MenuIsOpen, alive = humanoid.Health > 0, sitting = humanoid.Sit, anchored = root.Anchored,
        grounded = humanoid.FloorMaterial ~= Enum.Material.Air and player:GetAttribute("NG_InAria") ~= true,
        court = net ~= nil, inMatch = player:GetAttribute("NG_InMatch"), serving = player:GetAttribute("NG_PuoBattere") == true,
        commandsBlocked = blocked, manualUntil = receiveManualUntil,
        manual = api.Config.ReceiveManualPause > 0 and (UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UIS:IsKeyDown(Enum.KeyCode.Space)),
        pending = receiveMouse ~= nil or diveHeld ~= nil,
        nextAttempt = math.max(diveNextAttempt, receiveNextAttempt), minSpeed = api.Config.DiveMinSpeed,
        horizon = api.Config.DiveHorizon, autoAim = api.Config.DiveAutoAim, facing = root.CFrame.LookVector,
        rootPosition = root.Position, motion = root.AssemblyLinearVelocity,
        netCenter = net and net.center, netNormal = net and net.normal,
        netAxis = net and net.axis, netHalfWidth = net and net.halfWidth,
        netTopY = net and net.part.Position.Y + net.part.Size.Y * 0.5,
        ownSide = net and (flat(root.Position - net.center):Dot(net.normal) > 0 and 1 or -1),
        responseLead = api.DiveResponseLead(divePing, dt)}
    api.DiveTiming = {pingSeconds = divePing, responseLead = context.responseLead, frameSeconds = dt}
    local area, geometry = api.GetReceiveArea(), diveGeometry(root, humanoid)
    local cache = workspace:FindFirstChild("BallCache")
    local best, selected, reason, receivePreferred = nil, nil, "waiting for incoming hit", false
    for _, ball in ipairs(cache and cache:GetChildren() or {}) do
        local position, velocity, spin = ball:FindFirstChild("Position"), ball:FindFirstChild("Velocity"), ball:FindFirstChild("Spin")
        local pos = position and position:IsA("Vector3Value") and position.Value
        local vel = velocity and velocity:IsA("Vector3Value") and velocity.Value
        local sample = {active = ball.Parent ~= nil and ball.Name == "Ball" and not ball:GetAttribute("DeadAt") and not ball:GetAttribute("Settling"),
            ownTouch = (ball:GetAttribute("NG_UltimoTocco") or ball:GetAttribute("NG_ToccoUltimo")) == player.UserId
                or ball:GetAttribute("NG_Battuta") == true and ball:GetAttribute("NG_CreatoreId") == player.UserId,
            ownHalf = net ~= nil and pos ~= nil and flat(pos - net.center):Dot(net.normal) * flat(root.Position - net.center):Dot(net.normal) > 0,
            sameCourt = net ~= nil and pos ~= nil and api.TargetNearNet(pos, net, netCache),
            position = pos, velocity = vel, kind = ball:GetAttribute("NG_UltimoTipo"),
            eventN = ball:GetAttribute("NG_EvN"), eventTime = ball:GetAttribute("NG_EvT"),
            floor = tonumber(workspace:GetAttribute("NG_QuotaSuolo")) or tuning.QUOTA_CAMPO or 0.408,
            spin = spin and spin:IsA("Vector3Value") and spin.Value or Vector3.zero,
            gravity = ball:GetAttribute("NG_GravFattore"), side = ball:GetAttribute("NG_SpinOltreRete"),
            rampFraction = ball:GetAttribute("NG_SpinRampaFraz"), rampExponent = ball:GetAttribute("NG_SpinRampaEsp"), rampMin = ball:GetAttribute("NG_SpinRampaMin")}
        local plan, why = api.PlanAutoDive(context, sample, area, geometry, diveAttempts[ball], now)
        if plan and api.CheckIncomingBounds then
            local allowed, boundsReason, decision = api.CheckIncomingBounds(ball, sample, net, root.Position)
            if not allowed then plan, why = nil, boundsReason; api.NoteOutSkip("dive", decision) end
        end
        api.LastDiveDecision = {time = now, reason = why, eventN = sample.eventN, velocityY = vel and vel.Y,
            ownHalf = sample.ownHalf, eta = plan and plan.eta, responseLead = context.responseLead}
        if why == "receive can reach" then receivePreferred = true end
        reason = why
        if plan and (not best or plan.eta < best.eta) then best, selected = plan, ball end
    end
    if receivePreferred then diveStatus.Text = "Auto Dive: ON / receive can reach"
    elseif best then dispatchDive(root, best, geometry, selected, now)
    else diveStatus.Text = "Auto Dive: ON / " .. reason end
end

connect(RunService.Heartbeat, function(dt)
    local ok, err = pcall(updateAutoDive, dt)
    if not ok then
        api.DiveMetrics.Errors = api.DiveMetrics.Errors + 1
        api.SetAutoDive(false)
        diveStatus.Text = "Auto Dive: error / see menu"
        reportStartupError("Auto Dive", err, true)
    end
end)
connect(player.CharacterRemoving, function()
    releaseDiveInput()
    api.DiveBusyUntil = 0
    diveAttempts = setmetatable({}, {__mode = "k"})
end)

local elapsed=0
connect(RunService.Heartbeat,function(dt)
 elapsed+=dt; if elapsed>=1 then elapsed=0; refreshNets() end
 api.Status.receive,api.Status.dive=receiveStatus.Text,diveStatus.Text
end)
connect(player.CharacterAdded,function(character) api.ResetAutoReceiveCharacter(character) end)
connect(player.CharacterRemoving,function() api.ResetAutoReceiveCharacter(nil) end)
api.Startup.Ready=true
end)
if not ok then
 api.Startup.Error=tostring(message); api.Status.receive="Unavailable: "..tostring(message); api.Status.dive=api.Status.receive
 if api.SetAutoReceive then api.SetAutoReceive(false) end
 if api.SetAutoDive then api.SetAutoDive(false) end
end
-- Unavailable features stay visibly OFF; a failed startup cannot be armed.
local receive,dive=api.SetAutoReceive,api.SetAutoDive
function api.SetAutoReceive(enabled)
 if not api.Startup.Ready or not receive then return false end
 return receive(enabled)
end
function api.SetAutoDive(enabled)
 if not api.Startup.Ready or not dive then return false end
 return dive(enabled)
end
return api
end

-- One receive/dive engine per client, shared by menu owners.
local function createDefenseService(host)
    local env, owner = host.env, host.owner
    local service = env.VRSDefenseService
    if not service then
        service = {Owners = {}, Engine = nil, Owned = false, WantedReceive = false, WantedDive = false}
        env.VRSDefenseService = service
        function service.Refresh()
            local friend = env.VRSFriendAssist
            if not (friend and friend.Startup and friend.Startup.Ready and friend.SetAutoReceive and friend.SetAutoDive) then friend = nil end
            if friend and service.Engine ~= friend then
                local receive = service.WantedReceive or friend.Config.AutoReceive
                local dive = service.WantedDive or friend.Config.AutoDive
                if service.Engine and service.Owned then service.Engine.Destroy() end
                service.Engine, service.Owned = friend, false
                friend.SetAutoReceive(receive); friend.SetAutoDive(dive)
            elseif not service.Engine or not service.Owned and service.Engine ~= friend then
                service.Engine, service.Owned = host.createEngine(), true
                service.Engine.SetAutoReceive(service.WantedReceive)
                service.Engine.SetAutoDive(service.WantedDive)
            end
            local engine = service.Engine
            engine.PauseForAttack = function()
                for active in pairs(service.Owners) do
                    if active.Target or active.Aiming or active.FullAssist and active.FullAssist.Play then return true end
                end
                return false
            end
            service.WantedReceive, service.WantedDive = engine.Config.AutoReceive, engine.Config.AutoDive
            if not service.Owned then
                engine.Status = engine.Status or {}
                engine.Status.receive = "Auto Receive: " .. (service.WantedReceive and "ON" or "OFF") .. " / friend controller"
                engine.Status.dive = "Auto Dive: " .. (service.WantedDive and "ON" or "OFF") .. " / friend controller"
            end
            for active in pairs(service.Owners) do
                active.Config.AutoReceive, active.Config.AutoDive = service.WantedReceive, service.WantedDive
                active.DefenseStatus = engine.Status
                active.ReceiveMetrics, active.DiveMetrics = engine.ReceiveMetrics, engine.DiveMetrics
            end
            return engine
        end
        service.Connection = host.heartbeat:Connect(function()
            local ok, message = pcall(service.Refresh)
            service.LastError = not ok and tostring(message) or nil
        end)
    end
    service.Owners[owner] = true
    local lease, closed = {}, false
    function lease.Engine() if closed then return nil end; return service.Refresh() end
    function lease.SetReceive(enabled)
        local engine = lease.Engine(); if not engine then return false end
        engine.SetAutoReceive(enabled); service.Refresh(); return engine.Config.AutoReceive
    end
    function lease.SetDive(enabled)
        local engine = lease.Engine(); if not engine then return false end
        engine.SetAutoDive(enabled); service.Refresh(); return engine.Config.AutoDive
    end
    function lease.Destroy()
        if closed then return end
        closed = true; service.Owners[owner] = nil
        if next(service.Owners) == nil then
            service.Connection:Disconnect()
            if service.Owned and service.Engine then service.Engine.Destroy() end
            if not service.Owned and service.Engine then service.Engine.PauseForAttack = nil end
            if env.VRSDefenseService == service then env.VRSDefenseService = nil end
        end
    end
    service.Refresh()
    return lease
end

-- DEFENSE_COMPONENT_END












-- CONTROL_CENTER_COMPONENT_BEGIN
-- Generated by scripts/sync-vrs-control-center.mjs.
-- Shared tabbed control center. Settings and profiles contain data only.
local function createControlCenter(host)
    local ui = {Tabs = {}, Controls = {}, Keybinds = {}, Visible = true, Alive = true}
    local UIS, RunService = host.uis, host.runService
    local make, connect, env = host.make, host.connect, host.env
    host.gui.DisplayOrder = 150
    local function keyLabel(key)
        return ({Zero="0",One="1",Two="2",Three="3",Four="4",Five="5",Six="6",Seven="7",Eight="8",Nine="9"})[key] or key
    end
    local colors = {base = Color3.fromRGB(16, 18, 24), side = Color3.fromRGB(20, 23, 30),
        card = Color3.fromRGB(26, 30, 39), edge = Color3.fromRGB(43, 49, 62),
        text = Color3.fromRGB(234, 239, 247), muted = Color3.fromRGB(139, 151, 171),
        accent = Color3.fromRGB(95, 222, 194), off = Color3.fromRGB(56, 64, 81), control = Color3.fromRGB(35, 42, 54)}
    local function corner(object, radius) make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object) end
    local function label(parent, value, position, size, textSize, color)
        return make("TextLabel", {BackgroundTransparency = 1, Position = position, Size = size,
            Text = value, TextSize = textSize or 13, Font = Enum.Font.Gotham,
            TextColor3 = color or colors.text, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center}, parent)
    end
    local function button(parent, value, position, size)
        local object = make("TextButton", {Position = position, Size = size, Text = value,
            BackgroundColor3 = colors.control, BorderSizePixel = 0, TextColor3 = colors.text,
            Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = true}, parent)
        corner(object, 6); return object
    end
    local window = make("Frame", {Name = "ControlCenter", Size = UDim2.fromOffset(780, 560),
        Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = colors.base, BorderSizePixel = 0, Active = true}, host.gui)
    ui.Root = window; corner(window, 12)
    make("UIStroke", {Color = colors.edge, Thickness = 1}, window)
    local scale = make("UIScale", {Scale = 1}, window)
    local side = make("Frame", {Size = UDim2.new(0, 172, 1, 0), BackgroundColor3 = colors.side,
        BorderSizePixel = 0}, window); corner(side, 12)
    label(side, "VRS", UDim2.fromOffset(22, 20), UDim2.fromOffset(120, 26), 24, colors.accent).Font = Enum.Font.GothamBold
    label(side, "CONTROL CENTER", UDim2.fromOffset(23, 48), UDim2.fromOffset(145, 18), 9, colors.muted)
    local roleSwitch = button(side, host.role == "setting" and "SETTER  ↔" or "SPIKER  ↔", UDim2.fromOffset(14, 80), UDim2.fromOffset(144, 25))
    roleSwitch.TextSize = 10
    connect(roleSwitch.Activated, function()
        for _, other in pairs(env.VRSControlCenters or {}) do if other ~= ui and other.Alive then other.Focus(); return end end
    end)
    local hint = label(side, "RightShift  /  hide menu", UDim2.new(0, 18, 1, -65), UDim2.fromOffset(146, 32), 10, colors.muted)
    hint.TextWrapped = true
    label(side, "v" .. host.owner.Version, UDim2.new(0, 18, 1, -29), UDim2.fromOffset(140, 18), 10, colors.muted)
    local header = make("Frame", {Position = UDim2.fromOffset(172, 0), Size = UDim2.new(1, -172, 0, 85),
        BackgroundTransparency = 1, Active = true}, window)
    local heading = label(header, "Overview", UDim2.fromOffset(24, 19), UDim2.new(1, -130, 0, 25), 22)
    heading.Font = Enum.Font.GothamBold
    local subheading = label(header, "Live status and essential controls", UDim2.fromOffset(25, 49), UDim2.new(1, -70, 0, 20), 11, colors.muted)
    local hide = button(header, "–", UDim2.new(1, -78, 0, 19), UDim2.fromOffset(28, 28))
    local close = button(header, "×", UDim2.new(1, -44, 0, 19), UDim2.fromOffset(28, 28))
    connect(hide.Activated, function() ui.SetVisible(false) end)
    connect(close.Activated, host.unload)
    local message = label(window, "", UDim2.new(0, 196, 1, -26), UDim2.new(1, -218, 0, 19), 10, colors.accent)
    local function report(text, bad) message.Text = text; message.TextColor3 = bad and Color3.fromRGB(255, 172, 143) or colors.accent end
    function ui.SetVisible(visible)
        ui.Visible = visible == true; window.Visible = ui.Visible
        if not ui.Visible and env.VRSKeyCapture == ui then
            if ui.KeyButtons and ui.Capturing then ui.KeyButtons[ui.Capturing].Text = keyLabel(ui.Keybinds[ui.Capturing]) end
            env.VRSKeyCapture = nil; ui.Capturing = nil
        end
    end
    local pages = {
        {"Overview", "Live status and essential controls"}, {"Defense", "Receive and dive assistance"},
        {"Visuals", "Court overlays and trajectory displays"}, {"Keybinds", "Click a binding, then press a key · Esc cancels"},
        {"Profiles", "Save and restore your preferred settings"},
    }
    local orderedTabs = {}
    for index, spec in ipairs(pages) do
        local tab = {Name = spec[1], Subtitle = spec[2], Order = 0}
        tab.Button = button(side, spec[1], UDim2.fromOffset(14, 120 + (index - 1) * 43), UDim2.fromOffset(144, 35))
        tab.Button.TextXAlignment = Enum.TextXAlignment.Left
        make("UIPadding", {PaddingLeft = UDim.new(0, 12)}, tab.Button)
        tab.Page = make("ScrollingFrame", {Name = spec[1], Position = UDim2.fromOffset(196, 90),
            Size = UDim2.new(1, -220, 1, -128), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = colors.edge, CanvasSize = UDim2.new(), ClipsDescendants = true,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false}, window)
        make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, tab.Page)
        make("UIPadding", {PaddingBottom = UDim.new(0, 6), PaddingRight = UDim.new(0, 5)}, tab.Page)
        ui.Tabs[spec[1]] = tab; orderedTabs[#orderedTabs + 1] = tab
        connect(tab.Button.Activated, function() ui.SelectTab(spec[1]) end)
    end
    function ui.SelectTab(name)
        local tab = ui.Tabs[name]; if not tab then return false end
        ui.ActiveTab = name; heading.Text, subheading.Text = name, tab.Subtitle
        for _, item in ipairs(orderedTabs) do
            item.Page.Visible = item == tab
            item.Button.BackgroundColor3 = item == tab and colors.card or colors.side
            item.Button.TextColor3 = item == tab and colors.accent or colors.muted
        end
        return true
    end
    ui.SelectTab("Overview")
    local function row(tabName, title, description, height, reserve)
        local tab = assert(ui.Tabs[tabName]); tab.Order += 1
        local card = make("Frame", {Name = title, Size = UDim2.new(1, 0, 0, height or 72),
            BackgroundColor3 = colors.card, BorderSizePixel = 0, LayoutOrder = tab.Order}, tab.Page)
        corner(card, 8)
        label(card, title, UDim2.fromOffset(16, 10), UDim2.new(1, -(reserve or 100), 0, 21), 12).Font = Enum.Font.GothamMedium
        if description and description ~= "" then
            local detail = label(card, description, UDim2.fromOffset(16, 33), UDim2.new(1, -(reserve or 104), 0, 28), 10, colors.muted)
            detail.TextWrapped = true; detail.TextYAlignment = Enum.TextYAlignment.Top
        end
        return card
    end
    local schema, defaults, refreshers = {}, {}, {}
    local function register(spec)
        assert(not schema[spec.id], "Duplicate setting: " .. spec.id)
        schema[spec.id] = spec; defaults[spec.id] = spec.default
        if defaults[spec.id] == nil then defaults[spec.id] = spec.get() end
    end
    function ui.SetValue(id, value)
        local spec = schema[id]; if not spec then return false, "Unknown setting" end
        if spec.kind == "toggle" then
            if type(value) ~= "boolean" then return false, "Expected a toggle" end
        elseif spec.kind == "slider" then
            if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return false, "Invalid number" end
            value = math.clamp(value, spec.min, spec.max)
            value = math.clamp(spec.min + math.floor((value - spec.min) / spec.step + 0.5) * spec.step, spec.min, spec.max)
        elseif spec.kind == "number" then
            if type(value) ~= "number" or value ~= value or value < spec.min or value > spec.max then
                return false, string.format("Enter a number from %g to %g", spec.min, spec.max)
            end
        elseif spec.kind == "choice" then
            if not table.find(spec.options, value) then return false, "Invalid option" end
        end
        local ok, errorMessage = pcall(spec.set, value)
        if not ok then report(tostring(errorMessage), true); return false, tostring(errorMessage) end
        for _, refresh in ipairs(refreshers) do refresh() end
        return true
    end
    for _, spec in ipairs(host.controls) do
        if spec.kind == "status" then
            local card = row(spec.tab, spec.title, "", 76)
            local detail = label(card, "", UDim2.fromOffset(16, 33), UDim2.new(1, -32, 0, 33), 11, colors.muted)
            detail.TextWrapped = true
            refreshers[#refreshers + 1] = function() detail.Text = tostring(spec.get() or "Waiting for game state") end
        elseif spec.kind == "action" then
            local width = spec.actionText and #spec.actionText > 10 and 122 or 73
            local card = row(spec.tab, spec.title, spec.description, 72, width + 48)
            local action = button(card, spec.actionText or "Run", UDim2.new(1, -width - 16, 0, 22), UDim2.fromOffset(width, 29))
            connect(action.Activated, function() local ok, err = pcall(spec.run); if not ok then report(tostring(err), true) end end)
        else
            register(spec)
            local card = row(spec.tab, spec.title, spec.description, spec.kind == "slider" and 88 or 72)
            if spec.visible then refreshers[#refreshers + 1] = function() card.Visible = spec.visible() == true end end
            if spec.kind == "toggle" then
                local toggle = button(card, "", UDim2.new(1, -64, 0, 25), UDim2.fromOffset(46, 24))
                corner(toggle, 12)
                local dot = make("Frame", {Size = UDim2.fromOffset(16, 16), BackgroundColor3 = colors.text,
                    BorderSizePixel = 0}, toggle); corner(dot, 8)
                refreshers[#refreshers + 1] = function()
                    local active = spec.get() == true
                    toggle.BackgroundColor3 = active and colors.accent or colors.off
                    dot.Position = UDim2.fromOffset(active and 26 or 4, 4)
                    dot.BackgroundColor3 = active and colors.base or colors.text
                end
                connect(toggle.Activated, function() ui.SetValue(spec.id, not spec.get()) end)
                ui.Controls[spec.id] = toggle
            elseif spec.kind == "number" then
                local input = make("TextBox", {Name = spec.id, Position = UDim2.new(1, -100, 0, 23),
                    Size = UDim2.fromOffset(84, 28), BackgroundColor3 = colors.control, BorderSizePixel = 0,
                    Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = colors.accent,
                    Text = tostring(spec.get()), ClearTextOnFocus = false}, card)
                corner(input, 6)
                refreshers[#refreshers + 1] = function()
                    if UIS:GetFocusedTextBox() ~= input then input.Text = tostring(spec.get()) end
                end
                connect(input.FocusLost, function()
                    local ok, err = ui.SetValue(spec.id, tonumber(input.Text))
                    input.Text = tostring(spec.get())
                    if not ok then report(tostring(err), true) end
                end)
                ui.Controls[spec.id] = input
            elseif spec.kind == "slider" then
                local valueText = label(card, "", UDim2.new(1, -84, 0, 11), UDim2.fromOffset(68, 20), 12, colors.accent)
                valueText.TextXAlignment = Enum.TextXAlignment.Right
                local bar = button(card, "", UDim2.fromOffset(16, 62), UDim2.new(1, -32, 0, 18))
                bar.BackgroundTransparency = 1
                local track = make("Frame", {BackgroundColor3 = colors.off, BorderSizePixel = 0,
                    Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 6)}, bar); corner(track, 3)
                local fill = make("Frame", {BackgroundColor3 = colors.accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1)}, track)
                corner(fill, 3)
                local knob = make("Frame", {BackgroundColor3 = colors.text, BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12)}, track); corner(knob, 6)
                refreshers[#refreshers + 1] = function()
                    local value = tonumber(spec.get()) or spec.min
                    local fraction = math.clamp((value - spec.min) / (spec.max - spec.min), 0, 1)
                    fill.Size, knob.Position = UDim2.fromScale(fraction, 1), UDim2.fromScale(fraction, 0.5)
                    valueText.Text = string.format(spec.format or "%.2f", value) .. (spec.suffix or "")
                end
                local function move(x)
                    if bar.AbsoluteSize.X <= 0 then return end
                    ui.SetValue(spec.id, spec.min + math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1) * (spec.max - spec.min))
                end
                connect(bar.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        ui.Slider = {move = move, input = input}; move(input.Position.X)
                    end
                end)
                ui.Controls[spec.id] = bar
            else
                local choose = button(card, "", UDim2.new(1, -103, 0, 23), UDim2.fromOffset(87, 28))
                refreshers[#refreshers + 1] = function() choose.Text = tostring(spec.get()) end
                connect(choose.Activated, function()
                    local index = table.find(spec.options, spec.get()) or 0
                    ui.SetValue(spec.id, spec.options[index % #spec.options + 1])
                end)
                ui.Controls[spec.id] = choose
            end
        end
    end
    local keyDefaults, keySpecs, keyButtons = {}, {}, {}
    ui.KeyButtons = keyButtons
    for _, binding in ipairs(host.bindings) do keyDefaults[binding.id] = binding.key; ui.Keybinds[binding.id] = binding.key; keySpecs[binding.id] = binding end
    local function validKey(name)
        if type(name) ~= "string" or name == "Unknown" or name == "Escape" then return false end
        local ok, item = pcall(function() return Enum.KeyCode[name] end)
        return ok and item ~= nil
    end
    function ui.SetBinding(id, name)
        if not keySpecs[id] or not validKey(name) then return false, "Choose a keyboard key" end
        for other, key in pairs(ui.Keybinds) do if other ~= id and key == name then return false, "That key is already assigned" end end
        ui.Keybinds[id] = name
        host.owner.Keybinds = ui.Keybinds
        if host.bindingsChanged then host.bindingsChanged(ui.Keybinds) end
        if keyButtons[id] then keyButtons[id].Text = keyLabel(name) end
        hint.Text = ui.Keybinds.HideUI .. "  /  hide menu"
        return true
    end
    for _, binding in ipairs(host.bindings) do
        local card = row("Keybinds", binding.title, binding.description, 72)
        local key = button(card, keyLabel(binding.key), UDim2.new(1, -116, 0, 23), UDim2.fromOffset(100, 29))
        keyButtons[binding.id] = key
        connect(key.Activated, function()
            if env.VRSKeyCapture and env.VRSKeyCapture ~= ui then return end
            if ui.Capturing and keyButtons[ui.Capturing] then keyButtons[ui.Capturing].Text = keyLabel(ui.Keybinds[ui.Capturing]) end
            env.VRSKeyCapture, ui.Capturing = ui, binding.id; key.Text = "Press a key…"
        end)
    end
    host.owner.Keybinds = ui.Keybinds
    local sessionKey = tostring(host.userId) .. ":" .. host.role
    env.VRSAssistProfiles = env.VRSAssistProfiles or {}
    local store = env.VRSAssistProfiles[sessionKey] or {profiles = {}}
    env.VRSAssistProfiles[sessionKey] = store
    local directory = "VRSAssist/" .. tostring(host.userId) .. "/" .. host.role
    local disk = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" and type(makefolder) == "function"
    if disk then
        local ok = pcall(function()
            for _, folder in ipairs({"VRSAssist", "VRSAssist/" .. tostring(host.userId), directory}) do
                if type(isfolder) ~= "function" or not isfolder(folder) then makefolder(folder) end
            end
        end)
        disk = ok
    end
    function ui.Snapshot()
        local snapshot = {version = 1, role = host.role, settings = {}, keys = {}}
        for id, spec in pairs(schema) do snapshot.settings[id] = spec.get() end
        for id, key in pairs(ui.Keybinds) do snapshot.keys[id] = key end
        return snapshot
    end
    function ui.Apply(snapshot)
        if type(snapshot) ~= "table" or snapshot.version ~= 1 or snapshot.role ~= host.role
            or type(snapshot.settings) ~= "table" or type(snapshot.keys) ~= "table" then return false, "Incompatible profile" end
        -- Validate every entry before applying any setting.
        for id, value in pairs(snapshot.settings) do
            local spec = schema[id]
            if not spec then return false, "Unknown profile setting" end
            if spec.kind == "toggle" and type(value) ~= "boolean" then return false, "Invalid toggle" end
            if spec.kind == "slider" and (type(value) ~= "number" or value ~= value or math.abs(value) == math.huge) then return false, "Invalid slider" end
            if spec.kind == "number" and (type(value) ~= "number" or value ~= value or value < spec.min or value > spec.max) then return false, "Invalid number" end
            if spec.kind == "choice" and not table.find(spec.options, value) then return false, "Invalid choice" end
        end
        local proposed, used = {}, {}
        for id, old in pairs(ui.Keybinds) do
            local key = snapshot.keys[id] or old
            if not validKey(key) or used[key] then return false, "Invalid or duplicate keybind" end
            proposed[id], used[key] = key, true
        end
        for id in pairs(snapshot.keys) do if not keySpecs[id] then return false, "Unknown keybind" end end
        local before = ui.Snapshot()
        for id, value in pairs(snapshot.settings) do
            local ok, err = ui.SetValue(id, value)
            if not ok then
                for restoreId, restore in pairs(before.settings) do pcall(schema[restoreId].set, restore) end
                return false, err
            end
        end
        ui.Keybinds = proposed; host.owner.Keybinds = proposed
        if host.bindingsChanged then host.bindingsChanged(proposed) end
        for id, key in pairs(proposed) do keyButtons[id].Text = keyLabel(key) end
        hint.Text = proposed.HideUI .. "  /  hide menu"
        return true
    end
    local function profileName(name) return type(name) == "string" and #name > 0 and #name <= 32 and name:match("^[%w_-]+$") ~= nil end
    local function write(name, snapshot)
        store.profiles[name] = snapshot
        if disk then
            local ok = pcall(function() writefile(directory .. "/" .. name .. ".json", host.http:JSONEncode(snapshot)) end)
            if not ok then disk = false; report("Saved for this session; file storage unavailable", true) end
        end
    end
    local function read(name)
        if disk then
            local ok, result = pcall(function()
                local file = directory .. "/" .. name .. ".json"
                if not isfile(file) then return nil end
                local value = readfile(file); if #value > 32768 then return nil end
                return host.http:JSONDecode(value)
            end)
            if ok and result then return result end
        end
        return store.profiles[name]
    end
    function ui.SaveProfile(name)
        if not profileName(name) or name == "last" then return false, "Use 1–32 letters, numbers, _ or -" end
        local snapshot = ui.Snapshot(); write(name, snapshot); write("last", snapshot); store.last = snapshot
        return true
    end
    function ui.LoadProfile(name)
        if not profileName(name) then return false, "Invalid name" end
        local snapshot = read(name); if not snapshot then return false, "Profile not found" end
        local ok, err = ui.Apply(snapshot)
        if ok then store.last = ui.Snapshot(); write("last", store.last) end
        return ok, err
    end
    function ui.DeleteProfile(name)
        if not profileName(name) or name == "last" then return false, "Invalid name" end
        if disk and type(delfile) ~= "function" then return false, "File deletion unavailable" end
        if disk then
            local ok = pcall(function() local file = directory .. "/" .. name .. ".json"; if isfile(file) then delfile(file) end end)
            if not ok then return false, "Could not delete profile" end
        end
        store.profiles[name] = nil; ui.NextProfileScan = 0; ui.DiskProfiles = nil; return true
    end
    function ui.Reset()
        return ui.Apply({version = 1, role = host.role, settings = defaults, keys = keyDefaults})
    end
    local profileCard = row("Profiles", "Your configurations", "Restores toggles, sliders and keybinds. Enabled assists resume when loaded.", 150)
    local name = make("TextBox", {Position = UDim2.fromOffset(16, 80), Size = UDim2.new(1, -32, 0, 28),
        BackgroundColor3 = colors.base, BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = colors.text, PlaceholderText = "Profile name", Text = "Default", ClearTextOnFocus = false}, profileCard)
    corner(name, 5)
    for index, record in ipairs({{"Save", ui.SaveProfile}, {"Load", ui.LoadProfile}, {"Delete", ui.DeleteProfile}}) do
        local action = button(profileCard, record[1], UDim2.fromOffset(16 + (index - 1) * 95, 116), UDim2.fromOffset(87, 26))
        connect(action.Activated, function()
            local ok, err = record[2](name.Text)
            report(ok and (record[1] .. ": " .. name.Text) or tostring(err), not ok)
        end)
    end
    local available = row("Profiles", "Available profiles", "", 72)
    local list = label(available, "", UDim2.fromOffset(16, 34), UDim2.new(1, -32, 0, 25), 10, colors.muted)
    list.TextWrapped = true
    local function refreshProfiles()
        local names, seen = {}, {}
        for key in pairs(store.profiles) do if key ~= "last" then seen[key] = true end end
        if disk and ui.ActiveTab == "Profiles" and type(listfiles) == "function" and os.clock() >= (ui.NextProfileScan or 0) then
            ui.NextProfileScan = os.clock() + 2
            local ok, files = pcall(listfiles, directory)
            ui.DiskProfiles = {}
            if ok then for _, file in ipairs(files) do local key = file:match("([^/\\]+)%.json$"); if key and key ~= "last" then ui.DiskProfiles[key] = true end end end
        end
        for key in pairs(ui.DiskProfiles or {}) do seen[key] = true end
        for key in pairs(seen) do names[#names + 1] = key end; table.sort(names)
        list.Text = #names > 0 and table.concat(names, "  ·  ") or "No saved profiles yet"
    end
    refreshers[#refreshers + 1] = refreshProfiles
    local resetCard = row("Profiles", "Reset settings", "Restore this script's defaults and keybinds.", 72)
    local reset = button(resetCard, "Reset", UDim2.new(1, -89, 0, 22), UDim2.fromOffset(73, 29))
    connect(reset.Activated, function() ui.Reset(); report("Defaults restored") end)
    local storage = row("Profiles", "Configuration storage", "", 72)
    local storageText = label(storage, "", UDim2.fromOffset(16, 34), UDim2.new(1, -32, 0, 25), 10, colors.muted)
    storageText.TextWrapped = true
    refreshers[#refreshers + 1] = function()
        storageText.Text = disk and "Saved on this device. Profiles persist across restarts."
            or "Session only. File storage is unavailable on this client."
    end
    local drag
    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = {position = window.Position, pointer = input.Position, input = input}
        end
    end)
    connect(UIS.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if ui.Slider then ui.Slider.move(input.Position.X) end
            if drag then
                local delta = input.Position - drag.pointer
                local camera = workspace.CurrentCamera
                local size = camera and camera.ViewportSize
                local x = drag.position.X.Offset + delta.X
                local y = drag.position.Y.Offset + delta.Y
                if size then x = math.clamp(x, -size.X * 0.5 + 100, size.X * 0.5 - 100); y = math.clamp(y, -size.Y * 0.5 + 35, size.Y * 0.5 - 35) end
                window.Position = UDim2.new(0.5, x, 0.5, y)
            end
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag, ui.Slider = nil, nil end
    end)
    connect(UIS.WindowFocusReleased, function() drag, ui.Slider = nil, nil end)
    connect(UIS.InputBegan, function(input, processed)
        if not ui.Alive or UIS:GetFocusedTextBox() or host.guiService.MenuIsOpen then return end
        if env.VRSKeyCapture == ui and ui.Capturing then
            env.VRSLastCapturedInput = input
            env.VRSLastCapturedAt = os.clock()
            local id = ui.Capturing
            if input.KeyCode == Enum.KeyCode.Unknown then return end
            if input.KeyCode == Enum.KeyCode.Escape then
                keyButtons[id].Text = keyLabel(ui.Keybinds[id])
            else
                local ok, err = ui.SetBinding(id, input.KeyCode.Name)
                if not ok then report(err, true); return end
            end
            ui.Capturing, env.VRSKeyCapture = nil, nil; return
        end
        if env.VRSKeyCapture or env.VRSLastCapturedInput == input and os.clock() - (env.VRSLastCapturedAt or 0) < 0.05 or processed then return end
        for id, key in pairs(ui.Keybinds) do
            if input.KeyCode == Enum.KeyCode[key] then
                if id ~= "ToggleReceive" and id ~= "ToggleDive" and env.VRSActiveControlCenter ~= ui then return end
                if id == "ToggleReceive" or id == "ToggleDive" then
                    local previous = env.VRSDefenseKeyInput
                    if previous and previous.input == input and os.clock() - previous.at < 0.03 then return end
                    env.VRSDefenseKeyInput = {input = input, at = os.clock()}
                end
                if id == "HideUI" then ui.SetVisible(not ui.Visible)
                elseif keySpecs[id].run then keySpecs[id].run() end
                return
            end
        end
    end)
    function ui.Destroy()
        if not ui.Alive then return end
        local snapshot = ui.Snapshot(); store.last = snapshot; write("last", snapshot)
        ui.Alive = false
        if env.VRSKeyCapture == ui then env.VRSKeyCapture = nil end
        if env.VRSControlCenters and env.VRSControlCenters[host.role] == ui then env.VRSControlCenters[host.role] = nil end
        if env.VRSActiveControlCenter == ui then
            env.VRSActiveControlCenter = nil
            for _, other in pairs(env.VRSControlCenters or {}) do if other.Alive then other.Focus(); break end end
        end
        window:Destroy()
    end
    local elapsed = 1
    connect(RunService.Heartbeat, function(dt)
        if not ui.Alive then return end
        elapsed += dt; if elapsed < 0.15 then return end; elapsed = 0
        local camera = workspace.CurrentCamera
        if camera then scale.Scale = math.clamp(math.min((camera.ViewportSize.X - 32) / 780, (camera.ViewportSize.Y - 40) / 560), 0.3, 1) end
        for _, refresh in ipairs(refreshers) do refresh() end
    end)
    if host.bindingsChanged then host.bindingsChanged(ui.Keybinds) end
    local last = store.last or read("last")
    if last then local ok, err = ui.Apply(last); if not ok then report("Saved settings ignored: " .. tostring(err), true) end end
    for _, refresh in ipairs(refreshers) do refresh() end
    host.legacyPanel.Visible = false
    function ui.Focus()
        for _, other in pairs(env.VRSControlCenters or {}) do if other ~= ui then other.SetVisible(false) end end
        env.VRSActiveControlCenter = ui; ui.SetVisible(true)
    end
    env.VRSControlCenters = env.VRSControlCenters or {}
    env.VRSControlCenters[host.role] = ui
    ui.Focus()
    return ui
end

local function installControlCenter(host)
    local api, role, controls, bindings = host.owner, host.role, {}, {}
    local function add(spec) controls[#controls + 1] = spec end
    local function toggle(tab, id, title, description, get, set, default)
        add({kind = "toggle", tab = tab, id = id, title = title, description = description,
            get = get, set = set, default = default})
    end
    local function configToggle(tab, key, title, description)
        toggle(tab, key, title, description, function() return api.Config[key] end, function(value)
            api.Config[key] = value
            if key == "ShowSetterPreview" and api.SetterPreview then api.SetterPreview.SetEnabled(value) end
        end)
    end
    local function slider(tab, key, title, description, config, minimum, maximum, step, format)
        add({kind = "slider", tab = tab, id = config == api.Config and key or "Defense." .. key,
            title = title, description = description, min = minimum, max = maximum, step = step,
            format = format, get = function() return config[key] end, set = function(value) config[key] = value end})
    end
    local function bind(id, title, key, run, description)
        bindings[#bindings + 1] = {id = id, title = title, key = key, run = run, description = description}
    end
    local engine = host.defense.Engine()
    toggle("Defense", "AutoReceive", "Auto Receive", "Receive incoming balls within normal reach.",
        function() return api.Config.AutoReceive end, api.SetAutoReceive, false)
    toggle("Defense", "AutoDive", "Auto Dive", "Dive when a normal receive cannot reach the ball.",
        function() return api.Config.AutoDive end, api.SetAutoDive, false)
    for _, spec in ipairs({{"ReceiveInBackground", "Background receive", "Allow game-targeted receives while unfocused."},
        {"SkipOutBalls", "Leave predicted out balls", "Skip contacts when the predicted landing is outside your court."},
        {"DiveAutoAim", "Face the dive", "Turn toward the planned dive direction."}}) do
        local key = spec[1]
        toggle("Defense", "Defense." .. key, spec[2], spec[3], function() return host.defense.Engine().Config[key] end,
            function(value) host.defense.Engine().Config[key] = value end)
    end
    -- Access the current shared engine, including a friend script loaded later.
    local defenseConfig = setmetatable({}, {__index = function(_, key) return host.defense.Engine().Config[key] end,
        __newindex = function(_, key, value) host.defense.Engine().Config[key] = value end})
    slider("Defense", "ReceiveLeadSeconds", "Receive anticipation", "Extra time allowed for an incoming contact.", defenseConfig, 0, 0.18, 0.005, "%.3fs")
    slider("Defense", "DiveMinSpeed", "Minimum dive ball speed", "Ignore slower balls that do not need an automatic dive.", defenseConfig, 10, 150, 1, "%.0f")
    slider("Defense", "DiveHorizon", "Dive prediction window", "How far ahead the dive planner checks the flight.", defenseConfig, 0.15, 1.2, 0.05, "%.2fs")
    add({kind = "status", tab = "Defense", title = "Receive status", get = function()
        local current = host.defense.Engine(); return current.Status and current.Status.receive or current.Startup and current.Startup.Error or "Waiting"
    end})
    add({kind = "status", tab = "Defense", title = "Dive status", get = function()
        local current = host.defense.Engine(); return current.Status and current.Status.dive or current.Startup and current.Startup.Error or "Waiting"
    end})
    add({kind = "status", tab = "Overview", title = role == "setting" and "Set tracking" or "Spike tracking", get = host.status})
    if role == "setting" then
        toggle("Overview", "AimEnabled", "Set aim", "Use the selected set target at your manual power.",
            function() return api.Config.AimEnabled end, api.SetAimEnabled)
        add({kind = "choice", tab = "Visuals", id = "Mode", title = "Set previews", description = "Choose which hypothetical set paths are visible.",
            options = {"Both", "Front", "Back"}, get = function() return api.Config.Mode end, set = function(value) api.Config.Mode = value end})
        configToggle("Overview", "SetLeadEnabled", "Moving target prediction", "Choose a meeting point for sideways cross plays.")
        slider("Overview", "AimHoldSeconds", "Aim hold", "How long one released aim press remains active.", api.Config, 0.1, 1, 0.05, "%.2fs")
        slider("Overview", "SetLeadMaxStuds", "Maximum lateral lead", "Limit how far prediction can lead a sliding spiker.", api.Config, 0, 10, 0.5, "%.1f")
        slider("Overview", "SetAimMaxCorrection", "Route correction limit", "Allow small corrections without chasing a new meeting point.", api.Config, 0, 4, 0.25, "%.2f")
        configToggle("Visuals", "Enabled", "Set trajectories", "Show the front and back set previews.")
        configToggle("Visuals", "ShowIncomingLanding", "Ball paths and landings", "Keep rally trajectories and landing markers visible.")
        configToggle("Visuals", "ShowSetHitbox", "Set contact volume", "Display the existing set reach.")
        configToggle("Visuals", "ShowReceiveHitbox", "Receive contact volume", "Display the existing receive reach.")
        bind("FrontAim", "Front set aim", "F", nil, "Match your game's front-set key when changing this.")
        bind("BackAim", "Back set aim", "R", nil, "Match your game's back-set key when changing this.")
        bind("ToggleAim", "Toggle set aim", "Five", function() api.SetAimEnabled(not api.Config.AimEnabled) end)
        bind("TogglePaths", "Toggle set paths", "Insert", function() api.Config.Enabled = not api.Config.Enabled end)
    else
        toggle("Overview", "AutoAim", "Spike aim", "Aim your spike toward an open court target.",
            function() return api.Config.AutoAim end, api.SetAutoAim)
        toggle("Overview", "FullAssist", "Full assistance", "Stay armed when calibration is ready. Manual input still yields the play.",
            function() return api.FullAssist and api.FullAssist.Wanted == true end, function(value)
                if api.FullAssist and value ~= api.FullAssist.Wanted then api.FullAssist.Toggle() end
            end)
        toggle("Overview", "FullBackground", "Background full assistance", "Keep full assistance active while the game is unfocused.",
            function() return api.FullAssist and api.FullAssist.Config.AllowBackground == true end,
            function(value) if api.FullAssist then api.FullAssist.SetBackground(value) end end)
        add({kind = "action", tab = "Overview", title = "Jump and spike calibration", description = "Record jumps and successful manual spikes.", actionText = "Record / finish", run = function()
            if api.FullAssist then
                if api.FullAssist.Recording then api.FullAssist.FinishCalibration() else api.FullAssist.StartCalibration() end
            end
        end})
        add({kind = "status", tab = "Overview", title = "Full assistance status", get = host.fullStatus})
        add({kind = "status", tab = "Overview", title = "Setter preview status", get = host.setterStatus})
        slider("Overview", "AimMargin", "Court edge margin", "Keep planned spike targets inside the sidelines.", api.Config, 2, 8, 0.25, "%.2f")
        for _, spec in ipairs({{"ShowTrajectory", "Ball paths and landings", "Show rally flights and landing markers."},
            {"ShowSetterPreview", "Setter preview", "Show the estimated incoming set."},
            {"ShowSpikeHitbox", "Spike contact volume", "Display the existing spike reach."},
            {"ShowOwnBlocks", "Your block volume", "Display your block overlay."},
            {"ShowOtherBlocks", "Other block volumes", "Display the blocker overlays."},
            {"HighlightBall", "Ball highlight", "Highlight tracked balls."}}) do configToggle("Visuals", spec[1], spec[2], spec[3]) end
        bind("ToggleAim", "Toggle spike aim", "Five", function() api.SetAutoAim(not api.Config.AutoAim) end)
        bind("FullAssist", "Toggle full assistance", "Six", function() if api.FullAssist then api.FullAssist.Toggle() end end)
        bind("TogglePaths", "Toggle ball paths", "Insert", function() api.Config.ShowTrajectory = not api.Config.ShowTrajectory end)
    end
    configToggle("Visuals", "ShowPlayerPowers", "Player power labels", "Show P# above every available player.")
    configToggle("Visuals", "ShowOpponentServe", "Serve facing guide", "Keep the server's facing guide visible alongside the flight.")
    toggle("Overview", "StaminaRefill", "Stamina refill", "Enable stamina refill.",
        function() return api.Stamina.IsEnabled() end, api.SetStaminaRefill)
    toggle("Overview", "JumpBoost", "Jump height multiplier", "Adjust jump height on your next takeoff.",
        function() return api.Jump.IsEnabled() end, api.SetJumpBoost, false)
    add({kind = "number", tab = "Overview", id = "JumpHeightMultiplier", title = "Height multiplier",
        description = "1 = normal height / 1.2 = 20% higher. Range: 0.1–2.", min = 0.1, max = 2, default = 1,
        visible = function() return api.Jump.IsEnabled() end,
        get = function() return api.Jump.GetMultiplier() end, set = api.SetJumpHeightMultiplier})
    toggle("Overview", "TiltBoost", "Tilt multiplier", "Increase airborne forward/back and sideways lean.",
        function() return api.Tilt.IsEnabled() end, api.SetTiltBoost, false)
    add({kind = "number", tab = "Overview", id = "TiltMultiplier", title = "Tilt amount",
        description = "1 = native tilt / 2 = twice the lean. Range: 0.1-3.", min = 0.1, max = 3, default = 1,
        visible = function() return api.Tilt.IsEnabled() end,
        get = function() return api.Tilt.GetMultiplier() end, set = api.SetTiltMultiplier})
    bind("ToggleReceive", "Toggle Auto Receive", "Seven", function() api.SetAutoReceive(not api.Config.AutoReceive) end)
    bind("ToggleDive", "Toggle Auto Dive", "Four", function() api.SetAutoDive(not api.Config.AutoDive) end)
    bind("HideUI", "Show / hide menu", "RightShift", nil, "Hiding the menu keeps enabled assists and court overlays running.")
    host.controls, host.bindings = controls, bindings
    return host.createUI(host)
end

-- CONTROL_CENTER_COMPONENT_END
-- CONTROL_CENTER_INTEGRATION_BEGIN
do
    local wasReceive = api.Config.AutoReceive == true
    if api.SetAutoReceive then api.SetAutoReceive(false, "shared defense controller") end
    local defense = createDefenseService({env=env,owner=api,heartbeat=RunService.Heartbeat,createEngine=createDefenseEngine})
    api.Defense = defense
    function api.SetAutoReceive(value) return defense.SetReceive(value) end
    function api.SetAutoDive(value) return defense.SetDive(value) end
    if wasReceive then api.SetAutoReceive(true) end
    local ok,result = pcall(installControlCenter, {owner=api,role="setting",gui=gui,legacyPanel=panel,
        env=env,userId=player.UserId,uis=UIS,runService=RunService,guiService=GuiService,
        make=make,connect=connect,http=game:GetService("HttpService"),defense=defense,
        unload=api.Destroy,createUI=createControlCenter,status=function() return targetStatus.Text:gsub("F:", (api.Config.FrontAimKey or "F") .. ":"):gsub("R:", (api.Config.BackAimKey or "R") .. ":") .. "\n" .. status.Text end,
        bindingsChanged = function(keys)
        api.Config.FrontAimKey, api.Config.BackAimKey = keys.FrontAim, keys.BackAim
        api.RebindAimKeys()
    end,
    })
    if ok then api.Interface=result else
        api.InterfaceError=tostring(result); warn("[VRS] Control center: "..tostring(result))
        defense.SetReceive(false); defense.SetDive(false)
    end
end
-- CONTROL_CENTER_INTEGRATION_END
