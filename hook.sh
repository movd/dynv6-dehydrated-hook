#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)" 
DOMAIN=${2}
TOKEN_VALUE=${4}
DYNV6_DOMAINS=(dns.army dns.navy dynv6.net v6.army v6.navy v6.rocks) # TODO: Make this dynamic
DYNV6_APIBASE="https://dynv6.com/api/v2/zones"
DYNV6_TOKEN=${DYNV6_TOKEN}
DYNV6_ZONEID=${DYNV6_ZONEID}
list_filename="public_suffix_list_sorted.dat"
list_full_path="${DIR}/${list_filename}"
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
  _test_echo "${ENV}"
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
    # shellcheck disable=SC1090
    source "${DIR}/${ENV}.env" 2>/dev/null || _exiterr "${DIR}/${ENV}.env is not available!" &&
    set +o allexport
    [[ -n "${DYNV6_TOKEN}" ]] || _exiterr "Environment variable DYNV6_TOKEN is empty!"
    [[ -n "${DYNV6_ZONEID}" ]] || _exiterr "Environment variable DYNV6_ZONEID is empty!"
  fi
}

get_publicsuffix_list() {
  # The Mozilla Foundation maintains a Public Suffix List for effective top-level domains, (for example .co.uk instead of .uk)
  # https://publicsuffix.org/list/public_suffix_list.dat
  # Download only if not older than 7 days

  do_download() {
    curl -sL "https://publicsuffix.org/list/public_suffix_list.dat" --output /tmp/public_suffix_list.dat &&

    # add all dynv6.com endings to this list 
    for dynv6_domain in "${DYNV6_DOMAINS[@]}"
    do
      echo "${dynv6_domain}" >> /tmp/public_suffix_list.dat
    done

    grep -v "//" /tmp/public_suffix_list.dat \
    | sed '/^[[:space:]]*$/d' \
    | sort \
    > "${list_full_path}"
    _echo "Downloaded publicsuffix.org list to '${list_full_path}'" &&
    rm -rf /tmp/public_suffix_list.dat
  }

  if [[ $(find "${DIR}" -iname "${list_filename}" -type f -mtime +7 -print) ]]; then
    _echo "File '${list_filename}' exists and is older than 7 days."
    do_download
  fi

  if ! [[ $(find "${DIR}" -iname "${list_filename}" -type f -print) ]]; then
    _echo "File '${list_filename}' does not exist."
    do_download
  fi
}

create_acme_challenge_host() { 
  # split domain into array
  local my_domain="${1}"
  IFS='.' read -r -a array <<< "${my_domain}"
  for (( i=0; i<${#array[@]}; i++ )); do
  # iterate trough array and remove the $i element from front
  check_var=${array[*]:$i} 
  part_to_check="${check_var// /.}"
  if grep -q "${part_to_check}" "${list_full_path}"; then
    # echo "${part_to_check} is a public suffix"
    # this turns leela.fry.bender.example.org.za into '_acme-challenge.leela.fry.bender'
    acme_challenge_hostname_with_dot="_acme-challenge.$(echo "${my_domain}" | sed s/"${part_to_check}"// | sed s/"${array[$i-1]}."// | sed s/"*."//)"
    break
  fi
  done
  acme_challenge_hostname="${acme_challenge_hostname_with_dot: :-1}"  # remove last dot
  _test_echo "${acme_challenge_hostname}"
}


test_dynv6_connection() {
  # test connection to dynv6 api
  test_connection_status_code=$(curl -s -o /dev/null -I -w "%{http_code}" -X GET -H "Authorization: Bearer ${DYNV6_TOKEN}" ${DYNV6_APIBASE}/"${DYNV6_ZONEID}"/records)
  if ! [[ $test_connection_status_code = "200" ]]; then
    [[ "$test_connection_status_code" == "401" ]] && _exiterr "Error 401: Unauthorized"
    [[ "$test_connection_status_code" == "403" ]] && _exiterr "Error 403: Forbidden. Check your DYNV6_TOKEN"
    [[ "$test_connection_status_code" == "404" ]] && _exiterr "Error 404: Zone not found. Check your DYNV6_ZONEID"
    _exiterr "could not connect to dynv6 api. returned http status code: ${test_connection_status_code}"
  fi
}

deploy_challenge_dynv6() {
  create_acme_challenge_host "${DOMAIN}"

  _echo "Deploying Token to dynv6.com for \"${DOMAIN}\""
  json='{"name":"'"$acme_challenge_hostname"'","data":"'$TOKEN_VALUE'","type":"TXT"}'
  _echo "Sending payload to dynv6.com: ${json}"

  res=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${DYNV6_TOKEN}" -d "$json" ${DYNV6_APIBASE}/"${DYNV6_ZONEID}"/records)
  record_id=$(echo "${res}"| jq -r '.id')

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
  create_acme_challenge_host "${DOMAIN}"
   # always dump all records of zone to $all_records
  all_records=$(curl -s -X GET -H "Accept: application/json" -H "Authorization: Bearer ${DYNV6_TOKEN}" ${DYNV6_APIBASE}/"${DYNV6_ZONEID}"/records)

  # get recordIDs of all names _acme-challenge hostnames matching the given
  acme_challenge_record_ids=$(echo "${all_records}" | jq -r --arg name "$acme_challenge_hostname" 'map(select((.name == $name ))) | .[].id')

  if [ -n "$acme_challenge_record_ids" ]; then
      # is not empty delete
      _echo "Cleaning up challenge responses for \"${DOMAIN}\" ..."
      for record_id in $acme_challenge_record_ids; do
      res=$(curl -s -o /dev/null -I -w "%{http_code}" -X DELETE -H "Authorization: Bearer ${DYNV6_TOKEN}" ${DYNV6_APIBASE}/"${DYNV6_ZONEID}"/records/"${record_id}")
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
        get_publicsuffix_list
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
  # shellcheck disable=SC2181
  if [ $? -gt 0 ]
  then
    exit 1
  fi
fi

