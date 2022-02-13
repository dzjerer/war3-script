/*
 * Preprocessor Prototype (v2.0.0)
 *
 * GUI 환경에서 함수를 자유롭게 호출할 수 있도록 도와주는 전처리기
 *
 * [코드 변환 규칙]
 * - ${Prototype.funcWithHint(2)}("dummy", arg0, "dummy", arg1, "dummy", funcName, "dummy")
 *   -> funcName(arg0, arg1)
 *   함수를 치환합니다.
 *   ${Prototype.funcWithHint(n)}의 n은 사용할 인자 개수입니다.
 *   "dummy" 인자는 GUI에서 설명을 적는 문자열입니다.
 *
 * - ${Prototype.eventFuncWithHint(2)}(trigger, "dummy", arg0, "dummy", arg1, "dummy", funcName, "dummy")
 *   -> funcName(trigger, arg0, arg1)
 *   ${Prototype.funcWithHint(n)}의 이벤트 함수 버전
 *   첫 번째 인자로 트리거를 받습니다.
 *
 * - ${Prototype.value_x}(value)
 *   -> value
 *   value 값으로 치환합니다.
 *
 * - call EnumItemsInRectBJ( func( ... , ${Prototype.callback}, ... ), function callbackFunc )
 *   -> call func( ... , function callbackFunc, ... )
 *   콜백 함수를 치환합니다.
 *   콜백 함수를 정의하는 바깥 함수는 EnumItemsInRectBJ() 만 허용됩니다.
 *
 */
library PreprocessorPrototype requires PreprocessorJassCode, PreprocessorJassCodeUtil

