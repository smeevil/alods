defmodule Alods.DETS do

  @moduledoc """
  This module contains shared functions that can be used by our DETS tables.
  """

  defmacro __using__(name) do
    quote do

      @spec start_link :: {:ok, pid}
      def start_link do
        GenServer.start_link(__MODULE__, unquote(name), name: __MODULE__)
      end

      def init(name) do
        file = prepare_dets_table_location!(name)
        Process.flag(:trap_exit, true)
        auto_save = Application.get_env(:alods, :store_auto_save_ms, :timer.seconds(60))
        {:ok, _reference} = :dets.open_file(__MODULE__, file: file, auto_save: auto_save)
        {:ok, nil}
      end
      defoverridable [init: 1]

      #TODO seems not to trigger for mix test, in IEX when running :init.stop it works fine...
      def terminate(_reason, _status) do
        IO.puts "Closing DETS"
        :ok = :dets.close(__MODULE__)
        :normal
      end

      @doc """
      Get the current amount of record entries in the store
      """
      @spec length :: number
      def length, do: :dets.info(__MODULE__)[:size]

      @doc """
      Alias for lenth/1
      """
      @spec size :: number
      def size, do: length()

      @doc """
      Clears the store, WARNING this removes all records!
      """
      @spec clear! :: :ok
      def clear!, do: GenServer.call(__MODULE__, {:clear})

      @doc """
      Will return all records in the store
      """
      @spec list :: list
      def list, do: GenServer.call(__MODULE__, {:list})

      @doc"""
      Finds a record by id
      """
      @spec find(String.t) :: {:ok, %Alods.Record{}} | {:error, :record_not_found}
      def find(id), do: GenServer.call(__MODULE__, {:find, id})

      @doc"""
      Deletes the given record
      """
      @spec delete!(%Alods.Record{}) :: :ok
      def delete!(%Alods.Record{} = record), do: GenServer.call(__MODULE__, {:delete!, record})

      @doc"""
      Finds a record by id, and deletes that record
      """
      @spec delete(String.t) :: :ok | {:error, any}
      def delete(id) do
        case find(id) do
          {:ok, record} -> delete!(record)
          {:error, _} = error -> error
        end
      end

      def handle_call({:list}, _caller, state) do
        records = :dets.select(__MODULE__, select_all())
        {:reply, records, state}
      end

      def handle_call({:clear}, _caller, state) do
        :ok = :dets.delete_all_objects(__MODULE__)
        {:reply, :ok, state}
      end

      def handle_call({:find, id}, _caller, state) do
        result = find_record(id)
        {:reply, result, state}
      end

      def handle_call({:delete!, %Alods.Record{} = record}, _caller, state) do
        :ok = :dets.delete(__MODULE__, record.id)
        {:reply, :ok, state}
      end

      def handle_call({:push, %Alods.Record{} = record}, _caller, state) do
        case :dets.insert_new(__MODULE__, {record.id, record}) do
          true -> {:reply, {:ok, record.id}, state}
          error -> error
        end
      end

      @spec find_record(String.t) :: {:ok, %Alods.Record{}} | {:error, :record_not_found}
      defp find_record(id) do
        case :dets.lookup(__MODULE__, id) do
          empty_list when empty_list == [] -> {:error, :record_not_found}
          [{_id, record}] -> {:ok, record}
        end
      end

      @spec prepare_dets_table_location!(String.t | atom) :: charlist
      defp prepare_dets_table_location!(name) do
        env = Application.get_env(:alods, :env)
        if env == nil do
          raise(
            "Please make sure you define alods env in your config/dev.exs with `config :alods, env: :dev` for example"
          )
        end
        path = File.cwd! <> "/priv"
        unless File.exists?(path), do: File.mkdir_p!(path)
        to_charlist(path <> "/alods_#{name}_#{env}.ets")
      end

    end
  end
end
