set(PROJECT_AWE_NAME awesome)
set(PROJECT_AWECLIENT_NAME awesome-client)

# If ${SOURCE_DIR} is a git repository VERSION is set to
# `git-describe` later.
set(VERSION 3-devel)

set(VERSION_MAJOR ${VERSION})
set(VERSION_MINOR 0)
set(VERSION_PATCH 0)

set(CODENAME "Wake Up Call")

project(${PROJECT_AWE_NAME} C)

set(CMAKE_BUILD_TYPE RELEASE)

option(WITH_DBUS "build with D-BUS" ON)
option(WITH_IMLIB2 "build with Imlib2" OFF)
option(GENERATE_MANPAGES "generate manpages" ON)
option(GENERATE_LUADOC "generate luadoc" ON)

# {{{ CFLAGS
add_definitions(-std=gnu99 -ggdb3 -fno-strict-aliasing -Wall -Wextra
    -Wchar-subscripts -Wundef -Wshadow -Wcast-align -Wwrite-strings
    -Wsign-compare -Wunused -Wno-unused-parameter -Wuninitialized -Winit-self
    -Wpointer-arith -Wredundant-decls -Wformat-nonliteral
    -Wno-format-zero-length -Wmissing-format-attribute -Wmissing-prototypes
    -Wstrict-prototypes)
# }}}

# {{{ Find external utilities
macro(a_find_program var prg req)
    set(required ${req})
    find_program(${var} ${prg})
    if(NOT ${var})
        message(STATUS "${prg} not found.")
        if(required)
            message(FATAL_ERROR "${prg} is required to build awesome")
        endif()
    else()
        message(STATUS "${prg} -> ${${var}}")
    endif()
endmacro()

a_find_program(CAT_EXECUTABLE cat TRUE)
a_find_program(LN_EXECUTABLE ln TRUE)
a_find_program(GREP_EXECUTABLE grep TRUE)
a_find_program(GIT_EXECUTABLE git FALSE)
a_find_program(HOSTNAME_EXECUTABLE hostname FALSE)
a_find_program(GPERF_EXECUTABLE gperf TRUE)
a_find_program(LUAC_EXECUTABLE luac TRUE)
# programs needed for man pages
a_find_program(ASCIIDOC_EXECUTABLE asciidoc FALSE)
a_find_program(XMLTO_EXECUTABLE xmlto FALSE)
a_find_program(GZIP_EXECUTABLE gzip FALSE)
# lua documentation
a_find_program(LUA_EXECUTABLE lua FALSE)
a_find_program(LUADOC_EXECUTABLE luadoc FALSE)
# doxygen
include(FindDoxygen)
# pkg-config
include(FindPkgConfig)
# }}}

# {{{ Check if documentation can be build
if(GENERATE_MANPAGES)
    if(NOT ASCIIDOC_EXECUTABLE OR NOT XMLTO_EXECUTABLE OR NOT GZIP_EXECUTABLE)
        if(NOT ASCIIDOC_EXECUTABLE)
            SET(missing "asciidoc")
        endif()
        if(NOT XMLTO_EXECUTABLE)
            SET(missing ${missing} " xmlto")
        endif()
        if(NOT GZIP_EXECUTABLE)
            SET(missing ${missing} " gzip")
        endif()

        message(STATUS "Not generating manpages. Missing: " ${missing})
        set(GENERATE_MANPAGES OFF)
    endif()
endif()

if(GENERATE_LUADOC)
    if(NOT LUADOC_EXECUTABLE)
        message(STATUS "Not generating luadoc. Missing: luadoc")
        set(GENERATE_LUADOC OFF)
    endif()
endif()
# }}}

# {{{ Version stamp
if(EXISTS ${SOURCE_DIR}/.git/HEAD AND GIT_EXECUTABLE)
    # get current version
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe
        WORKING_DIRECTORY ${SOURCE_DIR}
        OUTPUT_VARIABLE VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    # file the git-version-stamp.sh script will look into
    set(VERSION_STAMP_FILE ${BUILD_DIR}/.version_stamp)
    file(WRITE ${VERSION_STAMP_FILE} ${VERSION})
    # create a version_stamp target later
    set(BUILD_FROM_GIT TRUE)
elseif( EXISTS ${SOURCE_DIR}/.version_stamp )
    # get version from version stamp
    file(READ ${SOURCE_DIR}/.version_stamp VERSION)
