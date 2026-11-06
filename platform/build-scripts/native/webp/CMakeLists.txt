if(APPLE)
  cmake_minimum_required(VERSION 3.17)
else()
  cmake_minimum_required(VERSION 3.16)
endif()

if(POLICY CMP0091)
  cmake_policy(SET CMP0091 NEW)
endif()

project(webp_jni C)

if(NOT WEBP_DIR)
  get_filename_component(WEBP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../external/webp" ABSOLUTE)
endif()
if(NOT JNI_INCLUDE_DIR)
  get_filename_component(JNI_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../prebuilts/studio/jdk/jni_headers/jdk11/include" ABSOLUTE)
endif()
if(NOT JNI_MD_INCLUDE_DIR)
  if(WIN32)
    set(JNI_MD_INCLUDE_DIR "${JNI_INCLUDE_DIR}/win32")
  elseif(APPLE)
    set(JNI_MD_INCLUDE_DIR "${JNI_INCLUDE_DIR}/darwin")
  else()
    set(JNI_MD_INCLUDE_DIR "${JNI_INCLUDE_DIR}/linux")
  endif()
endif()

set(WEBP_BUILD_ANIM_UTILS OFF CACHE BOOL "" FORCE)
set(WEBP_BUILD_CWEBP OFF CACHE BOOL "" FORCE)
set(WEBP_BUILD_DWEBP OFF CACHE BOOL "" FORCE)
set(WEBP_BUILD_GIF2WEBP OFF CACHE BOOL "" FORCE)
set(WEBP_BUILD_IMG2WEBP OFF CACHE BOOL "" FORCE)
set(WEBP_BUILD_VWEBP OFF CACHE BOOL "" FORCE)
set(WEBP_BUILD_WEBPINFO OFF CACHE BOOL "" FORCE)
set(WEBP_BUILD_LIBWEBPMUX OFF CACHE BOOL "" FORCE)
set(WEBP_BUILD_WEBPMUX OFF CACHE BOOL "" FORCE)
set(WEBP_BUILD_EXTRAS OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(WEBP_LINK_STATIC ON CACHE BOOL "" FORCE)
set(CMAKE_POSITION_INDEPENDENT_CODE ON CACHE BOOL "" FORCE)

if(MSVC)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
  foreach(flag_var
      CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
      CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO)
    if(${flag_var} MATCHES "/MD")
      string(REGEX REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
    endif()
  endforeach()
endif()

add_subdirectory("${WEBP_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/webp" EXCLUDE_FROM_ALL)

add_library(webp_jni SHARED "${WEBP_DIR}/swig/libwebp_java_wrap.c")
target_include_directories(webp_jni PRIVATE
  "${WEBP_DIR}/src"
  "${JNI_INCLUDE_DIR}"
  "${JNI_MD_INCLUDE_DIR}"
)
target_link_libraries(webp_jni PRIVATE webp)

if(WIN32)
  set(WEBP_JNI_PREFIX "")
else()
  set(WEBP_JNI_PREFIX "lib")
endif()

set_target_properties(webp_jni PROPERTIES
  PREFIX "${WEBP_JNI_PREFIX}"
  OUTPUT_NAME "webp_jni"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
  RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/bin"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
  LIBRARY_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/bin"
)
