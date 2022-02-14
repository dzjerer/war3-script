/*
 * Preprocessor InlineCondition (v2.0.0)
 *
 * GUI 환경에서 조건함수를 한 줄 조건문으로 치환하는 전처리기
 * 지역 변수를 조건 안에서 사용할 수 있습니다.
 *
 */
library PreprocessorInlineCondition requires PreprocessorJassCode, PreprocessorJassCodeUtil

//! novjass
//! preprocessor
Preprocessor.getInstance():register(function ()
  local InlineConditionPreprocessor = {}
  InlineConditionPreprocessor.__index = InlineConditionPreprocessor

  function InlineConditionPreprocessor.new()
    local self = setmetatable({}, InlineConditionPreprocessor)
    self._funcTable = {}
    self._referenceTable = {}
    return self
  end

  function InlineConditionPreprocessor:process(jass)
    self:_registerConditionFunctions(jass)
    jass = self:_replaceConditionFunctionCalls(jass)
    self:_countFunctionReference(jass)
    jass = self:_replaceNotReferencedFunctions(jass)
    return jass
  end

  function InlineConditionPreprocessor:_registerConditionFunctions(jass)
    local pattern = "function Trig_[%w_]+_Func[%w_]+ takes nothing returns boolean[\r\n]+.-[\r\n]+endfunction"
    for funcJass in string.gmatch(jass, pattern) do
      self:_registerConditionFunction(funcJass)
    end
    return jass
  end

  function InlineConditionPreprocessor:_registerConditionFunction(funcJass)
    if self:_registerAndConditionFunction(funcJass) then
      return true
    elseif self:_registerOrConditionFunction(funcJass) then
      return true
    elseif self:_registerOneLineConditionFunction(funcJass) then
      return true
    end
    return false
  end

  function InlineConditionPreprocessor:_registerAndConditionFunction(funcJass)
    local name, body = self:_parseConditionFunction(funcJass)
    if name == nil then
      return false
    end

    local conditions = {}
    local remaining = string.gsub(body, "    if %( not ([^\r\n]+) %) then[\r\n]+        return false[\r\n]+    endif[\r\n]+", function (condition)
      table.insert(conditions, condition)
      return ""
    end)
    if not string.match(remaining, "^%    return true$") then
      return false
    end
    if #conditions == 0 then
      return false
    end

    -- Inline nested condition
    for i, condition in ipairs(conditions) do
      local callingFunc = string.match(condition, "([%w_]+)[ \t]*%([ \t]*%)")
      if callingFunc ~= nil and self._funcTable[callingFunc] then
        conditions[i] = self._funcTable[callingFunc]
      end
    end

    local funcName = name
    local funcBody = "( " .. table.concat(conditions, " and ") .. " )"
    self._funcTable[funcName] = funcBody

    return true
  end

  function InlineConditionPreprocessor:_registerOrConditionFunction(funcJass)
    local name, body = self:_parseConditionFunction(funcJass)
    if name == nil then
      return false
    end

    local conditions = {}
    local remaining = string.gsub(body, "    if %( ([^\r\n]+) %) then[\r\n]+        return true[\r\n]+    endif[\r\n]+", function (condition)
      table.insert(conditions, condition)
      return ""
    end)
    if not string.match(remaining, "^%    return false$") then
      return false
    end
    if #conditions == 0 then
      return false
    end

    -- Inline nested condition
    for i, condition in ipairs(conditions) do
      local callingFunc = string.match(condition, "([%w_]+)[ \t]*%([ \t]*%)")
      if callingFunc ~= nil and self._funcTable[callingFunc] ~= nil then
        conditions[i] = self._funcTable[callingFunc]
      end
    end

    local funcName = name
    local funcBody = "( " .. table.concat(conditions, " or ") .. " )"
    self._funcTable[funcName] = funcBody

    return true
  end

  function InlineConditionPreprocessor:_registerOneLineConditionFunction(funcJass)
    local name, body = self:_parseConditionFunction(funcJass)
    if name == nil then
      return false
    end

    local condition = string.match(body, "^    return ([^\r\n]+)$")
    if condition == nil then
      return false
    end

    local conditionJassCode = JassCode.new(condition)
    if string.find(conditionJassCode.code, "//", 1, true) then
      return false
    end

    -- Inline nested condition
    condition = string.gsub(condition, "([%w_]+)([ \t]*%([ \t]*%))", function (callingFunc, suffix)
      if self._funcTable[callingFunc] ~= nil then
        return self._funcTable[callingFunc]
      end
      return callingFunc .. suffix
    end)

    local funcName = name
    local funcBody = "( " .. condition .. " )"
    self._funcTable[funcName] = funcBody

    return true
  end

  function InlineConditionPreprocessor:_parseConditionFunction(funcJass)
    local funcName, funcBody = string.match(funcJass, "^function ([%w_]+) takes nothing returns boolean[\r\n]+(.-)[\r\n]+endfunction$")
    return funcName, funcBody
  end

  function InlineConditionPreprocessor:_replaceConditionFunctionCalls(jass)
    local function replaceCondition(prefix, funcName, parenthesis)
      if self._funcTable[funcName] == nil then
        return prefix .. funcName .. parenthesis
      else
        return prefix .. self._funcTable[funcName]
      end
    end
    jass = string.gsub(jass, "([^%w_])(Trig_[%w_]+_Func[%w_]+)([ \t]*%([ \t]*%))", replaceCondition)
    return jass
  end

  function InlineConditionPreprocessor:_countFunctionReference(jass)
    for funcName in string.gmatch(jass, "[^\r\n]function[ \t]+(Trig_[%w_]+_Func[%w_]+)[ \t]*[^t]") do
      self._referenceTable[funcName] = true
    end
  end

  function InlineConditionPreprocessor:_replaceNotReferencedFunctions(jass)
    local pattern = "(function )(Trig_[%w_]+_Func[%w_]+)( takes nothing returns boolean[\r\n]+.-[\r\n]+endfunction)"
    jass = string.gsub(jass, pattern, function (prefix, name, suffix)
      local funcJass = prefix .. name .. suffix
      if self._funcTable[name] == nil or self._referenceTable[name] == true then
        return funcJass
      end
      return ""
    end)
    return jass
  end


  local function main()
    local jassPath = Preprocessor.getInstance():getJassFilePath()
    local jass = IO.readTextFile(jassPath)
    local processor = InlineConditionPreprocessor.new()
    local result = processor:process(jass)
    IO.writeTextFile(jassPath, result)
    return 0
  end

  return main()
end, "InlineCondition", {})
//! endpreprocessor
//! endnovjass

endlibrary
