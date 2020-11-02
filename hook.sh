#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)" 
HOOK=${1}
DOMAIN=${2}
TOKEN_VALUE=${4}
DYNV6_DOMAINS=(dns.army dns.navy dynv6.net v6.army v6.navy v6.rocks) # TODO: Make this dynamic
DYNV6_APIBASE="https://dynv6.com/api/v2/zones"
DYNV6_TOKEN=${DYNV6_TOKEN}
DYNV6_ZONEID=${DYNV6_ZONEID}
is_dynv6_domain="false"
domain_and_subdomains=""
record_id=""

_echo() {
  echo " + Hook: ${1}"
}

_test_echo() {
  if [ "${ENV}" == "test" ]; then
    echo "${1}"
  fi
}

set_environment() {
  _test_echo ${ENV}
}

# Print error message and exit with error (taken straight from dehydrated)
_exiterr() {
  echo "Hook ERROR: ${1}" >&2
  exit 1
}

check_dependencies_and_config() {
  # look for required binaries (taken straight from dehydrated)
  for binary in curl jq dig; do
    bin_path="$(command -v "${binary}" 2>/dev/null)" || _exiterr "This script requires ${binary}."
    [[ -x "${bin_path}" ]] || _exiterr "${binary} found in PATH but it's not executable"
  done

  if [ -z "${DYNV6_TOKEN}" ] || [ -z "${DYNV6_ZONEID}" ]; then
    # if env variables not set source .env file as config
    # load .env https://stackoverflow.com/a/30969768 and check
    set -o allexport
    source ${DIR}/${ENV}.env 2>/dev/null || _exiterr "${DIR}/${ENV}.env is not available!" &&
    set +o allexport
    [[ ! -z "${DYNV6_TOKEN}" ]] || _exiterr "Environment variable DYNV6_TOKEN is empty!" &&
    [[ ! -z "${DYNV6_ZONEID}" ]] || _exiterr "Environment variable DYNV6_ZONEID is empty!"
  fi
}

check_if_dynv6_domain() {
  my_domain=${@}
  for dynv6_domain in "${DYNV6_DOMAINS[@]}"
  do
    # echo ${dynv6_domain}
    if [[ "$my_domain" == *"$dynv6_domain" ]]; then
      is_dynv6_domain=true
    fi
  done

  _test_echo "is_dynv6_domain=${is_dynv6_domain}"
}

create_acme_challenge_host() { 
  my_domain=${@}
  check_if_dynv6_domain $my_domain

  # Set IFS to dot, so that we can split $@ on dots instead of spaces.
  local IFS='.'
  zones=($@)
  # strip root domain from $DOMAIN and only leave sub-domains
  # turns www.animals.example.com into "www animals" (remove last 2 items)
  # turns *.pets.animals.example.com into "* pets animals" (remove last 2 items)
  # turns animals.dynv6.net into " " (remove last 3 items)
  # turns cats.animals.dynv6.net into "cats" (remove last 3 items)
  # https://stackoverflow.com/a/54683506
  # https://stackoverflow.com/a/44939917
  num_elements_to_remove=2
  if [ "$is_dynv6_domain" = true ] ; then
    num_elements_to_remove=3
  fi

  domain_and_subdomains=$(echo "${zones[@]::${#zones[@]}-$num_elements_to_remove}") 
  acme_challenge_hostname=$(echo "_acme-challenge.${domain_and_subdomains}" | sed 's/ /./g')
  if [[ $acme_challenge_hostname == "_acme-challenge." ]]; then
    # if wildcard on base level then just:
    acme_challenge_hostname="_acme-challenge"
  fi

  _test_echo "${acme_challenge_hostname}"
}


