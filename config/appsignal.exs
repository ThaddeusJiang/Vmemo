import Config

config :appsignal, :config,
  otp_app: :vmemo,
  name: "vmemo",
  push_api_key: "ce2c83ab-9fca-4022-88f2-fd04ac9e2b36",
  env: Mix.env()
