#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src"
BUILD_DIR="${ROOT_DIR}/build"
OUTPUT_DIR="${ROOT_DIR}/../../plugins/game_center_plugin"

: "${GODOT_HEADERS_DIR:?Set GODOT_HEADERS_DIR to the local Godot iOS headers directory}"

IOS_SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SIM_SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"
COMMON_GODOT_INCLUDES=(
	-I"${GODOT_HEADERS_DIR}"
	-I"${GODOT_HEADERS_DIR}/platform/ios"
	-I"${GODOT_HEADERS_DIR}/drivers/apple_embedded"
)

rm -rf "${BUILD_DIR}"
mkdir -p \
	"${BUILD_DIR}/debug/iphoneos" \
	"${BUILD_DIR}/debug/iphonesimulator" \
	"${BUILD_DIR}/release/iphoneos" \
	"${BUILD_DIR}/release/iphonesimulator" \
	"${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}/GodotGameCenter.debug.xcframework" "${OUTPUT_DIR}/GodotGameCenter.release.xcframework"

build_static_lib() {
	local sdk_path="$1"
	local arch="$2"
	local slice_dir="$3"
	local min_flag="$4"
	local debug_define="$5"

	xcrun clang++ \
		-std=c++17 \
		-fobjc-arc \
		-fobjc-weak \
		${debug_define:+${debug_define}} \
		-arch "${arch}" \
		-isysroot "${sdk_path}" \
		"${min_flag}" \
		"${COMMON_GODOT_INCLUDES[@]}" \
		-framework Foundation \
		-framework GameKit \
		-framework UIKit \
		-c "${SRC_DIR}/game_center_plugin.mm" \
		-o "${slice_dir}/game_center_plugin.o"

	xcrun clang++ \
		-std=c++17 \
		-fobjc-arc \
		-fobjc-weak \
		${debug_define:+${debug_define}} \
		-arch "${arch}" \
		-isysroot "${sdk_path}" \
		"${min_flag}" \
		"${COMMON_GODOT_INCLUDES[@]}" \
		-framework Foundation \
		-framework GameKit \
		-framework UIKit \
		-c "${SRC_DIR}/game_center_plugin_bootstrap.mm" \
		-o "${slice_dir}/game_center_plugin_bootstrap.o"

	libtool -static \
		-o "${slice_dir}/libGodotGameCenter.a" \
		"${slice_dir}/game_center_plugin.o" \
		"${slice_dir}/game_center_plugin_bootstrap.o"
}

build_static_lib "${IOS_SDK_PATH}" "arm64" "${BUILD_DIR}/debug/iphoneos" "-miphoneos-version-min=14.0" "-DDEBUG_ENABLED"
build_static_lib "${SIM_SDK_PATH}" "arm64" "${BUILD_DIR}/debug/iphonesimulator" "-mios-simulator-version-min=14.0" "-DDEBUG_ENABLED"
build_static_lib "${IOS_SDK_PATH}" "arm64" "${BUILD_DIR}/release/iphoneos" "-miphoneos-version-min=14.0" ""
build_static_lib "${SIM_SDK_PATH}" "arm64" "${BUILD_DIR}/release/iphonesimulator" "-mios-simulator-version-min=14.0" ""

xcodebuild -create-xcframework \
	-library "${BUILD_DIR}/debug/iphoneos/libGodotGameCenter.a" \
	-headers "${SRC_DIR}" \
	-library "${BUILD_DIR}/debug/iphonesimulator/libGodotGameCenter.a" \
	-headers "${SRC_DIR}" \
	-output "${OUTPUT_DIR}/GodotGameCenter.debug.xcframework"

xcodebuild -create-xcframework \
	-library "${BUILD_DIR}/release/iphoneos/libGodotGameCenter.a" \
	-headers "${SRC_DIR}" \
	-library "${BUILD_DIR}/release/iphonesimulator/libGodotGameCenter.a" \
	-headers "${SRC_DIR}" \
	-output "${OUTPUT_DIR}/GodotGameCenter.release.xcframework"

echo "Built xcframeworks in ${OUTPUT_DIR}"
