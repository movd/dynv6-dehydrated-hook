#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)" 
DEHYDRATED_VERSION="0.6.5"
path_to_e2e_base_dir="${DIR}/e2e"
path_to_conf_base_dir="${DIR}/e2e/conf_dir"

# always start from scratch
rm -rf "${path_to_e2e_base_dir}"
mkdir -p "${path_to_conf_base_dir}"

run_main () {
# copy hook.sh to conf_dir
cp --verbose "$(dirname "${DIR}")"/hook.sh "${path_to_conf_base_dir}"/hook.sh
chmod +x "${path_to_conf_base_dir}"/hook.sh

cat <<EOF > "${path_to_conf_base_dir}/.env"
DYNV6_TOKEN="${SECRET_DYNV6_TOKEN}"
DYNV6_ZONEID="${SECRET_DYNV6_ZONEID}"
EOF

chmod +x "${path_to_conf_base_dir}"/hook.sh

# concat dehydrated config
cat <<EOF > "${path_to_conf_base_dir}/config"
CA="https://acme-staging-v02.api.letsencrypt.org/directory"
CHALLENGETYPE="dns-01"
HOOK="${path_to_conf_base_dir}/hook.sh"
EOF

# generate domains.txt with random san and wildcard 
# this creates a domains.txt with both static and random data:
# randomchars.example.dynv6.net *.randomchars.example.dynv6.net
# example.dynv6.net www.example.dynv6.net
# shellcheck disable=SC2018
random_hostname=$(head /dev/urandom | tr -dc a-z | head -c 12 ; echo '')
cat <<EOF > "${path_to_conf_base_dir}/domains.txt"
${random_hostname}.${SECRET_DYNV6_TEST_DOMAIN} *.${random_hostname}.${SECRET_DYNV6_TEST_DOMAIN}
${SECRET_DYNV6_TEST_DOMAIN} www.${SECRET_DYNV6_TEST_DOMAIN}
EOF

# start from scratch
rm -rf "${DIR}/e2e/dehydrated"
curl -sL https://github.com/dehydrated-io/dehydrated/releases/download/v"${DEHYDRATED_VERSION}"/dehydrated-"${DEHYDRATED_VERSION}".tar.gz | tar xvz -C "${DIR}/e2e/"
# get just dehydrated script and make executable
find "${DIR}" -iname "dehydrated" -type f -exec chmod + '{}' \; -exec mv '{}' "${DIR}/e2e" \;
rm -rvf "${path_to_e2e_base_dir}"/dehydrated-"${DEHYDRATED_VERSION}" &&
echo "# e2e: downloaded dehydrated"

echo "# e2e registring account at lets encrypt staging ca"
"${path_to_e2e_base_dir}"/dehydrated --register --accept-terms -f "${path_to_conf_base_dir}"/config

echo "# e2e: starting ${path_to_conf_base_dir}/hook.sh"
"${path_to_e2e_base_dir}"/dehydrated -c -f "${path_to_conf_base_dir}"/config

# remove everything 
rm -rf "${path_to_e2e_base_dir}"
} # end run_e2d()

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  run_main
fi