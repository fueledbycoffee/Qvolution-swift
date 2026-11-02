project(swift)

include(darling_lib)

set(DARLING_LIB_64BIT_ONLY TRUE)

set(DYLIB_INSTALL_NAME "/usr/lib/swift/libswiftCoreCompat.dylib")
add_darling_library(swiftCoreCompat SHARED
	swift_compat.S
)
target_link_libraries(swiftCoreCompat system)
set_target_properties(swiftCoreCompat PROPERTIES
	LINKER_LANGUAGE C
	OUTPUT_NAME "swiftCoreCompat"
)
set_property(TARGET swiftCoreCompat APPEND_STRING PROPERTY
	LINK_FLAGS " -Wl,-U,_swift_getTypeByMangledNameInContext -Wl,-U,'_\$ss12_ArrayBufferV19_getElementSlowPathyyXlSiF'"
)
install(TARGETS swiftCoreCompat DESTINATION libexec/darling/usr/lib/swift)

set(DYLIB_INSTALL_NAME "/usr/lib/swift/libswiftWebKit.dylib")
add_darling_library(swiftWebKit SHARED
	libswiftWebKit.S
)
target_link_libraries(swiftWebKit system)
set_target_properties(swiftWebKit PROPERTIES
	LINKER_LANGUAGE C
	OUTPUT_NAME "swiftWebKit"
)
install(TARGETS swiftWebKit DESTINATION libexec/darling/usr/lib/swift)

set(DYLIB_INSTALL_NAME "/usr/lib/swift/libswift_errno.dylib")
add_darling_library(swift_errno SHARED
	swift_errno.S
)
target_link_libraries(swift_errno system)
set_target_properties(swift_errno PROPERTIES
	LINKER_LANGUAGE C
	OUTPUT_NAME "swift_errno"
)
set_property(TARGET swift_errno APPEND_STRING PROPERTY
	LINK_FLAGS " -Wl,-reexport_library,${CMAKE_CURRENT_SOURCE_DIR}/libswiftDarwin.dylib")
install(TARGETS swift_errno DESTINATION libexec/darling/usr/lib/swift)

option(DARLING_BUILD_IMPORT_OVERLAYS "Build x86_64 Swift overlays from source" OFF)
# Source-built x86_64 overlays, Combine and CryptoKit matching the 6.3.3 core.
#
# libswiftCore and the other core runtime libraries above are the Swift 6.3.3
# release binaries, but the x86_64 overlay slices are Swift 5.2.2 and bind the
# 5.2.2 back-deployment SPI that 6.3.3 no longer exports. With this option the
# x86_64 overlays (Darwin, ObjectiveC, CoreFoundation, Dispatch, os, XPC,
# Foundation), Combine and CryptoKit are compiled from the pinned sources in
# overlays/ by overlays/CryptoKit/build-runtime-inputs.sh and build.sh during the
# build, and installed in place of the 5.2.2 slices. Nothing compiled is
# committed; every input is a source checkout pinned by those scripts.
option(DARLING_SWIFT_SOURCE_RUNTIME
	"Build and install the x86_64 Swift overlays, Combine and CryptoKit from source" OFF)
