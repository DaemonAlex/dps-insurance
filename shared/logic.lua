-- Pure helpers, no natives or database, so tests/run.lua can load them outside the game.
Logic = {}

-- Same rules as m-Insurance's NormalizePlate (server/utils.lua): upper case,
-- no spaces, dashes or dots.
function Logic.normalizePlate(plate)
    if plate == nil then return '' end
    local s = tostring(plate):upper()
    s = s:gsub('%z', ''):gsub('%s+', ''):gsub('[-%.]', '')
    return s
end

-- The fine an officer actually set: the adjusted fine wins over the code's base fine.
function Logic.fineAmount(chargeData, adjustments)
    local amount = adjustments and tonumber(adjustments.adjusted_fine)
    if amount == nil then amount = chargeData and tonumber(chargeData.fine) end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 0 then amount = 0 end
    return amount
end

-- Department account for a fine: the officer's job name, whatever shape it arrives in.
function Logic.societyOf(officerData, fallback)
    local job = officerData and officerData.job
    if type(job) == 'table' then job = job.name end
    if type(job) ~= 'string' or job == '' then return fallback end
    return job
end

return Logic
