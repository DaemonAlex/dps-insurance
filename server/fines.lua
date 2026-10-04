-- MDT fines: wasabi_mdt fires onChargeLinked/onChargeUnlinked server-side for every
-- charge an officer adds or removes. The money moves here; nothing else bills fines.

if not Config.Fines.enabled then return end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS dps_insurance_fines (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(64) NOT NULL,
            amount INT NOT NULL,
            reason VARCHAR(255) NOT NULL,
            society VARCHAR(64) NOT NULL,
            incident_id VARCHAR(64) NULL,
            charge_id VARCHAR(64) NULL,
            status ENUM('owed','paid','refunded','cancelled') NOT NULL DEFAULT 'owed',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            paid_at TIMESTAMP NULL,
            PRIMARY KEY (id),
            KEY idx_fines_owed (citizenid, status),
            KEY idx_fines_charge (incident_id, charge_id)
        )
    ]])
end)

local function tryCollect(row)
    local player = exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
    if not player then return false end
    if not player.Functions.RemoveMoney(Config.Fines.account, row.amount, row.reason) then return false end
    exports['Renewed-Banking']:addAccountMoney(row.society, row.amount)
    MySQL.update.await("UPDATE dps_insurance_fines SET status = 'paid', paid_at = NOW() WHERE id = ?", { row.id })
    lib.notify(player.PlayerData.source, { type = 'inform', description = ('Fine paid: $%d (%s)'):format(row.amount, row.reason) })
    return true
end

AddEventHandler('wasabi_mdt:onChargeLinked', function(chargeData, primaryIdentifier, incidentData, officerData, adjustments)
    local amount = Logic.fineAmount(chargeData, adjustments)
    if amount <= 0 or type(primaryIdentifier) ~= 'string' then return end
    local row = {
        citizenid = primaryIdentifier,
        amount = amount,
        reason = ('MDT fine: %s'):format(chargeData.title or 'charge'),
        society = Logic.societyOf(officerData, Config.Fines.fallbackSociety),
    }
    row.id = MySQL.insert.await(
        'INSERT INTO dps_insurance_fines (citizenid, amount, reason, society, incident_id, charge_id) VALUES (?, ?, ?, ?, ?, ?)',
        { row.citizenid, row.amount, row.reason, row.society, tostring(incidentData and incidentData.id or ''), tostring(chargeData.id or '') })
    local paid = tryCollect(row)
    lib.print.info(('[fines] %s fined %d for %s -> %s (%s)'):format(row.citizenid, amount, chargeData.title or '?', row.society, paid and 'paid' or 'owed'))
end)

AddEventHandler('wasabi_mdt:onChargeUnlinked', function(chargeData, primaryIdentifier, incidentData)
    if type(primaryIdentifier) ~= 'string' then return end
    local row = MySQL.single.await(
        "SELECT * FROM dps_insurance_fines WHERE citizenid = ? AND incident_id = ? AND charge_id = ? AND status IN ('owed','paid') ORDER BY id DESC LIMIT 1",
        { primaryIdentifier, tostring(incidentData and incidentData.id or ''), tostring(chargeData.id or '') })
    if not row then return end
    if row.status == 'owed' then
        MySQL.update.await("UPDATE dps_insurance_fines SET status = 'cancelled' WHERE id = ?", { row.id })
        return
    end
    local player = exports.qbx_core:GetPlayerByCitizenId(row.citizenid)
    if not player then return end -- refunded next time the charge is removed while they are online
    exports['Renewed-Banking']:removeAccountMoney(row.society, row.amount)
    player.Functions.AddMoney(Config.Fines.account, row.amount, 'MDT fine refunded: ' .. row.reason)
    MySQL.update.await("UPDATE dps_insurance_fines SET status = 'refunded' WHERE id = ?", { row.id })
    lib.print.info(('[fines] refunded %d to %s'):format(row.amount, row.citizenid))
end)

-- Fines given while the citizen was offline are collected when they log in.
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local cid = player and player.PlayerData and player.PlayerData.citizenid
    if not cid then return end
    local rows = MySQL.query.await("SELECT * FROM dps_insurance_fines WHERE citizenid = ? AND status = 'owed'", { cid }) or {}
    for i = 1, #rows do tryCollect(rows[i]) end
end)
