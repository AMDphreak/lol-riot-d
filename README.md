# lol-riot-d

D library wrapping the **Riot Web API** (`requests`, regional HTTPS, `X-Riot-Token`) and the local **League Client (LCU)** (lockfile, `https` to `127.0.0.1`, self-signed cert ignored, Basic auth `riot` + password). JSON uses **asdf** + **mir.serde** on sample structs; extend or add your own.

**Concurrency:** `lol_riot.concurrency` runs many blocking `GET`s in parallel with `std.parallelism`; the shared `TokenBucket` / limiter is mutex-backed so multiple threads are safe. For maximum throughput (and no Riot key), LCU is local and usually not the bottleneck set by Riot’s cloud limits.

**Rate limiting (Riot web only):**  

- **Token bucket** (`TokenBucket`, `RiotTokenBucketLimiter`) — refills to a cap; **allows short bursts** up to the cap, then throttles. A good default for matching Riot’s “X per 10s” **with burst** (e.g. `riotProductionBucket()` 500/10s style).  
- **Leaky bucket** (`LeakyBucket`, `RiotLeakyBucketLimiter`) — **one departure per interval**; smooth spacing, no burst. Slightly higher latency under short spikes; use if you need strictly even request spacing.  

`RiotNopLimiter` and `RiotRateLimitConfig.unthrottled()` = no client-side throttling (Riot’s servers may still 429 you).

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

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs `dub build` and `dub test` on Ubuntu (LDC + DMD) and Windows (LDC). Tag pushes `v*.*.*` also run a release build smoke job.

## Publishing on DUB (code.dlang.org)

1. Create the repo on GitHub (e.g. `github.com/amdphreak/lol-riot-d`) and push.
2. [Register at code.dlang.org](https://code.dlang.org/register) and [add the package](https://code.dlang.org) pointing at this repository.
3. Release versions with **annotated tags** `vMAJOR.MINOR.PATCH` (SemVer, leading `v`). The registry [polls git tags](https://dub.pm/dub-guide/publishing/) about twice per hour and picks up new versions automatically — no `dub publish` is required for the default public registry when the package is registered there.

**Optional:** the interactive `dub publish` command is for other workflows; the usual path is **register once + tag releases**.

## Local clone / dependency

```bash
dub add lol-riot-d
# or path = "../lol-riot-d" in dub.sdl / dub.json
```

Riot’s terms, keys, and limits: [developer.riotgames.com](https://developer.riotgames.com/docs/portal). LCU is unsupported by Riot for third-party use; use at your own risk.
