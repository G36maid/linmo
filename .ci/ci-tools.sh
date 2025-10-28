#!/bin/bash
set -e

# CI Tools Script

SCRIPT_NAME=$(basename "$0")
COMMAND=${1:-help}

show_help() {
	cat <<EOF
Usage: $SCRIPT_NAME <command> [options]

Commands:
  collect-data <toolchain> <test_output> [functional_output]
    Extract and store test data from CI outputs

  aggregate <results_dir> <output_file>
    Combine results from all toolchains into TOML summary

  format-comment <toml_file>
    Generate formatted PR comment from TOML

  post-comment <toml_file> <pr_number>
    Post formatted comment to PR

  print-report <toml_file>
    Print clean TOML report

Examples:
  $SCRIPT_NAME collect-data gnu "\$test_output" "\$functional_output"
  $SCRIPT_NAME aggregate all-test-results test-summary.toml
  $SCRIPT_NAME format-comment test-summary.toml
  $SCRIPT_NAME post-comment test-summary.toml 123
  $SCRIPT_NAME print-report test-summary.toml
EOF
}

# Data collection function
collect_data() {
	local toolchain=${1:-unknown}
	local test_output=${2:-}
	local functional_output=${3:-}

	if [ -z "$test_output" ]; then
		echo "Error: test_output required"
		exit 1
	fi

	mkdir -p test-results
	echo "$toolchain" >test-results/toolchain

	# Extract JSON data from app tests output
	if echo "$test_output" | grep -q "=== JSON_OUTPUT ==="; then
		echo "[DEBUG] Found JSON_OUTPUT marker in app tests"
		json_section=$(echo "$test_output" | sed -n '/=== JSON_OUTPUT ===/,/\[DEBUG\] Finished emitting JSON output/p' | grep -v -E "=== JSON_OUTPUT ===|\[DEBUG\]")
		if [ -n "$json_section" ]; then
			echo "$json_section" > test-results/apps_data.json
			echo "[DEBUG] Saved apps JSON data ($(echo "$json_section" | wc -l) lines)"
		else
			echo "[]" > test-results/apps_data.json
		fi
	else
		echo "[DEBUG] No JSON_OUTPUT marker found in app tests, creating empty JSON"
		echo "[]" > test-results/apps_data.json
	fi

	# Extract JSON data from functional tests output
	if [ -n "$functional_output" ]; then
		echo "[DEBUG] Functional output received (length: ${#functional_output})"
		
		if echo "$functional_output" | grep -q "=== JSON_OUTPUT ==="; then
			echo "[DEBUG] Found JSON_OUTPUT marker in functional tests"
			json_section=$(echo "$functional_output" | sed -n '/=== JSON_OUTPUT ===/,/\[DEBUG\] Finished emitting JSON output/p' | grep -v -E "=== JSON_OUTPUT ===|\[DEBUG\]")
			if [ -n "$json_section" ]; then
				echo "$json_section" > test-results/functional_data.json
				echo "[DEBUG] Saved functional JSON data ($(echo "$json_section" | wc -l) lines)"
			else
				echo "[]" > test-results/functional_data.json
			fi
		else
			echo "[DEBUG] No JSON_OUTPUT marker found in functional tests, creating empty JSON"
			echo "[]" > test-results/functional_data.json
		fi
	else
		echo "[DEBUG] No functional output received"
		echo "[]" > test-results/functional_data.json
	fi

	# Determine exit codes
	test_exit=0
	functional_exit=0
	echo "$test_output" | grep -q "validation FAILED" && test_exit=1
	[ -n "$functional_output" ] && echo "$functional_output" | grep -q "functional tests FAILED" && functional_exit=1

	echo "$test_exit" >test-results/crash_exit_code
	echo "$functional_exit" >test-results/functional_exit_code

	echo "Test data collected for $toolchain toolchain"
}

