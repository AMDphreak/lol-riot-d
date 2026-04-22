/++
	Riot **Web** (HTTPS) — platform `https://<platformId>.api.riotgames.com` and optional
	regional `https://<region>.api.riotgames.com` (match-v5, accounts, etc.),
	`X-Riot-Token`, and optional `RiotRequestLimiter` (see `lol_riot.rate_limit`).
+/
module lol_riot.riot_web;

import std.exception;
import std.format;
import std.string : startsWith;

import requests;

import lol_riot.region : webApiHost;
import lol_riot.rate_limit;

/++
	`apiKey` is `X-Riot-Token`. `regionalBaseUrl` is the full base with scheme, e.g. `https://europe.api.riotgames.com` — leave empty to disable `getRegional`.
+/
struct RiotWebConfig
{
	/// Platform: `na1`, `euw1`, …
	string platformId;
	/// Riot `X-Riot-Token` value
	string apiKey;
	/// e.g. `https://europe.api.riotgames.com` for routes that use regional host
	string regionalBaseUrl;
}

/++
	HTTPS client for the Riot web API. Share one instance and call from many threads: the limiter, if
	set, is invoked before every request.
+/
final class RiotWebClient
{
	private
	{
		Request _req;
		RiotRequestLimiter _limiter;
		RiotWebConfig _cfg;
	}

	/++
		Params:
			limiter = null — no limit. Otherwise `onBeforeRequest` runs first.
+/
	this(RiotWebConfig config, RiotRequestLimiter limiter = null)
	{
		_cfg = config;
		_limiter = limiter;
		_req = Request();
		_req.addHeaders([
			"Accept": "application/json",
			"X-Riot-Token": config.apiKey,
		]);
	}

	/++
		Convenience: build limiter from `RiotRateLimitConfig` (token vs leaky vs none) via `makeRiotRequestLimiter`.
+/
	this(RiotWebConfig config, RiotRateLimitConfig rate)
	{
		this(config, makeRiotRequestLimiter(rate));
	}

	/// `https://<platformId>.api.riotgames.com`
	@property string platformBase() const
	{
		return format!"https://%s"(webApiHost(_cfg.platformId));
	}

	/++
		GET a path on the **platform** host, e.g. `/lol/summoner/v4/summoners/by-puuid/...`
+/
	Response getPlatform(string path) @trusted
	{
		enforce(path.startsWith("/"), "path must start with /");
		if (_limiter !is null)
			_limiter.onBeforeRequest();
		return _req.get(platformBase ~ path);
	}

	/++
		GET a path on the **regional** host: `RiotWebConfig.regionalBaseUrl` + path (match-v5, account, …).
+/
	Response getRegional(string path) @trusted
	{
		enforce(_cfg.regionalBaseUrl.length, "RiotWebConfig.regionalBaseUrl is empty; set e.g. https://europe.api.riotgames.com");
		enforce(path.startsWith("/"), "path must start with /");
		if (_limiter !is null)
			_limiter.onBeforeRequest();
		return _req.get(_cfg.regionalBaseUrl ~ path);
	}
}
