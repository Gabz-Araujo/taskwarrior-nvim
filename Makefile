.PHONY: test test-file test-dir lint

# Default task
all: test

# Run all tests
test:
	@echo "Running all tests..."
	@find tests -name "*_spec.lua" -print0 | xargs -0 -I{} sh -c 'echo "\nRunning test: {}" && nvim --headless --clean -u tests/minimal_init.lua -c "lua require('\''plenary.busted'\'').run('\''{}'\'')" -c "qa!" || exit 1'
	@echo "\nAll tests completed successfully!"

# Run specific test file (make test-file FILE=tests/domain/task_spec.lua)
test-file:
	@echo "Running test: $(FILE)"
	@nvim --headless --clean -u tests/minimal_init.lua -c "lua require('plenary.busted').run('$(FILE)')" -c "qa!"

# Run specific test directory (make test-dir DIR=tests/domain)
test-dir:
	@echo "Running tests in directory: $(DIR)"
	@find $(DIR) -name "*_spec.lua" -print0 | xargs -0 -I{} sh -c 'echo "\nRunning test: {}" && nvim --headless --clean -u tests/minimal_init.lua -c "lua require('\''plenary.busted'\'').run('\''{}'\'')" -c "qa!" || exit 1'
	@echo "\nAll tests in $(DIR) completed successfully!"

# Run tests with coverage
# Note: You need to install luacov and luacov-reporter first
coverage:
	@echo "Running tests with coverage..."
	@rm -f luacov.stats.out luacov.report.out
	@LUA_PATH='lua/?.lua;lua/?/init.lua;$(LUA_PATH)' nvim --headless --clean -u tests/minimal_init.lua -c "lua require('plenary.busted').run('tests')" -c "qa!"
	@luacov
	@echo "Coverage report generated: luacov.report.out"

# Lint code with luacheck
# Note: You need to install luacheck first
lint:
	@echo "Linting code..."
	@luacheck lua/ tests/

