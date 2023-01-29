#Build Type
#Two possible values
#debug
#release
BUILD_TYPE = debug

#Build directory
BUILD_DIR = ./build

#Makefile generated from CMake
GENERATED_MAKEFILE = $(BUILD_DIR)/Makefile

#CMake flags
CMAKE_FLAGS = -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) -DBUILD_LLVM_PASSES=ON

#Check if cmake is installed
CMAKE = $(shell command -v cmake 2> /dev/null)

.PHONY: all
all: $(GENERATED_MAKEFILE)
	@ echo "Running build all..."
	@ $(MAKE) -C $(BUILD_DIR) --no-print-directory all

.PHONY: clean
clean: $(GENERATED_MAKEFILE)
	@ echo "Running clean, removing generated files..."
	@ $(MAKE) -C $(BUILD_DIR) --no-print-directory clean

.PHONY: fullclean
fullclean:
	@ echo "Running fullclean, removing the build results completely..."
	@ rm -rf thirdparty/scipoptsuite/*/
	@ rm -rf $(BUILD_DIR)

.PHONY: $(GENERATED_MAKEFILE)
$(GENERATED_MAKEFILE):
ifndef CMAKE
	$(error Required 'cmake' not found. Please install cmake.)
endif
	@ mkdir -p $(BUILD_DIR)
	@ echo $(CMAKE_FLAGS)
	@ cd $(BUILD_DIR) && $(CMAKE) $(CMAKE_FLAGS) ..

# $@  表示目标文件
# $^  表示所有的依赖文件
# $<  表示第一个依赖文件
# $?  表示比目标还要新的依赖文件列表
# git ===========================================================================================
commit:clean
	git add -A
	@echo "Please type in commit comment: "; \
	read comment; \
	git commit -m"$$comment"

sync: commit
	git push -u origin main

set_env:
	./cgrame_env
# projects ======================================================================================
proj			= sum
BENCHMARK_DIR	= ./benchmarks/microbench
LOOP_PARSER 	= ./build/script/LoopParser.py
PROJ_DIR		= $(BENCHMARK_DIR)/$(proj)
PREFIX			= $(PROJ_DIR)/$(proj)
LLVM_DFG_PLUGIN	= ./build/lib/libDFG.so
TAG				= $(PREFIX).tag
TAG_C			= $(PREFIX).tagged.c
BC_FILE			= $(PREFIX).bc
LL_FILE			= $(PREFIX).ll
PWD				= $(shell pwd)

build:$(proj).dot

view:
	xdot graph_loop.dot &
view_sample:
	# xdot $(PROJ_DIR)/pre-gen-graph_loop.dot &

$(proj).dot: $(TAG) $(BC_FILE) $(LLVM_DFG_PLUGIN)
	opt '$(BC_FILE)' -o '/dev/null' -enable-new-pm=0 -load '$(LLVM_DFG_PLUGIN)' --dfg-out -in-tag-pairs '$(TAG)' -loop-tags 'loop'
$(PREFIX).bc: $(TAG) $(TAG_C)
	clang -emit-llvm -c '$(TAG_C)' -o '$(PREFIX).bc' -O3 -fno-vectorize -fno-slp-vectorize -fno-unroll-loops
$(PREFIX).ll:$(PREFIX).bc
	llvm-dis '$(PREFIX).bc' -o '$(PREFIX).ll'
$(TAG) $(TAG_C): $(BENCHMARK_DIR)/$(proj)/$(proj).c
	$(LOOP_PARSER) $< $(TAG_C) $(TAG)
clean_proj:
	@echo
	cd $(PROJ_DIR) && make clean
