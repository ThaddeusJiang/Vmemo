defmodule VmemoWeb.LiveDashboard.ExternalServicesCache do
  @moduledoc false

  @key :vmemo_external_services_state

  def get_state do
    :persistent_term.get(@key, %{checked_at: nil, services: %{}})
  end

  def update_service(id, attrs) when is_atom(id) and is_map(attrs) do
    %{checked_at: checked_at, services: services} = get_state()
    new_services = Map.update(services, id, attrs, &Map.merge(&1, attrs))
    :persistent_term.put(@key, %{checked_at: checked_at, services: new_services})
    :ok
  end

  def set_checked_at(datetime) do
    %{services: services} = get_state()
    :persistent_term.put(@key, %{checked_at: datetime, services: services})
    :ok
  end
end
