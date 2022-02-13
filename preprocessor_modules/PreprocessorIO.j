/*
 * Preprocessor IO (v2.0.0)
 *
 * 전처리기 입출력 라이브러리
 *
 */
library PreprocessorIO

//! novjass
//! preprocessor
do
  IO = {}
  IO.__index = IO

  ---
  ---@param filePath string
  ---@return string
  ---@nodiscard
  function IO.readTextFile(filePath)
    local f = io.open(filePath, "r")
    local text = f:read("*all")
    f:close()
    return text
  end

  ---
  ---@param filePath string
  ---@param text     string
  function IO.writeTextFile(filePath, text)
    local f = io.open(filePath, "w")
    f:write(text)
    f:close()
  end
end
//! endpreprocessor
//! endnovjass

endlibrary
