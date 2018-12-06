# Understanding CharacterSet

_tldr: click [here](#decimaldigitscontent) to see all the characters of `.decimalDigits`_

Have you ever needed to check if a string was made up only of digits? How about the presence of punctuation or non-alphanumeric characters? One could use a variety of methods from one of the `Formatter` classes to `NSScanner` to a `NSPredicate` with a regex expression, but the [most](https://stackoverflow.com/questions/34354740/how-do-you-confirm-a-string-only-contains-numbers-in-swift/34354943) [likely](https://stackoverflow.com/questions/34587094/how-to-check-if-text-contains-only-numbers/34587234) [snippet](https://www.reddit.com/r/swift/comments/40jj5r/is_there_a_way_to_find_whether_or_not_a_character/cyun9yn/) you would've found involved the use of `CharacterSet`.

In brief summary, `CharacterSet` is an Objective-C-bridged Swift class that represents a set of Unicode characters. Its Objective-C counterpart, `NSCharacterSet` is toll-free bridged with CoreFoundation's `CFCharacterSet`. Written in C, `CFCharacterSet` is quite old, dating back to at least Mac OS 8. The main idea behind `CFCharacterSet` is to provide an Unicode-aware data structure that aids in the efficient searching of Unicode strings. Both `NSString` and `NSScanner` internally use `NSCharacterSet` for their string searching operations.

`CharacterSet` can be initialized as an empty set, a set of characters given a string, bytes, or the contents of a file. It comes with many conveniently predefined sets (such as the characters allowed in a URL query fragment or alphanumeric characters) and even allows set algebra such as union, intersection, and exclusive-or.

Using one of `CharacterSet`'s predefined sets feel convenient:

```swift
let stringToCheck: String = "42"
let numbers: CharacterSet = CharacterSet.decimalDigits
let stringIsANumber: Bool = stringToCheck.rangeOfCharacter(from: numbers.inverted) == nil
/// returns: `true`
```

Let's take a step back and look at the code above. **How do you know exactly which characters are included in `.decimalDigits`?**[^1] If the snippet above was validating untrusted user input for numerical characters (such as a phone PIN), not knowing exactly which characters belong in `CharacterSet.decimalDigits` not only may have substantial security implications but also create bugs and other undefined behavior. Let's better understand predefined character sets.

## What is in a predefined CharacterSet?

Unfortunately, `print()` does not work on `CharacterSet`:

```swift
print(CharacterSet.decimalDigits)
/// <CFCharacterSet Predefined DecimalDigit Set>
```

(This log output can be traced back to the original `CFCharacterSet`. Take a look yourself at line 892 of the [earliest publicly available source code for `CFCharacterSet`](https://opensource.apple.com/source/CF/CF-299/String.subproj/CFCharacterSet.c.auto.html)!)

Unfortunately, there is no convenient, built-in method to print all the characters in a `CharacterSet`. `CharacterSet` is neither a subclass of `Set` nor provide any enumerators/iterators for its contents. Let's create our own enumerator for `CharacterSet`! In order to do that, we have to have a good working knowledge of Unicode.

## Basic Understanding of Unicode

### UTF8 and UTF16

Unicode is a text-encoding standard that became necessary as many non-English speaking parts of the world became connected to the World Wide Web. It defines three structures that are relevant to us: UTF8, UTF16, and UTF32. The number at the end of those three names represent the size of their _code units_. A _code unit_ are short blocks of bits that, when combined, represent characters. UTF8 has 8-bit _code units_ and UTF16 has 16-bit _code units_.

UTF8 and UTF16 are considered _variable width_ meaning that one UTF8 character may be represented by upto four 8-bit code units (and two 16-bit code units for UTF16). Consider these two examples:

| Character (Hexadecimal) | Binary                                                       | UTF8                                                       |
| ----------------------- | ------------------------------------------------------------ | ---------------------------------------------------------- |
| $ (U+00**24**)          | `0010 0100`<br /> ([`2 4`](https://duckduckgo.com/?q=24+to+binary)) | Representable in 1 byte: `00100100`                        |
| € (U+**20AC**)          | `0010 0000 1010 1100`<br /> ([`2 0 A C`](https://duckduckgo.com/?q=20AC+to+binary)) | Representable in 3 bytes: `11100010 10000010 10101100`[^1] |

### UTF32

Notice that both four 8-bits and two 16-bits both add up to 32-bits. This is entirely by design: UTF32 is a _fixed width_ format into which UTF8 and UTF16 can easily fit without any extra work. All UTF32 characters contain 32 bits, even if it's not necessary (as we saw above with $ and €). This makes for an inefficient format, but there is *one benefit*: it is _**great**_ for searching because to find the _Nth_ character, you can iterate over every 32 bits instead of decoding every byte to see where the next character begins. This is precisely the reason why `NSCharacterSet.characterIsMember()` internally calls[^2] `longCharacterIsMember()` which only accepts a UTF32 character.

## `CharacterSet` and UTF32

The best way to search the membership of a character within `CharacterSet` is to get the UTF32 code point for that character and pass it to `NSCharacterSet`'s `longCharacterIsMember()`. It looks like this:

```swift
let numbers: NSCharacterSet = NSCharacterSet.decimalDigits as NSCharacterSet
let character: UTF32Char = UTF32Char(48) /// U+0048 is "0"
numbers.longCharacterIsMember(character) /// returns `true`
```
## What's Inside `CharacterSet.decimalDigits`?

Let's go back to our original goal: see what's inside of `CharacterSet.decimalDigits`. Here is an example of why it's so important to understand what's inside of it:

```swift
func invalidCharactersExist(input: String) -> Bool {
    let numbers = CharacterSet.decimalDigits
    let rangeOfInvalidCharacters = input.rangeOfCharacter(from: numbers.inverted)
    return rangeOfInvalidCharacters != nil
}

let string1 = "qwerty12345"
let string2 = "qwerty"
let string3 = "12345"

print("\"\(string1)\" contains invalid characters: \(invalidCharactersExist(input: string1))")
/// "qwerty12345" contains invalid characters: true

print("\"\(string2)\" contains invalid characters: \(invalidCharactersExist(input: string2))")
/// "qwerty" contains invalid characters: true

print("\"\(string3)\" contains invalid characters: \(invalidCharactersExist(input: string3))")
/// "12345" contains invalid characters: false
```

**Given above, how about "᧐᪂᧐"?**
_Let's see_

```swift
let string4 = "᧐᪂᧐"
print("\"\(string4)\" contains invalid characters: \(invalidCharactersExist(input: string4))")
/// "᧐᪂᧐" contains invalid characters: false
```

**_What?_** Let's explore further to understand _why_.

### Printing the contents of `CharacterSet`

Armed with how Unicode works for `CharacterSet`, let's write some code to print the contents of `CharacterSet`. Because `NSCharacterSet` only provides a way to test if a UTF32 character exists in the set, we will have to loop through every possible UTF32 character and check for their membership in the set:

```swift
extension NSCharacterSet {

    var characters:[String] {
        /// An array to hold all the found characters
        var characters: [String] = []

        /// Iterate over the 17 Unicode planes (0..16)
        for plane:UInt8 in 0..<17 {
            /// Iterating over all potential code points of each plane could be expensive as there
            /// can be as many as 2^16 code points per plane. Therefore, only search through a plane
            /// that has a character within the set.
            if self.hasMemberInPlane(plane) {

                /// Define the lower end of the plane (i.e. U+FFFF for beginning of Plane 0)
                let planeStart = UInt32(plane) << 16
                /// Define the lower end of the next plane (i.e. U+1FFFF for beginning of Plane 1)
                let nextPlaneStart = (UInt32(plane) + 1) << 16

                /// Iterate over all possible UTF32 characters from the beginning of the current
                /// plane until the next plane.
                for char:UTF32Char in planeStart..<nextPlaneStart {

                    /// Test if the character being iterated over is part of this `NSCharacterSet`
                    if self.longCharacterIsMember(char) {

                        /// Convert `UTF32Char` (a typealiased `UInt32`) into a `UnicodeScalar`.
                        /// Otherwise, converting `UTF32Char` directly to `String` would turn it
                        /// into a decimal representation of the code point, not the character.
                        if let unicodeCharacter = UnicodeScalar(char) {
                            characters.append(String(unicodeCharacter))
                        }
                    }
                }
            }
        }
        return characters
    }
}

let numbers: NSCharacterSet = NSCharacterSet.decimalDigits as NSCharacterSet
for character in numbers.characters {
    print(character)
}
```

And if you ran that in [Xcode Swift Playgrounds](LINK TO THE PLAYGROUNDS), here is what you would get:

[LINK TO THE GIST]

I encourage you to find other `CharacterSet`s to explore! _(Be careful, though. Some `CharacterSet`s are massive and may make your system unstable until it finishes running.)_

[^1]: Apple does provide exact code points of characters in certain sets such as `.whitespacesAndNewlines` and `.newlines`, but for most other sets only describe the Unicode General Category represented by the set, which I don't find particularly helpful. [This website](https://www.fileformat.info/info/unicode/category/index.htm) amog others does provide a list of all characters in each Unicode General Category.

[^1]: Here's how to translate the character's code point value to UTF8 binary

**Standardized UTF8 bit structure**

| Number of bytes | Byte 1     | Byte 2     | Byte 3     | Byte 4     |
| --------------- | ---------- | ---------- | ---------- | ---------- |
| 1               | `0xxxxxxx` |            |            |            |
| 2               | `110xxxxx` | `10xxxxxx` |            |            |
| 3               | `1110xxxx` | `10xxxxxx` | `10xxxxxx` |            |
| 4               | `11110xxx` | `10xxxxxx` | `10xxxxxx` | `10xxxxxx` |

Here's how to translate the character's code point value to UTF8 binary: Fill in all the `x`s in the table above with the binary value for the character ("€" = `0010 0000 1010 1100`). To figure out how many bytes are needed, consider the length of the binary needed for the character. 1-byte UTF8 can only accomodate 7 bits (only 7 `x`s in the table).  2-byte UTF8 can accomodate 11 bits. 3-byte can accomodate 16 bits, and 4-byte UTF8 can accomodate 21 bits. For the "€"  character, we need at least 14 bits (the first two zeros could potentially be left out), so it looks like we'll be using the 3-byte structure. The binary filled into the UTF8 structure looks like this (with the original binary **bolded**): 1110**0010** 10**000010** 10**101100**. (Notice if you take away the non-bolded binary digits, you get back the original binary for the "€" character!) The first byte in a 3-bite-long UTF8 character always begins with `1110`. This way, the UTF8 decoder knows how many following bytes belong to the same character in the data stream.

[^2]: Check line 1655 of [CFCharacterSet.c](https://opensource.apple.com/source/CF/CF-299/String.subproj/CFCharacterSet.c.auto.html)