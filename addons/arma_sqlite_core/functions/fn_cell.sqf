// Arma SQLite addon API. Server execution only.
params ["_cell", ["_nullValue", objNull]];

_cell params ["_type", "_value"];

switch _type do {
    case "text": { toString ([_value] call A3SQL_fnc_unhex) };
    case "integer": { _value }; // Preserve precision. parseNumber only for small game values.
    case "real": { parseNumber _value };
    case "blob": { [_value] call A3SQL_fnc_unhex };
    case "null": { _nullValue };
    default { throw format ["Unknown SQLite cell type: %1", _type]; };
}
