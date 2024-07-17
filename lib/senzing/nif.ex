defmodule Senzing.Nif do
  @moduledoc false
  alias Senzing.G2

  defmacro __using__(opts \\ []) do
    opts =
      Keyword.merge(opts,
        otp_app: :senzing,
        include_dir: [G2.locate_sdk_path()],
        link_lib: [Path.join(G2.locate_lib_path(), "libG2.so")],
        local_zig: true
      )

    quote do
      use Zig, unquote(opts)
    end
  end
end
