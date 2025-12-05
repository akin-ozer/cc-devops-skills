# Good Makefile Example
# Demonstrates best practices for Makefile creation
# Project: Example Application
# Version: 1.0.0

# Modern Makefile Header (GNU Make 4.0+)
# See: https://tech.davis-hansson.com/p/make/
SHELL := bash

# Delete target on recipe failure (GNU Make best practice)
.DELETE_ON_ERROR:

# Disable built-in suffix rules for faster builds
.SUFFIXES:

# Variables with immediate expansion (recommended)
PROJECT := example-app
VERSION := 1.0.0
BUILD_DIR := build
SRC_DIR := src
TEST_DIR := tests

# Compiler and flags
CC ?= gcc
CFLAGS := -Wall -Wextra -O2
LDFLAGS :=

# Find source files
SOURCES := $(wildcard $(SRC_DIR)/*.c)
OBJECTS := $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(SOURCES))

# Phony targets properly declared
.PHONY: all build clean test install uninstall help

# Default target (first in file)
all: build test

# Help target for user guidance
help:
	@echo "Available targets:"
	@echo "  make build     - Build the application"
	@echo "  make test      - Run tests"
	@echo "  make clean     - Remove build artifacts"
	@echo "  make install   - Install to PREFIX (default: /usr/local)"
	@echo "  make uninstall - Remove installed files"
	@echo "  make help      - Show this help message"

# Build the main application
build: $(BUILD_DIR)/$(PROJECT)
	@echo "Build complete: $(BUILD_DIR)/$(PROJECT)"

# Link object files into executable
$(BUILD_DIR)/$(PROJECT): $(OBJECTS) | $(BUILD_DIR)
	@echo "Linking $@..."
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@

# Compile source files to object files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	@echo "Compiling $<..."
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Create build directory (order-only prerequisite)
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Run tests
test: build
	@echo "Running tests..."
	@set -e; \
	for test in $(TEST_DIR)/*.sh; do \
		echo "  Running $$test..."; \
		bash $$test; \
	done
	@echo "All tests passed!"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@if [ -d "$(BUILD_DIR)" ]; then \
		rm -rf $(BUILD_DIR); \
		echo "  Removed $(BUILD_DIR)"; \
	fi
	@echo "Clean complete"

# Installation with proper defaults
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

install: build
	@echo "Installing $(PROJECT) to $(DESTDIR)$(BINDIR)..."
	@install -d $(DESTDIR)$(BINDIR)
	@install -m 755 $(BUILD_DIR)/$(PROJECT) $(DESTDIR)$(BINDIR)/
	@echo "Installation complete"

# Uninstall
uninstall:
	@echo "Uninstalling $(PROJECT) from $(DESTDIR)$(BINDIR)..."
	@if [ -f "$(DESTDIR)$(BINDIR)/$(PROJECT)" ]; then \
		rm -f $(DESTDIR)$(BINDIR)/$(PROJECT); \
		echo "  Removed $(DESTDIR)$(BINDIR)/$(PROJECT)"; \
	fi
	@echo "Uninstall complete"