//! novjass
//! preprocessor
Preprocessor.getInstance():register(function ()
  local PrototypePreprocessor = {}
  PrototypePreprocessor.__index = PrototypePreprocessor

  function PrototypePreprocessor.new()
    local self = setmetatable({}, PrototypePreprocessor)
    return self
  end

  function PrototypePreprocessor:process(jass)
    self._jassCode = JassCode.new(jass)

    local result = {}
    local cursor = 1
    while true do
      local s, e
      s, e = string.find(self._jassCode.code, "[^\r\n]+", cursor)
      if s == nil then
        break
      end

      local line = self:_processLine(s, e)
      table.insert(result, string.sub(self._jassCode.jass, cursor, s - 1))
      table.insert(result, line)

      cursor = e + 1
    end
    table.insert(result, string.sub(self._jassCode.jass, cursor))

    return table.concat(result)
  end

  function PrototypePreprocessor:_processLine(startIndex, endIndex)
    local jassCode = JassCode.sub(self._jassCode, startIndex, endIndex)

    local changed = true
    while changed do
      changed, jassCode = self:_processOnce(jassCode)
    end

    return jassCode.jass
  end

  function PrototypePreprocessor:_processOnce(jassCode)
    if not string.find(jassCode.code, "${Prototype.", 1, true) then
      return false, jassCode
    end

    local changed = false
    if not changed then
      changed, jassCode = self:_replaceFuncWithHint(jassCode)
    end
    if not changed then
      changed, jassCode = self:_replaceEventFuncWithHint(jassCode)
    end
    if not changed then
      changed, jassCode = self:_replaceValue(jassCode)
    end
    if not changed then
      changed, jassCode = self:_replaceCallback(jassCode)
    end

    return changed, jassCode
  end

  function PrototypePreprocessor:_replaceFuncWithHint(jassCode)
    local s, e, n = string.find(jassCode.code, "%$%{Prototype%.funcWithHint%((%d+)%)%}")
    if n == nil then
      return false, jassCode
    end

    local args, _, argsEndIndex = JassCodeUtil.parseArguments(jassCode, e + 1)
    if args == nil then
      return false, jassCode
    end

    local func = JassCodeUtil.trimArgument(jassCode, args[n*2 + 2])
    local funcArgs = {}
    for i=1,n do
      table.insert(funcArgs, JassCodeUtil.trimArgument(jassCode, args[i*2]))
    end

    local begin = JassCode.sub(jassCode, 1, s - 1)

    local replacement = JassCode.sub(jassCode, func[1], func[2])
    replacement = replacement .. JassCode.newCode("( ")
    for i, arg in ipairs(funcArgs) do
      if i > 1 then
        replacement = replacement .. JassCode.newCode(", ")
      end
      replacement = replacement .. JassCode.sub(jassCode, arg[1], arg[2])
    end
    replacement = replacement .. JassCode.newCode(" )")

    local rest = JassCode.sub(jassCode, argsEndIndex + 1)

    jassCode = begin .. replacement .. rest
    return true, jassCode
  end

  function PrototypePreprocessor:_replaceEventFuncWithHint(jassCode)
    local s, e, n = string.find(jassCode.code, "%$%{Prototype%.eventFuncWithHint%((%d+)%)%}")
    if n == nil then
      return false, jassCode
    end

    local args, _, argsEndIndex = JassCodeUtil.parseArguments(jassCode, e + 1)
    if args == nil then
      return false, jassCode
    end

    local trigger = JassCodeUtil.trimArgument(jassCode, args[1])
    local func = JassCodeUtil.trimArgument(jassCode, args[1 + n*2 + 2])
    local funcArgs = {}
    for i=1,n do
      table.insert(funcArgs, JassCodeUtil.trimArgument(jassCode, args[1 + i*2]))
    end

    local begin = JassCode.sub(jassCode, 1, s - 1)

    local replacement = JassCode.sub(jassCode, func[1], func[2])
    replacement = replacement .. JassCode.newCode("( ")
    replacement = replacement .. JassCode.sub(jassCode, trigger[1], trigger[2])
    for i, arg in ipairs(funcArgs) do
      replacement = replacement .. JassCode.newCode(", ") .. JassCode.sub(jassCode, arg[1], arg[2])
    end
    replacement = replacement .. JassCode.newCode(" )")

    local rest = JassCode.sub(jassCode, argsEndIndex + 1)

    jassCode = begin .. replacement .. rest
    return true, jassCode
  end

  function PrototypePreprocessor:_replaceValue(jassCode)
    local s, e = string.find(jassCode.code, "%$%{Prototype%.value_[%w_]+%}")
    if s == nil then
      return false, jassCode
    end

    local args, _, argsEndIndex = JassCodeUtil.parseArguments(jassCode, e + 1)
    if args == nil then
      return false, jassCode
    end

    local value = JassCodeUtil.trimArgument(jassCode, args[1])

    local begin = JassCode.sub(jassCode, 1, s - 1)
    local replacement = JassCode.sub(jassCode, value[1], value[2])
    local rest = JassCode.sub(jassCode, argsEndIndex + 1)

    jassCode = begin .. replacement .. rest
    return true, jassCode
  end

  function PrototypePreprocessor:_replaceCallback(jassCode)
    if not string.find(jassCode.code, "${Prototype.callback}", 1, true) then
      return false, jassCode
    end

    local pattern = "(%s*call%s+)EnumItemsInRectBJ%s*%(%s*%(%s*(.+)%s*%)%s*,%s*(function%s+[%w_]+)%s*%)"
    local command, body, callback = string.match(jassCode.jass, pattern)
    if command == nil then
      return false, jassCode
    end

    local jass = command .. body
    jassCode = JassCode.new(jass)

    while true do
      local s, e = string.find(jassCode.code, "${Prototype.callback}", 1, true)
      if s == nil then
        break
      end
      
      jassCode = JassCode.sub(jassCode, 1, s-1) .. JassCode.newCode(callback) .. JassCode.sub(jassCode, e+1)
    end

    return true, jassCode
  end


  local function main()
    local jassPath = Preprocessor.getInstance():getJassFilePath()
    local jass = IO.readTextFile(jassPath)
    local processor = PrototypePreprocessor.new()
    local result = processor:process(jass)
    IO.writeTextFile(jassPath, result)
    return 0
  end

  return main()
end, "Prototype", {})
//! endpreprocessor
//! endnovjass

endlibrary
