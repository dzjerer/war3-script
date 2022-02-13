/*
 * Preprocessor LocalVariable (v2.0.0)
 *
 * GUI 환경에서 지역 변수를 함수 호출 형태로 정의하도록 도와주는 전처리기
 *
 * [코드 변환 규칙]
 * - call ${LocalVariable.define}(name, type)
 *   -> local type name
 *   지역 변수의 이름과 타입을 자유롭게 정의합니다.
 *
 * - call ${LocalVariable.globalToLocal}(udg_name)
 *   -> local inferred_type udg_name
 *   전역 변수와 동일한 이름과 동일한 타입을 갖는 지역 변수를 정의합니다.
 *   GUI 환경에서 전역 변수를 지역 변수로서 사용할 수 있습니다.
 *
 */
library PreprocessorLocalVariable requires PreprocessorJassCode, PreprocessorJassCodeUtil, PreprocessorPrototype

//! novjass
//! preprocessor
Preprocessor.getInstance():register(function ()
  local function iterLines(s)
    if s:sub(-1)~="\n" then s=s.."\n" end
    return s:gmatch("[^\n]*\n")
  end

  local function startswith(s, prefix)
    return string.sub(s, 1, string.len(prefix)) == prefix
  end

  local LocalVariablePreprocessor = {}
  LocalVariablePreprocessor.__index = LocalVariablePreprocessor

  function LocalVariablePreprocessor.new()
    local self = setmetatable({}, LocalVariablePreprocessor)
    return self
  end

  function LocalVariablePreprocessor:process(jass)
    self._jassCode = JassCode.new(jass)
    self._typeTable = self:_createUdgTypeTable()

    local result = {}
    local cursor = 1
    while true do
      local s, e
      s, e = string.find(self._jassCode.code, "%$%{LocalVariable%.[^\n]*", cursor)
      if s == nil then
        break
      end

      local line = self:_processLine(s, e)
      if startswith(line.code, "local ") or startswith(line.code, "set ") then
        s = s - 5
      end
      table.insert(result, string.sub(self._jassCode.jass, cursor, s - 1))
      table.insert(result, line.jass)

      cursor = e + 1
    end
    table.insert(result, string.sub(self._jassCode.jass, cursor))

    return table.concat(result)
  end

  function LocalVariablePreprocessor:_processLine(startIndex, endIndex)
    local jassCode = JassCode.sub(self._jassCode, startIndex, endIndex)

    local changed = true
    while changed do
      changed, jassCode = self:_processOnce(jassCode)
    end

    return jassCode
  end

  function LocalVariablePreprocessor:_processOnce(jassCode)
    local s, e
    s, e = string.find(jassCode.code, "%$%{LocalVariable%.[^%}]+%}")
    if s == nil then
      return false, jassCode
    end

    local identifier = string.sub(jassCode.jass, s, e)
    local subJassCode = JassCode.sub(jassCode, s)
    local changed = false

    if not changed then
      changed, subJassCode = self:_replaceGlobalToLocal(subJassCode, identifier)
    end
    if not changed then
      changed, subJassCode = self:_replaceDefine(subJassCode, identifier)
    end

    jassCode = JassCode.sub(jassCode, 1, s - 1) .. subJassCode
    return changed, jassCode
  end

  function LocalVariablePreprocessor:_createUdgTypeTable()
    local typeTable = {}
    local globals = string.match(self._jassCode.code, "[\r\n]globals%s(.-)[\r\n]endglobals%s")
    for line in iterLines(globals) do
      if string.match(line, "udg_") then
        local type, identifier = string.match(line, "%s*(.-)%s+(udg_%w+)")
        typeTable[identifier] = type
      end
    end
    return typeTable
  end

  function LocalVariablePreprocessor:_replaceDefine(jassCode, identifier)
    if identifier ~= "${LocalVariable.define}" then
      return false, jassCode
    end

    local args, _, argsEndIndex = JassCodeUtil.parseArguments(jassCode, string.len(identifier) + 1)
    if args == nil then
      return false, jassCode
    end
    if #args ~= 2 then
      error("The number of '${LocalVariable.define}' arguments must be 2, but " .. #args)
    end

    local identifierPos = JassCodeUtil.trimArgument(jassCode, args[1])
    local typePos = JassCodeUtil.trimArgument(jassCode, args[2])

    local varName = string.sub(jassCode.jass, identifierPos[1], identifierPos[2])
    local varType = string.sub(jassCode.jass, typePos[1], typePos[2])
    local replacement = JassCode.newCode("local " .. varType .. " " .. varName)

    local rest = JassCode.sub(jassCode, argsEndIndex + 1)

    jassCode = replacement .. rest
    return true, jassCode
  end

  function LocalVariablePreprocessor:_replaceGlobalToLocal(jassCode, identifier)
    if identifier ~= "${LocalVariable.globalToLocal}" then
      return false, jassCode
    end

    local args, _, argsEndIndex = JassCodeUtil.parseArguments(jassCode, string.len(identifier) + 1)
    if args == nil then
      return false, jassCode
    end
    if #args ~= 1 then
      error("The number of '${LocalVariable.globalToLocal}' arguments must be 1, but " .. #args)
    end

    local identifierPos = JassCodeUtil.trimArgument(jassCode, args[1])

    local varName = string.sub(jassCode.jass, identifierPos[1], identifierPos[2])
    local varType = self._typeTable[varName]
    local replacement = JassCode.newCode("local " .. varType .. " " .. varName)

    local rest = JassCode.sub(jassCode, argsEndIndex + 1)

    jassCode = replacement .. rest
    return true, jassCode
  end


  local function main()
    local jassPath = Preprocessor.getInstance():getJassFilePath()
    local jass = IO.readTextFile(jassPath)
    local processor = LocalVariablePreprocessor.new()
    local result = processor:process(jass)
    IO.writeTextFile(jassPath, result)
    return 0
  end

  return main()
end, "LocalVariablePreprocessor", {"Prototype"})
//! endpreprocessor
//! endnovjass

endlibrary