# Result aggregation function
aggregate_results() {
	local results_dir=${1:-all-test-results}
	local output_file=${2:-test-summary.json}

	if [ ! -d "$results_dir" ]; then
		echo "Error: Results directory not found: $results_dir"
		exit 1
	fi

	# Initialize status
	gnu_build="failed" gnu_crash="failed" gnu_functional="failed"
	llvm_build="failed" llvm_crash="failed" llvm_functional="failed"
	overall="failed"

	# Initialize JSON data collections
	declare -A apps_json functional_json

	# Process artifacts
	for artifact_dir in "$results_dir"/test-results-*; do
		[ ! -d "$artifact_dir" ] && continue

		toolchain=$(cat "$artifact_dir/toolchain" 2>/dev/null || echo "unknown")
		crash_exit=$(cat "$artifact_dir/crash_exit_code" 2>/dev/null || echo "1")
		functional_exit=$(cat "$artifact_dir/functional_exit_code" 2>/dev/null || echo "1")

		build_status="passed"
		crash_status=$([ "$crash_exit" = "0" ] && echo "passed" || echo "failed")
		functional_status=$([ "$functional_exit" = "0" ] && echo "passed" || echo "failed")

		case "$toolchain" in
		"gnu")
			gnu_build="$build_status"
			gnu_crash="$crash_status"
			gnu_functional="$functional_status"
			;;
		"llvm")
			llvm_build="$build_status"
			llvm_crash="$crash_status"
			llvm_functional="$functional_status"
			;;
		esac

		# Collect apps JSON data
		if [ -f "$artifact_dir/apps_data.json" ] && [ -s "$artifact_dir/apps_data.json" ]; then
			apps_json["$toolchain"]=$(cat "$artifact_dir/apps_data.json")
		else
			apps_json["$toolchain"]="[]"
		fi

		# Collect functional tests JSON data
		if [ -f "$artifact_dir/functional_data.json" ] && [ -s "$artifact_dir/functional_data.json" ]; then
			functional_json["$toolchain"]=$(cat "$artifact_dir/functional_data.json")
		else
			functional_json["$toolchain"]="[]"
		fi
	done

	# Overall status
	if [ "$gnu_build" = "passed" ] && [ "$gnu_crash" = "passed" ] && [ "$gnu_functional" = "passed" ] &&
		[ "$llvm_build" = "passed" ] && [ "$llvm_crash" = "passed" ] && [ "$llvm_functional" = "passed" ]; then
		overall="passed"
	fi

	# Create base JSON structure
	base_json=$(jq -n \
		--arg overall_status "$overall" \
		--arg timestamp "$(date -Iseconds)" \
		--arg architecture "riscv32" \
		--arg timeout "5" \
		--arg gnu_build "$gnu_build" \
		--arg gnu_crash "$gnu_crash" \
		--arg gnu_functional "$gnu_functional" \
		--arg llvm_build "$llvm_build" \
		--arg llvm_crash "$llvm_crash" \
		--arg llvm_functional "$llvm_functional" \
		'{
			summary: {
				status: $overall_status,
				timestamp: $timestamp
			},
			info: {
				architecture: $architecture,
				timeout: ($timeout | tonumber)
			},
			gnu: {
				build: $gnu_build,
				crash: $gnu_crash,
				functional: $gnu_functional,
				apps: {},
				functional_tests: {},
				functional_criteria: {}
			},
			llvm: {
				build: $llvm_build,
				crash: $llvm_crash,
				functional: $llvm_functional,
				apps: {},
				functional_tests: {},
				functional_criteria: {}
			}
		}')

	# Process apps data for each toolchain
	for toolchain in gnu llvm; do
		if [ -n "${apps_json[$toolchain]}" ] && [ "${apps_json[$toolchain]}" != "[]" ]; then
			# Add app results from JSON
			base_json=$(echo "$base_json" | jq --arg tc "$toolchain" --argjson apps_data "${apps_json[$toolchain]}" '
				.[$tc].apps = ($apps_data | map({(.app_name): .status}) | add // {})
			')
		fi
	done

	# Process functional tests data for each toolchain  
	for toolchain in gnu llvm; do
		if [ -n "${functional_json[$toolchain]}" ] && [ "${functional_json[$toolchain]}" != "[]" ]; then
			# Add functional test results and criteria from JSON
			base_json=$(echo "$base_json" | jq --arg tc "$toolchain" --argjson func_data "${functional_json[$toolchain]}" '
				.[$tc].functional_tests = ($func_data | map({(.test_name): .overall_status}) | add // {}) |
				.[$tc].functional_criteria = ($func_data | map(
					.test_name as $test_name | .criteria // [] | map({("\($test_name):\(.name)"): .status})
				) | flatten | add // {})
			')
		fi
	done

	# Write JSON to file
	echo "$base_json" | jq '.' > "$output_file"

	echo "Results aggregated into $output_file"
	[ "$overall" = "passed" ] && exit 0 || exit 1
}

# JSON parsing helpers
get_json_value() {
	local path=$1 file=$2
	jq -r "$path // empty" "$file"
}

get_json_object_keys() {
	local path=$1 file=$2
	jq -r "$path | keys[]?" "$file" 2>/dev/null || true
}

get_symbol() {
	case $1 in
	"passed") echo "✅" ;; "failed") echo "❌" ;; *) echo "⚠️" ;;
	esac
}

# PR comment formatting
format_comment() {
	local json_file=${1:-test-summary.json}

	if [ ! -f "$json_file" ]; then
		echo "Error: JSON file not found: $json_file"
		exit 1
	fi

	# Extract basic info using jq
	overall_status=$(get_json_value '.summary.status' "$json_file")
	timestamp=$(get_json_value '.summary.timestamp' "$json_file")
	gnu_build=$(get_json_value '.gnu.build' "$json_file")
	gnu_crash=$(get_json_value '.gnu.crash' "$json_file")
	gnu_functional=$(get_json_value '.gnu.functional' "$json_file")
	llvm_build=$(get_json_value '.llvm.build' "$json_file")
	llvm_crash=$(get_json_value '.llvm.crash' "$json_file")
	llvm_functional=$(get_json_value '.llvm.functional' "$json_file")

	# Generate comment
	cat <<EOF
## Linmo CI Test Results

**Overall Status:** $(get_symbol "$overall_status") $overall_status
**Timestamp:** $timestamp

### Toolchain Results

| Toolchain | Build | Crash Test | Functional |
|-----------|-------|------------|------------|
| **GNU** | $(get_symbol "$gnu_build") $gnu_build | $(get_symbol "$gnu_crash") $gnu_crash | $(get_symbol "$gnu_functional") $gnu_functional |
| **LLVM** | $(get_symbol "$llvm_build") $llvm_build | $(get_symbol "$llvm_crash") $llvm_crash | $(get_symbol "$llvm_functional") $llvm_functional |
EOF

	# Apps section
	gnu_apps_keys=$(get_json_object_keys '.gnu.apps' "$json_file")
	llvm_apps_keys=$(get_json_object_keys '.llvm.apps' "$json_file")

	if [ -n "$gnu_apps_keys" ] || [ -n "$llvm_apps_keys" ]; then
		echo ""
		echo "### Application Tests"
		echo ""
		echo "| App | GNU | LLVM |"
		echo "|-----|-----|------|"

		# Get all unique app names
		all_apps=$(echo -e "$gnu_apps_keys\n$llvm_apps_keys" | sort -u | grep -v '^$')

		while IFS= read -r app; do
			[ -z "$app" ] && continue
			gnu_status=$(get_json_value ".gnu.apps[\"$app\"]" "$json_file")
			llvm_status=$(get_json_value ".llvm.apps[\"$app\"]" "$json_file")
			[ -z "$gnu_status" ] && gnu_status=""
			[ -z "$llvm_status" ] && llvm_status=""
			echo "| \`$app\` | $(get_symbol "$gnu_status") $gnu_status | $(get_symbol "$llvm_status") $llvm_status |"
		done <<< "$all_apps"
	fi

	# Functional tests section (detailed criteria)
	gnu_functional_criteria_keys=$(get_json_object_keys '.gnu.functional_criteria' "$json_file")
	llvm_functional_criteria_keys=$(get_json_object_keys '.llvm.functional_criteria' "$json_file")

	if [ -n "$gnu_functional_criteria_keys" ] || [ -n "$llvm_functional_criteria_keys" ]; then
		echo ""
		echo "### Functional Test Details"
		echo ""
		echo "| Test | GNU | LLVM |"
		echo "|------|-----|------|"

		# Get all unique criteria names
		all_criteria=$(echo -e "$gnu_functional_criteria_keys\n$llvm_functional_criteria_keys" | sort -u | grep -v '^$')

		while IFS= read -r criteria; do
			[ -z "$criteria" ] && continue
			gnu_status=$(get_json_value ".gnu.functional_criteria[\"$criteria\"]" "$json_file")
			llvm_status=$(get_json_value ".llvm.functional_criteria[\"$criteria\"]" "$json_file")
			[ -z "$gnu_status" ] && gnu_status=""
			[ -z "$llvm_status" ] && llvm_status=""
			echo "| \`$criteria\` | $(get_symbol "$gnu_status") $gnu_status | $(get_symbol "$llvm_status") $llvm_status |"
		done <<< "$all_criteria"
	fi

	echo ""
	echo "---"
	echo "*Report generated from \`$json_file\`*"
}

# Post PR comment
post_comment() {
	local json_file=${1:-test-summary.json}
	local pr_number=${2:-$GITHUB_PR_NUMBER}

	if [ -z "$pr_number" ]; then
		echo "Error: PR number not provided"
		exit 1
	fi

	if [ ! -f "$json_file" ]; then
		echo "Error: JSON file not found: $json_file"
		exit 1
	fi

	if [ -z "$GITHUB_TOKEN" ]; then
		echo "Error: GITHUB_TOKEN environment variable not set"
		exit 1
	fi

	comment_body=$(format_comment "$json_file")
	temp_file=$(mktemp)
	echo "$comment_body" >"$temp_file"
	gh pr comment "$pr_number" --body-file "$temp_file"
	rm -f "$temp_file"
	echo "PR comment posted successfully"
}

# Print report
print_report() {
	local json_file=${1:-test-summary.json}

	if [ ! -f "$json_file" ]; then
		echo "Error: JSON file not found: $json_file"
		exit 1
	fi

	echo "========================================="
	echo "Linmo CI Test Report"
	echo "========================================="
	echo ""
	cat "$json_file"
	echo ""
	echo "========================================="
	echo "Report generated from: $json_file"
	echo "========================================="
}

# Main command dispatcher
case "$COMMAND" in
"collect-data")
	shift
	collect_data "$@"
	;;
"aggregate")
	shift
	aggregate_results "$@"
	;;
"format-comment")
	shift
	format_comment "$@"
	;;
"post-comment")
	shift
	post_comment "$@"
	;;
"print-report")
	shift
	print_report "$@"
	;;
"help" | "--help" | "-h")
	show_help
	;;
*)
	echo "Error: Unknown command '$COMMAND'"
	echo "Use '$SCRIPT_NAME help' for usage information"
	exit 1
	;;
esac
