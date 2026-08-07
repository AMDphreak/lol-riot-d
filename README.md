<a id="readme-top"></a>
<div align="center">
  <a href="https://github.com/AMDphreak/lol-riot-d/graphs/contributors"><img src="https://img.shields.io/github/contributors/AMDphreak/lol-riot-d.svg?style=for-the-badge" alt="Contributors"></a>
  <a href="https://github.com/AMDphreak/lol-riot-d/network/members"><img src="https://img.shields.io/github/forks/AMDphreak/lol-riot-d.svg?style=for-the-badge" alt="Forks"></a>
  <a href="https://github.com/AMDphreak/lol-riot-d/stargazers"><img src="https://img.shields.io/github/stars/AMDphreak/lol-riot-d.svg?style=for-the-badge" alt="Stargazers"></a>
  <a href="https://github.com/AMDphreak/lol-riot-d/issues"><img src="https://img.shields.io/github/issues/AMDphreak/lol-riot-d.svg?style=for-the-badge" alt="Issues"></a>
  <h1>lol-riot-d</h1>
  <p>D: Riot Web API + LCU (lol-riot-d)</p>
  <p>
    <a href="https://github.com/AMDphreak/lol-riot-d/issues">Report Bug</a>
    &middot;
    <a href="https://github.com/AMDphreak/lol-riot-d/issues">Request Feature</a>
  </p>

</div>


<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#installation">Installation</a></li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

## About The Project

D library wrapping the **Riot Web API** (`requests`, regional HTTPS, `X-Riot-Token`) and the local **League Client (LCU)** (lockfile, `https` to `127.0.0.1`, self-signed cert ignored, Basic auth `riot` + password). JSON uses **asdf** + **mir.serde** on sample structs; extend or add your own.

**Concurrency:** `lol_riot.concurrency` runs many blocking `GET`s in parallel with `std.parallelism`; the shared `TokenBucket` / limiter is mutex-backed so multiple threads are safe. For maximum throughput (and no Riot key), LCU is local and usually not the bottleneck set by Riot's cloud limits.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Installation

```bash
dub add lol-riot-d
# or path = "../lol-riot-d" in dub.sdl / dub.json
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

**Rate limiting (Riot web only):**

- **Token bucket** (`TokenBucket`, `RiotTokenBucketLimiter`) — refills to a cap; **allows short bursts** up to the cap, then throttles. A good default for matching Riot's "X per 10s" **with burst** (e.g. `riotProductionBucket()` 500/10s style).
- **Leaky bucket** (`LeakyBucket`, `RiotLeakyBucketLimiter`) — **one departure per interval**; smooth spacing, no burst. Slightly higher latency under short spikes; use if you need strictly even request spacing.

`RiotNopLimiter` and `RiotRateLimitConfig.unthrottled()` = no client-side throttling (Riot's servers may still 429 you).

**Choosing token vs leaky at init** — pass `RiotRateLimitConfig` to `RiotWebClient` (or call `makeRiotRequestLimiter` and use the `RiotRequestLimiter` constructor):

- `RiotRateLimitConfig.development()` / `production()` — **token** bucket presets.
- `RiotRateLimitConfig.leaky(50.0)` — **leaky** pacing at 50 departures / second.
- `RiotRateLimitConfig(RiotRateLimitStrategy.tokenBucket, 500, 50)` — custom token values.
- Custom class: `new RiotWebClient(cfg, yourLimiter)`.

```d
import lol_riot;
import requests;

void main() {
	// LCU: auto w = LcuClient.discover();  // OR new LcuClient(r"path\to\lockfile");
	// w.get("/lol-summoner/v1/current-summoner");

	// Riot web — pick strategy at init:
	// new RiotWebClient(RiotWebConfig("na1", key, ""), RiotRateLimitConfig.development());
	// new RiotWebClient(RiotWebConfig("na1", key, ""), RiotRateLimitConfig.leaky(50));
	// new RiotWebClient(RiotWebConfig("na1", key, ""), RiotRateLimitConfig.production());

	// auto r = web.getPlatform("/lol/status/v4/platform-data");
	// if (r.code == 200) { /* cast(string)r.responseBody.data */ }
}
```

### CI

GitHub Actions (`.github/workflows/ci.yml`) runs `dub build` and `dub test` on Ubuntu (LDC + DMD) and Windows (LDC). Tag pushes `v*.*.*` also run a release build smoke job.

### Publishing on DUB (code.dlang.org)

1. Create the repo on GitHub (e.g. `github.com/amdphreak/lol-riot-d`) and push.
2. [Register at code.dlang.org](https://code.dlang.org/register) and [add the package](https://code.dlang.org) pointing at this repository.
3. Release versions with **annotated tags** `vMAJOR.MINOR.PATCH` (SemVer, leading `v`). The registry [polls git tags](https://dub.pm/dub-guide/publishing/) about twice per hour and picks up new versions automatically — no `dub publish` is required for the default public registry when the package is registered there.

**Optional:** the interactive `dub publish` command is for other workflows; the usual path is **register once + tag releases**.

Riot's terms, keys, and limits: [developer.riotgames.com](https://developer.riotgames.com/docs/portal). LCU is unsupported by Riot for third-party use; use at your own risk.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contact

Ryan Johnson — [@amdphreak](https://twitter.com/amdphreak)

Project Link: [https://github.com/AMDphreak/lol-riot-d](https://github.com/AMDphreak/lol-riot-d)

Site: [https://ryanjohnson.dev](https://ryanjohnson.dev)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

