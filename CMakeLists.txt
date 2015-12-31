# Projektname
project (thomas-simulator)

# Minimalanforderungen
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)

# Konfiguration
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share/${CMAKE_PROJECT_NAME}")
set (PKGDATADIR "${DATADIR}/${CMAKE_PROJECT_NAME}")
set (RELEASE_NAME "${CMAKE_PROJECT_NAME}")
set (VERSION "0.1")
set (VERSION_INFO "Release")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

# CMake-Dateien
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Konfigurationsdatei generieren
configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)

# Auf Vala-Unterstützung prüfen
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.18" MINIMUM)
include (ValaPrecompile)

# Auf Bibliotheken prüfen
find_package (PkgConfig)
pkg_check_modules (DEPS REQUIRED granite gtk+-3.0 gthread-2.0 gio-2.0)
add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES} -lm)
link_directories (${DEPS_LIBRARY_DIRS})

# Unterverzeichnisse einbeziehen
add_subdirectory (src)
add_subdirectory (data)