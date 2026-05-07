defmodule Vmemo.Account.ApiTokenTest do
  use Vmemo.DataCase, async: true

  import Vmemo.AccountFixtures

  alias Vmemo.Account.ApiToken

  describe "token window queries" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "get_expiring_for_user/2 only includes active tokens expiring within days", %{user: user} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      in_2_days = DateTime.add(now, 2 * 24 * 60 * 60, :second)
      in_20_days = DateTime.add(now, 20 * 24 * 60 * 60, :second)

      expiring = create_token!(user, "expiring-token", in_2_days, true)
      _not_expiring = create_token!(user, "not-expiring-token", in_20_days, true)
      _never_expires = create_token!(user, "never-expires-token", nil, true)

      assert {:ok, tokens} = ApiToken.get_expiring_for_user(user, 7)
      token_ids = Enum.map(tokens, & &1.id)

      assert expiring.id in token_ids
      refute Enum.any?(tokens, &(&1.name == "not-expiring-token"))
      refute Enum.any?(tokens, &(&1.name == "never-expires-token"))
    end

    test "get_expired_for_user/1 returns ok tuple", %{user: user} do
      assert {:ok, _tokens} = ApiToken.get_expired_for_user(user)
    end
  end

  defp create_token!(user, name, expires_at, _is_active) do
    {_raw, hash} = ApiToken.generate_token()

    attrs = %{
      name: name,
      user_id: user.id,
      token_hash: hash
    }

    attrs =
      if is_nil(expires_at) do
        attrs
      else
        Map.put(attrs, :expires_at, expires_at)
      end

    case ApiToken.create(attrs, actor: user) do
      {:ok, token} ->
        token

      {:error, error} -> raise "failed to create token fixture: #{inspect(error)}"
    end
  end
end
