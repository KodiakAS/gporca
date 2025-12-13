include(ExternalProject)

# Configuration for building a bundled GP-Xerces when a system install is unavailable.
set(GPORCA_XERCES_VERSION "3.1.2")
set(GPORCA_XERCES_SHA256 "743bd0a029bf8de56a587c270d97031e0099fe2b7142cef03e0da16e282655a0")
set(GPORCA_XERCES_URL "https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-${GPORCA_XERCES_VERSION}.tar.gz")
set(GPORCA_XERCES_ARCHIVE_DEFAULT "${PROJECT_SOURCE_DIR}/third_party/xerces/xerces-c-${GPORCA_XERCES_VERSION}.tar.gz")
set(GPORCA_XERCES_ARCHIVE "${GPORCA_XERCES_ARCHIVE_DEFAULT}" CACHE FILEPATH "Path to local GP-Xerces tarball to build from (for offline builds).")
option(GPORCA_ALLOW_ONLINE_XERCES_DOWNLOAD "Allow CMake to download GP-Xerces if a local archive is missing." OFF)

function(gporca_configure_bundled_xerces)
  find_program(GPORCA_PATCH_EXECUTABLE patch)
  if (NOT GPORCA_PATCH_EXECUTABLE)
    message(FATAL_ERROR "patch executable not found (needed to apply GPDB Xerces patch)")
  endif()

  find_program(GPORCA_MAKE_EXECUTABLE NAMES gmake make)
  if (NOT GPORCA_MAKE_EXECUTABLE)
    message(FATAL_ERROR "make executable not found (needed to build bundled GP-Xerces)")
  endif()

  # Prefer local archive for offline builds; only fall back to remote when explicitly allowed.
  set(xerces_url "")
  if (EXISTS "${GPORCA_XERCES_ARCHIVE}")
    set(xerces_url "${GPORCA_XERCES_ARCHIVE}")
    message(STATUS "Using vendored GP-Xerces archive at ${GPORCA_XERCES_ARCHIVE}")
  elseif (GPORCA_ALLOW_ONLINE_XERCES_DOWNLOAD)
    set(xerces_url "${GPORCA_XERCES_URL}")
    message(STATUS "Downloading GP-Xerces from ${GPORCA_XERCES_URL}")
  else()
    message(FATAL_ERROR "GP-Xerces archive not found at ${GPORCA_XERCES_ARCHIVE}. Provide the tarball or enable GPORCA_ALLOW_ONLINE_XERCES_DOWNLOAD.")
  endif()

  set(xerces_prefix "${CMAKE_BINARY_DIR}/third_party/xerces")
  set(xerces_install "${xerces_prefix}")

  ExternalProject_Add(gporca_xerces
    PREFIX "${xerces_prefix}"
    URL "${xerces_url}"
    URL_HASH "SHA256=${GPORCA_XERCES_SHA256}"
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    UPDATE_COMMAND ""
    BUILD_IN_SOURCE 1
    PATCH_COMMAND "${GPORCA_PATCH_EXECUTABLE}" -p1 -i "${PROJECT_SOURCE_DIR}/patches/xerces-c-gpdb.patch"
    CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR>
    BUILD_COMMAND "${GPORCA_MAKE_EXECUTABLE}"
    INSTALL_COMMAND "${GPORCA_MAKE_EXECUTABLE}" install
    BUILD_BYPRODUCTS "${xerces_install}/lib/libxerces-c${CMAKE_SHARED_LIBRARY_SUFFIX}"
  )

  set(xerces_include "${xerces_install}/include")
  set(xerces_library "${xerces_install}/lib/libxerces-c${CMAKE_SHARED_LIBRARY_SUFFIX}")

  # Create expected include/lib directories eagerly so imported targets validate during configure.
  file(MAKE_DIRECTORY "${xerces_include}")
  file(MAKE_DIRECTORY "${xerces_install}/lib")

  add_library(Xerces::xerces-c UNKNOWN IMPORTED GLOBAL)
  set_target_properties(Xerces::xerces-c PROPERTIES
    IMPORTED_LOCATION "${xerces_library}"
    INTERFACE_INCLUDE_DIRECTORIES "${xerces_include}"
  )
  add_dependencies(Xerces::xerces-c gporca_xerces)

  set(XERCES_INCLUDE_DIR "${xerces_include}" PARENT_SCOPE)
  set(XERCES_INCLUDE_DIRS "${xerces_include}" PARENT_SCOPE)
  set(XERCES_LIBRARY "${xerces_library}" PARENT_SCOPE)
  set(XERCES_LIBRARIES "Xerces::xerces-c" PARENT_SCOPE)
  set(XERCES_FOUND TRUE PARENT_SCOPE)
  set(GPORCA_BUNDLED_XERCES TRUE CACHE BOOL "Using bundled GP-Xerces build." FORCE)

  message(STATUS "Using bundled GP-Xerces ${GPORCA_XERCES_VERSION}")
endfunction()
