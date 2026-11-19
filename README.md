<p align="center"><img src=".github/dps-logo.svg" alt="DelPerroSands" width="360"></p>

# dps-insurance

Ties **m-Insurance** into the rest of the Del Perro Sands server: the MDT, impound, hospitals and the medical chart. It adds no menus of its own; players buy and manage cover in m-Insurance as usual.

## What it does

| Area | Behaviour |
|---|---|
| **Coverage checks** | Answers "is this car insured?" and "does this person have health cover?" straight from m-Insurance's tables (its own exports are escrowed and undocumented). Answers are cached for 30 s. |
| **MDT fines** | When an officer links a charge in wasabi_mdt, the fine leaves the citizen's bank and goes to that officer's department account. Offline citizens pay at their next login. Unlinking a charge cancels an unpaid fine, or refunds a paid one when the citizen is online. Every fine is kept in `dps_insurance_fines`. |
| **Impound** | jg-advancedgarages will not release a car from impound while it has no valid insurance. |
| **Hospital bills** | Insured patients pay nothing for covered care; uninsured patients are charged to the hospital account (`lsmc` by default), e.g. the MRI scan. |
| **Medical chart** | dps-medical shows an "Insured" line on the patient chart. |
| **Parking** | dps-parking detects this resource and uses it for insurance checks. |

## Incidents from other scripts

`exports['dps-insurance']:ReportIncident({ plate, kind, citizenid?, name?, location?, photo?, notes? })` files a
car incident: an entry in m-Insurance's accident log (brokers and police see it there, with the picture) and a
premium rise on the car's active vehicle policy. The percent per kind is in `Config.Incidents.kinds`
(`fuel_driveoff` 10%, `fuel_driveoff_fire` 20%, anything else 5%), capped at 50% within 90 days, and every
rise is kept in `dps_insurance_incidents` and m-Insurance's own history. dps-fuel uses it for gas station
drive-offs caught on camera.

## Exports (server)

```lua
exports['dps-insurance']:GetVehicleCompliance(plate)   -- { plate, insurance, mot, tax, registration } expiries (unix ms) or nil
exports['dps-insurance']:IsVehicleInsured(plate)       -- true / false
exports['dps-insurance']:IsHealthInsured(citizenid)    -- true / false
exports['dps-insurance']:ChargeUninsuredCare(src, amount, label, society)
exports['dps-insurance']:ChargeCareItem(src, key, label) -- key from Config.Care, e.g. 'mriScan'
exports['dps-insurance']:ForgetCoverage(plateOrCitizenid) -- drop a cached answer after a policy change
```

Client callback: `lib.callback.await('dps-insurance:isVehicleInsured', false, plate)`.

## What it is for

A paid insurance script sells cover. On its own, nothing else on the server knows whether a
policy exists, so being uninsured costs a player nothing. This makes insurance matter: the police
computer, the impound, the hospital and the parking system all ask the same question and act on
the answer.

## On its own, and with other scripts

**It is a companion, not a standalone.** It needs m-Insurance (paid) and adds no menus. Players
buy and manage cover in m-Insurance exactly as before. This resource only reads m-Insurance's
tables, so an update to the paid script does not break it unless those tables change.

**With m-Insurance alone.** Other scripts get four exports that answer "is this car insured?" and
"does this person have health cover?".

**With a paid police computer (wasabi_mdt).** A fine linked to a charge is taken from the
citizen's bank and paid to the officer's department. An offline citizen pays at next login.

**With a paid garage script (jg-advancedgarages).** An uninsured car cannot be released from the
impound. The owner has to buy cover first.

