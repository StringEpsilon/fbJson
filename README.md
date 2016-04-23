# fbJson

A small JSON library written in FreeBASIC.

Latest stable is 0.14.0

## Parsing stuff

You can either give the JSON input via the constructor:

```
dim item as jsonItem = JsomItem("{}")
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

`jsonItem.AddItem(string, string) as boolean` 
Adds a value with a key (only on jsonObjects).

`jsonItem.AddItem(string) as boolean` 
Adds an item (only on jsonArrays). Returns true if successful.

`jsonItem.AddItem(string) as boolean` 
Adds a value (only on jsonArrays). Returns true if successful.

`jsonItem.RemoveItem(string) as boolean` 
Removes the child with the given key. Returns true if successful.

`jsonItem.RemoveItem(integer) as boolean` 
Removes the Nth child. Returns true if successful.

`jsonItem.ContainsKey(string) as boolean` 
Returns true if the item is an object that contains the given key.

`jsonItem.ToString() as string` 
Creates a string representation of the Item and all it's children.

#### JsonDocument

Inherits from JsonItem

`jsonDocument.ReadFile(string) as boolean`
Loads the JSON-file from the given path. Returns true if successful.

`jsonDocument.WriteFile(string [, boolean = true]) as boolean`
Writes the content of the item to a give path. Returns true if successful. Second parameter turns overwriting files on or off (default is on).
