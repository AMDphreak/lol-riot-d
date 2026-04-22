/++
	Optional pairing of a local LCU client and a Riot **web** client. Use the concrete types
	(`LcuClient`, `RiotWebClient`) for all protocol work; this struct only groups them.
+/
module lol_riot.client;

import lol_riot.lcu : LcuClient;
import lol_riot.riot_web : RiotWebClient;

/++
	`lcu` may be null (web-only). `web` may be null (local-only); most apps set both.
+/
struct LoLRiotSession
{
	/// LCU, or null
	LcuClient lcu;
	/// Riot web API, or null
	RiotWebClient web;
}
