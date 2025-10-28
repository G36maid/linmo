#!/bin/bash

# Configuration
TIMEOUT=5
TOOLCHAIN_TYPE=${TOOLCHAIN_TYPE:-gnu}

# Define functional tests and their expected PASS criteria
declare -A FUNCTIONAL_TESTS
FUNCTIONAL_TESTS["mutex"]="Fairness: PASS,Mutual Exclusion: PASS,Data Consistency: PASS,Overall: PASS"
FUNCTIONAL_TESTS["semaphore"]="All tests PASSED!"
#FUNCTIONAL_TESTS["test64"]="Unsigned Multiply: PASS,Unsigned Divide: PASS,Signed Multiply: PASS,Signed Divide: PASS,Left Shifts: PASS,Logical Right Shifts: PASS,Arithmetic Right Shifts: PASS,Overall: PASS"
#FUNCTIONAL_TESTS["suspend"]="Suspend: PASS,Resume: PASS,Self-Suspend: PASS,Overall: PASS"

# Add more functional tests here as they are developed
# Format: FUNCTIONAL_TESTS["app_name"]="Criterion: PASS,Criterion: PASS,..."
#
# Example entries for future functional tests:
# FUNCTIONAL_TESTS["cond"]="Producer Cycles: PASS,Consumer Cycles: PASS,Mutex Trylock: PASS,Overall: PASS"
# FUNCTIONAL_TESTS["pipes"]="Bidirectional IPC: PASS,Data Integrity: PASS,Overall: PASS"
# FUNCTIONAL_TESTS["mqueues"]="Multi-Queue Routing: PASS,Task Synchronization: PASS,Overall: PASS"

# Store detailed criteria results
declare -A CRITERIA_RESULTS

# Initialize JSON results array
JSON_RESULTS="[]"

# Add test result to JSON array
add_functional_test_result() {
	local test_name="$1"
	local overall_status="$2"
	local criteria_json="$3"
	local details="$4"
	
	local new_result
	if [ -n "$details" ]; then
		new_result=$(jq -n \
			--arg test_name "$test_name" \
			--arg overall_status "$overall_status" \
			--argjson criteria "$criteria_json" \
			--arg details "$details" \
			'{test_name: $test_name, overall_status: $overall_status, criteria: $criteria, details: $details}')
	else
		new_result=$(jq -n \
			--arg test_name "$test_name" \
			--arg overall_status "$overall_status" \
			--argjson criteria "$criteria_json" \
			'{test_name: $test_name, overall_status: $overall_status, criteria: $criteria}')
	fi
	
	JSON_RESULTS=$(echo "$JSON_RESULTS" | jq --argjson result "$new_result" '. + [$result]')
}

