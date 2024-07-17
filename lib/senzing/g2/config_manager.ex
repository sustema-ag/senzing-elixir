defmodule Senzing.G2.ConfigManager do
  @moduledoc """
  The G2 Config Manager modifies Senzing configurations in the Senzing database.

  See https://docs.senzing.com/python/3/g2configmgr/index.html

  To use any of these functions, make sure to start `Senzing.G2.ResourceInit`
  with the `mod` option set to `#{__MODULE__}`.
  """

  @behaviour Senzing.G2.ResourceInit

  alias Senzing.G2
  alias Senzing.G2.Config
  alias Senzing.G2.ConfigManager.Nif
  alias Senzing.G2.ResourceInit

  @type resource_init_option() :: {:verbose_logging, boolean()}
  @type resource_init_options() :: [resource_init_option()]

  @type config_id :: integer()
  @type config_parameters :: map()

  ##############################################################################
  # ResourceInit Callbacks
  ##############################################################################

  # This method will initialize the G2 Config object.
  #
  # It must be called prior to any other calls.
  #
  # Usually you will want to start the config by starting the `senzing`
  # application or by starting `Senzing.G2.Init` module as a worker.
  @doc false
  @impl ResourceInit
  @spec resource_init(
          name :: String.t(),
          ini_params :: ResourceInit.ini_params(),
          options :: resource_init_options()
        ) :: G2.result()
  def resource_init(name, ini_params, options \\ []) when is_binary(name) and is_map(ini_params),
    do: Nif.init(name, IO.iodata_to_binary(:json.encode(ini_params)), options[:verbose_logging] || false)

  # This method will destroy and perform cleanup for the G2 Config object.
  #
  # It should be called after all other calls are complete.
  @doc false
  @impl ResourceInit
  @spec resource_destroy() :: G2.result()
  defdelegate resource_destroy, to: Nif, as: :destroy

  ##############################################################################
  # Exposed Functions
  ##############################################################################

  @doc """
  Adds a configuration JSON document to the Senzing database.

  See https://docs.senzing.com/python/3/g2configmgr/index.html#addconfig

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      iex> {:ok, config_json} = Senzing.G2.Config.save(config)
      iex> {:ok, config_id} = Senzing.G2.ConfigManager.add_config(config_json, comment: "comment")
      iex> is_integer(config_id)
      true

  """
  @spec add_config(config :: Config.t(), opts :: [comment: String.t()]) :: G2.result(config_id())
  def add_config(config, opts \\ []), do: Nif.add_config(config, Keyword.get(opts, :comment, ""))

  @doc """
  Retrieves a specific configuration JSON document from the data repository.

  See https://docs.senzing.com/python/3/g2configmgr/index.html#getconfig

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      iex> {:ok, config_json} = Senzing.G2.Config.save(config)
      iex> {:ok, config_id} = Senzing.G2.ConfigManager.add_config(config_json, comment: "comment")
      iex> {:ok, config_json} = Senzing.G2.ConfigManager.get_config(config_id)
      iex> is_binary(config_json)
      true

  """
  @spec get_config(config_id :: config_id()) :: G2.result(Config.t())
  def get_config(config_id), do: Nif.get_config(config_id)

  @doc """
  Retrieves a list of the configuration JSON documents contained in the data repository.

  See https://docs.senzing.com/python/3/g2configmgr/index.html#listconfigs

  ## Examples

      iex> {:ok, configs} = Senzing.G2.ConfigManager.list_configs()
      iex> # {:ok, [%{"CONFIG_COMMENTS" => "comment", "CONFIG_ID" => 1990907876, "SYS_CREATE_DT" => "2024-02-22 19:46:22.556"}]}

  """
  @spec list_configs() :: G2.result([config_parameters()])
  def list_configs do
    with {:ok, json} <- Nif.list_configs(),
         %{"CONFIGS" => configs} <- :json.decode(json),
         do: {:ok, configs}
  end

  @doc """
  Retrieves a specific configuration ID from the data repository.

  See https://docs.senzing.com/python/3/g2configmgr/index.html#getdefaultconfigid

  ## Examples

      iex> {:ok, default_config_id} = Senzing.G2.ConfigManager.get_default_config_id()
      iex> is_integer(default_config_id)
      true

  """
  @spec get_default_config_id() :: G2.result(config_id())
  defdelegate get_default_config_id, to: Nif

  @doc """
  Sets the default configuration JSON document in the data repository.

  See https://docs.senzing.com/python/3/g2configmgr/index.html#setdefaultconfigid

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      iex> {:ok, config_json} = Senzing.G2.Config.save(config)
      iex> {:ok, config_id} = Senzing.G2.ConfigManager.add_config(config_json, comment: "comment")
      iex> :ok = Senzing.G2.ConfigManager.set_default_config_id(config_id)
      iex> {:ok, default_config_id} = Senzing.G2.ConfigManager.get_default_config_id()
      iex> config_id == default_config_id
      true

  """
  @spec set_default_config_id(config_id :: config_id()) :: G2.result()
  defdelegate set_default_config_id(config_id), to: Nif

  @doc """
  Checks the current default configuration ID, and if it matches, replaces it with another configured ID in the database.

  See https://docs.senzing.com/python/3/g2configmgr/index.html#replacedefaultconfigid

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      iex> {:ok, config_json} = Senzing.G2.Config.save(config)
      iex> {:ok, config_id} = Senzing.G2.ConfigManager.add_config(config_json, comment: "comment")
      iex> :ok = Senzing.G2.ConfigManager.set_default_config_id(config_id)
      iex> {:ok, new_config_id} = Senzing.G2.ConfigManager.add_config(config_json, comment: "comment")
      iex> :ok = Senzing.G2.ConfigManager.replace_default_config_id(new_config_id, config_id)
      iex> {:ok, default_config_id} = Senzing.G2.ConfigManager.get_default_config_id()
      iex> new_config_id == default_config_id
      true

  """
  @spec replace_default_config_id(new_config_id :: config_id(), old_config_id :: config_id()) :: G2.result()
  defdelegate replace_default_config_id(new_config_id, old_config_id), to: Nif
end
