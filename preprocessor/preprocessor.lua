do
  local PREPROCESSOR_VERSION = "2.0.1"
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

  function Preprocessor.getInstance()
    if Preprocessor._instance == nil then
      Preprocessor._instance = Preprocessor._new()
    end
    return Preprocessor._instance
  end

  function Preprocessor._new()
    local self = setmetatable({}, Preprocessor)
    self._initializerQueue = {}
    self._initializedStatus = {}
    self._jassFilePath = nil
    self._source = readTextFile(PREPROCESSOR_PATH)
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

  function Preprocessor:register(func, name, dependencies)
    if dependencies == nil then
      dependencies = {}
    end
    if name ~= nil and self._initializedStatus[name] ~= nil then
      error("Duplicated module name: " .. name)
    end

    table.insert(self._initializerQueue, {func, name, dependencies})
    if name ~= nil then
      self._initializedStatus[name] = false
    end
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

  function Preprocessor:process(jassFilePath)
    self._jassFilePath = jassFilePath
    return self:_process()
  end

  function Preprocessor:_process()
    local jass = readTextFile(self:getJassFilePath())
    local preprocessBlocks, filteredJass = self:_extractPreprocessBlocks(jass)
    writeTextFile(self:getJassFilePath(), filteredJass)

    self:_executePreprocessBlocks(preprocessBlocks)
    self:_executeModulesInQueue()

    return 0
  end

  function Preprocessor:_extractPreprocessBlocks(jass)
    local blocks = {}

    local function handleBlock(block)
      local pattern = "\n[ \t]*//![ \t]*preprocessor%s*\n(.-)\n[ \t]*//![ \t]*endpreprocessor[ \t]*\n"
      local lua = string.match(block, pattern)
      table.insert(blocks, lua)
      return "\n"
    end

    local pattern = "\n[ \t]*//![ \t]*preprocessor%s*\n.-\n[ \t]*//![ \t]*endpreprocessor[ \t]*\n"
    local filteredJass = string.gsub(jass, pattern, handleBlock)

    return blocks, filteredJass
  end

  function Preprocessor:_executePreprocessBlocks(blocks)
    local firstErr = nil

    for _, block in ipairs(blocks) do
      local success, err = pcall(dostring, block)
      if not success and firstErr == nil then
        firstErr = err
      end
    end

    if firstErr ~= nil then
      error(firstErr)
    end
  end

  function Preprocessor:_executeModulesInQueue()
    repeat
      local initializingModules = self:_popInitializableModules()
      for _, module in ipairs(initializingModules) do
        self:_initializeModule(module)
      end
    until #initializingModules == 0

    if #self._initializerQueue > 0 then
      error("Missing dependency error")
    end
  end

  function Preprocessor:_popInitializableModules()
    local initializableModules = {}
    local remainingModules = {}
    for _, module in ipairs(self._initializerQueue) do
      if self:_checkInitializable(module) then
        table.insert(initializableModules, module)
      else
        table.insert(remainingModules, module)
      end
    end
    self._initializerQueue = remainingModules
    return initializableModules
  end

  function Preprocessor:_checkInitializable(module)
    local _, _, dependencies = unpack(module)
    for _, dep in ipairs(dependencies) do
      if self._initializedStatus[dep] ~= true then
        return false
      end
    end
    return true
  end

  function Preprocessor:_initializeModule(module)
    local func, name, _ = unpack(module)
    func()
    if name ~= nil then
      self._initializedStatus[name] = true
    end
  end

  return Preprocessor
end
