package tfsec

import input as tfplan

# this policy uses tfsec to check for security issues and fails on high severity issues found

deny[msg] {
    # Run tfsec on the current plan
    process := tfsec.scan(tfplan)
    
    # Extract high severity issues
    issue := process.results[_]
    issue.severity == "HIGH"

    msg := sprintf("🚨 High Severity Security Issue Found:\nRule: %s\nDescription: %s\nLocation: %s",
        [issue.rule_id, issue.description, issue.location])
}
