# fbJson

A small JSON library written in FreeBASIC

## Why?

The existing parsers written in FB had bugs I could not fix with reasonable effort and I did not like the API. 

Also, it's a nice opportunity to learn something.

## API

#### JsonItem

`jsonItem()` Initilizes an empty item (of type `null` )

`jsonItem(string)` Initializes a the item with a JSON-string to parse.

`jsonItem[string]` Returns the child element with the corresponding key.

`jsonItem[integer]` Returns the nth child of the item.

`jsonItem.Count` Gets the number of children.

`jsonItem.DataType` Gets the datatype of the item.

`jsonItem.Value` Gets or sets the value of the item (as string). Also sets the datatype. 

Please note: `Value` Returns nothing if the Item is of type Array or Object.

`jsonItem.ToString()` Creates a string representation of the Item and all it's children.

#### JsonDocument

Inherits from JsonItem

`jsonItem(string)` Initializes a the document with JSON from a given file.


## TODO

1) Add more functionality for the lazy.

2) Fix style and naming.

3) Add some tests.

Maybe, just maybe, use a hashtable for access via key.
