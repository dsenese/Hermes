//
//  Supabase.swift
//  Hermes
//
//  Initializes the Supabase client for use across the app.
//  Safe to ship with public anon key. Do not include service_role keys in the client app.
//

import Foundation
import Supabase

// Global Supabase client per Supabase iOS/SwiftUI quickstart
// https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui
let supabase: SupabaseClient = {
    let url = URL(string: "https://hwmeitwlnygrhygsebkx.supabase.co")!
    let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3bWVpdHdsbnlncmh5Z3NlYmt4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyODk1NjAsImV4cCI6MjA2ODg2NTU2MH0.2nZE6REpWBzOLUPa_u1vJygPaqAatZ-8yEdi9y8qGYE"
    return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
}()


