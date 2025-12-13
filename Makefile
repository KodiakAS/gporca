# Simple helper Makefile for local or CI builds

BUILD_DIR ?= build
# 默认以 Debug 构建以便本地 make test 捕获调试断言/测试
BUILD_TYPE ?= Debug
GENERATOR ?= Ninja
JOBS ?= 8
CMAKE_ARGS ?=
CTEST_ARGS ?=
TARGET ?=

configure:
	@mkdir -p "$(BUILD_DIR)"
	cmake -G "$(GENERATOR)" -S . -B "$(BUILD_DIR)" -DCMAKE_BUILD_TYPE="$(BUILD_TYPE)" -DCMAKE_EXPORT_COMPILE_COMMANDS=ON $(CMAKE_ARGS)

build: configure
	ninja -C "$(BUILD_DIR)" $(TARGET)

test: build
	cd "$(BUILD_DIR)" && ctest -j"$(JOBS)" --output-on-failure $(CTEST_ARGS)

clean:
	@rm -rf "$(BUILD_DIR)"

.PHONY: configure build test clean
