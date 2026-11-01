cmake_minimum_required(VERSION 3.20)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(swift_import_overlays NONE)
endif()
find_package(Python3 REQUIRED COMPONENTS Interpreter)
file(GLOB recipes CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/../*/imports.json")
foreach(recipe IN LISTS recipes)
  get_filename_component(module_dir "${recipe}" DIRECTORY)
  get_filename_component(module "${module_dir}" NAME)
  set(image "${CMAKE_CURRENT_BINARY_DIR}/${module}/libswift${module}.dylib")
  file(GLOB_RECURSE inputs CONFIGURE_DEPENDS "${module_dir}/*.swift" "${module_dir}/*.h" "${module_dir}/*.modulemap")
  add_custom_command(OUTPUT "${image}"
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/build.py" "${recipe}" "${CMAKE_CURRENT_BINARY_DIR}/${module}"
    DEPENDS ${inputs} "${recipe}" "${CMAKE_CURRENT_SOURCE_DIR}/build.py" "${CMAKE_CURRENT_SOURCE_DIR}/swiftc-darwin.py"
    VERBATIM)
  add_custom_target(swift_import_${module} ALL DEPENDS "${image}")
  install(FILES "${image}" DESTINATION libexec/darling/usr/lib/swift)
endforeach()
