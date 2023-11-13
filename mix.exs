defmodule ExNet.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_net,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      # 引导mix同时执行make clean
      make_clean: ["clean"],
      compilers: [:elixir_make] ++ Mix.compilers(),
      # 不启动实际网卡内容单独测试
      aliases: [test: "test --no-start"],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExNet.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.7.7", runtime: false}
    ]
  end
end
