#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'

setup() {
  source "${BATS_TEST_DIRNAME}/e2e-run.sh" 
}

@test "test if all secrets are available as environmental varibales" {
  output=$(env)
  run echo "${output}"
  assert_output --partial 'SECRET_DYNV6_TEST_DOMAIN'
  assert_output --partial 'SECRET_DYNV6_TOKEN'
  assert_output --partial 'SECRET_DYNV6_ZONEID'
}

@test "run complete end to end test" {
  run run_main
  assert_success
  assert_output --partial 'e2e: downloaded dehydrated'
  assert_output --partial 'Downloaded publicsuffix.org list'
  assert_output --partial 'Creating chain cache directory'
  assert_output --partial 'Creating new directory'
  assert_output --partial 'DNS entry added successfully, waiting for propagation...'
  assert_output --partial 'Challenge is valid!'
  assert_output --partial 'Hook: Successfully deleted token at dynv6.com'
}
