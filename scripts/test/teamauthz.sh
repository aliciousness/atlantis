#!/bin/bash

# Test script for team authorization
# This script tests various scenarios for the team_authz.sh script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTHZ_SCRIPT="$SCRIPT_DIR/../teamauthz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test case
run_test() {
    local test_name="$1"
    local expected_result="$2"  # "pass" or "deny"
    local command="$3"
    local repo="$4"
    shift 4
    local teams=("$@")
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "\n${YELLOW}Test: $test_name${NC}"
    echo "Command: $command $repo ${teams[*]}"
    echo "Expected: $expected_result"
    
    # Run the script and capture output and exit code
    local output
    local exit_code
    output=$(bash "$AUTHZ_SCRIPT" "$command" "$repo" "${teams[@]}" 2>/dev/null)
    exit_code=$?
    
    echo "Got output: '$output'"
    echo "Exit code: $exit_code"
    
    # Check result
    local actual_result="deny"
    if [[ $exit_code -eq 0 && "$output" == *"pass"* ]]; then
        actual_result="pass"
    fi
    
    if [[ "$actual_result" == "$expected_result" ]]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAILED - Expected $expected_result, got $actual_result${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Function to set environment variables for production tests
setup_prod_env() {
    export PROJECT_NAME="production"
    export USER_NAME="test-user"
    export BASE_BRANCH_NAME="main"
    export PULL_NUM="123"
}

# Function to set environment variables for dev tests
setup_dev_env() {
    export PROJECT_NAME="development"
    export USER_NAME="dev-user"
    export BASE_BRANCH_NAME="develop"
    export PULL_NUM="456"
}

# Function to set environment for environments/prod tests
setup_env_prod() {
    export PROJECT_NAME="environments/prod"
    export USER_NAME="test-user"
    export BASE_BRANCH_NAME="main"
    export PULL_NUM="123"
}

# Function to set environment for environments/dev tests
setup_env_dev() {
    export PROJECT_NAME="environments/dev"
    export USER_NAME="dev-user"
    export BASE_BRANCH_NAME="develop"
    export PULL_NUM="456"
}

# Function to clear environment
clear_env() {
    unset PROJECT_NAME USER_NAME BASE_BRANCH_NAME PULL_NUM
}

echo "=== Testing Atlantis Team Authorization Script ==="
echo "Script: $AUTHZ_SCRIPT"

# Check if script exists and is executable
if [[ ! -f "$AUTHZ_SCRIPT" ]]; then
    echo -e "${RED}Error: Script not found at $AUTHZ_SCRIPT${NC}"
    exit 1
fi

if [[ ! -x "$AUTHZ_SCRIPT" ]]; then
    echo "Making script executable..."
    chmod +x "$AUTHZ_SCRIPT"
fi

echo -e "\n${YELLOW}=== Production Apply Tests ===${NC}"

# Test 1: Production apply with correct devops team
setup_prod_env
run_test "Prod apply with devops team" "pass" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/devops"

# Test 2: Production apply with tf_policy_approvers team
setup_prod_env
run_test "Prod apply with tf_policy_approvers team" "pass" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/tf_policy_approvers"

# Test 3: Production apply with wrong team
setup_prod_env
run_test "Prod apply with wrong team" "deny" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/random-team"

# Test 4: Production apply with multiple teams (one correct)
setup_prod_env
run_test "Prod apply with multiple teams (one correct)" "pass" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/random-team" "gce-digital-marketing-infrastructure/devops"

# Test 5: Production apply with no teams
setup_prod_env
run_test "Prod apply with no teams" "deny" "apply" "gce-digital-marketing-infrastructure/myrepo"

echo -e "\n${YELLOW}=== Development Apply Tests ===${NC}"

# Test 6: Dev apply with devops team
setup_dev_env
run_test "Dev apply with devops team" "pass" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/devops"

# Test 7: Dev apply with Trainee team
setup_dev_env
run_test "Dev apply with Trainee team" "pass" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/Trainee"

# Test 8: Dev apply with wrong team
setup_dev_env
run_test "Dev apply with wrong team" "deny" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/random-team"

echo -e "\n${YELLOW}=== Plan Tests ===${NC}"

# Test 9: Plan command (should always pass)
clear_env
export PROJECT_NAME="production"
run_test "Plan on production" "pass" "plan" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/any-team"

# Test 10: Plan with no teams
clear_env
export PROJECT_NAME="development"
run_test "Plan with no teams" "pass" "plan" "gce-digital-marketing-infrastructure/myrepo"

echo -e "\n${YELLOW}=== Import Tests ===${NC}"

# Test 11: Import with admin team
clear_env
export PROJECT_NAME="production"
run_test "Import with admin team" "pass" "import" "gce-digital-marketing-infrastructure/myrepo" "admins"

# Test 12: Import with prod-deployers team
clear_env
export PROJECT_NAME="production"
run_test "Import with prod-deployers team" "pass" "import" "gce-digital-marketing-infrastructure/myrepo" "prod-deployers"

# Test 13: Import with wrong team
clear_env
export PROJECT_NAME="production"
run_test "Import with wrong team" "deny" "import" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/random-team"

echo -e "\n${YELLOW}=== Your Environment Structure Tests ===${NC}"

# Test your specific project naming: environments/prod and environments/dev

# Test 14: environments/prod apply with devops team
setup_env_prod
run_test "environments/prod apply with devops team" "pass" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/devops"

# Test 15: environments/prod apply with tf_policy_approvers team
setup_env_prod
run_test "environments/prod apply with tf_policy_approvers team" "pass" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/tf_policy_approvers"

# Test 16: environments/dev apply with devops team
setup_env_dev
run_test "environments/dev apply with devops team" "pass" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/devops"

# Test 17: environments/dev apply with Trainee team
setup_env_dev
run_test "environments/dev apply with Trainee team" "pass" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/Trainee"

# Test 18: environments/dev apply with wrong team
setup_env_dev
run_test "environments/dev apply with wrong team" "deny" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/random-team"

echo -e "\n${YELLOW}=== Edge Cases ===${NC}"

# Test 19: Invalid command
clear_env
export PROJECT_NAME="production"
run_test "Invalid command" "deny" "destroy" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/devops"

# Test 20: Empty teams for production (should deny)
setup_prod_env
run_test "Empty teams list for prod" "deny" "apply" "gce-digital-marketing-infrastructure/myrepo"

echo -e "\n${YELLOW}=== Debug Mode Test ===${NC}"

# Test 21: Debug mode
export DEBUG=1
setup_prod_env
echo -e "\n${YELLOW}Running with DEBUG=1 (should see debug output):${NC}"
bash "$AUTHZ_SCRIPT" "apply" "gce-digital-marketing-infrastructure/myrepo" "gce-digital-marketing-infrastructure/devops"
unset DEBUG

# Clean up
clear_env

echo -e "\n${YELLOW}=== Test Summary ===${NC}"
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed! 🎉${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please review the script.${NC}"
    exit 1
fi