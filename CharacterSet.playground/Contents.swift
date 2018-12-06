import Foundation



// MARK: - Snippet 1

let stringToCheck1: String = "42"
let numbers1: CharacterSet = CharacterSet.decimalDigits
let stringIsANumber1: Bool = stringToCheck1.rangeOfCharacter(from: numbers1.inverted) == nil
/// returns: `true`



// MARK: - Snippet 2

print(CharacterSet.decimalDigits)
/// <CFCharacterSet Predefined DecimalDigit Set>



// MARK: - Snippet 3

let numbers3: NSCharacterSet = NSCharacterSet.decimalDigits as NSCharacterSet
let character3: UTF32Char = UTF32Char(48) /// U+0048 is "0"
numbers3.longCharacterIsMember(character3) /// returns `true`



// MARK: - Snippet 4

func invalidCharactersExist4(input4: String) -> Bool {
    let numbers4 = CharacterSet.decimalDigits
    let rangeOfInvalidCharacters4 = input4.rangeOfCharacter(from: numbers4.inverted)
    return rangeOfInvalidCharacters4 != nil
}

let string1 = "qwerty12345"
let string2 = "qwerty"
let string3 = "12345"

print("\"\(string1)\" contains invalid characters: \(invalidCharactersExist4(input4: string1))")
/// "qwerty12345" contains invalid characters: true

print("\"\(string2)\" contains invalid characters: \(invalidCharactersExist4(input4: string2))")
/// "qwerty" contains invalid characters: true

print("\"\(string3)\" contains invalid characters: \(invalidCharactersExist4(input4: string3))")
/// "12345" contains invalid characters: false



// MARK: - Snippet 5

let string4 = "᧐᪂᧐"
print("\"\(string4)\" contains invalid characters: \(invalidCharactersExist4(input4: string4))")
/// "᧐᪂᧐" contains invalid characters: false



// MARK: - Snippet 6

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

let numbers6: NSCharacterSet = NSCharacterSet.decimalDigits as NSCharacterSet
for character in numbers6.characters {
    print(character)
}
