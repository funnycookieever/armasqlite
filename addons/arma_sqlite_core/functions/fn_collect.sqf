// Arma SQLite addon API. Server execution only.
params ["_reply", ["_releaseChunk", true]];

if ((_reply select 1) != "chunk") exitWith { _reply };

(_reply select 2) params ["_id", "_totalBytes"];

private _offset = 0;
private _pieces = [];

while {_offset < _totalBytes} do {
    private _part = ["read", [_id, (_offset toFixed 0), "4096"]] call A3SQL_fnc_raw;
    if ((_part select 0) != 0 || {(_part select 1) != "part"}) then {
        throw format ["A3SQL read failed for %1: %2", _id, _part];
    };
    (_part select 2) params ["_from", "_next", "_total", "_piece"];
    if (_from != _offset || {_next <= _offset} || {_total != _totalBytes}) then {
        throw format ["A3SQL invalid chunk offsets for %1", _id];
    };
    _pieces pushBack _piece;
    _offset = _next;
    // Yield while collecting large results in scheduled SQF.
    if (canSuspend) then { uiSleep 0.001; };
};

if (_releaseChunk) then { ["release", [_id]] call A3SQL_fnc_raw; };

parseSimpleArray (_pieces joinString "")
