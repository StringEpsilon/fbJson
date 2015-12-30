#define fbJson_DEBUG
#include once "../../fbJson.bi"

dim as jsonItem array = jsonItem("{""foo"":}")

if (array.datatype = malformed) then
	Print "Test OK"
end if