set(SWIFT_SOURCE_RUNTIME_OVERLAYS Darwin ObjectiveC CoreFoundation Dispatch os XPC Foundation)
set(_swift_source_runtime_names "")
set(_srt_component "")
if(DARLING_SWIFT_SOURCE_RUNTIME)
	# A separate install component lets a staged runtime of the same source commit take
	# only these files: cmake -DCOMPONENT=swift_source_runtime -P cmake_install.cmake
	set(_srt_component COMPONENT swift_source_runtime)
	if(TARGET_ARM64)
		message(FATAL_ERROR "DARLING_SWIFT_SOURCE_RUNTIME builds the x86_64 slices; arm64 uses the bundled overlays")
	endif()
	set(DARLING_SWIFT_TOOLCHAIN "" CACHE PATH "Swift 6.3.3 toolchain usr directory (bin/swiftc, bin/clang)")
	set(DARLING_SWIFT_RESOURCE_DIR "" CACHE PATH
		"Resource directory holding source-built Darwin Swift, _Concurrency and _StringProcessing modules")
	set(DARLING_SWIFT_LINK_ROOT "" CACHE PATH
		"Darling runtime root (libexec/darling) of the same sources, used only as the link-time library root")
	set(DARLING_SWIFT_OPENCOMBINE_SRC "" CACHE PATH "OpenCombine checkout (pinned by build-module-inputs.sh)")
	set(DARLING_SWIFT_COLLECTIONS_SRC "" CACHE PATH "swift-collections checkout (pinned by build-module-inputs.sh)")
	set(DARLING_SWIFT_CMARK_SRC "" CACHE PATH "swift-cmark checkout (pinned by build-module-inputs.sh)")
	set(DARLING_SWIFT_FOUNDATION_SRC "" CACHE PATH "swift-foundation checkout (pinned by build-module-inputs.sh)")
	set(DARLING_SWIFT_CRYPTO_SRC "" CACHE PATH "swift-crypto clone holding the commits pinned by overlays/CryptoKit/build.sh")
	foreach(_input DARLING_SWIFT_TOOLCHAIN DARLING_SWIFT_RESOURCE_DIR DARLING_SWIFT_LINK_ROOT
			DARLING_SWIFT_OPENCOMBINE_SRC DARLING_SWIFT_COLLECTIONS_SRC DARLING_SWIFT_CMARK_SRC
			DARLING_SWIFT_FOUNDATION_SRC DARLING_SWIFT_CRYPTO_SRC)
		if(NOT IS_DIRECTORY "${${_input}}")
			message(FATAL_ERROR "DARLING_SWIFT_SOURCE_RUNTIME requires ${_input} to name a directory")
		endif()
	endforeach()

	set(_srt "${CMAKE_CURRENT_BINARY_DIR}/source-runtime-x86_64")
	set(_srt_overlays "${_srt}/overlays")
	set(_srt_cryptokit "${_srt}/cryptokit")
	set(_srt_ld "${CMAKE_BINARY_DIR}/src/external/cctools-port/cctools/ld64/src/${APPLE_TARGET_TRIPLET_64BIT}-ld")
	set(_srt_env
		SWIFT_TOOLCHAIN=${DARLING_SWIFT_TOOLCHAIN}
		SWIFT_RESOURCE_DIR=${DARLING_SWIFT_RESOURCE_DIR}
		DARLING_SDK=${CMAKE_SOURCE_DIR}/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
		DARLING_SOURCE_ROOT=${CMAKE_SOURCE_DIR}
		DARLING_ROOT=${DARLING_SWIFT_LINK_ROOT}
		DARLING_LD=${_srt_ld}
		DARLING_LIBSYSTEM=${DARLING_SWIFT_LINK_ROOT}/usr/lib/libSystem.B.dylib
		OPENCOMBINE_SRC=${DARLING_SWIFT_OPENCOMBINE_SRC}
		SWIFT_COLLECTIONS_SRC=${DARLING_SWIFT_COLLECTIONS_SRC}
		SWIFT_CMARK_SRC=${DARLING_SWIFT_CMARK_SRC}
		SWIFT_FOUNDATION_SRC=${DARLING_SWIFT_FOUNDATION_SRC}
		CRYPTOKIT_SOURCE=${DARLING_SWIFT_CRYPTO_SRC}
		CRYPTOKIT_ARCH=x86_64
	)
	set(_srt_overlay_outputs "${_srt_overlays}/Combine.framework/Versions/A/Combine")
	foreach(_module ${SWIFT_SOURCE_RUNTIME_OVERLAYS})
		list(APPEND _srt_overlay_outputs "${_srt_overlays}/libswift${_module}.dylib")
		list(APPEND _swift_source_runtime_names "libswift${_module}.dylib")
	endforeach()
	# Plain configure-time glob, deliberately without CONFIGURE_DEPENDS: that adds an always-run
	# check, so "ninja -n" would never report "no work to do" (the tree's build-completion test).
	# A newly added overlay source therefore needs a reconfigure, and a change to an external
	# input (toolchain, resource dir, link root, pinned checkouts) needs a manual rebuild of
	# swift_source_runtime: none of those are DEPENDS of the rules below.
	file(GLOB_RECURSE _srt_overlay_sources
		"${CMAKE_CURRENT_SOURCE_DIR}/overlays/*.swift" "${CMAKE_CURRENT_SOURCE_DIR}/overlays/*.h"
		"${CMAKE_CURRENT_SOURCE_DIR}/overlays/*.c" "${CMAKE_CURRENT_SOURCE_DIR}/overlays/*.m"
		"${CMAKE_CURRENT_SOURCE_DIR}/overlays/*.mm" "${CMAKE_CURRENT_SOURCE_DIR}/overlays/*.sh"
		"${CMAKE_CURRENT_SOURCE_DIR}/overlays/*.list" "${CMAKE_CURRENT_SOURCE_DIR}/overlays/*.patch")
	# CoreGraphics.framework re-exports @rpath/libswiftCoreGraphics.dylib (cocotron CoreGraphics
	# CMakeLists); CryptoKit autolinks CoreGraphics, so map that leaf like swift_dylib_map.cmake does.
	# The core runtime libraries come from this directory (Swift 6.3.3 release binaries);
	# the freshly linked overlays shadow the 5.2.2 ones through the script's -L order.
	add_custom_command(OUTPUT ${_srt_overlay_outputs}
		COMMAND ${CMAKE_COMMAND} -E env ${_srt_env}
			SWIFT_RUNTIME_DIR=${CMAKE_CURRENT_SOURCE_DIR}
			CRYPTOKIT_MODULES_BUILD_DIR=${_srt_overlays} LD_EXTRA_FLAGS=
			sh ${CMAKE_CURRENT_SOURCE_DIR}/overlays/CryptoKit/build-runtime-inputs.sh
		DEPENDS ${_srt_overlay_sources} ${APPLE_TARGET_TRIPLET_64BIT}-ld
		COMMENT "Building x86_64 Swift overlays and Combine from source"
		VERBATIM USES_TERMINAL)
	add_custom_command(OUTPUT "${_srt_cryptokit}/CryptoKit"
		COMMAND ${CMAKE_COMMAND} -E env ${_srt_env}
			SWIFT_RUNTIME_DIR=${_srt_overlays}/runtime OVERLAY_BUILD_DIR=${_srt_overlays}
			CRYPTOKIT_BUILD_DIR=${_srt_cryptokit}
			"LD_EXTRA_FLAGS=-syslibroot ${DARLING_SWIFT_LINK_ROOT} -dylib_file @rpath/libswiftCoreGraphics.dylib:${CMAKE_CURRENT_SOURCE_DIR}/libswiftCoreGraphics.dylib"
			sh ${CMAKE_CURRENT_SOURCE_DIR}/overlays/CryptoKit/build.sh
		DEPENDS ${_srt_overlay_outputs} ${_srt_overlay_sources}
		COMMENT "Building x86_64 CryptoKit from source"
		VERBATIM USES_TERMINAL)
	# Swift 6 toolchain SDKs split Darwin into _DarwinFoundation1..3; binaries built against them
	# bind Darwin-module symbols (e.g. $s6Darwin5errnos5Int32Vvg) to this image. It carries no code
	# and re-exports the rebuilt Darwin overlay, like libswift_errno above re-exports Darwin.
	# Install name and compatibility version 1.0.0 from CotEditor 7.1.3's load command (rung 5).
	set(_srt_darwinfoundation1 "${_srt_overlays}/libswift_DarwinFoundation1.dylib")
	add_custom_command(OUTPUT "${_srt_darwinfoundation1}"
		COMMAND ${_srt_ld} -dylib -arch x86_64 -platform_version macos 26.0 26.0
			-syslibroot ${DARLING_SWIFT_LINK_ROOT}
			-install_name /usr/lib/swift/libswift_DarwinFoundation1.dylib
			-compatibility_version 1.0.0 -current_version 1.0.0
			-reexport_library ${_srt_overlays}/libswiftDarwin.dylib
			${DARLING_SWIFT_LINK_ROOT}/usr/lib/libSystem.B.dylib
			-o "${_srt_darwinfoundation1}"
		DEPENDS ${_srt_overlay_outputs}
		COMMENT "Linking x86_64 libswift_DarwinFoundation1 re-export"
		VERBATIM)
	add_custom_target(swift_source_runtime ALL
		DEPENDS ${_srt_overlay_outputs} "${_srt_cryptokit}/CryptoKit" "${_srt_darwinfoundation1}")
	install(FILES "${_srt_darwinfoundation1}" DESTINATION libexec/darling/usr/lib/swift ${_srt_component})
	set(SWIFT_SOURCE_RUNTIME_DIR "${_srt_overlays}" CACHE INTERNAL "")
	set(SWIFT_SOURCE_RUNTIME_CRYPTOKIT "${_srt_cryptokit}/CryptoKit" CACHE INTERNAL "")
	foreach(_module ${SWIFT_SOURCE_RUNTIME_OVERLAYS})
		if(DARLING_BUILD_IMPORT_OVERLAYS AND (_module STREQUAL "CoreFoundation" OR _module STREQUAL "os"))
			continue()
		endif()
		install(FILES "${_srt_overlays}/libswift${_module}.dylib" DESTINATION libexec/darling/usr/lib/swift
			${_srt_component})
	endforeach()
