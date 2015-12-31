#define fbJson_DEBUG
#include once "../../fbJson.bi"

dim as jsonItem item = jsonItem("{""foo"":bar}")

if item.DataType = malformed then 
  print "problem"
else
  print "ok"
end if
