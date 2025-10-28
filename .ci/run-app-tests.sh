#!/bin/bash

# Configuration
TIMEOUT=5
TOOLCHAIN_TYPE=${TOOLCHAIN_TYPE:-gnu}

# Initialize JSON results array
JSON_RESULTS="[]"

# Test a single app: build, run, check
# Returns: 0=passed, 1=failed, 2=build_failed
# Also updates JSON_RESULTS with test result
test_app() {
	local app=$1
	local status details=""

	echo "=== Testing $app ($TOOLCHAIN_TYPE) ==="

	# Build phase
	echo "[+] Building..."
	make clean >/dev/null 2>&1
	if ! make "$app" TOOLCHAIN_TYPE="$TOOLCHAIN_TYPE" >/dev/null 2>&1; then
		echo "[!] Build failed"
		status="build_failed"
		details="Build compilation failed"
		add_test_result "$app" "$status" "$details"
		return 2
	fi

	# Run phase
	echo "[+] Running in QEMU (timeout: ${TIMEOUT}s)..."
	local output exit_code
	output=$(timeout ${TIMEOUT}s qemu-system-riscv32 -nographic -machine virt -bios none -kernel build/image.elf 2>&1)
	exit_code=$?

	# Check phase
	if echo "$output" | grep -qiE "(trap|exception|fault|panic|illegal|segfault)"; then
		echo "[!] Crash detected"
		status="failed"
		details="Crash detected in output"
		add_test_result "$app" "$status" "$details"
		return 1
	elif [ $exit_code -eq 124 ] || [ $exit_code -eq 0 ]; then
		echo "[✓] Passed"
		status="passed"
		add_test_result "$app" "$status" ""
		return 0
	else
		echo "[!] Exit code $exit_code"
		status="failed" 
		details="Non-zero exit code: $exit_code"
		add_test_result "$app" "$status" "$details"
		return 1
	fi
}

# Add test result to JSON array
add_test_result() {
	local app_name="$1"
	local status="$2"
	local details="$3"
	
	local new_result
	if [ -n "$details" ]; then
		new_result=$(jq -n \
			--arg app_name "$app_name" \
			--arg status "$status" \
			--arg details "$details" \
			'{app_name: $app_name, status: $status, details: $details}')
	else
		new_result=$(jq -n \
			--arg app_name "$app_name" \
			--arg status "$status" \
			'{app_name: $app_name, status: $status}')
	fi
	
	JSON_RESULTS=$(echo "$JSON_RESULTS" | jq --argjson result "$new_result" '. + [$result]')
}

# Auto-discover apps if none provided
if [ $# -eq 0 ]; then
	APPS=$(find app/ -name "*.c" -exec basename {} .c \; | sort | tr '\n' ' ')
	echo "[+] Auto-discovered apps: $APPS"
else
	APPS="$@"
fi

# Filter excluded apps
EXCLUDED_APPS=""
if [ -n "$EXCLUDED_APPS" ]; then
	FILTERED_APPS=""
	for app in $APPS; do
		[[ ! " $EXCLUDED_APPS " =~ " $app " ]] && FILTERED_APPS="$FILTERED_APPS $app"
	done
	APPS="$FILTERED_APPS"
fi

echo "[+] Testing apps: $APPS"
echo "[+] Toolchain: $TOOLCHAIN_TYPE"
echo ""

# Track results for summary
PASSED_APPS=""
FAILED_APPS=""
BUILD_FAILED_APPS=""

# Test each app
for app in $APPS; do
	test_app "$app"
	case $? in
	0) PASSED_APPS="$PASSED_APPS $app" ;;
	1) FAILED_APPS="$FAILED_APPS $app" ;;
	2) BUILD_FAILED_APPS="$BUILD_FAILED_APPS $app" ;;
	esac
	echo ""
done

# Summary (human readable)
echo "=== STEP 2 APP TEST RESULTS ==="
[ -n "$PASSED_APPS" ] && echo "[✓] PASSED:$PASSED_APPS"
[ -n "$FAILED_APPS" ] && echo "[!] FAILED (crashes):$FAILED_APPS"
[ -n "$BUILD_FAILED_APPS" ] && echo "[!] BUILD FAILED:$BUILD_FAILED_APPS"

# JSON output
echo ""
echo "=== JSON_OUTPUT ==="
echo "$JSON_RESULTS" | jq '.'

# Exit status
if [ -n "$FAILED_APPS" ] || [ -n "$BUILD_FAILED_APPS" ]; then
	echo ""
	echo "[!] Step 2 validation FAILED"
	exit 1
else
	echo ""
	echo "[+] Step 2 validation PASSED"
fi
