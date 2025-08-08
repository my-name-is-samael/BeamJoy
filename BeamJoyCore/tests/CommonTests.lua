local logTag = "BJCTest"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.GREEN, nil, CONSOLE_COLORS.FOREGROUNDS.LIGHT_GREEN)
local logTagError = "BJCTestError"
SetLogType(logTagError, CONSOLE_COLORS.FOREGROUNDS.RED, nil, CONSOLE_COLORS.FOREGROUNDS.LIGHT_RED)

local C = {}
local testStarted, expectIndex = false, 0

---@param testName string
function C.test(testName, exec)
    testStarted = true
    Log("Starting test " .. testName, logTag)
    expectIndex = 0
    local ok, err = pcall(exec)
    if not ok then
        Log(string.var("Test {1} #{2} failed !", { testName, expectIndex }), logTagError)
        Log(err, logTagError)
        testStarted = false
        error()
    end
    Log("Test " .. testName .. " success !", logTag)
    testStarted = false
end

---@param value any
---@param expected any? default true
---@param errorMessage string?
function C.expect(value, expected, errorMessage)
    if not testStarted then
        LogError("expect called outside a test")
        return
    end

    expected = expected or true
    expectIndex = expectIndex + 1
    if type(value) ~= type(expected) then
        error(errorMessage or ("Expected type " .. type(expected) .. ", got " .. type(value)))
    elseif type(value) == "table" then
        if not table.compare(value, expected, true) then
            error(errorMessage or ("Expected " .. table.stringify(expected) .. ", got " .. table.stringify(value)))
        end
    elseif value ~= expected then
        local expectedStr = tostring(expected)
        if type(expected) == "string" then
            expectedStr = "'" .. expectedStr .. "'"
        end
        local valueStr = tostring(value)
        if type(value) == "string" then
            valueStr = "'" .. valueStr .. "'"
        end
        error(errorMessage or ("Expected " .. expectedStr .. ", got " .. valueStr))
    end
end

return C
