# Bad Makefile Example
# Demonstrates common mistakes and anti-patterns
# DO NOT USE THIS IN PRODUCTION!

# Variables with recursive expansion (inefficient)
BUILD_TIME = $(shell date +%Y%m%d-%H%M%S)
SOURCES = $(wildcard src/*.c)

# Hardcoded credentials (SECURITY ISSUE!)
API_KEY = sk-1234567890abcdef
DB_PASSWORD = super_secret_password

# No .PHONY declarations (major issue!)
all: build test

build:
    echo "Building..."
    gcc -o app $(SOURCES)

# Missing .PHONY - won't run if file 'test' exists
test:
	go test ./...

# Missing .PHONY - dangerous!
clean:
	rm -rf $(BUILD_DIR)/*

# Unsafe variable expansion
deploy:
	ssh user@$(SERVER) "cd /app && git pull origin $(BRANCH)"

# Missing error handling
install:
	cp app /usr/local/bin/
	cp docs/app.1 /usr/share/man/man1/

# Spaces instead of tabs in some recipes (syntax error!)
broken-target:
    echo "This uses spaces!"
    echo "This will fail!"

# Mixed tabs and spaces (syntax error!)
mixed:
	echo "This uses a tab"
    echo "This uses spaces - ERROR!"

# No dependency specification
app.o:
	gcc -c app.c

# Hardcoded paths (not portable)
backup:
	cp app /home/user/backups/

# No validation of dangerous operations
dangerous-clean:
	rm -rf $(USER_INPUT)/*

# Incorrect variable expansion in loop
loop-bug:
	for file in *.c; do \
		echo "Compiling $file"; \
		gcc -c $file; \
	done

# Missing := causing repeated shell calls
debug:
	echo $(BUILD_TIME)
	echo $(BUILD_TIME)

# Unquoted variable in dangerous context
unsafe-rm:
	rm -rf $(BUILD_DIR)

# No default values for critical variables
install-unsafe:
	cp app $(PREFIX)/bin/