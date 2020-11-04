#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'

base_dir=$(dirname ${BATS_TEST_DIRNAME})
hook_script="${base_dir}/hook.sh"

setup() {
  export ENV="test"
  source ${hook_script}
  run set_environment
  assert_output 'test'
}

function teardown() {
  export ENV="test"
  rm -rf ${base_dir}/${ENV}.env
}

# test check_dependencies_and_config
@test 'unit: exit with missing or wrong .env file' {
  # abort if empty .env
  echo "DYNV6_ZONEID=123456" >  ${base_dir}/${ENV}.env
  assert_file_exist ${base_dir}/${ENV}.env
  run check_dependencies_and_config
  assert_failure
  assert_output --partial "DYNV6_TOKEN is empty"

  # DYNV6_TOKEN is missing in .env
  echo "DYNV6_ZONEID=123456" >  ${base_dir}/${ENV}.env
  assert_file_exist ${base_dir}/${ENV}.env
  run check_dependencies_and_config
  assert_failure
  assert_output --partial "DYNV6_TOKEN is empty"

  # DYNV6_ZONEID is missing in .env
  echo "DYNV6_TOKEN=123456" >  ${base_dir}/${ENV}.env
  assert_file_exist ${base_dir}/${ENV}.env
  run check_dependencies_and_config
  assert_failure
  assert_output --partial "DYNV6_ZONEID is empty"
}

@test 'unit: download the public suffix list' {
    run get_publicsuffix_list
    assert_success
    assert_file_exist "${base_dir}/public_suffix_list_sorted.dat"
}

@test 'unit: 'example.dynv6.net' results in name='_acme-challenge'' {
  # '${SECRET_DYNV6_TEST_DOMAIN}' results in name: '_acme-challenge'
  run create_acme_challenge_host "example.dynv6.net"
  assert_success
  assert_line --index 0 "_acme-challenge"
}

@test 'unit: 'leela.example.dynv6.net' results in name='_acme-challenge.leela'' {
  # fry.${SECRET_DYNV6_TEST_DOMAIN}' results in name: '_acme-challenge.fry'
  run create_acme_challenge_host "leela.example.dynv6.net"
  assert_success
  assert_line --index 0 "_acme-challenge.leela"
}

@test 'unit: 'example.com' results in name='_acme-challenge'' {
  run create_acme_challenge_host "example.com"
  assert_success
  assert_line --index 0 "_acme-challenge"
}

@test 'unit: '*.example.com' results in name='_acme-challenge'' {
  run create_acme_challenge_host "*.example.com"
  assert_success
  assert_line --index 0 "_acme-challenge"
}

@test 'unit: 'fry.example.com' results in name='_acme-challenge.fry'' { 
  run create_acme_challenge_host "*.fry.example.com"
  assert_success
  assert_line --index 0 "_acme-challenge.fry"
}

@test 'unit: '*.fry.example.com' results in name='_acme-challenge.fry'' { 
  run create_acme_challenge_host "*.fry.example.com"
  assert_success
  assert_line --index 0 "_acme-challenge.fry"
}

@test 'unit: 'example.org.za' results in name='_acme-challenge'' {
  run create_acme_challenge_host "example.org.za"
  assert_success
  assert_line --index 0 "_acme-challenge"
}

@test 'unit: '*.example.org.za' results in name='_acme-challenge'' {
  run create_acme_challenge_host "*.example.org.za"
  assert_success
  assert_line --index 0 "_acme-challenge"
}

@test 'unit: 'bender.example.org.za' results in name='_acme-challenge.bender'' { 
  run create_acme_challenge_host "bender.example.org.za"
  assert_success
  assert_line --index 0 "_acme-challenge.bender"
}

@test 'unit: '*.bender.example.org.za' results in name='_acme-challenge.bender'' { 
  run create_acme_challenge_host "*.bender.example.org.za"
  assert_success
  assert_line --index 0 "_acme-challenge.bender"
}

