# Tailscale on UniFi Dream Machine

This repo contains the scripts necessary to install and run a [tailscale](https://tailscale.com)
instance on your [UniFi Dream Machine](https://unifi-network.ui.com/dreammachine) (UDM/UDM Pro/UDR/UDM-SE).
It does so by piggy-backing on the excellent [boostchicken/udm-utilities](https://github.com/boostchicken/udm-utilities)
to provide a persistent service and runs using Tailscale's usermode networking feature.

## 🔒 Cryptographically Verified Builds

This fork adds **cryptographic hash verification** to protect against supply chain attacks and package tampering.

### Why Verified Builds?

The standard Tailscale-UDM installation downloads pre-built packages without cryptographic verification. This fork addresses that security gap by:

- ✅ **Building from source** using official Tailscale binaries
- ✅ **Generating cryptographic hashes** (SHA256/SHA512/BLAKE2) for every package
- ✅ **Verifying hashes** before installation - aborts if tampered
- ✅ **Transparent builds** on GitHub Actions with public logs
- ✅ **Automated releases** with full hash manifests

### Trust Model

When using verified builds, you are trusting:
- GitHub Actions infrastructure
- This repository owner (bloxsome)
- Tailscale's official binary distribution
- Cryptographic hash algorithms (SHA256/SHA512/BLAKE2)

You are **NOT** trusting unverified download mirrors or third-party packages.

## Installation

### Option 1: Verified Installation (Recommended)

Install with automatic cryptographic hash verification:

```sh
# Install with hash verification
export GITHUB_REPO="bloxsome/tailscale-udm"
curl -sSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install-verified.sh | sh
```

This installer will:
1. Download the latest release manifest with expected hashes
2. Download the package from GitHub Releases
3. Compute SHA256 hash of the downloaded package
4. **Abort if hashes don't match** (protecting against tampering)
5. Only install if verification passes

### Option 2: Standard Installation

If you prefer the standard installation method:

```sh
# Install without hash verification (uses upstream release)
curl -sSLq https://raw.github.com/SierraSoftworks/tailscale-udm/main/install.sh | sh
```

### Post-Installation

After installation completes:

1. Run `tailscale up` to start Tailscale
2. Follow the on-screen steps to configure Tailscale and connect it to your network
3. Confirm that Tailscale is working by running `tailscale status`

## Compatibility

**ⓘ You can confirm your OS version by running `/usr/bin/ubnt-device-info firmware_detail`**

This package is compatible with UniFi OS 2.x+ and is known to work on the following devices:

- UniFi Dream Machine (UDM)
- UniFi Dream Machine Pro (UDM Pro)
- UniFi Dream Router (UDR)
- UniFi Dream Machine Special Edition (UDM-SE)
- UniFi Cloud Key Gen 2 (UCK-G2)
- UniFi Cloud Key Gen 2 Plus (UCK-G2-PLUS)
- UniFi NAS Pro

We expect that it should function on most consumer-grade UniFi devices without issue, but if you
do run into any problems, please [open an issue](https://github.com/SierraSoftworks/tailscale-udm/issues)
and provide the following information:

- The device you are running on (e.g. UDM Pro)
- The UniFi OS version you are running (e.g. 2.4.8 - this can be found by running `/usr/bin/ubnt-device-info firmware_detail`)
- The steps you took to install Tailscale and any errors you encountered.

**WARNING:** This package is no longer compatible with UniFi OS 1.x (the legacy OS on UDM/UDM Pro). If you
are running UniFi OS 1.x and are unable to upgrade to the latest stable version of UniFi OS, you
should use the legacy version of this package, which is available in the `legacy` branch of
this repository. The legacy version is no longer maintained and may not work with the latest
version of Tailscale.

## Management

### Configuring Tailscale

You can configure Tailscale using all the normal `tailscale up` options, you should be able to
find `tailscale` on your path after installation.

```sh
tailscale up --advertise-routes=10.0.0.0/24 --advertise-exit-node --advertise-tags=tag:it
```

### Restarting Tailscale

On UniFi OS 2.x+, Tailscale is managed using `systemd` and the `tailscaled` service. You can
restart it using the following command.

```sh
systemctl restart tailscaled
```

### Upgrading Tailscale

Upgrading Tailscale on UniFi OS 2.x+ can be done either using `apt` or by using the `manage.sh`
helper script.

#### Using `apt`

```sh
apt update && apt install -y tailscale
```

#### Using `manage.sh`

```sh
/data/tailscale/manage.sh update

# Or, if you are connected over Tailscale and want to run the update anyway
nohup /data/tailscale/manage.sh update!
```

### Remove Tailscale

To remove Tailscale, you can run the following command, or run the steps below manually.

```sh
/data/tailscale/manage.sh uninstall
```

#### Manual Steps

1. Kill the `tailscaled` daemon with `systemctl stop tailscaled`.
2. Remove the `tailscale` & `tailscale-archive-keyring` package using `dpkg -P tailscale tailscale-archive-keyring`.
3. Remove the management script and state using `rm -Rf /data/tailscale`.
4. Remove the `on_boot.d` script using `rm /data/on_boot.d/10-tailscaled.sh`.
5. Remove the `cache` folder using `rm -rf /var/cache/tailscale`.

## Contributing

There are clearly lots of folks who are interested in running Tailscale on their UDMs. If
you're one of those people and have an idea for how this can be improved, please create a
PR and we'll be more than happy to incorporate the changes.

## Frequently Asked Questions

### How do I advertise routes?

You do this by updating your Tailscale configuration as you would on any other machine,
just remember to provide the full path to the `tailscale` binary when doing so.

```sh
# Specify the routes you'd like to advertise using their CIDR notation

# UniFi OS 1.x
/mnt/data/tailscale/tailscale up --advertise-routes="10.0.0.0/24,192.168.0.0/24"

# UniFi OS 2.x/3.x
tailscale up --advertise-routes="10.0.0.0/24,192.168.0.0/24"
```

### Can I route traffic from machines on my local network to Tailscale endpoints automatically?

Yes! As of January 30, 2025, [two][tailscale-pr10828] [changes][tailscale-pr14452] to Tailscale have made this
possible. Much credit goes to @tomvoss and @jasonwbarnett, who contributed significant effort to
the initial implementation, detailed [in this GitHub issue][tailnet-routing-discussion].
Before going further please read tailscale's [subnet router documentation][tailscale-subnet-router-docs]
and familiarize yourself with the concepts of subnet routers, independent of UniFi OS.

#### Prerequisites

Before proceeding, please review Tailscale’s [subnet router documentation][tailscale-subnet-router-docs]
to understand the core concepts of subnet routing, independent of UniFi OS.

**NOTE**: You do not need to manually enable `net.ipv4.ip_forward` on your UniFi OS
device as it is enabled by default. If you want to confirm its status, run:

```sh
sysctl net.ipv4.ip_forward
```

**WARNING**: You should conduct all of these changes over a direct network connection to your
UniFi OS device, as you may lose access to the device if you misconfigure Tailscale or other network
settings.

#### Switch to TUN mode

The quickest way to switch to TUN mode is to install the latest version of tailscale-udm, which
will automatically configure Tailscale to use TUN mode.

```bash
curl -sSLq https://raw.github.com/SierraSoftworks/tailscale-udm/main/install.sh | sh
```

##### Manually Switching to TUN Mode

If you have been running Tailscale on your UniFi device for a while, there is a good chance
that you are running in "userspace" networking mode. This mode is not compatible with advertising
routes, so you will need to switch to TUN mode.

To do so, edit your `/data/tailscale/tailscale-env` file and ensure that the
`TAILSCALED_FLAGS` variable does **NOT** include the `--tun userspace-networking` flag. Unless you
have manually configured any other options, it should look like this:

```bash
PORT="41641"
TAILSCALED_FLAGS=""
TAILSCALE_FLAGS=""
TAILSCALE_AUTOUPDATE="true"
TAILSCALE_CHANNEL="stable"
```

Then re-configure Tailscale by running `/data/tailscale/manage.sh install`, which will
update your `/etc/default/tailscaled` file to use the new configuration and restart the
`tailscaled` service.

#### Verifying Your Setup

To ensure that Tailscale is running correctly, check for the existence of the
tailscale0 network interface:

```sh
ip link show tailscale0
```

A successful setup should return output similar to:

```text
129: tailscale0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1280 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 500
    link/none
```

If you see `Device "tailscale0" does not exist.` instead, it means you are still running in
[userspace networking mode][tailscale-userspace-networking-docs], which will not
work. Follow the steps above to switch to TUN mode and try again.

#### Final Configuration

Once you have verified that you are not running in userspace networking mode, proceed with configuring Tailscale:

```sh
tailscale up --advertise-exit-node --advertise-routes="<one-or-more-local-subnets>" --snat-subnet-routes=false --accept-routes --reset
```

Example:

```sh
tailscale up --advertise-exit-node --advertise-routes="10.0.0.0/24" --snat-subnet-routes=false --accept-routes --reset
```

For more details on available options, see the official [tailscale up command documentation][tailscale-up-docs].

### Why can't I see a network interface for Tailscale?

Legacy versions of the tailscale-udm script configured Tailscale to run in userspace networking
mode on the UDM rather than as a TUN interface, which meant you wouldn't see it in the `ip addr` list.

If you are running an older version of tailscale-udm, you can switch to TUN mode by following
the [instructions above](#manually-switching-to-tun-mode).

### Does this support Tailscale SSH?

You bet, make sure you're running the latest version of Tailscale and then run `tailscale up --ssh`
to enable it. You'll need to setup SSH ACLs in your account by following
[this guide](https://tailscale.com/kb/1193/tailscale-ssh/).

```sh
# UniFi OS 1.x
# Update Tailscale to its latest version
/mnt/data/tailscale/manage.sh update!

# Enable SSH advertisment through Tailscale
/mnt/data/tailscale/tailscale up --ssh

# UniFi OS 2.x/3.x
# Update Tailscale to its latest version
/data/tailscale/manage.sh update!

# Enable SSH advertisment through Tailscale
tailscale up --ssh
```

### How do I generate HTTPS certificates with Tailscale?

Tailscale can generate valid HTTPS certificates for your UDM using Let's Encrypt. This requires:

- MagicDNS enabled in your Tailscale admin console
- HTTPS enabled in your Tailscale admin console

```sh
# Generate a certificate
/data/tailscale/manage.sh cert generate

# Install certificate into UniFi OS (2.x+)
/data/tailscale/manage.sh cert install-unifi

# Restart UniFi Core to apply
systemctl restart unifi-core
```

Certificates expire after 90 days. Use `cert renew` to renew them.
The hostname is automatically determined from your Tailscale configuration.

On UniFi OS 2.x+, a systemd timer is automatically installed when you generate
your first certificate. This timer runs weekly to check and renew certificates
before they expire.

## Building Verified Packages

This fork includes a GitHub Actions workflow that builds cryptographically verified packages.

### Triggering a Build

**Manual Build:**
1. Go to the [Actions tab](../../actions/workflows/build-and-hash.yml)
2. Click **"Run workflow"**
3. Enter the Tailscale version (e.g., `1.76.1`)
4. Optionally specify a build number (default: `1`)
5. Click **"Run workflow"**

**Automated Builds:**
The workflow runs automatically every Sunday at 2 AM UTC to build packages for new Tailscale releases.

### Build Output

Each build creates a GitHub Release containing:
- **tailscale-udm.tgz** - The complete package
- **HASHES.txt** - SHA256/SHA512/BLAKE2 hashes
- **latest.json** - Machine-readable build manifest with download URLs and hashes

### Manual Verification

If you want to manually verify a downloaded package:

```sh
# Download package and hashes
VERSION="v1.76.1-1"
curl -sSLf -o tailscale-udm.tgz \
  "https://github.com/bloxsome/tailscale-udm/releases/download/${VERSION}/tailscale-udm.tgz"
curl -sSLf -o HASHES.txt \
  "https://github.com/bloxsome/tailscale-udm/releases/download/${VERSION}/HASHES.txt"

# Verify SHA256
grep SHA256 HASHES.txt
sha256sum tailscale-udm.tgz

# If hashes match, install manually
tar xzf tailscale-udm.tgz -C /data
/data/tailscale/manage.sh install
/data/tailscale/manage.sh start
```

[tailscale-pr10828]: https://github.com/tailscale/tailscale/pull/10828
[tailscale-pr14452]: https://github.com/tailscale/tailscale/pull/14452
[tailnet-routing-discussion]: https://github.com/SierraSoftworks/tailscale-udm/discussions/51
[tailscale-subnet-router-docs]: https://tailscale.com/kb/1019/subnets
[tailscale-up-docs]: https://tailscale.com/kb/1241/tailscale-up
[tailscale-userspace-networking-docs]: https://tailscale.com/kb/1112/userspace-networking
