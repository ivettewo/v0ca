import SwiftUI

/// Light Markdown for the answer bubble. Models reply with headings, bold and
/// lists, and raw `###` / `**` in the text looks like a bug.
///
/// Deliberately small: headings, bullets, numbered items, bold/italic/code.
/// No tables, links, quotes or fenced blocks — a spoken question rarely gets
/// them back, and each one costs a parser branch and a layout decision.
struct AnswerText: View {
    let raw: String
    var color: Color = Tokens.textMeta

    /// Body size of the bubble; everything else is derived from it.
    private static let size: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(Self.blocks(raw).enumerated()), id: \.offset) { _, block in
                line(block)
            }
        }
    }

    @ViewBuilder
    private func line(_ block: Block) -> some View {
        switch block.kind {
        case .heading:
            Text(Self.inline(block.text, weight: .semibold, size: Self.size + 1))
                .font(Tokens.sans(Self.size + 1, weight: .semibold))
                .foregroundStyle(Tokens.text)
                .padding(.top, 4)
        case .paragraph:
            Text(Self.inline(block.text))
                .font(Tokens.sans(Self.size))
                .lineSpacing(5)
                .foregroundStyle(color)
        case .item(let level, let marker):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(marker)
                    .font(Tokens.sans(Self.size))
                    .foregroundStyle(Tokens.text3)
                    // Numbers are wider than bullets; a fixed column keeps the
                    // text edges of neighbouring items aligned.
                    .frame(minWidth: 11, alignment: .leading)
                Text(Self.inline(block.text))
                    .font(Tokens.sans(Self.size))
                    .lineSpacing(5)
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(level) * 14)
        }
    }

    // MARK: - Blocks

    fileprivate struct Block {
        enum Kind: Equatable {
            case heading
            case paragraph
            /// Nesting depth and the glyph or number to show.
            case item(level: Int, marker: String)
        }

        let kind: Kind
        let text: String
    }

    /// One pass over the lines. Consecutive plain lines are joined into one
    /// paragraph, the way Markdown treats them; a blank line ends it.
    fileprivate static func blocks(_ source: String) -> [Block] {
        var result: [Block] = []
        var paragraph: [String] = []

        func flush() {
            guard !paragraph.isEmpty else { return }
            result.append(Block(kind: .paragraph, text: paragraph.joined(separator: " ")))
            paragraph = []
        }

        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
            if line.isEmpty {
                flush()
                continue
            }
            let indent = rawLine.prefix { $0 == " " || $0 == "\t" }.count
            if let heading = strip(line, prefixes: ["######", "#####", "####", "###", "##", "#"]) {
                flush()
                result.append(Block(kind: .heading, text: heading))
            } else if let bullet = strip(line, prefixes: ["- ", "* ", "+ "]) {
                flush()
                let level = min(indent / 2, 3)
                result.append(Block(
                    kind: .item(level: level, marker: level == 0 ? "•" : "◦"), text: bullet
                ))
            } else if let numbered = numberedItem(line) {
                flush()
                result.append(Block(
                    kind: .item(level: min(indent / 2, 3), marker: numbered.marker),
                    text: numbered.text
                ))
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return result
    }

    private static func strip(_ line: String, prefixes: [String]) -> String? {
        for prefix in prefixes where line.hasPrefix(prefix) {
            let rest = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            // "#Hashtag" is not a heading; "# Heading" is.
            if prefix.hasSuffix("#"), line.dropFirst(prefix.count).first != " " { continue }
            return rest.isEmpty ? nil : rest
        }
        return nil
    }

    /// "1. text" or "2) text".
    private static func numberedItem(_ line: String) -> (marker: String, text: String)? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 2 else { return nil }
        let rest = line.dropFirst(digits.count)
        guard let separator = rest.first, separator == "." || separator == ")" else { return nil }
        let text = rest.dropFirst().trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return ("\(digits).", text)
    }

    // MARK: - Inline

    /// `**bold**`, `*italic*` and `` `code` ``. Bold lands on medium rather than
    /// bold: in a 13pt bubble full bold shouts.
    private static func inline(
        _ text: String, weight: Font.Weight = .medium, size: CGFloat = AnswerText.size
    ) -> AttributedString {
        guard var attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return AttributedString(text)
        }
        for run in attributed.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.stronglyEmphasized) {
                attributed[run.range].font = Tokens.sans(size, weight: weight)
            }
            if intent.contains(.emphasized) {
                attributed[run.range].font = Tokens.sans(size).italic()
            }
            if intent.contains(.code) {
                attributed[run.range].font = Tokens.mono(size - 1)
            }
        }
        return attributed
    }
}
