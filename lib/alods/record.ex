defmodule Alods.Record do
  @moduledoc """
  These are the records that are stored in the queue.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, []}
  embedded_schema do
    field :created_at, :utc_datetime
    field :callback, Alods.EctoCallback
    field :delivered_at, :utc_datetime
    field :data, Alods.EctoMapOrTuple
    field :method, :string #Alods.EctoAtom
    field :reason, :map
    field :retries, :integer, default: 0
    field :status, :string
    field :timestamp, :integer
    field :updated_at, :utc_datetime
    field :url, :string
  end

  @required_fields [:created_at, :data, :id, :method, :status, :timestamp, :url]
  @optional_fields [:callback, :delivered_at, :reason, :retries, :updated_at]

  @valid_statuses ["delivered", "pending", "permanent_failure", "processing"]
  @valid_methods ["get", "post"]
  @valid_protocols ["http", "https"]

  @doc """
  Use this to create the Alods.Record struct which will validate all options given.
  """
  @spec create(params :: map | list) :: {:ok, %Alods.Record{}} | {:error, Ecto.Changeset.t}
  def create(params \\ %{})
  def create(params) when is_list(params), do: create(Enum.into(params, %{}))
  def create(params) do
    case changeset(%Alods.Record{}, add_defaults(params)) do
      %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      changeset -> {:error, Enum.map(changeset.errors, fn ({field, {msg, _}}) -> {field, msg} end)}
    end
  end

  @doc """
  Will Update a given record and raise if validation failed or something else went wrong
  """
  @spec update!(%Alods.Record{}, map | list) :: %Alods.Record{}
  def update!(%Alods.Record{} = record, params) when is_list(params), do: update!(record, Enum.into(params, %{}))
  def update!(%Alods.Record{} = record, params) do
    {:ok, record} = update(record, params)
    record
  end

  @doc """
  Will update a given record
  """
  @spec update(%Alods.Record{}, map) :: {:ok, %Alods.Record{}} | {:error, any}
  def update(%Alods.Record{} = record, params) when is_list(params), do: update(record, Enum.into(params, %{}))
  def update(%Alods.Record{} = record, params) do
    params = params
             |> maybe_change_atoms_to_strings
             |> Map.put(:updated_at, DateTime.utc_now)

    case changeset(record, params) do
      %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      changeset -> {:error, Enum.map(changeset.errors, fn ({field, {msg, _}}) -> {field, msg} end)}
    end
  end

  @spec changeset(%Alods.Record{}, map) :: Ecto.Changeset.t
  defp changeset(struct, params) do
    params = maybe_change_atoms_to_strings(params)

    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses, message: "should be one of #{Enum.join(@valid_statuses, ", ")}")
    |> validate_inclusion(:method, @valid_methods, message: "should be one of #{Enum.join(@valid_methods, ", ")}")
    |> validate_number(:retries, greater_than_or_equal_to: 0)
    |> validate_url
  end

  @spec validate_url(Ecto.Changeset.t) :: Ecto.Changeset.t
  defp validate_url(
         %{
           changes: %{
             url: url
           }
         } = changeset
       ) do
    case URI.parse(url) do
      %{scheme: scheme} when not scheme in @valid_protocols ->
        Ecto.Changeset.add_error(changeset, :url, "invalid_or_missing_protocol")
      %{host: nil} -> Ecto.Changeset.add_error(changeset, :url, "invalid_host")
      _ -> changeset
    end
  end
  defp validate_url(changeset), do: changeset

  @spec add_defaults(map) :: map
  defp add_defaults(params) do
    params
    |> Map.put_new(:id, Ecto.UUID.generate())
    |> Map.put_new(:timestamp, :os.system_time(:seconds))
    |> Map.put(:status, :pending)
    |> Map.put(:retries, 0)
    |> Map.put(:created_at, DateTime.utc_now)
  end

  @spec maybe_change_atoms_to_strings(map) :: map
  defp maybe_change_atoms_to_strings(params) do
    params
    |> convert_atom_value(:status)
    |> convert_atom_value(:method)
  end

  @spec convert_atom_value(map, atom) :: map
  defp convert_atom_value(params, key) do
    case Map.get(params, key) do
      nil -> params
      value when is_atom(value) -> Map.put(params, key, Atom.to_string(value))
      _ -> params
    end
  end

end
