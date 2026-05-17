#!/usr/bin/env bash
# STUB — replace this file with your project's test-convention checks.
#
# This script is called by the pre-commit framework with the paths of
# staged source files as arguments. It should exit 1 (with a helpful
# message) when a convention is violated, and exit 0 otherwise.
#
# Common checks to implement for your stack:
#
#   1. Test isolation — e.g. no mocking framework usage on full-context
#      integration tests (@SpringBootTest in Java, TestServer in Go, etc.)
#
#   2. Filename / class suffix conventions — e.g.
#        *IT.* or *IntegrationTest.* → must be a full-context test
#        *Test.*                     → must NOT be a full-context test
#
#   3. API documentation completeness — e.g. controllers that declare
#      validation on route parameters must document the 400 response.
#
# See .github/copilot-instructions.md §Testing conventions for the
# project-specific rules this script should enforce.
#
# REFERENCE IMPLEMENTATION (Spring Boot / Java):
#   See fee-hqadmin-rest-svc/scripts/check-test-conventions.sh in the
#   harness-dev-framework examples/ directory for a complete Spring Boot
#   reference implementation covering all three checks above.
#
# Input: paths to source files, passed by the pre-commit framework.
# Exit:  0 if all pass, 1 if any violation found.

set -euo pipefail

# No-op stub — remove this line and add your checks below.
exit 0
