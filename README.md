# [dehydrated](https://github.com/dehydrated-io/dehydrated) hook script for dynv6.com

[![example branch parameter](https://github.com/movd/dynv6-dehydrated-hook/workflows/Test%20pushed%20commit%20with%20Bats/badge.svg?branch=main)](https://github.com/movd/dynv6-dehydrated-hook/actions)

This bash script utilizes the [dynv6.com REST API](https://dynv6.github.io/api-spec/) to deploy challenge-response tokens straight to your zone's DNS records. By solving these [DNS-01 challenges](https://github.com/dehydrated-io/dehydrated/blob/master/docs/dns-verification.md), you can prove that you control a given domain without deploying an HTTP response. This is great for non-web services or certificates that are meant for use with internal services. Also, this gives you the possibility to create valid wild card certificates. 

dynv6.com is an entirely free dynamic DNS provider that supports both IPv4 and IPv6 records. Users can delegate their own top-level domains and use their service. Please note: I'm in no way affiliated with dynv6.com. This script comes with absolutely no guarantees. 

## What's working?

This script should work with:
- Subdomains that end with domains owned by dynv6.com (`dns.army, dns.navy, dynv6.net, v6.army, v6.navy, v6.rocks`)
- A top-level domains that you delegated to dynv6.com 
- Limitations: 
  - You must set up the delegated domain as a single zone 

## What's not yet working?
- Second-level domains like `example.co.uk` or `example.org.za` don't work yet

## Usage/Setup

First, clone this repo or download `hook.sh` directly. Afterward, set your hook in your dehydrated config. For example:

```sh
HOOK="${BASEDIR}/dynv6-dehydrated-hook/hook.sh"
```

## Example run:

Barebones dehydrated config:

```sh
CA="https://acme-staging-v02.api.letsencrypt.org/directory" 
CHALLENGETYPE="dns-01"
HOOK="/var/lib/dehydrated/dynv6-dehydrated-hook/hook.sh"
```

A successful certification process looks like this:

```sh
$ sudo -u dehydrated /usr/bin/dehydrated -c -f /path/to/dehydrated_base_dir/config
Processing io.example.com with alternative names: *.io.example.com
 + Creating new directory /path/to/dehydrated_base_dir/certs/io.example.com ...
 + Signing domains...
 + Generating private key...
 + Generating signing request...
 + Requesting new certificate order from CA...
 + Received 2 authorizations URLs from the CA
 + Handling authorization for io.example.com
 + Handling authorization for io.example.com
 + 2 pending challenge(s)
 + Deploying challenge tokens...
 + Hook: Deploying Token to dynv6.com for "io.example.com"
 + Hook: Sending payload to dynv6.com: {"name":"_acme-challenge.io","data":"ZaC4pBB2_pb0DuazXI1vTtzz-CJIXbAtAHBsOg3Tz","type":"TXT"}
 + Hook: DNS entry added successfully, waiting for propagation...
 + Hook: Deploying Token to dynv6.com for "io.example.com"
 + Hook: Sending payload to dynv6.com: {"name":"_acme-challenge.io","data":"BhNdL7mHjUJRZnzscul83Dy3qwWY-Ddx6aPgRW4Bm","type":"TXT"}
 + Hook: DNS entry added successfully, waiting for propagation...
 + Responding to challenge for io.example.com authorization...
 + Challenge is valid!
 + Responding to challenge for io.example.com authorization...
 + Challenge is valid!
 + Cleaning challenge tokens...
 + Hook: Cleaning up challenge responses for "io.example.com" ...
 + Hook: Successfully deleted token at dynv6.com
 + Hook: Successfully deleted token at dynv6.com
 + Requesting certificate...
 + Checking certificate...
 + Done!
 + Creating fullchain.pem...
 + Done!
```

## How to Contribute

We welcome issues to and pull requests against this repository!

Thanks to:
* https://github.com/o1oo11oo/dehydrated-all-inkl-hook (check dns propagation with `dig`)

