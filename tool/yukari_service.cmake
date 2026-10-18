# Builds the background service (packages/yukari_core/bin/yukari_service.dart)
# with `dart build cli` and installs it as bin/yukari-service in the app bundle.
# Its libraries go to lib/, where the service looks for them; on Linux that is
# where the app keeps the same EasyTier library.
function(yukari_add_service)
  # FLUTTER_ROOT and PROJECT_DIR stay local to flutter/, so read them here too.
  include("${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/generated_config.cmake")
  # Flutter's own dart wrapper takes the tool lock the running build holds.
  set(DART "${FLUTTER_ROOT}/bin/cache/dart-sdk/bin/dart${CMAKE_EXECUTABLE_SUFFIX}")
  # The service belongs to the core package, whose dependency graph holds
  # neither the app nor its desktop tray.
  set(CORE_DIR "${PROJECT_DIR}/packages/yukari_core")
  set(OUTPUT_DIR "${PROJECT_BINARY_DIR}/yukari_service")
  set(EXECUTABLE "${OUTPUT_DIR}/bundle/bin/yukari_service${CMAKE_EXECUTABLE_SUFFIX}")
  file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS
    "${CORE_DIR}/lib/*.dart" "${CORE_DIR}/bin/*.dart")

  add_custom_command(
    OUTPUT "${EXECUTABLE}"
    COMMAND "${DART}" build cli
      --target bin/yukari_service.dart --output "${OUTPUT_DIR}"
    DEPENDS ${SOURCES} "${PROJECT_DIR}/pubspec.lock" "${CORE_DIR}/hook/build.dart"
    WORKING_DIRECTORY "${CORE_DIR}"
    COMMENT "Building the Yukari background service"
    VERBATIM)
  add_custom_target(yukari_service ALL DEPENDS "${EXECUTABLE}")
  # Both run build hooks in .dart_tool, so never at once.
  add_dependencies(yukari_service flutter_assemble)

  install(PROGRAMS "${EXECUTABLE}"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/bin"
    RENAME "yukari-service${CMAKE_EXECUTABLE_SUFFIX}"
    COMPONENT Runtime)
  install(DIRECTORY "${OUTPUT_DIR}/bundle/lib/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/lib"
    COMPONENT Runtime)
endfunction()
