import Config

# Required by Ash 3.x for `:string` length constraints (matches ash_a2ui's
# own recommendation: codepoints, consistent with SQL data layers).
config :ash, default_string_length_count: :codepoints
