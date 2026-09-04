import Foundation
import UIKit

enum SwiftTokenType: String, CaseIterable {
    case keyword
    case `type`
    case function
    case property
    case variable
    case string
    case number
    case comment
    case attribute
    case `operator`
    case boolean
    case `nil`
    case directive
    case module
    case plain
}

struct SwiftToken {
    let type: SwiftTokenType
    let range: NSRange
}

struct SyntaxTheme {
    static let dark = SyntaxTheme(
        keyword: UIColor(red: 0.97, green: 0.46, blue: 0.79, alpha: 1),
        typeColor: UIColor(red: 0.36, green: 0.80, blue: 0.95, alpha: 1),
        function: UIColor(red: 0.67, green: 0.87, blue: 0.53, alpha: 1),
        property: UIColor(red: 0.78, green: 0.63, blue: 0.95, alpha: 1),
        variable: UIColor(white: 0.92, alpha: 1),
        string: UIColor(red: 0.98, green: 0.58, blue: 0.42, alpha: 1),
        number: UIColor(red: 0.84, green: 0.75, blue: 0.45, alpha: 1),
        comment: UIColor(red: 0.42, green: 0.55, blue: 0.42, alpha: 1),
        attribute: UIColor(red: 0.84, green: 0.75, blue: 0.45, alpha: 1),
        operatorColor: UIColor(white: 0.85, alpha: 1),
        boolean: UIColor(red: 0.97, green: 0.46, blue: 0.79, alpha: 1),
        nilColor: UIColor(red: 0.97, green: 0.46, blue: 0.79, alpha: 1),
        directive: UIColor(red: 0.98, green: 0.58, blue: 0.42, alpha: 1),
        module: UIColor(red: 0.36, green: 0.80, blue: 0.95, alpha: 1),
        plain: UIColor(white: 0.90, alpha: 1),
        background: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1),
        currentLine: UIColor(white: 1.0, alpha: 0.06),
        lineNumber: UIColor(white: 0.45, alpha: 1),
        selection: UIColor(red: 0.25, green: 0.45, blue: 0.75, alpha: 0.5)
    )
    
    let keyword: UIColor
    let typeColor: UIColor
    let function: UIColor
    let property: UIColor
    let variable: UIColor
    let string: UIColor
    let number: UIColor
    let comment: UIColor
    let attribute: UIColor
    let operatorColor: UIColor
    let boolean: UIColor
    let nilColor: UIColor
    let directive: UIColor
    let module: UIColor
    let plain: UIColor
    let background: UIColor
    let currentLine: UIColor
    let lineNumber: UIColor
    let selection: UIColor
    
    func color(for tokenType: SwiftTokenType) -> UIColor {
        switch tokenType {
        case .keyword: return keyword
        case .type: return typeColor
        case .function: return function
        case .property: return property
        case .variable: return variable
        case .string: return string
        case .number: return number
        case .comment: return comment
        case .attribute: return attribute
        case .operator: return operatorColor
        case .boolean: return boolean
        case .nil: return nilColor
        case .directive: return directive
        case .module: return module
        case .plain: return plain
        }
    }
}
