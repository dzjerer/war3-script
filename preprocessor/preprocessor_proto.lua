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

  local function dostring(str)
    local f = assert(loadstring(str))
    return f()
  end


  local Preprocessor = {}
  Preprocessor.__index = Preprocessor

  function Preprocessor.version()
    return PREPROCESSOR_VERSION
  end

  function Preprocessor.getInstance()
    if Preprocessor._instance == nil then
      Preprocessor._instance = Preprocessor._new()
    end
    return Preprocessor._instance
  end

  function Preprocessor._new()
    local self = setmetatable({}, Preprocessor)
    self._jassFilePath = nil
    self._source = readTextFile(self.getSourceFilePath())
    return self
  end

  function Preprocessor.run(jassFilePath)
    local preprocessor = Preprocessor.getInstance()
    local success, ret = pcall(Preprocessor.process, preprocessor, jassFilePath)
    if preprocessor:isUpdated() then
      preprocessor:showMessage("Preprocessor updated. Please save the map again.")
      return 2
    end
    if not success then
      preprocessor:showErrorMessage(ret)
      return 1
    end
    return ret
  end

  function Preprocessor.getSourceFilePath()
    return PREPROCESSOR_PATH
  end

  function Preprocessor:getJassFilePath()
    return self._jassFilePath
  end

  function Preprocessor:showMessage(msg)
    wehack.messagebox(msg, "Preprocessor", false)
  end

  function Preprocessor:showErrorMessage(msg)
    wehack.messagebox(msg, "Preprocessor", true)
  end

  function Preprocessor:isUpdated()
    local currentSource = readTextFile(self.getSourceFilePath())
    return currentSource ~= self._source
  end

  function Preprocessor:process(jassFilePath)
    self._jassFilePath = jassFilePath
    local script = readTextFile(jassFilePath)
    self:_executePreprocessBlocks(script)
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

  return Preprocessor
end
