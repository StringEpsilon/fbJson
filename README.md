# fbJson

A small JSON library written in FreeBASIC.

Latest stable is 1.0.1

## License

fbJson is licensed under the [MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/) from version 0.14.1 onwards.

## Roadmap

Past 1.0 / nice to have:

* [ ] More quality of life functionality
	* [ ] Datatype specific properties
* [ ] Write properly escaped json on toString() call.
* [ ] Make toString() fast(er)

## fbJson specifics

Unfortunately, the JSON spec (RFC 8259) leaves some aspects up for interpretation. You have to watch for the following:

* **UTF-8 forgiveness**: The RFC says that all valid JSON must be UTF-8. fbJSON will reject all input that's not UTF-8 or contains
 bytesquences that are not valid in UTF. Further, fbJSON will reject certain inputs that are valid in principle, but not (currently) valid
 unicode. This includes escaped values in the \uXXXX notation.
* **Nesting**: The RFC says: "An implementation may set limits on the maximum depth ofnesting". fbJSON doesn't. It will happily
 parse nested elements until it runs out of memory. **Beware.**
* **String length**: Same situation. In theory, the upper limit is whatever FreeBasics limit is, minus 2 byte.
* **Duplicate keys**: Parse() will use the newer value for any key. Meaning ```{"a": 1, "a": 2}``` is treated like ```{"a": 2}```.

Note: jsonItem.AddItem() will not override existing keys, since I think the programmer should have more control when
manipulating the JSON this way.

## Usage

For hassle free use as-is, I suggest simply throwing the entire fbJson/ folder and the fbJson.bi file into your
repository to include the code at compile time. 

If you don't want to litter your repository with my source code, you can also compile fbJson.bas with the "-lib" or "-dll" 
flag. Then you only need the fbJsonBase.bi and fbJsonItem.bi along with the DLL.


## Parsing stuff

You can either give the JSON input via the constructor:

```
dim item as jsonItem = JsonItem("{}")
```

Or you can create the instance first and then use .Parse().

```
dim item as jsonItem
' some code ...
item.Parse("{}")
```

You could also overwrite instances with the constructor like below, but that comes with some overhead.

```
dim item as jsonItem
' some code ...
item = JsomItem("{}")
```

## Accessing elements

You can access any child-element via the square brackets, either by using the index of the element,
or in case of json-Objects, using the key.

`jsonItem[string]` 
Returns the child element with the corresponding key. 

Keys are case senstive.

`jsonItem[integer]` 
Returns the nTh child of the item.

Keep in mind that the index starts at 0.

## Other properties and methods

#### JsonItem

`jsonItem.Count` 
Gets the total number of children.

`jsonItem.DataType` 
Gets the datatype of the item.

`jsonItem.Key`
Gets or sets the key of the item. Setting the key will _silently_ fail when the new key is already in use. 

`jsonItem.Value as string` 
Gets or sets the value of the item (as string). Also sets the datatype. Returns an emptry string on objects and arrays.

`jsonItem.AddItem(string, jsonItem) as boolean` 
Adds an item with a key (only on jsonObjects).
If the item is of type null, it's converted into an object.

`jsonItem.AddItem(string, string) as boolean` 
Adds a value with a key (only on jsonObjects).
If the item is of type null, it's converted into an object.

`jsonItem.AddItem(string) as boolean` 
Adds an item (only on jsonArrays). Returns true if successful.
If the item is of type null, it's converted into an array.

`jsonItem.AddItem(string) as boolean` 
Adds a value (only on jsonArrays). Returns true if successful.
If the item is of type null, it's converted into an array.


`jsonItem.RemoveItem(string) as boolean` 
Removes the child with the given key. Returns true if successful.

`jsonItem.RemoveItem(integer) as boolean` 
Removes the Nth child. Returns true if successful.

`jsonItem.ContainsKey(string) as boolean` 
Returns true if the item is an object that contains the given key.

`jsonItem.ToString() as string` 
Creates a string representation of the Item and all it's children.

## Performance and compiler options

I unscientifically tested how fast fbJson parses through this monstrosity of a JSON file:

https://github.com/zemirco/sf-city-lots-json/blob/master/citylots.json (181 mb)

On my desktop machine (AMD Ryzen 7 1700X), I get the following results:

| Compiler options  | parsing time (s) |
| ------------- | ------------- |
| fbc "%f"  | 6.33  |
| fbc "%f" -gen GCC -Wc -O1 | ~4.01  |

Test-setup is just loading the file with open and get# and this loop:

```
dim as double start = timer
for i as uinteger = 1 to 30
	dim item as jsonItem = jsonItem(jsonFile)
next
print (timer - start) / 30
```

Setup:

* AMD Ryzen 7 1700X 
* FreeBASIC Compiler - Version 1.06.0 (11-18-2017) (64bit)
* glibc 2.28
* Linux 4.20.4 (64bit)
* fbJson commit 6ef899d296

## Design

The basic principle behind fbJson is to handle all parsing of JSON in one go. There is no AST, no tokenization, etc. 
JsonBase.Parse() will do all the heavy lifting while iterating over the input byte for byte. Ideally, fbJson would not
do a single string comparison and only ever look at each byte of the input once. Didn't quite get there ;-)

fbJson is not the fastest parser in the world, but I tried my best to optimize it. As a result, a lot of the code
is rather ugly and convuluted. isValidDouble() is the most prominent example. Keep that in mind when exploring the codebase.
