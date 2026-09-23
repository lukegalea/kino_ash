# kino needs its app tree running for Kino.JS.new (Kino.JS.DataStore).
# Outside Livebook, Kino.Bridge calls fail soft, which is exactly the
# headless mode these tests exercise.
{:ok, _} = Application.ensure_all_started(:kino)

ExUnit.start()
