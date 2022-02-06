library PreprocessorInstallerForJNEditor

scope UpdatePreprocessor
//! novjass
//! preprocessor

-- update_preprocessor.lua:start

-- update_preprocessor.lua:end

//! endpreprocessor
//! endnovjass
endscope

scope InstallLoader
//! novjass
//! preprocessor
--[==[
//! endnovjass

//! externalblock extension=lua ObjectMerger $FILENAME$

//! i -- install_loader.lua:start

//! i -- install_loader.lua:end

//! endexternalblock

//! novjass
]==]--
//! endpreprocessor
//! endnovjass
endscope

endlibrary
