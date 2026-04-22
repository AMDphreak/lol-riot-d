/++
	League Client (LCU) REST access over `https` on localhost, Basic auth, self-signed cert.
+/
module lol_riot.lcu;

import std.exception : enforce;
import std.format : format;
import std.string : startsWith;

import requests;
import requests.base : BasicAuthentication;

import lol_riot.lockfile : LcuLockfile, readLcuLockfile, findDefaultLcuLockfile;
import lol_riot.types : LcuCurrentSummoner, fromJson;

/++
	HTTP/HTTPS client for the LCU. Not rate-limited (local); reuse one instance per app.
+/
final class LcuClient
{
	private
	{
		Request _req;
		string _base; /// `https://127.0.0.1:port`
		bool _ok;
	}

	/++
		Construct from a parsed `lockfile`.
+/
	this(LcuLockfile lf)
	{
		_setup(lf);
	}

	/++
		Read and parse a lockfile at `path`.
+/
	this(string lockfilePath)
	{
		this(readLcuLockfile(lockfilePath));
	}

	/++
		Use `LEAGUE_LOCKFILE` or standard game paths. Throws if not found.
+/
	static LcuClient discover()
	{
		const p = findDefaultLcuLockfile();
		enforce(p.length, "set LEAGUE_LOCKFILE or start League to create the lockfile");
		return new LcuClient(p);
	}

	/// True if constructed without throwing (always true after `this` completes).
	@property bool isConfigured() @nogc const pure nothrow
	{
		return _ok;
	}

	/// `https://127.0.0.1:PORT`
	@property string baseUrl() @nogc const pure nothrow
	{
		return _base;
	}

	/++
		GET a path (must start with `/`), e.g. `/lol-summoner/v1/current-summoner`
+/
	Response get(string lcuPath) @trusted
	{
		enforce(lcuPath.length && lcuPath.startsWith("/"), "LCU path must start with /");
		return _req.get(_base ~ lcuPath);
	}

	/++
		GET and return body as `string` if status is 200, else throw with code.
+/
	string getString(string lcuPath) @trusted
	{
		auto r = get(lcuPath);
		enforce(
			cast(ushort) 200 == r.code,
			format!"LCU HTTP %d for %s"(cast(int) r.code, lcuPath));
		return (cast(string) r.responseBody.data);
	}

	/++
		Typed `current-summoner` helper.
+/
	LcuCurrentSummoner getCurrentSummoner() @trusted
	{
		return fromJson!LcuCurrentSummoner(getString("/lol-summoner/v1/current-summoner").dup);
	}

	private void _setup(LcuLockfile lf) @trusted
	{
		_base = format!"https://127.0.0.1:%s"(lf.port);
		_req = Request();
		_req.sslSetVerifyPeer(false);
		_req.addHeaders([ "Accept": "application/json" ]);
		_req.authenticator = new BasicAuthentication("riot", lf.password);
		_ok = true;
	}
}
