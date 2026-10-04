-- Answers "is this car / person covered right now?" straight from m-Insurance's tables.
-- m-Insurance's own exports are escrowed and undocumented, so we read its data instead.

local cache = {}

local PLATE_EXPR = "REPLACE(REPLACE(REPLACE(UPPER(TRIM(%s)), ' ', ''), '-', ''), '.', '')"

local function nowMs() return os.time() * 1000 end

local function cached(key, build)
    local hit = cache[key]
    if hit and os.time() - hit.at < Config.CacheSeconds then return hit.value end
    local value = build()
    cache[key] = { at = os.time(), value = value }
    return value
end

local function expiry(tableName, plate)
    local sql = ('SELECT MAX(expiry) FROM %s WHERE %s = ?'):format(tableName, PLATE_EXPR:format('plate'))
    local value = tonumber(MySQL.scalar.await(sql, { plate }))
    if value and value > nowMs() then return value end
    return nil
end

---Insurance, MOT, tax and registration for one plate. Each field is the expiry
---(unix ms) when valid, or nil when missing or expired.
---@param plate string
---@return table|nil
function GetVehicleCompliance(plate)
    plate = Logic.normalizePlate(plate)
    if plate == '' then return nil end
    return cached('veh:' .. plate, function()
        local insurance = tonumber(MySQL.scalar.await(
            ("SELECT MAX(end_date) FROM insurance_policies WHERE type = 'vehicle' AND status = 'active' AND %s = ? AND end_date > ?")
                :format(PLATE_EXPR:format('identifier')),
            { plate, nowMs() }))
        return {
            plate = plate,
            insurance = insurance,
            mot = expiry('insurance_mot', plate),
            tax = expiry('insurance_tax', plate),
            registration = expiry('insurance_registration', plate),
        }
    end)
end

---@param plate string
---@return boolean
function IsVehicleInsured(plate)
    local c = GetVehicleCompliance(plate)
    return c ~= nil and c.insurance ~= nil
end

---Health cover for a character (m-Insurance stores the citizenid as the identifier).
---@param citizenid string
---@return boolean
function IsHealthInsured(citizenid)
    if type(citizenid) ~= 'string' or citizenid == '' then return false end
    return cached('health:' .. citizenid, function()
        local found = MySQL.scalar.await(
            "SELECT 1 FROM insurance_policies WHERE type = 'health' AND status = 'active' AND (identifier = ? OR citizenid = ?) AND end_date > ? LIMIT 1",
            { citizenid, citizenid, nowMs() })
        return found ~= nil
    end) == true
end

local function citizenidOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData and player.PlayerData.citizenid
end

---Charge a patient for care unless their health insurance covers it.
---Returns true when the patient was covered or paid.
---@param src number patient server id
---@param amount number
---@param label string what the money is for
---@param society? string account that receives the money
function ChargeUninsuredCare(src, amount, label, society)
    local cid = citizenidOf(src)
    if not cid or not amount or amount <= 0 then return false end
    if IsHealthInsured(cid) then
        lib.notify(src, { type = 'success', description = ('%s covered by your health insurance'):format(label) })
        return true
    end
    local player = exports.qbx_core:GetPlayer(src)
    if not player.Functions.RemoveMoney('bank', amount, label) then
        lib.notify(src, { type = 'error', description = ('Could not pay $%d for %s'):format(amount, label) })
        return false
    end
    exports['Renewed-Banking']:addAccountMoney(society or Config.Care.society, amount)
    lib.notify(src, { type = 'inform', description = ('Paid $%d for %s (no health insurance)'):format(amount, label) })
    lib.print.info(('[care] %s paid %d for %s'):format(cid, amount, label))
    return true
end

-- Coverage changes the moment someone buys or renews; drop the cache when m-Insurance writes.
-- (No open event from m-Insurance, so the short cache timeout is the safety net.)
function ForgetCoverage(plateOrCid)
    if not plateOrCid then cache = {} return end
    cache['veh:' .. Logic.normalizePlate(plateOrCid)] = nil
    cache['health:' .. plateOrCid] = nil
end

exports('GetVehicleCompliance', GetVehicleCompliance)
exports('IsVehicleInsured', IsVehicleInsured)
exports('IsHealthInsured', IsHealthInsured)
exports('ChargeUninsuredCare', ChargeUninsuredCare)
exports('ForgetCoverage', ForgetCoverage)

-- Client-side gates (jg-advancedgarages impound release) ask through this callback.
lib.callback.register('dps-insurance:isVehicleInsured', function(_, plate)
    return IsVehicleInsured(plate)
end)

---Charge a priced care item from Config.Care (e.g. 'mriScan') unless insured.
---@param src number patient server id
---@param key string Config.Care price key
function ChargeCareItem(src, key, label)
    local amount = tonumber(Config.Care[key])
    if not amount then return false end
    return ChargeUninsuredCare(src, amount, label or key, Config.Care.society)
end
exports('ChargeCareItem', ChargeCareItem)
