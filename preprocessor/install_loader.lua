do
  WEHACK_FILE_PATH = "wehack.lua"
  PREPROCESSOR_PATH = "External Tools\\preprocessor.lua"
  JASS_SCRIPT_PATH = "logs\\war3map.j"
  TEMP_DIR = "logs"

  WEHACK_INJECTION_TEMPLATE = [[
-- Preprocessor:begin
-- Loader.version: 0.0.0
        if toolresult == 0 then
            local Preprocessor = dofile("{PREPROCESSOR_PATH}")
            toolresult = Preprocessor.run("{JASS_SCRIPT_PATH}")
        end
-- Preprocessor:end
]]

  PREPROCESSOR_PROTO_LUA = [[
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
]]

  function msgbox(msg)
    local filePath = TEMP_DIR .. "\\temp.vbs"
    local script
    msg = msg:gsub('"', '""')
    msg = msg:gsub('\r', '"&Chr(13)&"')
    msg = msg:gsub('\n', '"&Chr(10)&"')
    script = 'MsgBox "" & "' .. msg .. '", 0, "Preprocessor Installer"'

    writeTextFile(filePath, script)
    os.execute(filePath)
  end

  function isFile(filePath)
    local file = io.open(filePath, "r")
    if file ~= nil then
      file:close()
      return true
    else
      return false
    end
  end

  function copyFile(src, dst)
    os.execute('copy "' .. src .. '" "' .. dst .. '"')
  end

  function readTextFile(filePath)
    local text = nil
    local file = io.open(filePath, "r")
    text = file:read("*all")
    file:close()
    return text
  end

  function writeTextFile(filePath, text)
    local file = io.open(filePath, "w")
    file:write(text)
    file:close()
  end

  function checkLauncherInstalled()
    local script = readTextFile(WEHACK_FILE_PATH)
    return script:match("[\r\n]%s*-- Preprocessor:begin%s") ~= nil
  end

  function installLauncher()
    local script = readTextFile(WEHACK_FILE_PATH)
    local pos = script:find("[\r\n]+[^\r\n]+%Wtoolresult%s*==%s*0%W")
    local injection = getWehackInjectionCode()
    newScript = script:sub(1, pos) .. injection .. script:sub(pos+1)
    writeTextFile(WEHACK_FILE_PATH, newScript)
    return script ~= newScript
  end

  function installPreprocessor()
    writeTextFile(PREPROCESSOR_PATH, PREPROCESSOR_PROTO_LUA)
    return true
  end

  function uninstallLauncher()
    local script = readTextFile(WEHACK_FILE_PATH)
    script = script:gsub("([\r\n]%s*-- Preprocessor:begin%s*[\r\n].-[\r\n]%s*-- Preprocessor:end%s*)([\r\n])", "%2")
    writeTextFile(WEHACK_FILE_PATH, script)
  end

  function getWehackInjectionCode()
    code = WEHACK_INJECTION_TEMPLATE
    code = code:gsub("{PREPROCESSOR_PATH}", PREPROCESSOR_PATH:gsub('\\', '\\\\'))
    code = code:gsub("{JASS_SCRIPT_PATH}", JASS_SCRIPT_PATH:gsub('\\', '\\\\'))
    return code
  end

  function checkBackupExists(filePath)
    local backupFilePath = filePath .. ".bak"
    return isFile(backupFilePath)
  end

  function backupFile(filePath)
    local backupFilePath = filePath .. ".bak"
    copyFile(filePath, backupFilePath)
  end

  function checkJNEditor()
    local script = readTextFile(WEHACK_FILE_PATH)
    return script:match("JassNative Editor") ~= nil
  end

  function main()
    if not isFile(WEHACK_FILE_PATH) then
      msgbox("Preprocessor installation failed. '" .. WEHACK_FILE_PATH .. "' does not exist.")
      return 1
    end
    if not checkJNEditor() then
      msgbox("Preprocessor installation failed. JassNative Editor is not detected.")
      return 1
    end

    if not checkBackupExists(WEHACK_FILE_PATH) then
      backupFile(WEHACK_FILE_PATH)
    end
    if checkLauncherInstalled() then
      uninstallLauncher()
    end
    if not installLauncher() then
      msgbox("Preprocessor installation failed. Unknown 'wehack.lua'.")
      return 1
    end
    if not installPreprocessor() then
      msgbox("Preprocessor installation failed. Cannot create preprocessor script.")
      return 1
    end
    msgbox("Preprocessor installed. Please restart WorldEdit.")
    return 0
  end

  return main()
end
