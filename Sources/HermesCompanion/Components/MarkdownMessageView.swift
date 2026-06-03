import SwiftUI
import AppKit

public enum MarkdownBlock: Hashable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String?, code: String)
    case bulletList(items: [String])
    case numberedList(items: [String])
    case blockquote(text: String)
}

public struct MarkdownMessageView: View {
    let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public var body: some View {
        let blocks = parseMarkdown(text)
        
        VStack(alignment: .leading, spacing: 10) {
            if blocks.isEmpty && !text.isEmpty {
                // Fallback to plain text
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)
            } else {
                ForEach(0..<blocks.count, id: \.self) { index in
                    renderBlock(blocks[index])
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            parseInlineText(text)
                .font(.system(size: headingSize(for: level), weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 4)
                
        case .paragraph(let text):
            parseInlineText(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: false)
                
        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(language ?? "code")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    
                    Spacer()
                    
                    CopyButton(textToCopy: code, buttonLabel: "Copy")
                        .padding(.trailing, 6)
                }
                .background(Color.white.opacity(0.04))
                
                ScrollView(.horizontal, showsIndicators: true) {
                    highlightCode(code, language: language)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(8)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.black.opacity(0.3))
            }
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<items.count, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.hermesTeal)
                        parseInlineText(items[idx])
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.leading, 8)
                }
            }
            
        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<items.count, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.hermesTeal)
                        parseInlineText(items[idx])
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.leading, 8)
                }
            }
            
        case .blockquote(let text):
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.hermesPurple)
                    .frame(width: 3)
                    .padding(.trailing, 8)
                
                parseInlineText(text)
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
    }
    
    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 18
        case 2: return 16
        case 3: return 14
        default: return 13
        }
    }
}

// MARK: - Safe Copy Button

public struct CopyButton: View {
    let textToCopy: String
    let buttonLabel: String
    @State private var isCopied = false
    
    public init(textToCopy: String, buttonLabel: String) {
        self.textToCopy = textToCopy
        self.buttonLabel = buttonLabel
    }
    