else()
	unset(SWIFT_SOURCE_RUNTIME_DIR CACHE)
	unset(SWIFT_SOURCE_RUNTIME_CRYPTOKIT CACHE)
endif()

if(DARLING_BUILD_IMPORT_OVERLAYS)
    if(TARGET_ARM64)
        message(FATAL_ERROR "Import overlays currently support x86_64 only")
    endif()
    add_subdirectory(overlays/imports)
endif()
file(GLOB DYLIBS "*.dylib")
foreach(_name ${_swift_source_runtime_names})
	list(REMOVE_ITEM DYLIBS "${CMAKE_CURRENT_SOURCE_DIR}/${_name}")
endforeach()
if(DARLING_BUILD_IMPORT_OVERLAYS)
    file(GLOB import_recipes "${CMAKE_CURRENT_SOURCE_DIR}/overlays/*/imports.json")
    foreach(recipe IN LISTS import_recipes)
        get_filename_component(module_dir "${recipe}" DIRECTORY)
        get_filename_component(module "${module_dir}" NAME)
        list(REMOVE_ITEM DYLIBS "${CMAKE_CURRENT_SOURCE_DIR}/libswift${module}.dylib")
    endforeach()
endif()
if(DYLIBS)
	install(FILES ${DYLIBS} DESTINATION libexec/darling/usr/lib/swift)
