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


-- Incidents (fuel drive-offs and the like) raise a car's premium by a percent, capped over a window.
-- prevTotal = percent already added in the window. Returns the percent to add now (0 when at the cap).
function Logic.surchargeToAdd(prevTotal, pct, cap)
    prevTotal, pct, cap = tonumber(prevTotal) or 0, tonumber(pct) or 0, tonumber(cap) or 0
    if pct <= 0 or prevTotal >= cap then return 0 end
    return math.min(pct, cap - prevTotal)
end

function Logic.raisedPrice(price, pct)
    price = tonumber(price) or 0
    return math.floor(price * (100 + (tonumber(pct) or 0)) / 100 + 0.5)
end

return Logic
