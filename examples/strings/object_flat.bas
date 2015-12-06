#include once "../fbJson.bi"

dim as jsonItem item = jsonItem("{""Name"": ""fbJson"", ""Url"": ""https://github.com/StringEpsilon/fbJson"", ""commits"": 29 }")

print item["Name"].value
print item["Url"].Value
print item[2].Value
print item["InvalidKey"].Value ' Access to invalid keys or integers

item.RemoveItem("dimensions")

' Output: 
' fbJson
' https://github.com/StringEpsilon/fbJson
' 21
'