endif()

# Combine is a universal Swift framework (x86_64 + arm64 built from OpenCombine MIT).
include(InstallSymlink)
set(COMBINE_FRAMEWORK_DIR "libexec/darling/System/Library/Frameworks/Combine.framework")
if(DARLING_SWIFT_SOURCE_RUNTIME)
	install(PROGRAMS "${_srt_overlays}/Combine.framework/Versions/A/Combine"
		DESTINATION "${COMBINE_FRAMEWORK_DIR}/Versions/A" ${_srt_component})
else()
	install(PROGRAMS Combine.framework/Versions/A/Combine
		DESTINATION "${COMBINE_FRAMEWORK_DIR}/Versions/A")
endif()
InstallSymlink(A "${CMAKE_INSTALL_PREFIX}/${COMBINE_FRAMEWORK_DIR}/Versions/Current" ${_srt_component})
InstallSymlink(Versions/Current/Combine "${CMAKE_INSTALL_PREFIX}/${COMBINE_FRAMEWORK_DIR}/Combine" ${_srt_component})

# The bundled CryptoKit is arm64-only. Other targets need an explicit source build.
set(DARLING_CRYPTOKIT_BINARY ""
    CACHE FILEPATH "Source-built CryptoKit executable for the configured target architecture")
set(_cryptokit_bundled "${CMAKE_CURRENT_SOURCE_DIR}/CryptoKit.framework/Versions/A/CryptoKit")
set(_cryptokit_binary "${DARLING_CRYPTOKIT_BINARY}")
if(NOT _cryptokit_binary AND DARLING_SWIFT_SOURCE_RUNTIME)
    set(_cryptokit_binary "${SWIFT_SOURCE_RUNTIME_CRYPTOKIT}")
endif()
if(NOT _cryptokit_binary AND TARGET_ARM64)
    set(_cryptokit_binary "${_cryptokit_bundled}")
