-- Plain-Lua test runner for lib/* and the engine-mock integration test.
--   lua .dev/tests/run.lua       (from the pack root, with a stock Lua 5.4)
--   python3 .dev/tests/run.py    (uses the `lupa` package when no lua binary is installed)
package.path = "./?.lua;./.dev/?.lua;" .. package.path

local failures, passed = {}, 0
local current = "?"

function test(name, fn)
	current = name
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failures[#failures + 1] = name .. ": " .. tostring(err)
	end
end

function eq(actual, expected, msg)
	if actual ~= expected then
		error((msg or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

function truthy(v, msg)
	if not v then
		error(msg or "expected a truthy value", 2)
	end
end

function falsy(v, msg)
	if v then
		error(msg or "expected a falsy value", 2)
	end
end

local files = {
	"tests.registry_test", "tests.ray_test", "tests.drops_test", "tests.farm_test", "tests.splice_test",
	"tests.worldname_test", "tests.locks_test", "tests.trade_test", "tests.market_test", "tests.balance_test",
	"tests.integration_test", "tests.ui_test",
}
for _, f in ipairs(files) do
	local ok, err = pcall(require, f)
	if not ok then
		failures[#failures + 1] = f .. " failed to load: " .. tostring(err)
	end
end

print(string.format("%d passed, %d failed", passed, #failures))
for _, f in ipairs(failures) do
	print("FAIL " .. f)
end
if #failures > 0 then
	os.exit(1)
end
