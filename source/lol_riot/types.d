/++
	JSON models for common responses (asdf + mir.serde). Extend or fork structs for your routes.
+/
module lol_riot.types;

import mir.serde;
import asdf : deserialize;

/++
	LCU `GET /lol-summoner/v1/current-summoner` (fields vary by client; optional keys use defaults).
+/
struct LcuCurrentSummoner
{
	@serdeKeys("displayName", "gameName", "name")
	@serdeOptional
	string displayName;
	@serdeOptional
	long accountId;
	@serdeOptional
	long summonerId;
	@serdeOptional
	long puuid;
	@serdeOptional
	int profileIconId;
	@serdeOptional
	int summonerLevel;
}

/++
	Web API `.../lol/summoner/v4/...` — typical core fields.
+/
struct RiotSummonerV4
{
	@serdeOptional
	string puuid;
	@serdeOptional
	long accountId;
	@serdeOptional
	int profileIconId;
	@serdeOptional
	long revisionDate;
	@serdeOptional
	string name;
	@serdeOptional
	string id; /// encrypted local summoner id
	@serdeOptional
	int summonerLevel;
}

/++
	Deserialize a JSON string into `T` (asdf).
+/
T fromJson(T)(in char[] json) @trusted
{
	return deserialize!T(json);
}
