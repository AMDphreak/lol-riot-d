/++
	Regional platform hostnames (League of Legends v4/v5 platform routing).
+/
module lol_riot.region;

import std.format : format;
import std.exception : enforce;

/// Known platform / routing ids used in hostnames (e.g. "na1", "euw1").
struct LoLPlatform
{
	///
	string id;
}

/++
	HTTPS host for web API: `https://%s.api.riotgames.com`.format(platformId)
+/
string webApiHost(string platformId) @safe
{
	enforce(platformId.length, "empty platformId");
	return format!"%s.api.riotgames.com"(platformId);
}

///
unittest
{
	assert(euw1() == "euw1.api.riotgames.com");
}

/// euw1 host (example convenience).
string euw1() @safe
{
	return webApiHost("euw1");
}
