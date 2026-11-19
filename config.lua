Config = {}

-- Seconds a coverage answer is reused before the database is asked again.
Config.CacheSeconds = 30

-- MDT fines (wasabi_mdt:onChargeLinked). Money leaves the citizen's bank and goes
-- into the arresting officer's department account (society name = job name).
-- Offline citizens are charged at their next login.
Config.Fines = {
    enabled = true,
    account = 'bank',
    fallbackSociety = 'police', -- used when the officer's job cannot be read
}

-- Charges for care that health insurance covers (insured patients pay nothing).
-- Placeholder prices until the server price base is set.
Config.Care = {
    society = 'lsmc',   -- hospital account that receives the money
    mriScan = 250,
}

-- Incidents reported by other scripts (ReportIncident export): a report in m-Insurance's accident log (brokers and
-- police see it there, with the picture), and a premium rise on the car's active vehicle policy.
Config.Incidents = {
    enabled = true,
    reporter = 'Station camera',     -- shown as the reporting officer in the accident log
    windowDays = 90,                 -- rises within this window count toward the cap
    maxSurcharge = 50,               -- percent a car's premium can rise in the window, all incidents together
    kinds = {                        -- percent per incident, by kind
        fuel_driveoff = { surcharge = 10, label = 'Gas station drive-off (pump nozzle torn off)' },
        fuel_driveoff_fire = { surcharge = 20, label = 'Gas station drive-off, pump fire' },
    },
    defaultSurcharge = 5,            -- for a kind not listed above
}
