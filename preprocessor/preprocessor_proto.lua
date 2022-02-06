do
  local PREPROCESSOR_VERSION = "0.0.0"
  local PREPROCESSOR_PATH = debug.getinfo(1, "S").source:sub(2)


  local function readTextFile(filePath)
    local text = nil
    local file = io.open(filePath, "r")
    text = file:read("*all")
    file:close()
    return text
  end

  local function writeTextFile(filePath, text)
    local file = io.open(filePath, "w")
    file:write(text)
    file:close()
  end

  local function dostring(str)
    local f = assert(loadstring(str))
    return f()
  end


  local Preprocessor = {}
  Preprocessor.__index = Preprocessor

  function Preprocessor.version()
    return PREPROCESSOR_VERSION
  end

  function Preprocessor.new()
    local self = setmetatable({}, Preprocessor)
    self._scriptFilePath = nil
    self._source = readTextFile(PREPROCESSOR_PATH)
    return self
  end

  function Preprocessor.run(scriptFilePath)
    local preprocessor = Preprocessor.new()
    local success, ret = pcall(Preprocessor.process, preprocessor, scriptFilePath)
    if preprocessor:isUpdated() then
      preprocessor:showMessage("Preprocessor updated. Please save the map again.")
      return 2
    end
    if success then
      return ret
    else
      preprocessor:showErrorMessage(ret)
      return 1
    end
  end

  function Preprocessor:getPreprocessorPath()
    return PREPROCESSOR_PATH
  end

  function Preprocessor:getScriptFilePath()
    return self._scriptFilePath
  end

  function Preprocessor:showMessage(msg)
    wehack.messagebox(msg, "Preprocessor", false)
  end

  function Preprocessor:showErrorMessage(msg)
    wehack.messagebox(msg, "Preprocessor", true)
  end

  function Preprocessor:isUpdated()
    local currentSource = readTextFile(PREPROCESSOR_PATH)
    return currentSource ~= self._source
  end

  function Preprocessor:process(scriptFilePath)
    local old_preprocessor = preprocessor
    preprocessor = self

    self._scriptFilePath = scriptFilePath
    local returnCode = self:_process()

    preprocessor = old_preprocessor
    return returnCode
  end

  function Preprocessor:_process(scriptFilePath)
    local script = readTextFile(self:getScriptFilePath())

    self:_executePreprocessBlocks(script)
    jass = self:_removePreprocessBlocks(script)
    writeTextFile(self:getScriptFilePath(), jass)

    return 0
  end

  function Preprocessor:_executePreprocessBlocks(script)
    local firstErr = nil

    for block in script:gmatch("[\r\n]%s*//!%spreprocessor%s*[\r\n](.-)[\r\n]%s*//!%s*endpreprocessor%s*") do
      local success, err = pcall(dostring, block)
      if not success and firstErr == nil then
        firstErr = err
      end
    end

    if firstErr ~= nil then
      error(firstErr)
    end
  end

  function Preprocessor:_removePreprocessBlocks(script)
    return script:gsub("[\r\n](%s*//!%spreprocessor%s*[\r\n].-[\r\n]%s*//!%s*endpreprocessor%s-)[\r\n]", "\n")
  end

  return Preprocessor
end
