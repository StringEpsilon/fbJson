/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/

#define fbJSON_debug

#include once "../fbJson.bas"

dim as jsonItem root = jsonItem()

root.addItem("Name", "fbJson")
root.addItem("Version", "0.17.2")
root.addItem("Double", "11.1e10")
root.addItem("String", """11.1e10""")
root.addItem("Purpose", "To chew bubblegum and parse JSON.")
root.addItem("Status", "All out of bubblegum.")
root.addItem("array", jsonItem())

for i as integer = 1 to 10
	root["array"].addItem(str(i))
next

print root.toString()
