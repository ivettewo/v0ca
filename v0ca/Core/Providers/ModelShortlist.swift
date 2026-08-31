import Foundation

/// Which models are worth offering by default.
///
/// Providers report everything they have: dated snapshots of the same model,
/// previews, retired families, and — through an aggregator — image, video and
/// music generators that cannot answer a question at all. An allowlist of the
/// families people actually recognize is the only thing that keeps the picker
/// usable; a blacklist loses that race with every release.
///
/// This filter never removes a model from reach: the Providers tab has a switch
/// that shows the full list. When a rule here goes stale, the model moves out of
/// the default list, it does not disappear.
enum ModelShortlist {
    /// Recognized families, matched as a prefix of the id with the aggregator's
    /// namespace stripped ("openai/gpt-4o-mini" → "gpt-4o-mini").
    ///
    /// Edit this list when a provider ships a new flagship — it is data, and it
    /// is meant to be edited.
    private static let families = [
        // OpenAI: 4o and up, nothing from the 3.5 era.
        "gpt-5", "gpt-4.1", "gpt-4o", "o3", "o4",
        // Anthropic.
        "claude-opus-4", "claude-sonnet-4", "claude-haiku-4", "claude-3-7-sonnet",
        // Google: 2.5 and up.
        "gemini-3", "gemini-2.5",
        // xAI: 3 and up.
        "grok-4", "grok-3",
        // Alibaba.
        "qwen3", "qwen-max", "qwen-plus",
        // DeepSeek.
        "deepseek-chat", "deepseek-reasoner",
    ]

    /// Variants that are the same model in a lab coat: a preview of a release
    /// that already shipped, an experiment, a dated rehearsal.
    private static let excluded = ["preview", "experimental", "-exp", "-alpha", "-beta"]

    /// The default list: recognized families, one entry per model.
    static func featured(_ models: [ProviderModel]) -> [ProviderModel] {
        let matching = models.filter { model in
            let id = bare(model.id)
            guard !excluded.contains(where: { id.contains($0) }) else { return false }
            return families.contains { id.hasPrefix($0) }
        }
        return dedupedByRelease(matching)
    }

    /// Anthropic ships dated ids ("claude-sonnet-4-5-20250929") and OpenAI ships
    /// both an alias and its snapshots. Group by what the model *is* and keep one
    /// per group: the alias when there is one, otherwise the newest date.
    private static func dedupedByRelease(_ models: [ProviderModel]) -> [ProviderModel] {
        var best: [String: ProviderModel] = [:]
        var order: [String] = []
        for model in models {
            let key = releaseKey(bare(model.id))
            if let current = best[key] {
                best[key] = preferred(current, model)
            } else {
                best[key] = model
                order.append(key)
            }
        }
        return order.compactMap { best[$0] }
    }

    /// Between two ids of the same model: the undated alias wins, and between two
    /// dated ones the later date does.
    private static func preferred(_ lhs: ProviderModel, _ rhs: ProviderModel) -> ProviderModel {
        let left = date(in: bare(lhs.id))
        let right = date(in: bare(rhs.id))
        switch (left, right) {
        case (nil, _): return lhs
        case (_, nil): return rhs
        case (let l?, let r?): return l >= r ? lhs : rhs
        }
    }

    /// The id without the aggregator's namespace, lowercased.
    private static func bare(_ id: String) -> String {
        let tail = id.split(separator: "/").last.map(String.init) ?? id
        return tail.lowercased()
    }

    /// The id with any trailing date dropped — what identifies the model itself.
    private static func releaseKey(_ id: String) -> String {
        guard let found = date(in: id) else { return id }
        return id.replacingOccurrences(of: found, with: "").trimmingCharacters(in: ["-"])
    }

    /// A trailing "-20250929" or "-2025-09-29", if present.
    private static func date(in id: String) -> String? {
        let parts = id.split(separator: "-").map(String.init)
        // "-20250929"
        if let last = parts.last, last.count == 8, last.allSatisfy(\.isNumber) {
            return "-" + last
        }
        // "-2025-09-29"
        if parts.count >= 3 {
            let tail = parts.suffix(3)
            let lengths = tail.map(\.count)
            if lengths == [4, 2, 2], tail.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
                return "-" + tail.joined(separator: "-")
            }
        }
        return nil
    }
}
