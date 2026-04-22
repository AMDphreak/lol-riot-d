/++
	Parallel, thread-based fan-out for **blocking** `requests` I/O. Web calls still pass through
	`RiotRequestLimiter` on a shared `RiotWebClient`, so the token bucket’s mutex serializes
	acquires safely across threads.
+/
module lol_riot.concurrency;

import std.range : iota;
import std.parallelism;
import std.exception : enforce;

import requests;

import lol_riot.lcu : LcuClient;
import lol_riot.riot_web : RiotWebClient;

/++
	Parallel LCU fetches. Result order matches `paths`.
+/
string[] lcuGetInParallel(LcuClient client, in string[] paths) @trusted
{
	enforce(paths.length, "no paths");
	auto out_ = new string[paths.length];
	foreach (idx; iota(paths.length).parallel)
		out_[idx] = client.getString(paths[idx]);
	return out_.dup;
}

/++
	Parallel platform GETs. Result order matches `paths`.
+/
Response[] riotGetPlatformInParallel(RiotWebClient client, in string[] paths) @trusted
{
	enforce(paths.length, "no paths");
	auto out_ = new Response[paths.length];
	foreach (idx; iota(paths.length).parallel)
		out_[idx] = client.getPlatform(paths[idx]);
	return out_.dup;
}

/++
	Parallel regional GETs (same `RiotWebClient.getRegional` rules as single-threaded use).
+/
Response[] riotGetRegionalInParallel(RiotWebClient client, in string[] paths) @trusted
{
	enforce(paths.length, "no paths");
	auto out_ = new Response[paths.length];
	foreach (idx; iota(paths.length).parallel)
		out_[idx] = client.getRegional(paths[idx]);
	return out_.dup;
}
