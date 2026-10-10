// Arma SQLite addon API. Server execution only.
params ["_reply"];

if ((_reply select 0) != 0) then { throw format ["A3SQL database error: %1", _reply]; };

_reply
