-- ReportIncident: other scripts (dps-fuel drive-offs today) report a car incident here. It goes into m-Insurance's
-- accident log (so brokers and police see it, picture included) and raises the premium on the car's active vehicle
-- policy by the kind's percent, capped over a window. Every rise is kept in dps_insurance_incidents.
local PLATE_EXPR = "REPLACE(REPLACE(REPLACE(UPPER(TRIM(%s)), ' ', ''), '-', ''), '.', '')"

---@param data table { plate, kind, citizenid?, name?, location?, photo?, notes? }
---@return boolean, number|string  ok, percent added (or the reason it did nothing)
function ReportIncident(data)
    local I = Config.Incidents
    if not I or not I.enabled then return false, 'off' end
    if type(data) ~= 'table' or type(data.plate) ~= 'string' or type(data.kind) ~= 'string' then return false, 'bad data' end
    local plate = Logic.normalizePlate(data.plate)
    if plate == '' then return false, 'no plate' end
    local kind = I.kinds[data.kind] or { surcharge = I.defaultSurcharge, label = data.kind }

    MySQL.insert('INSERT INTO m_insurance_accidents (vehicle_plate, citizen_name, officer_name, road_location, screenshot, date, observations) '
        .. 'VALUES (?, ?, ?, ?, ?, NOW(), ?)',
        { plate, data.name or 'Unknown', I.reporter, data.location or 'Unknown', data.photo, kind.label .. (data.notes and ('. ' .. data.notes) or '') })

    local policy = MySQL.single.await(("SELECT id, citizenid, subscription_price FROM insurance_policies WHERE type = 'vehicle' AND status = 'active' "
        .. "AND %s = ? ORDER BY end_date DESC LIMIT 1"):format(PLATE_EXPR:format('identifier')), { plate })
    local added = 0
    if policy and tonumber(policy.subscription_price) then
        local prev = tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(surcharge), 0) FROM dps_insurance_incidents WHERE plate = ? AND at > NOW() - INTERVAL ? DAY',
            { plate, I.windowDays })) or 0
        added = Logic.surchargeToAdd(prev, kind.surcharge, I.maxSurcharge)
        if added > 0 then
            local newPrice = Logic.raisedPrice(policy.subscription_price, added)
            MySQL.update.await('UPDATE insurance_policies SET subscription_price = ? WHERE id = ?', { newPrice, policy.id })
            MySQL.insert('INSERT INTO insurance_history (citizenid, action, details, amount) VALUES (?, ?, ?, ?)',
                { policy.citizenid, 'premium_increase', ('%s: +%d%% on %s'):format(kind.label, added, plate), newPrice })
        end
    end
    MySQL.insert('INSERT INTO dps_insurance_incidents (plate, kind, citizenid, surcharge, photo) VALUES (?, ?, ?, ?, ?)',
        { plate, data.kind, data.citizenid, added, data.photo })
    return true, added
end
exports('ReportIncident', ReportIncident)

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS dps_insurance_incidents (
        id INT AUTO_INCREMENT PRIMARY KEY, plate VARCHAR(16) NOT NULL, kind VARCHAR(40) NOT NULL, citizenid VARCHAR(64) NULL,
        surcharge INT NOT NULL DEFAULT 0, photo VARCHAR(255) NULL, at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (plate, at))]])
end)
