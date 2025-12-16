import Foundation

struct USDAKeyProvider {
    /// Resolve the USDA API key from multiple locations.
    /// Priority:
    /// 1. Environment `USDA_API_KEY`
    /// 2. Environment `INFOPLIST_KEY_USDA_API_KEY` (if it contains a nested Info.plist key name, read that; otherwise treat as value)
    /// 3. Bundle Info.plist `USDA_API_KEY`
    /// 4. Bundle Info.plist `INFOPLIST_KEY_USDA_API_KEY` (nested lookup or value)
    /// 5. UserDefaults entries for the same keys
    static func apiKey() -> String? {
        let env = ProcessInfo.processInfo.environment

        func isPlaceholder(_ v: String) -> Bool {
            return v == "REPLACE_ME_USDA_API_KEY"
        }

        func masked(_ s: String) -> String {
            let s = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.count <= 6 { return String(repeating: "*", count: s.count) }
            let prefix = s.prefix(3)
            let suffix = s.suffix(3)
            return "\(prefix)•••\(suffix)"
        }

        // 1. Direct env override
        if let v = env["USDA_API_KEY"], !v.isEmpty, !isPlaceholder(v) {
#if DEBUG
            print("USDAKeyProvider: found key from ENV USDA_API_KEY -> \(masked(v))")
#endif
            return v
        }

        // 2. Env may contain either the actual key or the name of an Info.plist key
        if let v = env["INFOPLIST_KEY_USDA_API_KEY"], !v.isEmpty {
            if let nested = Bundle.main.object(forInfoDictionaryKey: v) as? String, !nested.isEmpty, !isPlaceholder(nested) {
#if DEBUG
                print("USDAKeyProvider: found key via ENV INFOPLIST_KEY_USDA_API_KEY -> nested Info.plist key \(v) -> \(masked(nested))")
#endif
                return nested
            }
            if !isPlaceholder(v) {
#if DEBUG
                print("USDAKeyProvider: found key from ENV INFOPLIST_KEY_USDA_API_KEY -> \(masked(v))")
#endif
                return v
            }
        }

        // 3. Info.plist direct key
        if let v = Bundle.main.object(forInfoDictionaryKey: "USDA_API_KEY") as? String, !v.isEmpty, !isPlaceholder(v) {
#if DEBUG
            print("USDAKeyProvider: found key from Info.plist USDA_API_KEY -> \(masked(v))")
#endif
            return v
        }

        // 4. Info.plist entry that either contains the key name or the value
        if let v = Bundle.main.object(forInfoDictionaryKey: "INFOPLIST_KEY_USDA_API_KEY") as? String, !v.isEmpty {
            if let nested = Bundle.main.object(forInfoDictionaryKey: v) as? String, !nested.isEmpty, !isPlaceholder(nested) {
#if DEBUG
                print("USDAKeyProvider: found key via Info.plist INFOPLIST_KEY_USDA_API_KEY -> nested Info.plist key \(v) -> \(masked(nested))")
#endif
                return nested
            }
            if !isPlaceholder(v) {
#if DEBUG
                print("USDAKeyProvider: found key from Info.plist INFOPLIST_KEY_USDA_API_KEY -> \(masked(v))")
#endif
                return v
            }
        }

        // 5. infoDictionary direct access (redundant but safe)
        if let v = Bundle.main.infoDictionary?["USDA_API_KEY"] as? String, !v.isEmpty, !isPlaceholder(v) {
#if DEBUG
            print("USDAKeyProvider: found key from Bundle.infoDictionary USDA_API_KEY -> \(masked(v))")
#endif
            return v
        }
        if let v = Bundle.main.infoDictionary?["INFOPLIST_KEY_USDA_API_KEY"] as? String, !v.isEmpty {
            if let nested = Bundle.main.infoDictionary?[v] as? String, !nested.isEmpty, !isPlaceholder(nested) {
#if DEBUG
                print("USDAKeyProvider: found key via Bundle.infoDictionary INFOPLIST_KEY_USDA_API_KEY -> nested Info.plist key \(v) -> \(masked(nested))")
#endif
                return nested
            }
            if !isPlaceholder(v) {
#if DEBUG
                print("USDAKeyProvider: found key from Bundle.infoDictionary INFOPLIST_KEY_USDA_API_KEY -> \(masked(v))")
#endif
                return v
            }
        }

        // 6. UserDefaults fallbacks
        if let v = UserDefaults.standard.string(forKey: "USDA_API_KEY"), !v.isEmpty, !isPlaceholder(v) {
#if DEBUG
            print("USDAKeyProvider: found key from UserDefaults USDA_API_KEY -> \(masked(v))")
#endif
            return v
        }
        if let v = UserDefaults.standard.string(forKey: "INFOPLIST_KEY_USDA_API_KEY"), !v.isEmpty {
            if let nested = UserDefaults.standard.string(forKey: v), !nested.isEmpty, !isPlaceholder(nested) {
#if DEBUG
                print("USDAKeyProvider: found key via UserDefaults INFOPLIST_KEY_USDA_API_KEY -> nested key \(v) -> \(masked(nested))")
#endif
                return nested
            }
            if !isPlaceholder(v) {
#if DEBUG
                print("USDAKeyProvider: found key from UserDefaults INFOPLIST_KEY_USDA_API_KEY -> \(masked(v))")
#endif
                return v
            }
        }

        return nil
    }
}
