-- lua5.4 tests/run.lua  (pure logic only; no game natives)
package.path = './?.lua;' .. package.path
dofile('shared/logic.lua')
local fails, n = 0, 0
local function eq(a, b, what) n = n + 1; if a ~= b then fails = fails + 1; print(('FAIL %s: got %s want %s'):format(what, tostring(a), tostring(b))) end end
eq(Logic.normalizePlate(' ab 12-c.d '), 'AB12CD', 'plate cleanup')
eq(Logic.normalizePlate(nil), '', 'nil plate')
eq(Logic.fineAmount({ fine = 150 }, nil), 150, 'base fine')
eq(Logic.fineAmount({ fine = 150 }, { adjusted_fine = 75 }), 75, 'adjusted fine wins')
eq(Logic.fineAmount({ fine = 150 }, { adjusted_fine = 0 }), 0, 'adjusted to zero')
eq(Logic.fineAmount({ fine = -5 }, nil), 0, 'no negative fines')
eq(Logic.fineAmount(nil, nil), 0, 'missing charge')
eq(Logic.societyOf({ job = 'bcso' }, 'police'), 'bcso', 'job string')
eq(Logic.societyOf({ job = { name = 'sasp' } }, 'police'), 'sasp', 'job table')
eq(Logic.societyOf({}, 'police'), 'police', 'fallback')
print(('%d tests, %d failed'):format(n, fails))
os.exit(fails == 0 and 0 or 1)
