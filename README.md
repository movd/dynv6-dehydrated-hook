# [dehydrated](https://github.com/dehydrated-io/dehydrated) hook script for dynv6.com

[![example branch parameter](https://github.com/movd/dynv6-dehydrated-hook/workflows/Test%20pushed%20commit%20with%20Bats/badge.svg?branch=main)](https://github.com/movd/dynv6-dehydrated-hook/actions)

This bash script utilizes the [dynv6.com REST API](https://dynv6.github.io/api-spec/) to deploy challenge-response tokens straight to your zone's DNS records. By solving these [DNS-01 challenges](https://github.com/dehydrated-io/dehydrated/blob/master/docs/dns-verification.md), you can prove that you control a given domain without deploying an HTTP response. This is great for non-web services or certificates that are meant for use with internal services. Also, this gives you the possibility to create valid wild card certificates. 

dynv6.com is an entirely free dynamic DNS provider that supports both IPv4 and IPv6 records. Users can delegate their own top-level domains and use their service. Please note: I'm in no way affiliated with dynv6.com. This script comes with absolutely no guarantees. 

## What's working?

This script should work with:

✅ Subdomains that end with domains owned by dynv6.com (`dns.army, dns.navy, dynv6.net, v6.army, v6.navy, v6.rocks`)

✅ Top-level domain that you delegated to dynv6.com 

- Limitations: 
  - You must set up the delegated domain as a single zone

## Usage/Setup

First, clone this repo or download `hook.sh` directly. Afterward, set your hook in your dehydrated config. For example:

```sh
HOOK="${BASEDIR}/dynv6-dehydrated-hook/hook.sh"
```

### Create configuration file

To use this hook, you need to supply an API key and Zone ID. You can get both from the dynv6.com backend.

Get API Key:
- Go to https://dynv6.com/keys and log in with your credentials
- View your default token or create a new one: "🔍 Details"

Get Zone ID:
- Click "My Zones" -> example.dynv6.net 
- You can now get the zone from the URL. For example, the ID of the domain https://dynv6.com/zones/123456 is `123456`

You must create a `.env` file and put it in the same folder as the `hook.sh`:

For example:
```sh
DYNV6_TOKEN=aWd-YQFncZkN1U5WKiLF1XnZCL2WLR
DYNV6_ZONEID=123456
```

This script requires `jq` and `dnsutils`.

## Example run:

Barebones dehydrated config:

```sh
CA="https://acme-staging-v02.api.letsencrypt.org/directory" 
CHALLENGETYPE="dns-01"
HOOK="/var/lib/dehydrated/dynv6-dehydrated-hook/hook.sh"
```

A successful certification process looks like this:

<details>
<summary>View log (click to expand)</summary>
<pre lang="sh">
# INFO: Using main config file /path/to/dehydrated/conf_dir/config
 + Creating chain cache directory /path/to/dehydrated/conf_dir/chains
Processing leela.example.com with alternative names: *.leela.example.com
 + Creating new directory /path/to/dehydrated/conf_dir/certs/leela.example.com ...
 + Signing domains...
 + Generating private key...
 + Generating signing request...
 + Requesting new certificate order from CA...
 + Received 2 authorizations URLs from the CA
 + Handling authorization for leela.example.com
 + Handling authorization for leela.example.com
 + 2 pending challenge(s)
 + Deploying challenge tokens...
 + Hook: File 'public_suffix_list_sorted.dat' does not exist.
 + Hook: Downloaded publicsuffix.org list to '/path/to/dehydrated/conf_dir/public_suffix_list_sorted.dat'
 + Hook: Deploying Token to dynv6.com for "leela.example.com"
 + Hook: Sending payload to dynv6.com: {"name":"_acme-challenge.leela","data":"TarEHkULpndP1Uqw9uh17rGGFn5Ufl6Cwwb81h4KbpN","type":"TXT"}
 + Hook: DNS entry added successfully, waiting for propagation...
 + Hook: Deploying Token to dynv6.com for "leela.example.com"
 + Hook: Sending payload to dynv6.com: {"name":"_acme-challenge.leela","data":"YI0TqmipxomVpbjyXqB4RY3Dn3RFrqLFV30Wk0aI3Tl","type":"TXT"}
 + Hook: DNS entry added successfully, waiting for propagation...
 + Responding to challenge for leela.example.com authorization...
 + Challenge is valid!
 + Responding to challenge for leela.example.com authorization...
 + Challenge is valid!
 + Cleaning challenge tokens...
 + Hook: Cleaning up challenge responses for "leela.example.com" ...
 + Hook: Successfully deleted token at dynv6.com
 + Hook: Successfully deleted token at dynv6.com
 + Requesting certificate...
 + Checking certificate...
 + Done!
 + Creating fullchain.pem...
 + Done!
Processing example.com with alternative names: www.example.com
 + Creating new directory /path/to/dehydrated/conf_dir/certs/example.com ...
 + Signing domains...
 + Generating private key...
 + Generating signing request...
 + Requesting new certificate order from CA...
 + Received 2 authorizations URLs from the CA
 + Handling authorization for example.com
 + Handling authorization for www.example.com
 + 2 pending challenge(s)
 + Deploying challenge tokens...
 + Hook: Deploying Token to dynv6.com for "example.com"
 + Hook: Sending payload to dynv6.com: {"name":"_acme-challenge","data":"QETelufgzkgyPWzAeeI3s4Wod0pXSym4c4FFQo2AMqz","type":"TXT"}
 + Hook: DNS entry added successfully, waiting for propagation...
 + Hook: Deploying Token to dynv6.com for "www.example.com"
 + Hook: Sending payload to dynv6.com: {"name":"_acme-challenge.www","data":"v5djCbh1YFKN97vOVY7zCApKznDWlS9MQuxSqvjkenA","type":"TXT"}
 + Hook: DNS entry added successfully, waiting for propagation...
 + Responding to challenge for example.com authorization...
 + Challenge is valid!
 + Responding to challenge for www.example.com authorization...
 + Challenge is valid!
 + Cleaning challenge tokens...
 + Hook: Cleaning up challenge responses for "example.com" ...
 + Hook: Successfully deleted token at dynv6.com
 + Hook: Cleaning up challenge responses for "www.example.com" ...
 + Hook: Successfully deleted token at dynv6.com
 + Requesting certificate...
 + Checking certificate...
 + Done!
 + Creating fullchain.pem...
 + Done!
</pre>
</details>

## How to Contribute

I welcome issues to and pull requests against this repository!

## License

This script itself is released under a MIT License. 

When running, the script downloads the great [Public Suffix List](https://github.com/publicsuffix/list), which is maintained by the Mozilla Foundation and maintainers. The list is released under a Mozilla Public License 2.0.