    public var body: some View {
        Button(action: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(textToCopy, forType: .string)
            isCopied = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isCopied = false
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                Text(isCopied ? "Copied" : buttonLabel)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(isCopied ? .emerald : .white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Markdown Block Parser

public func parseMarkdown(_ input: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    let lines = input.components(separatedBy: .newlines)
    var currentLines: [String] = []
    
    var inCodeBlock = false
    var codeBlockContent = ""
    var activeLanguage: String? = nil
    
    func flushAccumulated() {
        if !currentLines.isEmpty {
            let paragraphText = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraphText.isEmpty {
                blocks.append(.paragraph(text: paragraphText))
            }
            currentLines = []
        }
    }
    
    var inBulletList = false
    var bulletItems: [String] = []
    
    var inNumberedList = false
    var numberedItems: [String] = []
    
    func flushLists() {
        if inBulletList {
            if !bulletItems.isEmpty {
                blocks.append(.bulletList(items: bulletItems))
            }
            bulletItems = []
            inBulletList = false
        }
        if inNumberedList {
            if !numberedItems.isEmpty {
                blocks.append(.numberedList(items: numberedItems))
            }
            numberedItems = []
            inNumberedList = false
        }
    }
    
    for line in lines {
        // Handle code blocks
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            if inCodeBlock {
                blocks.append(.codeBlock(language: activeLanguage, code: codeBlockContent.trimmingCharacters(in: .newlines)))
                codeBlockContent = ""
                activeLanguage = nil
                inCodeBlock = false
            } else {
                flushLists()
                flushAccumulated()
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                let lang = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                activeLanguage = lang.isEmpty ? nil : sanitiseLanguageLabel(lang)
                inCodeBlock = true
            }
            continue
        }
        
        if inCodeBlock {
            codeBlockContent += line + "\n"
            continue
        }
        
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Handle Headings
        if trimmed.hasPrefix("#") {
            flushLists()
            flushAccumulated()
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if !parts.isEmpty, parts[0].allSatisfy({ $0 == "#" }) {
                let level = parts[0].count
                let text = parts.count > 1 ? String(parts[1]) : ""
                blocks.append(.heading(level: level, text: text))
                continue
            }
        }
        
        // Handle Blockquotes
        if trimmed.hasPrefix(">") {
            flushLists()
            flushAccumulated()
            let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            blocks.append(.blockquote(text: text))
            continue
        }
        
        // Handle Bullet Lists
        if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("+ ") {
            if !inBulletList {
                flushAccumulated()
                inBulletList = true
            }
            let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            bulletItems.append(itemText)
            continue
        }
        
        // Handle Numbered Lists
        if let dotIndex = trimmed.firstIndex(of: "."),
           dotIndex > trimmed.startIndex,
           trimmed[trimmed.startIndex..<dotIndex].allSatisfy({ $0.isNumber }),
           trimmed.index(after: dotIndex) < trimmed.endIndex,
           trimmed[trimmed.index(after: dotIndex)] == " " {
            if !inNumberedList {
                flushAccumulated()
                inNumberedList = true
            }
            let itemText = String(trimmed[trimmed.index(dotIndex, offsetBy: 2)...]).trimmingCharacters(in: .whitespaces)
            numberedItems.append(itemText)
            continue
        }
        
        // Regular line
        if trimmed.isEmpty {
            flushLists()
            flushAccumulated()
        } else {
            currentLines.append(line)
        }
    }
    
    flushLists()
    flushAccumulated()
    return blocks
}

private func sanitiseLanguageLabel(_ lang: String) -> String? {
    let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+-#_-"))
    guard lang.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else {
        return nil
    }
    let clean = lang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if clean.isEmpty || clean.count > 24 {
        return nil
    }
    return clean
}

// MARK: - Inline Parser

public func prepareSafeInlineString(_ input: String) -> String {
    var text = input
    
    // 1. Unsafe image removal: ![alt](url) -> [image omitted]
    let imgRegex = try? NSRegularExpression(pattern: "!\\[(.*?)\\]\\((.*?)\\)", options: [])
    if let imgRegex = imgRegex {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        text = imgRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "[image omitted]")
    }
    
    // 2. Safe link format: [anchor](url) -> anchor
    let linkRegex = try? NSRegularExpression(pattern: "\\[(.*?)\\]\\((.*?)\\)", options: [])
    if let linkRegex = linkRegex {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        text = linkRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1")
    }
    
    return text
}

public func parseInlineText(_ input: String) -> Text {
    let prepared = prepareSafeInlineString(input)
    
    var resultText = Text("")
    var index = prepared.startIndex
    
    while index < prepared.endIndex {
        // Check inline code: `code`
        if prepared[index] == "`" {
            let rest = prepared[index...]
            if let nextTick = rest.dropFirst().firstIndex(of: "`") {
                let codeSegment = String(rest.dropFirst()[..<nextTick])
                resultText = resultText + Text(codeSegment).font(.system(.body, design: .monospaced)).foregroundColor(.hermesTeal)
                index = prepared.index(nextTick, offsetBy: 2)
                continue
            }
        }
        
        // Check bold: **text**
        if prepared[index...].hasPrefix("**") {
            let rest = prepared[prepared.index(index, offsetBy: 2)...]
            if let nextStars = rest.firstIndex(of: "*"), rest.index(after: nextStars) < prepared.endIndex, rest[rest.index(after: nextStars)] == "*" {
                let boldSegment = String(rest[..<nextStars])
                resultText = resultText + Text(boldSegment).bold()
                index = prepared.index(nextStars, offsetBy: 4)
                continue
            }
        }
        
        // Check italic: *text* (but not **)
        if prepared[index] == "*" {
            let rest = prepared[prepared.index(index, offsetBy: 1)...]
            if let nextStar = rest.firstIndex(of: "*") {
                let italicSegment = String(rest[..<nextStar])
                resultText = resultText + Text(italicSegment).italic()
                index = prepared.index(nextStar, offsetBy: 2)
                continue
            }
        }
        
        // Default: add single character
        resultText = resultText + Text(String(prepared[index]))
        index = prepared.index(after: index)
    }
    
    return resultText
}

// MARK: - Safe Copy Normaliser

public func cleanForCopy(_ text: String) -> String {
    // 1. Strip images and links (replaces ![alt](url) -> [image omitted], and [anchor](url) -> anchor)
    var clean = prepareSafeInlineString(text)
    
    // 2. Remove fenced code markers (like ```swift)
    let lines = clean.components(separatedBy: .newlines)
    var resultLines: [String] = []
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") {
            continue
        }
        resultLines.append(line)
    }
    clean = resultLines.joined(separator: "\n")
    
    return clean
}

// MARK: - Lightweight Syntax Highlighting

public func highlightCode(_ code: String, language: String?) -> Text {
    guard let lang = language?.lowercased(), lang == "swift" || lang == "shell" || lang == "sh" || lang == "bash" else {
        return Text(code).foregroundColor(.hermesTeal)
    }
    
    let swiftKeywords: Set<String> = [
        "let", "var", "func", "import", "class", "struct", "enum", "if", "else", 
        "return", "try", "await", "async", "guard", "nil", "true", "false"
    ]
    
    let shellKeywords: Set<String> = [
        "echo", "exit", "if", "then", "else", "fi", "for", "in", "do", 
        "done", "sudo", "ssh", "hermes", "git", "cd", "mkdir", "rm"
    ]
    
    let keywords = lang == "swift" ? swiftKeywords : shellKeywords
    let keywordColor = lang == "swift" ? Color.hermesPurple : Color.amber
    
    var result = Text("")
    
    let wordBoundary = CharacterSet.alphanumerics.inverted
    let scanner = Scanner(string: code)
    scanner.charactersToBeSkipped = nil
    
    while !scanner.isAtEnd {
        if let word = scanner.scanCharacters(from: .alphanumerics) {
            if keywords.contains(word) {
                result = result + Text(word).foregroundColor(keywordColor).bold()
            } else {
                result = result + Text(word).foregroundColor(.hermesTeal)
            }
        }
        
        if let separators = scanner.scanCharacters(from: wordBoundary) {
            result = result + Text(separators).foregroundColor(.hermesTeal)
        }
    }
    
    return result
}
