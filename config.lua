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
    society = 'omc',   -- hospital account that receives the money
    mriScan = 250,
}
