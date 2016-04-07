#define fbJSON_debug

#include once "../../fbJson.bi"

dim as jsonDocument document
if ( document.ReadFile("structure.json") = false ) then end

? "Expected: 4, actual: "& document.Count
