// Arma SQLite addon API. Server execution only.
params ["_id", ["_waitSeconds", 30]];

if (!canSuspend) then { throw "A3SQL_fnc_await requires scheduled SQF"; };

private _end = diag_tickTime + _waitSeconds;
private _reply = ["poll", [_id]] call A3SQL_fnc_raw;

while {(_reply select 1) == "pending" && {diag_tickTime < _end}} do {
    uiSleep 0.01;
    _reply = ["poll", [_id]] call A3SQL_fnc_raw;
};

if ((_reply select 1) == "pending") then {
    ["cancel", [_id]] call A3SQL_fnc_raw;
    _end = diag_tickTime + 5;
    while {(_reply select 1) == "pending" && {diag_tickTime < _end}} do {
        uiSleep 0.01;
        _reply = ["poll", [_id]] call A3SQL_fnc_raw;
    };
    if ((_reply select 1) == "pending") then {
        throw format ["A3SQL job %1 still pending after cancel. Poll and release it later.", _id];
    };
};

_reply = [_reply, false] call A3SQL_fnc_collect;
["release", [_id]] call A3SQL_fnc_raw;
[_reply] call A3SQL_fnc_check
