/*
 * PreprocessorInstallerForJNEditor (v0.0.0)
 *
 * JNEditor에 전처리기(Preprocessor)를 설치하는 스크립트입니다.
 *
 * [설치 방법]
 * 1. 새 지도를 만듭니다.
 * 2. 본 스크립트를 새 지도에 복사합니다.
 * 3. 지도를 두 번 저장합니다.
 * 4. "Preprocessor installed. Please restart WorldEdit." 라는 메시지가 나오면 에디터를 재시작합니다.
 * 5. 설치 끝!
 *
 */
library PreprocessorInstallerForJNEditor

//! novjass
//! preprocessor
--[==[
//! endnovjass

//! externalblock extension=lua ObjectMerger $FILENAME$

//! i -- install_loader.lua:start
//! i do
//! i   WEHACK_FILE_PATH = "wehack.lua"
//! i   PREPROCESSOR_PATH = "External Tools\\preprocessor.lua"
//! i   JASS_SCRIPT_PATH = "logs\\war3map.j"
//! i   TEMP_DIR = "logs"
//! i 
//! i   WEHACK_INJECTION_TEMPLATE = [[
//! i -- Preprocessor:begin
//! i -- Loader.version: 0.0.0
//! i         if toolresult == 0 and grim.exists("{PREPROCESSOR_PATH}") then
//! i             Preprocessor = dofile("{PREPROCESSOR_PATH}")
//! i             toolresult = Preprocessor.run("{JASS_SCRIPT_PATH}")
//! i         end
//! i -- Preprocessor:end
//! i ]]
//! i 
//! i   PREPROCESSOR_PROTO_LUA = [[
//! i do
//! i   local PREPROCESSOR_VERSION = "0.0.0"
//! i   local PREPROCESSOR_PATH = debug.getinfo(1, "S").source:sub(2)
//! i 
//! i 
//! i   local function readTextFile(filePath)
//! i     local text = nil
//! i     local file = io.open(filePath, "r")
//! i     text = file:read("*all")
//! i     file:close()
//! i     return text
//! i   end
//! i 
//! i   local function dostring(str)
//! i     local f = assert(loadstring(str))
//! i     return f()
//! i   end
//! i 
//! i 
//! i   local Preprocessor = {}
//! i   Preprocessor.__index = Preprocessor
//! i 
//! i   function Preprocessor.version()
//! i     return PREPROCESSOR_VERSION
//! i   end
//! i 
//! i   function Preprocessor.getInstance()
//! i     if Preprocessor._instance == nil then
//! i       Preprocessor._instance = Preprocessor._new()
//! i     end
//! i     return Preprocessor._instance
//! i   end
//! i 
//! i   function Preprocessor._new()
//! i     local self = setmetatable({}, Preprocessor)
//! i     self._jassFilePath = nil
//! i     self._source = readTextFile(self.getSourceFilePath())
//! i     return self
//! i   end
//! i 
//! i   function Preprocessor.run(jassFilePath)
//! i     local preprocessor = Preprocessor.getInstance()
//! i     local success, ret = pcall(Preprocessor.process, preprocessor, jassFilePath)
//! i     if preprocessor:isUpdated() then
//! i       preprocessor:showMessage("Preprocessor updated. Please save the map again.")
//! i       return 2
//! i     end
//! i     if not success then
//! i       preprocessor:showErrorMessage(ret)
//! i       return 1
//! i     end
//! i     return ret
//! i   end
//! i 
//! i   function Preprocessor.getSourceFilePath()
//! i     return PREPROCESSOR_PATH
//! i   end
//! i 
//! i   function Preprocessor:getJassFilePath()
//! i     return self._jassFilePath
//! i   end
//! i 
//! i   function Preprocessor:showMessage(msg)
//! i     wehack.messagebox(msg, "Preprocessor", false)
//! i   end
//! i 
//! i   function Preprocessor:showErrorMessage(msg)
//! i     wehack.messagebox(msg, "Preprocessor", true)
//! i   end
//! i 
//! i   function Preprocessor:isUpdated()
//! i     local currentSource = readTextFile(self.getSourceFilePath())
//! i     return currentSource ~= self._source
//! i   end
//! i 
//! i   function Preprocessor:process(jassFilePath)
//! i     self._jassFilePath = jassFilePath
//! i     local script = readTextFile(jassFilePath)
//! i     self:_executePreprocessBlocks(script)
//! i     return 0
//! i   end
//! i 
//! i   function Preprocessor:_executePreprocessBlocks(script)
//! i     local firstErr = nil
//! i 
//! i     for block in script:gmatch("[\r\n]%s*//!%spreprocessor%s*[\r\n](.-)[\r\n]%s*//!%s*endpreprocessor%s*") do
//! i       local success, err = pcall(dostring, block)
//! i       if not success and firstErr == nil then
//! i         firstErr = err
//! i       end
//! i     end
//! i 
//! i     if firstErr ~= nil then
//! i       error(firstErr)
//! i     end
//! i   end
//! i 
//! i   return Preprocessor
//! i end
//! i ]]
//! i 
//! i local function copyFile(src, dst)
//! i   os.execute('copy "' .. src .. '" "' .. dst .. '"')
//! i end
//! i 
//! i local function readTextFile(filePath)
//! i   local text = nil
//! i   local file = io.open(filePath, "r")
//! i   text = file:read("*all")
//! i   file:close()
//! i   return text
//! i end
//! i 
//! i local function writeTextFile(filePath, text)
//! i   local file = io.open(filePath, "w")
//! i   file:write(text)
//! i   file:close()
//! i end
//! i 
//! i local function getWehackInjectionCode()
//! i   local preprocessorPath = PREPROCESSOR_PATH:gsub('\\', '\\\\')
//! i   local jassScriptPath = JASS_SCRIPT_PATH:gsub('\\', '\\\\')
//! i 
//! i   local code = WEHACK_INJECTION_TEMPLATE
//! i   code = code:gsub("{PREPROCESSOR_PATH}", preprocessorPath)
//! i   code = code:gsub("{JASS_SCRIPT_PATH}", jassScriptPath)
//! i   return code
//! i end
//! i 
//! i local function msgbox(msg)
//! i     local filePath = TEMP_DIR .. "\\temp.vbs"
//! i     local script
//! i     msg = msg:gsub('"', '""')
//! i     msg = msg:gsub('\r', '"&Chr(13)&"')
//! i     msg = msg:gsub('\n', '"&Chr(10)&"')
//! i     script = 'MsgBox "" & "' .. msg .. '", 0, "Preprocessor Installer"'
//! i 
//! i     writeTextFile(filePath, script)
//! i     os.execute(filePath)
//! i   end
//! i 
//! i   local function isFile(filePath)
//! i     local file = io.open(filePath, "r")
//! i     if file ~= nil then
//! i       file:close()
//! i       return true
//! i     else
//! i       return false
//! i     end
//! i   end
//! i 
//! i   local function checkLauncherInstalled()
//! i     local script = readTextFile(WEHACK_FILE_PATH)
//! i     return script:match("[\r\n]%s*-- Preprocessor:begin%s") ~= nil
//! i   end
//! i 
//! i   local function installLauncher()
//! i     local script = readTextFile(WEHACK_FILE_PATH)
//! i     local pos = script:find("[\r\n]+[^\r\n]+%Wtoolresult%s*==%s*0%W")
//! i     local injection = getWehackInjectionCode()
//! i     local newScript = script:sub(1, pos) .. injection .. script:sub(pos+1)
//! i     writeTextFile(WEHACK_FILE_PATH, newScript)
//! i     return script ~= newScript
//! i   end
//! i 
//! i   local function installPreprocessor()
//! i     writeTextFile(PREPROCESSOR_PATH, PREPROCESSOR_PROTO_LUA)
//! i     return true
//! i   end
//! i 
//! i   local function uninstallLauncher()
//! i     local script = readTextFile(WEHACK_FILE_PATH)
//! i     script = script:gsub("([\r\n]%s*-- Preprocessor:begin%s*[\r\n].-[\r\n]%s*-- Preprocessor:end%s*)([\r\n])", "%2")
//! i     writeTextFile(WEHACK_FILE_PATH, script)
//! i   end
//! i 
//! i   local function checkBackupExists(filePath)
//! i     local backupFilePath = filePath .. ".bak"
//! i     return isFile(backupFilePath)
//! i   end
//! i 
//! i   local function backupFile(filePath)
//! i     local backupFilePath = filePath .. ".bak"
//! i     copyFile(filePath, backupFilePath)
//! i   end
//! i 
//! i   local function checkJNEditor()
//! i     local script = readTextFile(WEHACK_FILE_PATH)
//! i     return script:match("JassNative Editor") ~= nil
//! i   end
//! i 
//! i   local function main()
//! i     if not isFile(WEHACK_FILE_PATH) then
//! i       msgbox("Preprocessor installation failed. '" .. WEHACK_FILE_PATH .. "' does not exist.")
//! i       return 1
//! i     end
//! i     if not checkJNEditor() then
//! i       msgbox("Preprocessor installation failed. JassNative Editor is not detected.")
//! i       return 1
//! i     end
//! i 
//! i     if not checkBackupExists(WEHACK_FILE_PATH) then
//! i       backupFile(WEHACK_FILE_PATH)
//! i     end
//! i     if checkLauncherInstalled() then
//! i       uninstallLauncher()
//! i     end
//! i     if not installLauncher() then
//! i       msgbox("Preprocessor installation failed. Unknown 'wehack.lua'.")
//! i       return 1
//! i     end
//! i     if not installPreprocessor() then
//! i       msgbox("Preprocessor installation failed. Cannot create preprocessor script.")
//! i       return 1
//! i     end
//! i     msgbox("Preprocessor installed. Please restart WorldEdit.")
//! i     return 0
//! i   end
//! i 
//! i   return main()
//! i end
//! i -- install_loader.lua:end

//! endexternalblock

//! novjass
]==]--
//! endpreprocessor
//! endnovjass

endlibrary
