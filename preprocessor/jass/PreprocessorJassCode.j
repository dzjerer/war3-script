/*
 * Preprocessor JassCode (v2.0.0)
 *
 * 스크립트 파싱을 돕는 JassCode class
 * jass 스크립트와 code를 함께 관리해줍니다.
 * code는 분리된 주석이 제거되고 필터링된 문자열이 있는 jass 스크립트입니다.
 *
 */
library PreprocessorJassCode

//! novjass
//! preprocessor
do
  local function findNextSpecialToken(s, i)
    local token
    while true do
      i = string.find(s, "[/\"'%*]", i)
      if i == nil then
        break
      end

      token = string.sub(s, i, i)
      if token == "\"" or token == "'" then
        break
      end

      token = string.sub(s, i, i + 1)
      if token == "/*" or token == "//" or token == "*/" then
        break
      end

      i = i + 1
      token = nil
    end

    if token == nil then
      return nil, nil, nil
    end

    local startIndex = i
    local endIndex = i + string.len(token) - 1
    return token, startIndex, endIndex
  end

  local function findDelimitedCommentsBlock(script, startIndex)
    local endIndex = nil
    local i = startIndex + 2
    local depth = 1
    local token

    while true do
      token, _, i = findNextSpecialToken(script, i)
      if token == nil then
        break
      end
      i = i + 1

      if token == "/*" then
        depth = depth + 1
      elseif token == "*/" then
        depth = depth - 1
        if depth == 0 then
          endIndex = i - 1
          break
        end
      end
    end

    return startIndex, endIndex
  end

  local function filterLiteral(script)
    local result = {}
    local token, s, e
    local cursor = 1
    local lastCursor = cursor
    local sub

    while true do
      token, s, cursor = findNextSpecialToken(script, cursor)
      if token == nil then
        break
      end
      cursor = cursor + 1

      if token == "/*" then
        s, e = findDelimitedCommentsBlock(script, s)
      elseif token == "//" then
        _, e = string.find(script, "[^\r\n]*", s + token:len())
      elseif token == "\"" or token == "'" then
        sub = string.match(script, token.."([^\r\n]*)", s)
        sub = string.gsub(sub, "\\.", "__")
        e = string.find(sub, token)
        if e ~= nil then
          e = s + e
        end
      elseif token == "*/" then
        error("Parse error: Missing start of '" .. token .. "' (" .. s .. ")")
      end

      if e == nil then
        error("Parse error: Missing end of '" .. token .. "' (" .. s .. ")")
      end

      table.insert(result, string.sub(script, lastCursor, s - 1))
      if token == "/*" then
        local text = string.sub(script, s+2, e-2)
        local replacement = string.gsub(text, "[^\r\n]", " ")
        table.insert(result, "  " .. replacement .. "  ")
      elseif token == "//" then
        table.insert(result, string.sub(script, s, e))
      elseif token == "\"" or token == "'" then
        table.insert(result, (string.sub(script, s, s) .. string.rep("_", e - s - 1) .. string.sub(script, e, e)))
      end

      cursor = e + 1
      lastCursor = cursor
    end
    table.insert(result, string.sub(script, lastCursor))

    return table.concat(result)
  end

  ---
  ---Manage jass scripts and code at the same time.
  ---The code is a jass script with delimited comments removed and strings filtered.
  ---
  ---@class JassCode
  ---@field jass       string
  ---@field code       string
  JassCode = {}
  JassCode.__index = JassCode

  ---
  ---@param jass       string
  ---@param code?      string
  ---@return JassCode
  ---@nodiscard
  function JassCode.new(jass, code)
    local self = setmetatable({}, JassCode)
    self.jass = jass
    self.code = code
    if self.code == nil then
      self.code = filterLiteral(jass)
    end
    return self
  end

  ---
  ---@param code string
  ---@return JassCode
  ---@nodiscard
  function JassCode.newCode(code)
    local self = setmetatable({}, JassCode)
    self.jass = code
    self.code = code
    return self
  end

  ---
  ---Returns the substring of the JassCode that starts at `i` and continues until `j`.
  ---
  ---[View documents](command:extension.lua.doc?["en-us/54/manual.html/pdf-string.sub"])
  ---
  ---@param i  integer
  ---@param j? integer
  ---@return JassCode
  ---@nodiscard
  function JassCode:sub(i, j)
    return JassCode.new(self.jass:sub(i, j), self.code:sub(i, j))
  end

  ---
  ---@param o1 JassCode
  ---@param o2 JassCode
  ---@return JassCode
  ---@nodiscard
  function JassCode.__concat(o1, o2)
    return JassCode.new(o1.jass .. o2.jass, o1.code .. o2.code)
  end

  ---
  ---Given a list where all elements are JassCode, returns the string `list[i]..sep..list[i+1] ··· sep..list[j]`.
  ---
  ---[View documents](command:extension.lua.doc?["en-us/54/manual.html/pdf-table.concat"])
  ---
  ---@param list table
  ---@param sep? string
  ---@param i?   integer
  ---@param j?   integer
  ---@return JassCode
  ---@nodiscard
  function JassCode.tableConcat(list, sep, i, j)
    local jassList = {}
    local codeList = {}
    for _, jc in ipairs(list) do
      table.insert(jassList, jc.jass)
      table.insert(codeList, jc.code)
    end
    local jass = table.concat(jassList, sep, i, j)
    local code = table.concat(codeList, sep, i, j)
    return JassCode.new(jass, code)
  end

  return 0
end
//! endpreprocessor
//! endnovjass

endlibrary
