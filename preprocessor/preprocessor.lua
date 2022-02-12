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

  local function iterLines(s)
    if s:sub(-1)~="\n" then s=s.."\n" end
    return s:gmatch("[^\n]*\n")
  end


  local Preprocessor = {}
  Preprocessor.__index = Preprocessor

  function Preprocessor.version()
    return PREPROCESSOR_VERSION
  end

  function Preprocessor.new()
    local self = setmetatable({}, Preprocessor)
    self._initializerQueue = {}
    self._initializedStatus = {}
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

  function Preprocessor:process(scriptFilePath)
    local old_preprocessor = preprocessor
    preprocessor = self

    self._scriptFilePath = scriptFilePath
    local returnCode = self:_process()

    preprocessor = old_preprocessor
    return returnCode
  end

  function Preprocessor:_process()
    local script = readTextFile(self:getScriptFilePath())
    local preprocessBlocks, jass = self:_extractPreprocessBlocks(script)
    writeTextFile(self:getScriptFilePath(), jass)

    self:_executePreprocessBlocks(preprocessBlocks)
    self:_initModules()

    return 0
  end

  function Preprocessor:_extractPreprocessBlocks(script)
    local jass = {}
    local blocks = {}
    local block = nil

    for line in iterLines(script) do
      local command = line:match("^%s*//!%s*(%w+)%s*$")
      if command == "preprocessor" then
        if block ~= nil then
          error("Missing '//! endpreprocess'")
        end
        block = {}
      elseif command == "endpreprocessor" then
        if block == nil then
          error("Missing '//! preprocess'")
        end
        block = table.concat(block)
        table.insert(blocks, block)
        block = nil
      else
        if block == nil then
          table.insert(jass, line)
        else
          table.insert(block, line)
        end
      end
    end
    jass = table.concat(jass)
    return blocks, jass
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

  function Preprocessor:_initModules()
    repeat
      initializingModules = self:_popInitializableModules()
      for _, module in ipairs(initializingModules) do
        self:_initialize(module)
      end
    until #initializingModules == 0

    if #self._initializerQueue > 0 then
      error("Dipendency Error")
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
    local func, name, dependencies = unpack(module)
    for _, dep in ipairs(dependencies) do
      if self._initializedStatus[dep] ~= true then
        return false
      end
    end
    return true
  end

  function Preprocessor:_initialize(module)
    local func, name, dependencies = unpack(module)
    func()
    if name ~= nil then
      self._initializedStatus[name] = true
    end
  end

  return Preprocessor
end
