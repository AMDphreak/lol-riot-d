/++
	HTTP rate limit strategies for the Riot web API (development vs production
	quotas, or custom limits you configure).

	**Token bucket** — Refills a balance of "tokens" at a steady rate up to
	a maximum burst. A request consumes one token. Bursty traffic is allowed
	until the bucket empties, then the caller blocks until refilled.

	**Leaky bucket** — Evenly space operations: each `arrive` takes the next
	available time slot, so sustained departures are at most `drainPerSecond`
	without a separate input buffer. Good for strict pacing; poor match for
	bursty workloads that you still need to pass quickly (use token bucket for that).

	For official Riot limits, see: $(LINK https://developer.riotgames.com/docs/portal)
+/
module lol_riot.rate_limit;

import core.sync.condition;
import core.sync.mutex;
import core.time;
import std.algorithm : min;
import std.exception : enforce;

/++
	Which limiter to install when you do not use a custom `RiotRequestLimiter`.
+/
enum RiotRateLimitStrategy
{
	/// No throttling
	none,
	/// `TokenBucket` with `RiotRateLimitConfig.tokenBurst` and `perSecond` refill
	tokenBucket,
	/// `LeakyBucket` with `RiotRateLimitConfig.perSecond` as drain / sec
	leakyBucket,
}

/++
	Parameters for `makeRiotRequestLimiter` and the `RiotWebClient` overload
	that takes a struct instead of a `RiotRequestLimiter`.

	- **Token** — `tokenBurst` = max burst, `perSecond` = refill rate.
	- **Leaky** — `perSecond` = drain / sec; `tokenBurst` is unused.
+/
struct RiotRateLimitConfig
{
	RiotRateLimitStrategy strategy = RiotRateLimitStrategy.tokenBucket;
	/// Token bucket: max burst. Ignored for leaky.
	double tokenBurst = 10;
	/// Token: tokens refilled / sec. Leaky: departures / sec.
	double perSecond = 1;

	/// Riot “development” style token bucket: 10 burst, 1/s refill
	static RiotRateLimitConfig development() @safe pure nothrow @nogc
	{
		return RiotRateLimitConfig(RiotRateLimitStrategy.tokenBucket, 10, 1.0);
	}

	/// Common production line: 500 / 10 s as token bucket
	static RiotRateLimitConfig production() @safe pure nothrow @nogc
	{
		return RiotRateLimitConfig(RiotRateLimitStrategy.tokenBucket, 500, 50.0);
	}

	/// Strict pacing at `perSecond` departures (no burst)
	static RiotRateLimitConfig leaky(double drainPerSecond) @safe
	{
		import std.exception : enforce;
		enforce(drainPerSecond > 0, "leaky: perSecond > 0");
		return RiotRateLimitConfig(RiotRateLimitStrategy.leakyBucket, 0, drainPerSecond);
	}

	/// Unthrottled (dev keys still subject to Riot’s server — use for LCU only or tests)
	static RiotRateLimitConfig unthrottled() @safe pure nothrow @nogc
	{
		return RiotRateLimitConfig(RiotRateLimitStrategy.none, 0, 0);
	}
}

/++
	Hook used by `RiotWebClient` so you can pass either a token bucket, a leaky
	bucket, or a custom implementation.
+/
interface RiotRequestLimiter
{
	/// Call immediately before the outbound HTTP request.
	void onBeforeRequest() @safe;
}

/++
	Skip rate limiting (e.g. local tests only — production web calls need a real limiter).
+/
final class RiotNopLimiter : RiotRequestLimiter
{
	override void onBeforeRequest() @safe
	{
	}
}

/++
	Shared token-bucket. Thread-safe.
+/
final class TokenBucket
{
	private
	{
		Mutex m;
		Condition c;
		double _tokens;
		immutable double _capacity;
		immutable double _refillPerSecond;
		MonoTime _last;
	}

	/++
		Params:
			capacity = max burst
			refillPerSecond = long-run average tokens per second
+/
	this(double capacity, double refillPerSecond)
	{
		enforce(capacity > 0 && refillPerSecond > 0, "invalid token bucket");
		_capacity = capacity;
		_refillPerSecond = refillPerSecond;
		m = new Mutex;
		c = new Condition(m);
		_tokens = capacity;
		_last = MonoTime.currTime;
	}

	/// Block until one request may proceed, then return.
	void acquire() @trusted
	{
		synchronized (m)
		{
			while (true)
			{
				_refill();
				if (_tokens >= 1.0)
				{
					_tokens -= 1.0;
					return;
				}
				const need = 1.0 - _tokens;
				auto waitS = (need / _refillPerSecond);
				if (waitS < 0.000_5)
					waitS = 0.000_5;
				auto w = msecs(cast(long)(waitS * 1000.0 + 0.5));
				c.wait(w);
			}
		}
	}

	private void _refill() @trusted
	{
		const n = MonoTime.currTime;
		const dt = (n - _last).total !"msecs" / 1000.0;
		_last = n;
		if (dt > 0)
		{
			_tokens = min(_capacity, _tokens + dt * _refillPerSecond);
			c.notifyAll();
		}
	}
}

/++
	Adapter: use a token bucket with `RiotWebClient`.
+/
final class RiotTokenBucketLimiter : RiotRequestLimiter
{
	private
	{
		TokenBucket _b;
	}

	this(TokenBucket b)
	{
		_b = b;
	}

	override void onBeforeRequest() @safe
	{
		_b.acquire();
	}
}

/++
	Evenly space operations (interval-based pacing). Thread-safe.
+/
final class LeakyBucket
{
	private
	{
		Mutex m;
		Condition c;
		Duration _interval;
		MonoTime _next;
	}

	/++
		Params:
			drainPerSecond = maximum sustained departures per second
+/
	this(double drainPerSecond)
	{
		enforce(drainPerSecond > 0, "drain per second must be > 0");
		m = new Mutex;
		c = new Condition(m);
		_interval = msecs(cast(long)(1000.0 / drainPerSecond + 0.5));
		if (_interval < 1.msecs)
			_interval = 1.msecs;
		_next = MonoTime.currTime;
	}

	/// Block until the next available departure slot.
	void arrive() @trusted
	{
		synchronized (m)
		{
			const now = MonoTime.currTime;
			MonoTime slot = _next;
			if (now > slot)
				slot = now;
			const w = slot - now;
			if (w > Duration.zero)
				c.wait(w);
			_next = slot + _interval;
		}
	}
}

/++
	Adapter: use a leaky bucket with `RiotWebClient`.
+/
final class RiotLeakyBucketLimiter : RiotRequestLimiter
{
	private
	{
		LeakyBucket _b;
	}

	this(LeakyBucket b)
	{
		_b = b;
	}

	override void onBeforeRequest() @safe
	{
		_b.arrive();
	}
}

/++
	Builds the limiter implied by `config`. Use with `RiotWebClient` or your own call sites.
+/
RiotRequestLimiter makeRiotRequestLimiter(const RiotRateLimitConfig config)
{
	final switch (config.strategy)
	{
	case RiotRateLimitStrategy.none:
		return new RiotNopLimiter;
	case RiotRateLimitStrategy.tokenBucket:
		return new RiotTokenBucketLimiter(
			new TokenBucket(config.tokenBurst, config.perSecond));
	case RiotRateLimitStrategy.leakyBucket:
		return new RiotLeakyBucketLimiter(
			new LeakyBucket(config.perSecond));
	}
}

/++
	Development key — 10/10s style defaults (tune in portal to match your key).
+/
TokenBucket riotDevelopmentBucket()
{
	return new TokenBucket(10, 1.0);
}

/++
	Standard production line often documented as 500 / 10 s (per platform).
+/
TokenBucket riotProductionBucket()
{
	return new TokenBucket(500, 50.0);
}

///
unittest
{
	auto t = makeRiotRequestLimiter(RiotRateLimitConfig.development());
	assert(t !is null);
	auto n = makeRiotRequestLimiter(RiotRateLimitConfig.unthrottled());
	assert(n !is null);
	auto l = makeRiotRequestLimiter(RiotRateLimitConfig.leaky(10));
	assert(l !is null);
}
