defmodule Senzing.Nif do
  @moduledoc false

  defmacro __using__(opts \\ []) do
    opts =
      Keyword.merge(opts,
        otp_app: :senzing,
        include_dir: [Path.join(System.fetch_env!("SENZING_ROOT"), "sdk/c")],
        link_lib: [Path.join(System.fetch_env!("SENZING_ROOT"), "lib/libG2.so")],
        local_zig: true
      )

    quote do
      use Zig, unquote(opts)
    end
  end
end
