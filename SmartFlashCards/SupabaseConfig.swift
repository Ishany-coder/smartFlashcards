import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "REPLACE WITH YOUR OWN")!
    static let anonKey = "REPLACE WITH YOUR OWN"

    static let client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
}
