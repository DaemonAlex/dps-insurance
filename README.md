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
| [dps-shops](https://github.com/DaemonAlex/dps-shops) | Shop clerks who greet and react to a robbery, then player-owned shops. |
| [dps-fleet](https://github.com/DaemonAlex/dps-fleet) | Vehicle browser and workshop on one panel: extras, liveries and mods for emergency vehicles. |
| [dps-parking](https://github.com/DaemonAlex/dps-parking) | Parking with valet, impound, violations and reserved spots. |
| [dps-vehiclepersistence](https://github.com/DaemonAlex/dps-vehiclepersistence) | Vehicles stay where they were parked. Pairs with dps-parking. |
| [dps-towjob](https://github.com/DaemonAlex/dps-towjob) | Queue-based tow job with jg-mechanic integration. |
| [dps-services](https://github.com/DaemonAlex/dps-services) | Request a tow and follow it live on the lb-phone and lb-tablet. Pairs with dps-towjob. |
| [dps-autoshops](https://github.com/DaemonAlex/dps-autoshops) | Self-service repair shops when no mechanic is on duty. |
| [dps-cityworker](https://github.com/DaemonAlex/dps-cityworker) | City infrastructure job and career. |
| [dps-ainpcs](https://github.com/DaemonAlex/dps-ainpcs) | NPCs you can talk to, with trust, quests and intel. |
| [dps-badpeds](https://github.com/DaemonAlex/dps-badpeds) | Police interaction with NPCs: stops, arrests, intel and jail records. |
| [dps-gangwars](https://github.com/DaemonAlex/dps-gangwars) | Ambient gang NPCs, territory population and war reinforcements. |
| [dps-rotations](https://github.com/DaemonAlex/dps-rotations) | Moves dealers, harvests and other spots on a fixed schedule. |
| [dps-trains](https://github.com/DaemonAlex/dps-trains) | The train system. Pairs with dps-trains-stock, dps-traintools and dps-transitapp. |
| [dps-transitapp](https://github.com/DaemonAlex/dps-transitapp) | Live train arrival boards on the lb-phone. |
| [dps-faceplant](https://github.com/DaemonAlex/dps-faceplant) | City help, reports and staff tools on the lb-phone and lb-tablet. |
| [dps-chat](https://github.com/DaemonAlex/dps-chat) | A command box for voice-only servers. No chat feed. |
| [dps-filmmode](https://github.com/DaemonAlex/dps-filmmode) | One key hides every HUD layer and gives a smooth free camera for recording. |