test_dynv6_connection() {
  # test connection to dynv6 api
  test_connection_status_code=$(curl -s -o /dev/null -I -w "%{http_code}" -X GET -H "Authorization: Bearer ${DYNV6_TOKEN}" ${DYNV6_APIBASE}/${DYNV6_ZONEID}/records)
  if ! [[ $test_connection_status_code = "200" ]]; then
    [[ "$test_connection_status_code" == "401" ]] && _exiterr "Error 401: Unauthorized"
    [[ "$test_connection_status_code" == "403" ]] && _exiterr "Error 403: Forbidden. Check your DYNV6_TOKEN"
    [[ "$test_connection_status_code" == "404" ]] && _exiterr "Error 404: Zone not found. Check your DYNV6_ZONEID"
    _exiterr "could not connect to dynv6 api. returned http status code: ${test_connection_status_code}"
  fi
}

deploy_challenge_dynv6() {
  create_acme_challenge_host $DOMAIN

  _echo "Deploying Token to dynv6.com for \"${DOMAIN}\""
  json='{"name":"'"$acme_challenge_hostname"'","data":"'$TOKEN_VALUE'","type":"TXT"}'
  _echo "Sending payload to dynv6.com: ${json}"

  res=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${DYNV6_TOKEN}" -d "$json" ${DYNV6_APIBASE}/${DYNV6_ZONEID}/records)
  record_id=$(echo ${res} | jq -r '.id')

  re='^[0-9]+$'
  if ! [[ $record_id =~ $re ]]; then
    _exiterr "something is really wrong. ${record_id} is not a number"
  fi

  # check dns propagation # https://github.com/o1oo11oo/dehydrated-all-inkl-hook/blob/master/hook.sh
  _echo "DNS entry added successfully, waiting for propagation..."
  i=1
  while ! dig TXT +trace +noall +answer "_acme-challenge.${DOMAIN}" | grep -q "${TOKEN_VALUE}"; do
    # abort propagation check after 10 seconds
    sleep 1
    ((i++))
    if ((i > 9)); then
      break
    fi
  done


}

clean_challenge_dynv6() {
  create_acme_challenge_host $DOMAIN
   # always dump all records of zone to $all_records
  all_records=$(curl -s -X GET -H "Accept: application/json" -H "Authorization: Bearer ${DYNV6_TOKEN}" ${DYNV6_APIBASE}/${DYNV6_ZONEID}/records)

  # get recordIDs of all names _acme-challenge hostnames matching the given
  acme_challenge_record_ids=$(echo $all_records | jq -r --arg name "$acme_challenge_hostname" 'map(select((.name == $name ))) | .[].id')

  if ! [ -z "$acme_challenge_record_ids" ]; then
      # is not empty delete
      _echo "Cleaning up challenge responses for \"${DOMAIN}\" ..."
      for record_id in $acme_challenge_record_ids; do
      res=$(curl -s -o /dev/null -I -w "%{http_code}" -X DELETE -H "Authorization: Bearer ${DYNV6_TOKEN}" ${DYNV6_APIBASE}/${DYNV6_ZONEID}/records/${record_id})
      if ! [[ $res = "204" ]]; then
        _exiterr "Could not delete record got status code ${res} instead of 204"
      else
        _echo "Successfully deleted token at dynv6.com"
      fi
      done
  fi
}

run_main() {
  check_dependencies_and_config || exit 1
  test_dynv6_connection || exit 1
}

# Start run_main only when executed directly otherwise exit
# required for testing with bats
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  run_main
  case "$1" in
    "deploy_challenge")
        deploy_challenge_dynv6
        ;;
    "clean_challenge")
        clean_challenge_dynv6
        ;;
    "deploy_cert")
        # optional:
        # /path/to/deploy_cert.sh "$@"
        ;;
    "unchanged_cert")
        # do nothing for now
        ;;
    "startup_hook")
        # do nothing for now
        ;;
    "exit_hook")
        # do nothing for now
        ;;
  esac

  if [ $? -gt 0 ]
  then
    echo $ENV
    exit 1
  fi
fi

