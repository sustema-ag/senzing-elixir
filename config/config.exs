import Config

config :logger, level: String.to_existing_atom(System.get_env("LOG_LEVEL", "warning"))

if System.fetch_env("IN_DEVCONTAINER") in ["true", "1"] do
  config :senzing, db_connection: "postgresql://postgres@localhost:5432:senzing"
end