endif()
if(_cryptokit_binary)
    if(NOT TARGET_ARM64 AND _cryptokit_binary STREQUAL _cryptokit_bundled)
        message(FATAL_ERROR "Bundled CryptoKit is arm64-only; select an explicit source-built executable for this target")
    endif()
    if(NOT EXISTS "${_cryptokit_binary}" AND NOT _cryptokit_binary STREQUAL SWIFT_SOURCE_RUNTIME_CRYPTOKIT)
        message(FATAL_ERROR "CryptoKit executable does not exist: ${_cryptokit_binary}")
    endif()
    set(CRYPTOKIT_FRAMEWORK_DIR "libexec/darling/System/Library/Frameworks/CryptoKit.framework")
    install(PROGRAMS "${_cryptokit_binary}"
        DESTINATION "${CRYPTOKIT_FRAMEWORK_DIR}/Versions/A" RENAME CryptoKit ${_srt_component})
    InstallSymlink(A "${CMAKE_INSTALL_PREFIX}/${CRYPTOKIT_FRAMEWORK_DIR}/Versions/Current" ${_srt_component})
    InstallSymlink(Versions/Current/CryptoKit "${CMAKE_INSTALL_PREFIX}/${CRYPTOKIT_FRAMEWORK_DIR}/CryptoKit" ${_srt_component})
endif()

# GroupActivities has no source-built x86_64 slice yet.
if(TARGET_ARM64)
	set(GROUPACTIVITIES_FRAMEWORK_DIR "libexec/darling/System/Library/Frameworks/GroupActivities.framework")
	install(PROGRAMS GroupActivities.framework/Versions/A/GroupActivities
		DESTINATION "${GROUPACTIVITIES_FRAMEWORK_DIR}/Versions/A")
	InstallSymlink(A "${CMAKE_INSTALL_PREFIX}/${GROUPACTIVITIES_FRAMEWORK_DIR}/Versions/Current")
	InstallSymlink(Versions/Current/GroupActivities "${CMAKE_INSTALL_PREFIX}/${GROUPACTIVITIES_FRAMEWORK_DIR}/GroupActivities")
endif()

# Newer clients bind Darwin's errno and POSIXErrorCode to this split overlay.
# Their implementations remain in the real Swift Darwin source overlay.
set(DARLING_DARWIN_FOUNDATION_OVERLAY "${CMAKE_CURRENT_SOURCE_DIR}/libswiftDarwin.dylib"
    CACHE FILEPATH "Source-built Swift Darwin overlay matching the selected runtime")
if(NOT EXISTS "${DARLING_DARWIN_FOUNDATION_OVERLAY}")
    message(FATAL_ERROR "Swift Darwin overlay does not exist")
endif()
set(DYLIB_INSTALL_NAME "/usr/lib/swift/libswift_DarwinFoundation1.dylib")
add_darling_library(swift_DarwinFoundation1 SHARED swift_DarwinFoundation1.S)
target_link_libraries(swift_DarwinFoundation1 system)
set_target_properties(swift_DarwinFoundation1 PROPERTIES
    LINKER_LANGUAGE C OUTPUT_NAME "swift_DarwinFoundation1")
# Keep both install-name mappings in use_ld64 aligned with the re-export.
get_property(_darwin_foundation_flags TARGET swift_DarwinFoundation1 PROPERTY LINK_FLAGS)
string(REPLACE "${CMAKE_SOURCE_DIR}/src/external/swift/libswiftDarwin.dylib"
    "${DARLING_DARWIN_FOUNDATION_OVERLAY}"
    _darwin_foundation_flags "${_darwin_foundation_flags}")
set_property(TARGET swift_DarwinFoundation1 PROPERTY LINK_FLAGS "${_darwin_foundation_flags}")
set_property(TARGET swift_DarwinFoundation1 APPEND_STRING PROPERTY LINK_FLAGS
    " -Wl,-reexport_library,${DARLING_DARWIN_FOUNDATION_OVERLAY}")
set_property(TARGET swift_DarwinFoundation1 APPEND PROPERTY LINK_DEPENDS
    "${DARLING_DARWIN_FOUNDATION_OVERLAY}")
install(TARGETS swift_DarwinFoundation1 DESTINATION libexec/darling/usr/lib/swift)
