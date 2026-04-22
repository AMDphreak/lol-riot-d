/++
	LCU `lockfile` discovery and parsing. Format (colon-separated):
	`name:pid:port:password:protocol`
+/
module lol_riot.lockfile;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.string;
import std.exception : enforce;
import std.process : environment;

/++
	LCU credentials from the League of Legends `lockfile`.
+/
struct LcuLockfile
{
	/// e.g. `LeagueClient`
	string processName;
	///
	int pid;
	/// Listen port
	ushort port;
	/// Password for Basic auth
	string password;
	/// Usually `https`
	string protocol;
}

/++
	Throws if the file is missing, unreadable, or not five colon-separated parts.
+/
LcuLockfile readLcuLockfile(string lockfilePath) @trusted
{
	enforce(exists(lockfilePath), "lockfile does not exist: " ~ lockfilePath);
	const raw = (cast(string) read(lockfilePath)).strip();
	return parseLcuLockfileContent(raw, lockfilePath);
}

/++
	Used by tests; does not read from disk.
+/
package LcuLockfile parseLcuLockfileContent(string content, string contextPath = "memory")
{
	auto parts = content.splitter(':');
	string[] a;
	foreach (p; parts)
		a ~= p;
	enforce(
		a.length == 5,
		contextPath ~ ": expected 5 colon-separated fields, got " ~ a.length.to!string);
	return LcuLockfile(
		a[0],
		a[1].to!int,
		a[2].to!ushort,
		a[3],
		a[4]);
}

/++
	Search order:
	1) env `LEAGUE_LOCKFILE` (full path to lockfile)
	2) `RIOT_GAMES\League of Legends\lockfile` under `LOCALAPPDATA`
	3) `Riot Games\League of Legends\lockfile` under `C:\` and `D:\` (if present)
+/
string findDefaultLcuLockfile() @trusted
{
	{
		const p = environment.get("LEAGUE_LOCKFILE", null);
		if (p !is null && p.length && p.exists)
			return p;
	}
	version (Windows)
	{
		const la = environment.get("LOCALAPPDATA", null);
		if (la !is null && la.length)
		{
			const candidate = buildPath(
				la, "Riot Games", "League of Legends", "lockfile");
			if (candidate.exists)
				return candidate;
		}
	}
	foreach (root; [r"C:\", r"D:\"])
	{
		auto c = buildPath(root, "Riot Games", "League of Legends", "lockfile");
		if (c.exists)
			return c;
	}
	return null;
}

///
unittest
{
	auto l = parseLcuLockfileContent("LeagueClient:1234:50000:secretpass:https");
	assert(l.port == 50000);
	assert(l.password == "secretpass");
	assert(l.processName == "LeagueClient");
}
