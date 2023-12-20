include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(_tmyproj__supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(_tmyproj__setup_options)
  option(_tmyproj__ENABLE_HARDENING "Enable hardening" ON)
  option(_tmyproj__ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    _tmyproj__ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    _tmyproj__ENABLE_HARDENING
    OFF)

  _tmyproj__supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR _tmyproj__PACKAGING_MAINTAINER_MODE)
    option(_tmyproj__ENABLE_IPO "Enable IPO/LTO" OFF)
    option(_tmyproj__WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(_tmyproj__ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(_tmyproj__ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(_tmyproj__ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(_tmyproj__ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(_tmyproj__ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(_tmyproj__ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(_tmyproj__ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(_tmyproj__ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(_tmyproj__ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(_tmyproj__ENABLE_PCH "Enable precompiled headers" OFF)
    option(_tmyproj__ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(_tmyproj__ENABLE_IPO "Enable IPO/LTO" ON)
    option(_tmyproj__WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(_tmyproj__ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(_tmyproj__ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(_tmyproj__ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(_tmyproj__ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(_tmyproj__ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(_tmyproj__ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(_tmyproj__ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(_tmyproj__ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(_tmyproj__ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(_tmyproj__ENABLE_PCH "Enable precompiled headers" OFF)
    option(_tmyproj__ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      _tmyproj__ENABLE_IPO
      _tmyproj__WARNINGS_AS_ERRORS
      _tmyproj__ENABLE_USER_LINKER
      _tmyproj__ENABLE_SANITIZER_ADDRESS
      _tmyproj__ENABLE_SANITIZER_LEAK
      _tmyproj__ENABLE_SANITIZER_UNDEFINED
      _tmyproj__ENABLE_SANITIZER_THREAD
      _tmyproj__ENABLE_SANITIZER_MEMORY
      _tmyproj__ENABLE_UNITY_BUILD
      _tmyproj__ENABLE_CLANG_TIDY
      _tmyproj__ENABLE_CPPCHECK
      _tmyproj__ENABLE_COVERAGE
      _tmyproj__ENABLE_PCH
      _tmyproj__ENABLE_CACHE)
  endif()

  _tmyproj__check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (_tmyproj__ENABLE_SANITIZER_ADDRESS OR _tmyproj__ENABLE_SANITIZER_THREAD OR _tmyproj__ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(_tmyproj__BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(_tmyproj__global_options)
  if(_tmyproj__ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    _tmyproj__enable_ipo()
  endif()

  _tmyproj__supports_sanitizers()

  if(_tmyproj__ENABLE_HARDENING AND _tmyproj__ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR _tmyproj__ENABLE_SANITIZER_UNDEFINED
       OR _tmyproj__ENABLE_SANITIZER_ADDRESS
       OR _tmyproj__ENABLE_SANITIZER_THREAD
       OR _tmyproj__ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${_tmyproj__ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${_tmyproj__ENABLE_SANITIZER_UNDEFINED}")
    _tmyproj__enable_hardening(_tmyproj__options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(_tmyproj__local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(_tmyproj__warnings INTERFACE)
  add_library(_tmyproj__options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  _tmyproj__set_project_warnings(
    _tmyproj__warnings
    ${_tmyproj__WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(_tmyproj__ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(_tmyproj__options)
  endif()

  include(cmake/Sanitizers.cmake)
  _tmyproj__enable_sanitizers(
    _tmyproj__options
    ${_tmyproj__ENABLE_SANITIZER_ADDRESS}
    ${_tmyproj__ENABLE_SANITIZER_LEAK}
    ${_tmyproj__ENABLE_SANITIZER_UNDEFINED}
    ${_tmyproj__ENABLE_SANITIZER_THREAD}
    ${_tmyproj__ENABLE_SANITIZER_MEMORY})

  set_target_properties(_tmyproj__options PROPERTIES UNITY_BUILD ${_tmyproj__ENABLE_UNITY_BUILD})

  if(_tmyproj__ENABLE_PCH)
    target_precompile_headers(
      _tmyproj__options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(_tmyproj__ENABLE_CACHE)
    include(cmake/Cache.cmake)
    _tmyproj__enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(_tmyproj__ENABLE_CLANG_TIDY)
    _tmyproj__enable_clang_tidy(_tmyproj__options ${_tmyproj__WARNINGS_AS_ERRORS})
  endif()

  if(_tmyproj__ENABLE_CPPCHECK)
    _tmyproj__enable_cppcheck(${_tmyproj__WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(_tmyproj__ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    _tmyproj__enable_coverage(_tmyproj__options)
  endif()

  if(_tmyproj__WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(_tmyproj__options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(_tmyproj__ENABLE_HARDENING AND NOT _tmyproj__ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR _tmyproj__ENABLE_SANITIZER_UNDEFINED
       OR _tmyproj__ENABLE_SANITIZER_ADDRESS
       OR _tmyproj__ENABLE_SANITIZER_THREAD
       OR _tmyproj__ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    _tmyproj__enable_hardening(_tmyproj__options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
