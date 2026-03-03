[![GitHub last commit](https://img.shields.io/github/v/release/deuza/ping2km?style=plastic)](https://github.com/deuza/ping2km/commits/main)
![GitHub Release Date](https://img.shields.io/github/release-date/deuza/ping2km)
[![GitHub last commit](https://img.shields.io/github/last-commit/deuza/ping2km?style=plastic)](https://github.com/deuza/ping2km/commits/main)
![GitHub commit activity](https://img.shields.io/github/commit-activity/t/deuza/ping2km)
[![License: CC0](https://img.shields.io/badge/license-CC0_1.0-lightgrey.svg?style=plastic)](https://creativecommons.org/publicdomain/zero/1.0/)
![Hack The Planet](https://img.shields.io/badge/hack-the--planet-black?style=flat-square\&logo=gnu\&logoColor=white)
![Built With Love](https://img.shields.io/badge/built%20with-%E2%9D%A4%20by%20DeuZa-red?style=plastic)  


# ping2km

**Ping with estimated distance based on the speed of light ... because why not?**

`ping2km` is a humorous/educational shell script that runs a continuous ping to a host and estimates the "as the fibre flies" distance based on the Round Trip Time (RTT).
```
$ ./ping2km www.gandi.fr
PING www.gandi.fr (217.70.185.65) 56(84) bytes of data [fibre: 2/3 c]
64 bytes from www.gandi.fr (217.70.185.65): icmp_seq=1 ttl=57 time=13.0 ms distance=1299 km
64 bytes from www.gandi.fr (217.70.185.65): icmp_seq=2 ttl=57 time=13.0 ms distance=1299 km
64 bytes from www.gandi.fr (217.70.185.65): icmp_seq=3 ttl=57 time=13.8 ms distance=1379 km
64 bytes from www.gandi.fr (217.70.185.65): icmp_seq=4 ttl=57 time=13.5 ms distance=1349 km
^C
--- www.gandi.fr ping2km statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3626ms
rtt min/avg/max/mdev = 13.0/13.325/13.8/.308 ms
fibre min/avg/max = 1299/1332/1379 km
root@pi5:~#
```

## How it works

The speed of light in an optical fibre is approximately 2/3 of *c* (speed of light in vacuum), which gives us ~199,861 km/s.

Since the RTT (Round Trip Time) is a round trip, the estimated distance is:
```
distance = (RTT_ms / 1000 / 2) × 199,861 km/s
         = RTT_ms × 99.9305 km
```

The output is designed to mimic standard `ping(8)` output as closely as possible, with the distance appended to each line.

## Disclaimer

This is **intentionally naive**. The estimation does not account for:

- Router/switch/firewall processing latency
- Network topology detours
- Buffering and queuing delays
- Application-level processing

The real distance traveled by packets is always greater than the geographic distance. This tool is meant for fun between friends, not for calibrating interferometers. ;-)

## Installation
```sh
curl -O https://raw.githubusercontent.com/deuza/ping2km/main/ping2km
chmod +x ping2km
sudo cp ping2km /usr/local/bin/
```

## Dependencies

Standard POSIX utilities, nothing exotic:

- `ping`
- `grep`
- `sed`
- `bc`
- `printf`

On Debian/Ubuntu, `bc` might need to be installed: `apt install bc`

## Usage
```
ping2km <host>
ping2km --help
ping2km --version
```

Hit `Ctrl+C` to stop 
A statistics summary will be displayed, including RTT and estimated fibre distance (min/avg/max).

## Compatibility

Tested on:

- Debian GNU/Linux (Bookworm, Trixie) — Raspberry Pi 5 / amd64
- FreeBSD 13.x / 14.x
- macOS (Darwin) — Ventura, Sonoma, Sequoia

The script uses strictly POSIX `sed`, POSIX shell arithmetic `$((...))`, and `bc` for floating point. No GNU-isms, no PCRE, no bashisms.

## Examples

Ping a hostname:
```
$ ping2km www.domain.tld
```

Ping an IP directly:
```
$ ping2km 1.1.1.1
```

Unknown host:
```
$ ping2km nope.invalid
ping2km: nope.invalid: Name or service not known
```

## History

This script was created around 2002 on Solaris/FreeBSD at Club-Internet with hard-coded paths in /sbin/ on 36 lines. 
It was revived, corrected, made portable, and properly documented in March 2026.

## License

CC0 — Public Domain. Do whatever you want with it.

## Author

<p align="center">With ❤️ by <a href="https://github.com/deuza">DeuZa</a></p>
