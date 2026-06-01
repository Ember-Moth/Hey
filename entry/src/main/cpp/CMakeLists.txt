cmake_minimum_required(VERSION 3.5.0)
project(heyvpn)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

set(HEYVPN_PREBUILT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/prebuilt/arm64-v8a)

add_library(heyvpn SHARED napi_init.cpp)
target_include_directories(heyvpn PRIVATE "${HEYVPN_PREBUILT_DIR}")
target_link_libraries(heyvpn PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
    libdl.so)

add_custom_command(TARGET heyvpn POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E remove -f
    "$<TARGET_FILE_DIR:heyvpn>/libxray.so"
    "$<TARGET_FILE_DIR:heyvpn>/libheytun2socks.so")

foreach(PREBUILT_LIB libheyxrayexec.so libheytun2socksexec.so)
    if(EXISTS "${HEYVPN_PREBUILT_DIR}/${PREBUILT_LIB}")
        add_custom_command(TARGET heyvpn POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${HEYVPN_PREBUILT_DIR}/${PREBUILT_LIB}"
            "$<TARGET_FILE_DIR:heyvpn>/${PREBUILT_LIB}")
    endif()
endforeach()
