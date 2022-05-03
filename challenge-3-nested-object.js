var _object = {"a":{"b":{"c": {"d":{"e":"f"}, "h":"g"}}}}
var _key = "a/b/c/h"

let arr = _key.split("/");

for (let i = 0; i < arr.length; i++) {
    _object = _object[arr[i]];
}
console.log(_object);