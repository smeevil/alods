defmodule Alods.DETS do

  @moduledoc """
  This module contains shared functions that can be used by our DETS tables.
  """

  defmacro __using__(name) do
    quote do
      use GenServer

      @doc"""
      Starts the Genserver which will keep the DETS table open and is the only one that has write rights.
      """
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

      def terminate(_reason, _status) do
        :ok = :dets.close(__MODULE__)
        :normal
      end

      @doc """
      Get the current amount of record entries in the store
      """
      @spec length :: number
      def length, do: :dets.info(__MODULE__)[:size]

      @doc """
      Alias for length/1
      """
      @spec size :: number
      def size, do: length()
      @doc """
      Clears the store, WARNING this removes all records!
      """
      @spec clear! :: :ok
      def clear!, do: :dets.delete_all_objects(__MODULE__)

      @doc """
      Will return all records in the store
      """
      @spec list :: list
      def list, do: :dets.select(__MODULE__, select_all())

      @doc"""
      Finds a record by id
      """
      @spec find(String.t) :: {:ok, %Alods.Record{}} | {:error, :record_not_found}
      def find(id) do
        case :dets.lookup(__MODULE__, id) do
          empty_list when empty_list == [] -> {:error, :record_not_found}
          [{_id, record}] -> {:ok, record}
        end
      end

      @doc"""
      Deletes the given record
      """
      @spec delete!(%Alods.Record{}) :: :ok
      def delete!(%Alods.Record{} = record), do: :dets.delete(__MODULE__, record.id)

      @doc"""
      Finds a record by id, and deletes that record
      """
      @spec delete(String.t) :: :ok | {:error, any}
      def delete(id) do
        case find(id) do
          {:ok, record} -> :dets.delete(__MODULE__, record.id)
          {:error, _} = error -> error
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
        file = path <> "/alods_#{name}_#{env}.ets"
        #DETS is not receiving a shutdown properly in test, we can remove the files and start fresh to prevent repair messages.
        if env == :test, do: File.rm!(file)
        to_charlist(file)
      end

    end
  end
end
