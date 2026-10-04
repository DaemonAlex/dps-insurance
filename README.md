# dps-insurance

Ties **m-Insurance** into the rest of the Del Perro Sands server: the MDT, impound, hospitals and the medical chart. It adds no menus of its own; players buy and manage cover in m-Insurance as usual.

## What it does

| Area | Behaviour |
|---|---|
| **Coverage checks** | Answers "is this car insured?" and "does this person have health cover?" straight from m-Insurance's tables (its own exports are escrowed and undocumented). Answers are cached for 30 s. |
| **MDT fines** | When an officer links a charge in wasabi_mdt, the fine leaves the citizen's bank and goes to that officer's department account. Offline citizens pay at their next login. Unlinking a charge cancels an unpaid fine, or refunds a paid one when the citizen is online. Every fine is kept in `dps_insurance_fines`. |
| **Impound** | jg-advancedgarages will not release a car from impound while it has no valid insurance. |
| **Hospital bills** | Insured patients pay nothing for covered care; uninsured patients are charged to the hospital account (`omc` by default), e.g. the MRI scan. |
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
| `wasabi_ambulance` pricing config | `mInsurance` enabled, per-injury pricing paid to `omc`, check-in discount. |
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
| `Config.Care.society` | `'omc'` | Hospital account for uninsured care |
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