# Test a single functional test: build, run, validate criteria
# Returns: 0=passed, 1=failed, 2=build_failed, 3=unknown_test
test_functional_app() {
	local test=$1

	echo "=== Functional Test: $test ==="

	# Check if test is defined
	if [ -z "${FUNCTIONAL_TESTS[$test]}" ]; then
		echo "[!] Unknown test (not in FUNCTIONAL_TESTS)"
		add_functional_test_result "$test" "unknown" "[]" "Test not defined in FUNCTIONAL_TESTS"
		return 3
	fi

	# Build phase
	echo "[+] Building..."
	make clean >/dev/null 2>&1
	if ! make "$test" TOOLCHAIN_TYPE="$TOOLCHAIN_TYPE" >/dev/null 2>&1; then
		echo "[!] Build failed"

		# Mark all criteria as build_failed and build JSON
		local expected_passes="${FUNCTIONAL_TESTS[$test]}"
		IFS=',' read -ra PASS_CRITERIA <<<"$expected_passes"
		local criteria_json="[]"
		for criteria in "${PASS_CRITERIA[@]}"; do
			local criteria_key=$(echo "$criteria" | sed 's/: PASS//g' | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
			local criteria_name=$(echo "$criteria" | sed 's/: PASS//g')
			CRITERIA_RESULTS["$test:$criteria_key"]="build_failed"
			
			local criteria_obj=$(jq -n \
				--arg name "$criteria_name" \
				--arg status "build_failed" \
				'{name: $name, status: $status}')
			criteria_json=$(echo "$criteria_json" | jq --argjson obj "$criteria_obj" '. + [$obj]')
		done

		add_functional_test_result "$test" "build_failed" "$criteria_json" "Build failed"
		return 2
	fi

	# Run phase
	echo "[+] Running (timeout: ${TIMEOUT}s)..."
	local output exit_code
	output=$(timeout ${TIMEOUT}s qemu-system-riscv32 -nographic -machine virt -bios none -kernel build/image.elf 2>&1)
	exit_code=$?

	# Parse expected criteria
	local expected_passes="${FUNCTIONAL_TESTS[$test]}"
	IFS=',' read -ra PASS_CRITERIA <<<"$expected_passes"

	# Check for crashes first
	if echo "$output" | grep -qiE "(trap|exception|fault|panic|illegal|segfault)"; then
		echo "[!] Crash detected"

		# Mark all criteria as crashed and build JSON
		local criteria_json="[]"
		for criteria in "${PASS_CRITERIA[@]}"; do
			local criteria_key=$(echo "$criteria" | sed 's/: PASS//g' | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
			local criteria_name=$(echo "$criteria" | sed 's/: PASS//g')
			CRITERIA_RESULTS["$test:$criteria_key"]="crashed"
			
			local criteria_obj=$(jq -n \
				--arg name "$criteria_name" \
				--arg status "crashed" \
				'{name: $name, status: $status}')
			criteria_json=$(echo "$criteria_json" | jq --argjson obj "$criteria_obj" '. + [$obj]')
		done

		add_functional_test_result "$test" "crashed" "$criteria_json" "Crash detected"
		return 1
	fi

	# Check exit code
	if [ $exit_code -eq 124 ]; then
		echo "[!] Timeout (test hung)"

		# Mark all criteria as timeout and build JSON
		local criteria_json="[]"
		for criteria in "${PASS_CRITERIA[@]}"; do
			local criteria_key=$(echo "$criteria" | sed 's/: PASS//g' | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
			local criteria_name=$(echo "$criteria" | sed 's/: PASS//g')
			CRITERIA_RESULTS["$test:$criteria_key"]="timeout"
			
			local criteria_obj=$(jq -n \
				--arg name "$criteria_name" \
				--arg status "timeout" \
				'{name: $name, status: $status}')
			criteria_json=$(echo "$criteria_json" | jq --argjson obj "$criteria_obj" '. + [$obj]')
		done

		add_functional_test_result "$test" "timeout" "$criteria_json" "Test hung (timeout)"
		return 1
	elif [ $exit_code -ne 0 ]; then
		echo "[!] Exit code $exit_code"

		# Mark all criteria as failed and build JSON
		local criteria_json="[]"
		for criteria in "${PASS_CRITERIA[@]}"; do
			local criteria_key=$(echo "$criteria" | sed 's/: PASS//g' | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
			local criteria_name=$(echo "$criteria" | sed 's/: PASS//g')
			CRITERIA_RESULTS["$test:$criteria_key"]="failed"
			
			local criteria_obj=$(jq -n \
				--arg name "$criteria_name" \
				--arg status "failed" \
				'{name: $name, status: $status}')
			criteria_json=$(echo "$criteria_json" | jq --argjson obj "$criteria_obj" '. + [$obj]')
		done

		add_functional_test_result "$test" "failed" "$criteria_json" "Exit code $exit_code"
		return 1
	fi

	# Validate criteria
	echo "[+] Checking PASS criteria:"
	local all_passes_found=true
	local missing_passes=""

	for criteria in "${PASS_CRITERIA[@]}"; do
		local criteria_key=$(echo "$criteria" | sed 's/: PASS//g' | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

		if echo "$output" | grep -qF "$criteria"; then
			echo "  ✓ Found: $criteria"
			CRITERIA_RESULTS["$test:$criteria_key"]="passed"
		else
			echo "  ✗ Missing: $criteria"
			all_passes_found=false
			missing_passes="$missing_passes '$criteria'"
			CRITERIA_RESULTS["$test:$criteria_key"]="failed"
		fi
	done

	# Build criteria JSON
	local criteria_json="[]"
	for criteria in "${PASS_CRITERIA[@]}"; do
		local criteria_key=$(echo "$criteria" | sed 's/: PASS//g' | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
		local criteria_name=$(echo "$criteria" | sed 's/: PASS//g')
		local criteria_status="${CRITERIA_RESULTS["$test:$criteria_key"]}"
		
		local criteria_obj=$(jq -n \
			--arg name "$criteria_name" \
			--arg status "$criteria_status" \
			'{name: $name, status: $status}')
		criteria_json=$(echo "$criteria_json" | jq --argjson obj "$criteria_obj" '. + [$obj]')
	done

	# Determine result and add to JSON results
	if [ "$all_passes_found" = true ]; then
		echo "[✓] All criteria passed"
		add_functional_test_result "$test" "passed" "$criteria_json"
		return 0
	else
		echo "[!] Missing criteria:$missing_passes"
		add_functional_test_result "$test" "failed" "$criteria_json" "Missing criteria:$missing_passes"
		return 1
	fi
}

echo "[+] Linmo Functional Test Suite (Step 3)"
echo "[+] Toolchain: $TOOLCHAIN_TYPE"
echo "[+] Timeout: ${TIMEOUT}s per test"
echo ""

# Get list of tests to run
if [ $# -eq 0 ]; then
	TESTS_TO_RUN=$(echo "${!FUNCTIONAL_TESTS[@]}" | tr ' ' '\n' | sort | tr '\n' ' ')
	echo "[+] Running all functional tests: $TESTS_TO_RUN"
else
	TESTS_TO_RUN="$@"
	echo "[+] Running specified tests: $TESTS_TO_RUN"
fi

echo ""

# Track results
PASSED_TESTS=""
FAILED_TESTS=""
BUILD_FAILED_TESTS=""
TOTAL_TESTS=0

# Test each app
for test in $TESTS_TO_RUN; do
	TOTAL_TESTS=$((TOTAL_TESTS + 1))

	test_functional_app "$test"
	case $? in
	0) PASSED_TESTS="$PASSED_TESTS $test" ;;
	1) FAILED_TESTS="$FAILED_TESTS $test" ;;
	2) BUILD_FAILED_TESTS="$BUILD_FAILED_TESTS $test" ;;
	3) FAILED_TESTS="$FAILED_TESTS $test" ;;
	esac
	echo ""
done

# Summary
echo ""
echo "=== STEP 3 FUNCTIONAL TEST RESULTS ==="
echo "Total tests: $TOTAL_TESTS"
[ -n "$PASSED_TESTS" ] && echo "[✓] PASSED ($(echo $PASSED_TESTS | wc -w)):$PASSED_TESTS"
[ -n "$FAILED_TESTS" ] && echo "[!] FAILED ($(echo $FAILED_TESTS | wc -w)):$FAILED_TESTS"
[ -n "$BUILD_FAILED_TESTS" ] && echo "[!] BUILD FAILED ($(echo $BUILD_FAILED_TESTS | wc -w)):$BUILD_FAILED_TESTS"

# JSON output
echo ""
echo "[DEBUG] About to emit JSON output for $TOTAL_TESTS tests"
echo "=== JSON_OUTPUT ==="
echo "$JSON_RESULTS" | jq '.'
echo "[DEBUG] Finished emitting JSON output"

# Exit status
if [ -n "$FAILED_TESTS" ] || [ -n "$BUILD_FAILED_TESTS" ]; then
	echo ""
	echo "[!] Step 3 functional tests FAILED"
	exit 1
else
	echo ""
	echo "[+] Step 3 functional tests PASSED"
fi