@test 'unit: test the test_dynv6_connection function 🙃' {
  # wrong zoneid results in 'not found'
  # right token, wrong zone
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID="1"
  run test_dynv6_connection
  assert_output --partial "404"
  assert_failure

  # right token and zoneid results in 'success'
  # right token, wrong zone
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID=${SECRET_DYNV6_ZONEID}
  run test_dynv6_connection
  assert_success
}

@test 'unit: deploy challenge response token for a dynv6.net domain (example.dynv6.net)' {
  # right token, wrong zone
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID=${SECRET_DYNV6_ZONEID}
  export DOMAIN=${SECRET_DYNV6_TEST_DOMAIN}
  
  export TOKEN_VALUE=domain_secret
  run deploy_challenge_dynv6 
  assert_output --partial '{"name":"_acme-challenge","data":"domain_secret","type":"TXT"}'
  assert_success
}

@test 'unit: deploy challenge response token for a dynv6.net subdomain (foo.example.dynv6.net)' {
  # right token, wrong zone
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID=${SECRET_DYNV6_ZONEID}
  export DOMAIN="unit.${SECRET_DYNV6_TEST_DOMAIN}"
  export TOKEN_VALUE=subdomain_secret
  run deploy_challenge_dynv6 
  assert_output --partial '{"name":"_acme-challenge.unit","data":"subdomain_secret","type":"TXT"}'
  assert_output --partial "DNS entry added successfully"
  assert_success
}

@test 'unit: clean challenge response token for a dynv6.net subdomain (foo.example.dynv6.net)' {
  # right token, wrong zone
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID=${SECRET_DYNV6_ZONEID}
  export DOMAIN="unit.${SECRET_DYNV6_TEST_DOMAIN}"
  run clean_challenge_dynv6 
  assert_output --partial "Successfully deleted token at dynv6.com"
  assert_success
}

@test 'integration: deploy challenge response token for a dynv6.net subdomain (integration.example.dynv6.net)' {
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID=${SECRET_DYNV6_ZONEID}
  output=$(${hook_script} deploy_challenge integration.${SECRET_DYNV6_TEST_DOMAIN} null hook_token) 
  run echo "${output}"
  assert_output --partial 'DNS entry added successfully'
  assert_output --partial '{"name":"_acme-challenge.integration","data":"hook_token","type":"TXT"}'
}

@test 'integration: clean challenge response token for a dynv6.net subdomain (integration.example.dynv6.net)' {
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID=${SECRET_DYNV6_ZONEID}
  output=$(${hook_script} clean_challenge integration.${SECRET_DYNV6_TEST_DOMAIN}) 
  run echo "${output}"
  assert_output --partial "Successfully deleted token at dynv6.com"
  assert_success
}

@test 'integration: deploy challenge response token for a dynv6.net domain (example.dynv6.net)' {
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID=${SECRET_DYNV6_ZONEID}
  output=$(${hook_script} deploy_challenge ${SECRET_DYNV6_TEST_DOMAIN} null hook_token) 
  run echo "${output}"
  assert_output --partial 'DNS entry added successfully'
  assert_output --partial '{"name":"_acme-challenge","data":"hook_token","type":"TXT"}'
}

@test 'integration: deploy challenge response token for a dynv6.net wildcard (*.example.dynv6.net)' {
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID=${SECRET_DYNV6_ZONEID}
  output=$(${hook_script} deploy_challenge *.${SECRET_DYNV6_TEST_DOMAIN} null hook_token) 
  run echo "${output}"
  assert_output --partial 'DNS entry added successfully'
  assert_output --partial '{"name":"_acme-challenge","data":"hook_token","type":"TXT"}'
}

@test 'integration: clean challenge response token for a dynv6.net wildcard (*.example.dynv6.net)' {
  export DYNV6_TOKEN=${SECRET_DYNV6_TOKEN}
  export DYNV6_ZONEID=${SECRET_DYNV6_ZONEID}
  output=$(${hook_script} clean_challenge *.${SECRET_DYNV6_TEST_DOMAIN}) 
  run echo "${output}"
  assert_output --partial "Successfully deleted token at dynv6.com"
  assert_success
}

