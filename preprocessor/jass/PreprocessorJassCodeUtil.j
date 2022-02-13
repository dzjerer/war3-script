/*
 * Preprocessor JassCodeUtil (v2.0.0)
 *
 * JassCode 관련 유틸 함수 모음
 *
 */
library PreprocessorJassCodeUtil requires PreprocessorJassCode

//! novjass
//! preprocessor
do
  JassCodeUtil = {}
  JassCodeUtil.__index = JassCodeUtil

  ---
  ---@param jassCode   JassCode
  ---@param startIndex JassCode
  ---@return table   argPosList
  ---@return integer start
  ---@return integer end
  ---@nodiscard
  function JassCodeUtil.parseArguments(jassCode, startIndex)
    if string.sub(jassCode.code, startIndex, startIndex) ~= "(" then
      return nil, nil, nil
    end

    local args = {}
    local cursor = startIndex + 1
    local depth = 0
    local argStartIndex, argEndIndex
    argStartIndex = cursor
    while true do
      cursor = string.find(jassCode.code, "[%(%),]", cursor)
      if cursor == nil then
        return nil, nil, nil
      end

      local token = string.sub(jassCode.code, cursor, cursor)
      cursor = cursor + 1

      if token == "(" then
        depth = depth + 1
      elseif token == ")" then
        if depth == 0 then
          argEndIndex = cursor - 2
          local argLen = argEndIndex - argStartIndex + 1
          if argLen > 0 then
            local arg = {argStartIndex, argEndIndex}
            table.insert(args, arg)
          end
          break
        end
        depth = depth - 1
      elseif token == "," then
        if depth == 0 then
          argEndIndex = cursor - 2
          local arg = {argStartIndex, argEndIndex}
          table.insert(args, arg)

          argStartIndex = cursor
        end
      end
    end

    local endIndex = cursor - 1
    return args, startIndex, endIndex
  end

  ---
  ---@param jassCode JassCode
  ---@param argPos   table
  ---@return table   argPos
  ---@nodiscard
  function JassCodeUtil.trimArgument(jassCode, argPos)
    local subJass = string.sub(jassCode.jass, argPos[1], argPos[2])
    local lws, rws = string.match(subJass, "^(%s*).-(%s*)$")
    return {argPos[1] + string.len(lws), argPos[2] - string.len(rws)}
  end
end
//! endpreprocessor
//! endnovjass

endlibrary