endif()
# }}}

# {{{ Get hostname

execute_process(
    COMMAND ${HOSTNAME_EXECUTABLE} -f
    WORKING_DIRECTORY ${SOURCE_DIR}
    OUTPUT_VARIABLE BUILDHOSTNAME
    OUTPUT_STRIP_TRAILING_WHITESPACE)

# }}}

# {{{ Required libraries
#
# this sets up:
# AWESOME_REQUIRED_LIBRARIES
# AWESOME_REQUIRED_INCLUDE_DIRS
# AWESOMECLIENT_LIBRARIES

# Use pkgconfig to get most of the libraries
pkg_check_modules(AWESOME_REQUIRED REQUIRED
    glib-2.0
    cairo
    pango
    xcb
    xcb-event
    xcb-randr
    xcb-xinerama
    xcb-aux
    xcb-atom
    xcb-keysyms
    xcb-icccm
    cairo-xcb)

if(NOT AWESOME_REQUIRED_FOUND)
    message(FATAL_ERROR)
endif()

macro(a_find_library variable library)
    find_library(${variable} ${library})
    if(NOT ${variable})
        message(FATAL_ERROR ${library} " library not found.")
    endif()
endmacro()

# Check for readline, ncurse and libev
a_find_library(LIB_READLINE readline)
a_find_library(LIB_NCURSES ncurses)
a_find_library(LIB_EV ev)

# Check for lua5.1
find_path(LUA_INC_DIR lua.h
    /usr/include
    /usr/include/lua5.1
    /usr/local/include/lua5.1)

find_library(LUA_LIB NAMES lua5.1 lua
    /usr/lib
    /usr/lib/lua
    /usr/local/lib)

# Error check
if(NOT LUA_LIB)
    message(FATAL_ERROR "lua library not found")
endif()

set(AWESOME_REQUIRED_LIBRARIES ${AWESOME_REQUIRED_LIBRARIES}
    ${LIB_EV}
    ${LUA_LIB})

set(AWESOME_REQUIRED_INCLUDE_DIRS ${AWESOME_REQUIRED_INCLUDE_DIRS}
    ${LUA_INC_DIR})

set(AWESOMECLIENT_LIBRARIES
    ${LIB_READLINE}
    ${LIB_NCURSES})
# }}}

# {{{ Optional libraries
#
# this sets up:
# AWESOME_OPTIONAL_LIBRARIES
# AWESOME_OPTIONAL_INCLUDE_DIRS

if(WITH_DBUS)
    pkg_check_modules(DBUS dbus-1)
    if(DBUS_FOUND)
        set(AWESOME_OPTIONAL_LIBRARIES ${AWESOME_OPTIONAL_LIBRARIES} ${DBUS_LIBRARIES})
        set(AWESOME_OPTIONAL_INCLUDE_DIRS ${AWESOME_OPTIONAL_INCLUDE_DIRS} ${DBUS_INCLUDE_DIRS})
    else()
        set(WITH_DBUS OFF)
        message(STATUS "DBUS not found. Disabled.")
    endif()
endif()

if(WITH_IMLIB2)
    pkg_check_modules(IMLIB2 imlib2)
    if(IMLIB2_FOUND)
        set(AWESOME_OPTIONAL_LIBRARIES ${AWESOME_OPTIONAL_LIBRARIES} ${IMLIB2_LIBRARIES})
        set(AWESOME_OPTIONAL_INCLUDE_DIRS ${AWESOME_OPTIONAL_INCLUDE_DIRS} ${IMLIB2_INCLUDE_DIRS})
    else()
        set(WITH_IMLIB2 OFF)
        message(STATUS "Imlib2 not found. Disabled.")
    endif()
endif()

if(NOT WITH_IMLIB2)
    pkg_check_modules(GDK_PIXBUF REQUIRED gdk-2.0>=2.2 gdk-pixbuf-2.0>=2.2)
    if(GDK_PIXBUF_FOUND)
        set(AWESOME_OPTIONAL_LIBRARIES ${AWESOME_OPTIONAL_LIBRARIES}
            ${GDK_PIXBUF_LIBRARIES})
        set(AWESOME_OPTIONAL_INCLUDE_DIRS ${AWESOME_OPTIONAL_INCLUDE_DIRS}
            ${GDK_PIXBUF_INCLUDE_DIRS})
    else()
        message(FATAL_ERROR "GdkPixBuf not found.")
    endif()
