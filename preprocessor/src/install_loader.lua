do
  WEHACK_FILE_PATH = "wehack.lua"
  PREPROCESSOR_PATH = "External Tools\\preprocessor.lua"
  JASS_SCRIPT_PATH = "logs\\war3map.j"
  TEMP_DIR = "logs"

  WEHACK_INJECTION_TEMPLATE = [[
-- Preprocessor:begin
-- Loader.version: 0.0.0
        if toolresult == 0 and grim.exists("{PREPROCESSOR_PATH}") then
            Preprocessor = dofile("{PREPROCESSOR_PATH}")
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
]]

local function copyFile(src, dst)
  os.execute('copy "' .. src .. '" "' .. dst .. '"')
end

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

local function getWehackInjectionCode()
  local preprocessorPath = PREPROCESSOR_PATH:gsub('\\', '\\\\')
  local jassScriptPath = JASS_SCRIPT_PATH:gsub('\\', '\\\\')

  local code = WEHACK_INJECTION_TEMPLATE
  code = code:gsub("{PREPROCESSOR_PATH}", preprocessorPath)
  code = code:gsub("{JASS_SCRIPT_PATH}", jassScriptPath)
  return code
end

local function msgbox(msg)
    local filePath = TEMP_DIR .. "\\temp.vbs"
    local script
    msg = msg:gsub('"', '""')
    msg = msg:gsub('\r', '"&Chr(13)&"')
    msg = msg:gsub('\n', '"&Chr(10)&"')
    script = 'MsgBox "" & "' .. msg .. '", 0, "Preprocessor Installer"'

    writeTextFile(filePath, script)
    os.execute(filePath)
  end

  local function isFile(filePath)
    local file = io.open(filePath, "r")
    if file ~= nil then
      file:close()
      return true
    else
      return false
    end
  end

  local function checkLauncherInstalled()
    local script = readTextFile(WEHACK_FILE_PATH)
    return script:match("[\r\n]%s*-- Preprocessor:begin%s") ~= nil
  end

  local function installLauncher()
    local script = readTextFile(WEHACK_FILE_PATH)
    local pos = script:find("[\r\n]+[^\r\n]+%Wtoolresult%s*==%s*0%W")
    local injection = getWehackInjectionCode()
    local newScript = script:sub(1, pos) .. injection .. script:sub(pos+1)
    writeTextFile(WEHACK_FILE_PATH, newScript)
    return script ~= newScript
  end

  local function installPreprocessor()
    writeTextFile(PREPROCESSOR_PATH, PREPROCESSOR_PROTO_LUA)
    return true
  end

  local function uninstallLauncher()
    local script = readTextFile(WEHACK_FILE_PATH)
    script = script:gsub("([\r\n]%s*-- Preprocessor:begin%s*[\r\n].-[\r\n]%s*-- Preprocessor:end%s*)([\r\n])", "%2")
    writeTextFile(WEHACK_FILE_PATH, script)
  end

  local function checkBackupExists(filePath)
    local backupFilePath = filePath .. ".bak"
    return isFile(backupFilePath)
  end

  local function backupFile(filePath)
    local backupFilePath = filePath .. ".bak"
    copyFile(filePath, backupFilePath)
  end

  local function checkJNEditor()
    local script = readTextFile(WEHACK_FILE_PATH)
    return script:match("JassNative Editor") ~= nil
  end

  local function main()
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
