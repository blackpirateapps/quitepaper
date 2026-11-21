# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "quietpaper_watched_import")
project(${PROJECT_NAME} LANGUAGES CXX)

# Read the single toolchain authority rather than following moving stable.
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/../../rust-toolchain.toml" QP_TOOLCHAIN_FILE)
string(REGEX MATCH "channel = \"([^\"]+)\"" QP_TOOLCHAIN_MATCH "${QP_TOOLCHAIN_FILE}")
set(QUIETPAPER_RUST_TOOLCHAIN "${CMAKE_MATCH_1}")
if(NOT QUIETPAPER_RUST_TOOLCHAIN)
  message(FATAL_ERROR "Missing pinned Quiet Paper Rust toolchain")
endif()
include("../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../../rust/quietpaper_watched_import quietpaper_watched_import "")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(quietpaper_watched_import_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