endif()
# }}}

# {{{ Install path and configuration variables
if(DEFINED PREFIX)
    set(PREFIX ${PREFIX} CACHE PATH "install prefix")
    set(CMAKE_INSTALL_PREFIX ${PREFIX})
else()
    set(PREFIX ${CMAKE_INSTALL_PREFIX} CACHE PATH "install prefix")
endif()

#If a sysconfdir is specified, use it instead
#of the default configuration dir.
if(DEFINED SYSCONFDIR)
    set(SYSCONFDIR ${SYSCONFDIR} CACHE PATH "config directory")
else()
    set(SYSCONFDIR /etc CACHE PATH "config directory")
endif()

#If an XDG Config Dir is specificed, use it instead
#of the default XDG configuration dir.
if(DEFINED XDG_CONFIG_DIR)
    set(XDG_CONFIG_DIR ${XDG_CONFIG_SYS} CACHE PATH "xdg config directory")
else()
    set(XDG_CONFIG_DIR ${SYSCONFDIR}/xdg CACHE PATH "xdg config directory")
endif()

# setting AWESOME_DOC_PATH
if(DEFINED AWESOME_DOC_PATH)
    set(AWESOME_DOC_PATH ${AWESOME_DOC_PATH} CACHE PATH "awesome docs directory")
else()
    set(AWESOME_DOC_PATH ${PREFIX}/share/doc/${PROJECT_AWE_NAME} CACHE PATH "awesome docs directory")
endif()

# Hide to avoid confusion
mark_as_advanced(CMAKE_INSTALL_PREFIX)

set(AWESOME_VERSION          ${VERSION})
set(AWESOME_COMPILE_MACHINE  ${CMAKE_SYSTEM_PROCESSOR})
set(AWESOME_COMPILE_HOSTNAME ${BUILDHOSTNAME})
set(AWESOME_COMPILE_BY       $ENV{USER})
set(AWESOME_RELEASE          ${CODENAME})
set(AWESOME_SYSCONFDIR       ${XDG_CONFIG_DIR}/${PROJECT_AWE_NAME})
set(AWESOME_DATA_PATH        ${PREFIX}/share/${PROJECT_AWE_NAME})
set(AWESOME_MAN_PATH         ${PREFIX}/share/man)
set(AWESOME_LUA_LIB_PATH     ${AWESOME_DATA_PATH}/lib)
set(AWESOME_ICON_PATH        ${AWESOME_DATA_PATH}/icons)
set(AWESOME_THEMES_PATH      ${AWESOME_DATA_PATH}/themes)
set(AWESOME_XSESSION_PATH    ${PREFIX}/share/xsessions)
# }}}

# {{{ Configure files
set(AWESOME_CONFIGURE_FILES
    config.h.in
    awesomerc.lua.in
    themes/default.in
    lib/awful.lua.in
    awesome-version-internal.h.in
    awesome.doxygen.in)

macro(a_configure_file file)
    string(REGEX REPLACE ".in\$" "" outfile ${file})
    message(STATUS "Configuring ${outfile}")
    configure_file(${SOURCE_DIR}/${file}
                   ${BUILD_DIR}/${outfile}
                   ESCAPE_QUOTE
                   @ONLY)
endmacro()

foreach(file ${AWESOME_CONFIGURE_FILES})
    a_configure_file(${file})
endforeach()
#}}}

# {{{ CPack configuration
SET(CPACK_SET_DESTDIR                  TRUE)
set(CPACK_PACKAGE_NAME                 "${PROJECT_AWE_NAME}")
set(CPACK_GENERATOR                    "TBZ2")
set(CPACK_SOURCE_GENERATOR             "TBZ2")
set(CPACK_SOURCE_IGNORE_FILES
    ".git;.*.swp$;.*~;.*patch;.gitignore;${BUILD_DIR}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY  "A dynamic floating and tiling window manager")
set(CPACK_PACKAGE_VENDOR               "awesome development team")
set(CPACK_PACKAGE_DESCRIPTION_FILE     "${SOURCE_DIR}/README")
set(CPACK_RESOURCE_FILE_LICENSE        "${SOURCE_DIR}/LICENSE")
set(CPACK_PACKAGE_VERSION_MAJOR        "${VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR        "${VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH        "${VERSION_PATCH}")

include(CPack)
#}}}

# vim: filetype=cmake:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:encoding=utf-8:textwidth=80
