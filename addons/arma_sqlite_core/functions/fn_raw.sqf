// Arma SQLite addon API. Server execution only.
params ["_command", ["_arguments", []]];

if (!isServer) then { throw "SQLite helpers must run on the server"; };
if ((_arguments findIf { !(_x isEqualType "") }) >= 0) then {
    throw "Pass every extension argument as a string";
};

private _wire = "arma_sqlite" callExtension [_command, _arguments];
_wire params ["_text", "_returnCode", "_engineCode"];

// 301 is an execution-time warning. The operation may have completed.
if (_engineCode == 301) then { diag_log format ["A3SQL slow call: %1", _command]; };
if (_text == "" || !(_engineCode in [0, 301])) then {
    throw format ["A3SQL engine error %1 for %2", _engineCode, _command];
};

private _reply = parseSimpleArray _text;

if (count _reply != 3 || {(_reply select 0) != _returnCode}) then {
    throw format ["A3SQL invalid response to %1", _command];
};
if (_command == "release" && {(_reply select 0) == 0} && {count _arguments == 1}) then {
    uiNamespace setVariable ["A3SQL_ownedJobs", (uiNamespace getVariable ["A3SQL_ownedJobs", []]) - [_arguments select 0]];
};

_reply
