[![GitHub last commit](https://img.shields.io/github/v/release/deuza/ping2km?style=plastic)](https://github.com/deuza/ping2km/commits/main)
![GitHub Release Date](https://img.shields.io/github/release-date/deuza/ping2km)
[![GitHub last commit](https://img.shields.io/github/last-commit/deuza/ping2km?style=plastic)](https://github.com/deuza/ping2km/commits/main)
![GitHub commit activity](https://img.shields.io/github/commit-activity/t/deuza/ping2km)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/deuza/ping2km)
[![License: CC0](https://img.shields.io/badge/license-CC0_1.0-lightgrey.svg?style=plastic)](https://creativecommons.org/publicdomain/zero/1.0/)
[![License: WTFPL](https://img.shields.io/badge/license-WTFPL_2.0-lightgrey.svg?style=plastic)](https://www.wtfpl.net/)

![Hack The Planet](https://img.shields.io/badge/hack-the--planet-black?style=flat-square\&logo=gnu\&logoColor=white)
![Built With Love](https://img.shields.io/badge/built%20with-%E2%9D%A4%20by%20DeuZa-red?style=plastic)
[![X (formerly Twitter) Follow](https://img.shields.io/twitter/follow/DeuZa42?style=social)](https://x.com/DeuZa42)

# ping2km

**Ping with estimated distance based on the speed of light ... because why not? :D**

The shell script `ping2km` is a humorous tool that runs a continuous ping to a host and estimates the "as the fibre flies" distance based on the Round Trip Time (RTT).

![ping2km screenshot](screenshot.png)

## How it works

Four transmission models are available :

| Mode | Speed | Factor | Formula |
|------|-------|--------|---------|
| `--fiber` (default) | 2/3 c ≈ 199,861 km/s | 99.9305 | `distance = RTT_ms × 99.9305 km` |
| `--copper` | 2/3 c ≈ 197,863 km/s | 98.93 | `distance = RTT_ms × 98.93 km` |
| `--theoretical` | c ≈ 299,792 km/s | 149.896 | `distance = RTT_ms × 149.896 km` |
| `--dialup` | 2/3 c minus modem | 99.9305 | `distance = (RTT_ms - 120) × 99.9305 km` |

Since the RTT (Round Trip Time) is a round trip, the estimated distance is :

```
distance = (RTT_ms / 1000 / 2) × speed
```

### About the models

The **fiber** model uses the real speed of light in optical fibre (~2/3 of *c*, due to the refractive index of silica glass).

The **copper** model uses the real propagation speed in telephone twisted pair cables (~2/3 of *c*, due to the dielectric properties of the insulation). **Plot twist:** fiber and copper give nearly identical results (~1% difference). The signal travels at roughly the same speed in both media. The real difference between fiber and copper has never been propagation speed — it's bandwidth (data throughput) and attenuation (signal loss over distance).

The **theoretical** model uses *c*, the speed of light in vacuum (299,792 km/s). This is the absolute physical limit, achievable only in a perfect vacuum. In reality, no transmission medium reaches *c*. But where's the fun in reality?

The **dialup** model simulates the good old RTC (Public Switched Telephone Network) era. Analog modems added approximately 120 ms of round-trip latency just for signal encoding/decoding (modulation/demodulation — that's what "modem" stands for). This overhead is subtracted from the RTT before calculating the distance. Back in the dial-up days, the world was smaller. If the RTT is less than 120 ms, the distance shows `0 km [too close for dial-up]`.

The output is designed to mimic standard `ping(8)` output as closely as possible, with the distance appended to each line.

## Disclaimer

This is **intentionally naive**. The estimation does not account for :

- Router/switch/firewall processing latency
- Network topology detours
- Buffering and queuing delays
- Application-level processing
- etc.

The actual distance traveled by packets is always greater than the geographical distance, which means that Berlin may be closer to you than New York.     

**This tool is meant for fun between friends, not for calibrating interferometers ;-)**

## Installation

```sh
curl -O https://raw.githubusercontent.com/deuza/ping2km/main/ping2km.sh
mv ping2km.sh ping2km
chmod +x ping2km
sudo cp ping2km /usr/local/bin/
```

If curl is not available, you can use another tool such as wget to retrieve the script directly.

```sh
wget https://raw.githubusercontent.com/deuza/ping2km/main/ping2km.sh
``` 

## Dependencies

Standard POSIX utilities, nothing exotic :

- `ping`
- `grep`
- `sed`
- `bc`
- `printf`

On Debian/Ubuntu, `bc` might need to be installed : `apt install bc`

## Usage

```
ping2km [--fiber|--copper|--theoretical|--dialup] [-4] [-c count] <host>
ping2km --help
ping2km --version
```

Hit `Ctrl+C` to stop, a statistics summary will be displayed, including RTT and estimated distance (min/avg/max).

## Compatibility

Tested on :

- Debian GNU/Linux (Bookworm, Trixie) arm64/amd64
- FreeBSD 13.x / 14.x
- macOS (Darwin) Ventura, Sonoma, Sequoia

The script uses strictly POSIX `sed`, POSIX shell arithmetic `$((...))`, and `bc` for floating point, just KISS.

## Examples

Ping a hostname (fiber, default) :
```
$ ping2km www.deuza.net
```

Send only 5 packets :
```
$ ping2km -c 5 www.deuza.net
```

Ping with copper model (spoiler: same result as fiber, troll mode :P) :
```
$ ping2km --copper www.deuza.net
```

Ping with theoretical speed of light in vacuum :
```
$ ping2km --theoretical 1.1.1.1
```

Ping like it's 1998 :
```
$ ping2km --dialup www.kernel.org
```

Force IPv4 :
```
$ ping2km -4 www.deuza.net
```

Combine options :
```
$ ping2km --dialup -4 -c 10 www.kernel.org
```

Unknown host:
```
$ ping2km nope.invalid
ping2km: nope.invalid: Name or service not known
```

## History

This script was created around 2002 on Solaris/FreeBSD at Club-Internet on 36 lines.      
It was revived, corrected, made portable, and properly documented in March 2026.

## License

`CC0 1.0 Universal` -- Public Domain.  
[![CC0](https://mirrors.creativecommons.org/presskit/buttons/88x31/svg/cc-zero.svg)](https://creativecommons.org/publicdomain/zero/1.0/)    

`WTFPL` -- Do What the Fuck You Want to Public License.     
[![WTFPL](http://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-1.png)](http://www.wtfpl.net/)    

## Author
<a href="https://github.com/deuza">DeuZa</a>

## TODO       

Nothing planned

## BUGS

Should not work under Solaris and with exotic ping outputs.     
The output line that is parsed should look like this:

```
$ ping www.deuza.net
PING www.deuza.net (66.6.44.4) 56(84) bytes of data.
64 bytes from 66.6.44.4: icmp_seq=1 ttl=52 time=92.8 ms
64 bytes from 66.6.44.4: icmp_seq=2 ttl=52 time=96.1 ms
^C
--- www.deuza.net ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 92.836/94.470/96.105/1.634 ms
root@pi5:~#

```
## Star History

## Star History

<a href="https://www.star-history.com/?repos=deuza%2Fping2km&type=timeline&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/image?repos=deuza/ping2km&type=timeline&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/image?repos=deuza/ping2km&type=timeline&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/image?repos=deuza/ping2km&type=timeline&legend=top-left" />
 </picture>
</a>

<p align="center">With ❤️ by <a href="https://github.com/deuza">DeuZa</a></p></sup></sub>
