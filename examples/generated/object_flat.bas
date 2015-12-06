#include once "../../fbJson.bi"

dim as jsonItem item = jsonItem()
dim as jsonItem array = jsonItem("[""? item[\""lines\""][0].value"", ""? item[\""lines\""][1].value""]")

item.AddItem("Type", "Example")
item.AddItem("Name", "fromScatch.bas")
item.AddItem("Works", "true")
item.AddItem("linesOfCode", "15")
item.AddItem("lines", array)

? item["lines"][0].value
? item["lines"][1].value
?
? item.ToString()
