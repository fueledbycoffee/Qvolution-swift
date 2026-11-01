cmake_minimum_required(VERSION 3.20)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(swift_import_overlays NONE)
endif()
find_package(Python3 REQUIRED COMPONENTS Interpreter)
file(GLOB recipes "${CMAKE_CURRENT_SOURCE_DIR}/../*/imports.json")
foreach(recipe IN LISTS recipes)
  get_filename_component(module_dir "${recipe}" DIRECTORY)
  get_filename_component(module "${module_dir}" NAME)
  set(image "${CMAKE_CURRENT_BINARY_DIR}/${module}/libswift${module}.dylib")
  file(GLOB_RECURSE inputs "${module_dir}/*.swift" "${module_dir}/*.h" "${module_dir}/*.modulemap" "${module_dir}/*.patch")
  execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/build.py" --dependencies "${recipe}"
    RESULT_VARIABLE input_result OUTPUT_VARIABLE external_inputs OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT input_result EQUAL 0)
    message(FATAL_ERROR "Cannot resolve source inputs for ${module}")
  endif()
  add_custom_command(OUTPUT "${image}"
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/build.py" "${recipe}" "${CMAKE_CURRENT_BINARY_DIR}/${module}"
    DEPENDS ${inputs} ${external_inputs} "${recipe}" "${CMAKE_CURRENT_SOURCE_DIR}/build.py" "${CMAKE_CURRENT_SOURCE_DIR}/swiftc-darwin.py"
    VERBATIM)
  add_custom_target(swift_import_${module} ALL DEPENDS "${image}")
  install(FILES "${image}" DESTINATION libexec/darling/usr/lib/swift)
endforeach()