**With a paid ambulance script (wasabi_ambulance) and [dps-medical](https://github.com/DaemonAlex/dps-medical).**
Insured patients pay nothing for covered care. Uninsured patients are billed to the hospital. The
patient chart shows an "Insured" line.

**With [dps-parking](https://github.com/DaemonAlex/dps-parking).** Parking picks this up
automatically for its impound fee discount.

## Requirements

**Must be running before this resource:**

- `ox_lib`, `oxmysql`, `qbx_core`
- **m-Insurance** (paid, by Marcos/m-scripts). Its tables are read directly: `insurance_policies`, `insurance_mot`, `insurance_tax`, `insurance_registration`.

**Used when present (the matching integration below is needed for that feature):**

- `wasabi_mdt` — fines (events `wasabi_mdt:onChargeLinked` / `onChargeUnlinked`)
- `wasabi_banking` (answers the `Renewed-Banking` export names) — department and hospital accounts
- `jg-advancedgarages` — impound release check
- `wasabi_ambulance` + Pillbox medical hooks — care charges
- `dps-medical`, `dps-parking` — chart line and parking checks

## Install

1. Install and configure **m-Insurance** first (its own README). On DPS it lives in `resources/[rp]/[jobs]/m-Insurance`; the old `m-Insurance_QB` build must **not** run alongside it.
2. Put `dps-insurance` in your resources (we use `resources/[dps]/dps-insurance`) so it starts **after** m-Insurance.
3. Add the **insurance job** to `qbx_core/shared/jobs.lua` (DPS grades: Clerk, Broker, Senior Broker, Manager with `isboss` + `bankAuth`).
4. Add an **`insurance` society account** in wasabi_banking (`AllowedSocietiesAndRanks`, plus the `bank_accounts_new` row).
5. Add m-Insurance's **items** to `ox_inventory/data/items.lua` (from m-Insurance's README).
6. **MDT penal codes** for driving without insurance, MOT, tax or registration (DPS uses TR-31 to TR-34), with their fines.
7. **Optional integrations** (one small edit each, see the next section).
8. Restart the server. The fines table is created on first start.

## Integration edits on DPS

| File | Edit |
|---|---|
| `jg-advancedgarages/config/config-cl.lua` | Impound takeout verification calls `dps-insurance:isVehicleInsured` and blocks release when false. |
| `wasabi_ambulance` pricing config | `mInsurance` enabled, per-injury pricing paid to `lsmc`, check-in discount. |
| Pillbox `hooks_server.lua` | `onScanComplete` calls `ChargeCareItem(src, 'mriScan', 'MRI scan')`. |
| `dps-medical` | `getChartFor` returns `patient.insured` from `IsHealthInsured`. |
| `dps-parking/integrations/insurance.lua` | Detects dps-insurance and uses its exports. |

## Settings (`config.lua`)

| Setting | Default | Meaning |
|---|---|---|
| `Config.CacheSeconds` | 30 | How long a coverage answer is reused |
| `Config.Fines.enabled` | true | Turn MDT fines on or off |
| `Config.Fines.account` | `'bank'` | Which money the fine comes from |
| `Config.Fines.fallbackSociety` | `'police'` | Account used when the officer's job can't be read |
| `Config.Care.society` | `'lsmc'` | Hospital account for uninsured care |
| `Config.Care.mriScan` | 250 | Price of an MRI for uninsured patients (placeholder until the server price base is set) |

## Tests

```
lua5.4 tests/run.lua
```

Covers plate normalising (same rules as m-Insurance), fine amounts (an officer's adjusted fine wins) and department lookup.

## Files

```
fxmanifest.lua         dependencies and load order
config.lua             settings above
shared/logic.lua       pure helpers (no natives), used by the tests
server/coverage.lua    coverage reads, cache, exports, care charges
server/fines.lua       dps_insurance_fines table, MDT charge events, login collection
tests/run.lua
```

## Recent changes

- **19 November 2026.** `ReportIncident`: other scripts file car incidents (accident log entry and a capped premium rise). dps-fuel sends gas station drive-offs.

- **12 November 2026.** README: what it is for, how it works with each paid script, other DPS scripts.
- **31 October 2026.** The default hospital account is `lsmc` (Los Santos Medical Center). It was `omc`. Change `Config.Care.society` if your hospital job has another name.

## Author

Made by [DaemonAlex](https://github.com/DaemonAlex) for DelPerroSands.

## Other DPS scripts

All of these are made for DelPerroSands and run together on one Qbox server. Each one works on
its own. The ones marked "pairs with" do more when both are running.

| Script | What it does |
|---|---|
| [dps-inventory](https://github.com/DaemonAlex/dps-inventory) | The inventory: ox_inventory with equipment slots, backpacks, armour plates and a self status panel, in the DelPerroSands colours. |
| [dps-medical](https://github.com/DaemonAlex/dps-medical) | Patient records, illness and diagnostic tests. A companion to wasabi_ambulance. Pairs with dps-inventory: symptoms and diagnoses show on the status panel. |
| [dps-studio](https://github.com/DaemonAlex/dps-studio) | Build rooms, doors and portals in game from one panel (`/studio`), with owners and managers so staff do not have to support them. |
| [dps-shops](https://github.com/DaemonAlex/dps-shops) | Shop clerks who greet, react to robberies, talk back through dps-ainpcs and remember trouble, plus player-owned stores with delivery runs. Pairs with dps-ainpcs. |
| [dps-fleet](https://github.com/DaemonAlex/dps-fleet) | Vehicle browser and workshop on one panel: extras, liveries and mods for emergency vehicles. |
| [dps-parking](https://github.com/DaemonAlex/dps-parking) | Parking with valet, impound, violations and reserved spots. |
| [dps-vehiclepersistence](https://github.com/DaemonAlex/dps-vehiclepersistence) | Vehicles stay where they were parked. Pairs with dps-parking. |
| [dps-towjob](https://github.com/DaemonAlex/dps-towjob) | Queue-based tow job with jg-mechanic integration. |
| [dps-services](https://github.com/DaemonAlex/dps-services) | Request a tow and follow it live on the lb-phone and lb-tablet. Pairs with dps-towjob. |
| [dps-autoshops](https://github.com/DaemonAlex/dps-autoshops) | Self-service repair shops when no mechanic is on duty. |
| [dps-cityworker](https://github.com/DaemonAlex/dps-cityworker) | City infrastructure job and career. |
| [dps-ainpcs](https://github.com/DaemonAlex/dps-ainpcs) | NPCs you can talk to, with trust, quests and intel. Other scripts can make their own NPCs talk (dps-shops clerks). |
| [dps-badpeds](https://github.com/DaemonAlex/dps-badpeds) | Police interaction with NPCs: stops, arrests, intel and jail records. |
| [dps-gangwars](https://github.com/DaemonAlex/dps-gangwars) | Ambient gang NPCs, territory population and war reinforcements. |
| [dps-rotations](https://github.com/DaemonAlex/dps-rotations) | Moves dealers, harvests and other spots on a fixed schedule. |
| [dps-trains](https://github.com/DaemonAlex/dps-trains) | The train system. Pairs with dps-trains-stock, dps-traintools and dps-transitapp. |
| [dps-transitapp](https://github.com/DaemonAlex/dps-transitapp) | Live train arrival boards on the lb-phone. |
| [dps-faceplant](https://github.com/DaemonAlex/dps-faceplant) | City help, reports and staff tools on the lb-phone and lb-tablet. |
| [dps-chat](https://github.com/DaemonAlex/dps-chat) | A command box for voice-only servers. No chat feed. |
| [dps-filmmode](https://github.com/DaemonAlex/dps-filmmode) | One key hides every HUD layer and gives a smooth free camera for recording. |
| [dps-fuel](https://github.com/DaemonAlex/dps-fuel) | Gas station drive-offs for the ox_fuel nozzle: ripped hose, pump fire, station camera and a police call, by odds. Pairs with dps-insurance. |
| [dps-voice](https://github.com/DaemonAlex/dps-voice) | Spoken lines for NPCs, station announcements, dispatch and shops, from local voice models first. Pairs with dps-ainpcs. |
| [dps-bags](https://github.com/DaemonAlex/dps-bags) | Real bags for ox_inventory: the bag you carry shows on your character. |
| [dps-items](https://github.com/DaemonAlex/dps-items) | Item rules for ox_inventory: locked items, glovebox seats and an exploit watch. |
| [dps-furniture](https://github.com/DaemonAlex/dps-furniture) | Puts streamed furniture packs into the qs-housing furniture shop. |
| [dps-shellbrowser](https://github.com/DaemonAlex/dps-shellbrowser) | Staff tool to look at every qs-housing shell and set its door. |
| [dps-signs](https://github.com/DaemonAlex/dps-signs) | Rotates city messages across the SmartSigns road boards. |
| [dps-stationclear](https://github.com/DaemonAlex/dps-stationclear) | Hides map props that are in the way and keeps stray game peds off chosen spots. |
| [dps-citymap](https://github.com/DaemonAlex/dps-citymap) | A ready-made map of the whole city, cut into tiles for in-game screens. |
| [dps-cayo](https://github.com/DaemonAlex/dps-cayo) | Switches on the game's own Cayo Perico island, and nothing else. |
| [dps-aviation](https://github.com/DaemonAlex/dps-aviation) | Flight behaviour: aircraft idle instead of cutting out, sane taxi speed, a real start sequence. |
| [dps-airlines](https://github.com/DaemonAlex/dps-airlines) | Airlines job: passenger flights, cargo, charters, flight school and maintenance. |
| [dps-traintools](https://github.com/DaemonAlex/dps-traintools) | Rider tools for trains: board, sit, get off at a stop, ambient passengers. Pairs with dps-trains. |
| [dps-trains-stock](https://github.com/DaemonAlex/dps-trains-stock) | Train models and carriage sets for the train system. No scripts. Pairs with dps-trains. |
| [dps-traintracks](https://github.com/DaemonAlex/dps-traintracks) | Extra train track data. No scripts. Pairs with dps-trains. |
| [dps-crossings](https://github.com/DaemonAlex/dps-crossings) | Level crossings that close when a train comes. Pairs with dps-trains. |
| [dps-transit](https://github.com/DaemonAlex/dps-transit) | Passenger rail planning and scheduling (older system; dps-trains runs today). |
| [dps-maritime](https://github.com/DaemonAlex/dps-maritime) | Dock work and boat deliveries with progression. |
| [dps-maritime-maps](https://github.com/DaemonAlex/dps-maritime-maps) | Map files for the Jetsam docks, the map half of dps-maritime. |
| [dps-proracing](https://github.com/DaemonAlex/dps-proracing) | Circuit racing with lobbies, an AI practice grid and lap times. |
| [dps-carmenu](https://github.com/DaemonAlex/dps-carmenu) | Staff vehicle browser and spawner over the live Qbox vehicle list. |
| [dps-clothingbrowser](https://github.com/DaemonAlex/dps-clothingbrowser) | Staff tool to browse, identify and export clothing and uniforms. |
| [dps-lootpeds](https://github.com/DaemonAlex/dps-lootpeds) | Loot dead NPCs, with loot tables per model. |
| [dps-hookers](https://github.com/DaemonAlex/dps-hookers) | Adults-only RP (18+), adapted from MH Hookers by MaDHouSe. |
| [dps-weatherbridge](https://github.com/DaemonAlex/dps-weatherbridge) | Lets qb-weathersync and Renewed-Weathersync scripts work with night_natural_disasters. |
| [dps-fixes](https://github.com/DaemonAlex/dps-fixes) | Small server fixes kept in one resource. |
| [dps-bucketfix](https://github.com/DaemonAlex/dps-bucketfix) | Puts players back in the main world after spawning. |
| [dps-unfocus](https://github.com/DaemonAlex/dps-unfocus) | One key that frees a player stuck in a menu. |
| [dps-welcomecam](https://github.com/DaemonAlex/dps-welcomecam) | Aims the first camera a new player sees. |
| [dps-handlingdump](https://github.com/DaemonAlex/dps-handlingdump) | Developer tool: saves the stock handling of every vanilla vehicle. |
| [dps-weaponsounds](https://github.com/DaemonAlex/dps-weaponsounds) | Custom weapon sounds (planning; no code yet). |
| [dps-events](https://github.com/DaemonAlex/dps-events) | Playtime reward events (planning; no code yet). |
