// Arma SQLite addon API. Server execution only.
params [["_seconds", 30, [0]]];

if (!isServer) then { throw "SQLite readiness is server-only"; };
if (!canSuspend) then { throw "waitReady requires scheduled SQF"; };

private _deadline = diag_tickTime + _seconds;

while {!A3SQL_ready && {A3SQL_error == ""} && {diag_tickTime < _deadline}} do { uiSleep 0.02; };

if (!A3SQL_ready) then {
    if (A3SQL_error != "") then { throw A3SQL_error; };
    throw "SQLite startup timed out";
};

true
