defmodule Axotypixusc.MixProject do
  use Mix.Project

  def project do
    [
      app: :axotypixusc,
      version: "0.1.0",
      elixir: "~> 1.10",
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [:sc_ex_scsoundserver, :sc_ex_synthdef]
      ],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Axotypixusc, []},
      extra_applications: [:logger],
      applications: [:portmidi]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:portmidi, git: "https://github.com/olafklingt/ex-portmidi"},
      {:sc_ex_scsoundserver, git: "https://github.com/olafklingt/sc_ex_scsoundserver"},
      {:sc_ex_synthdef, git: "https://github.com/olafklingt/sc_ex_synthdef"}
      # {:sc_ex_scsoundserver, path: "../../github/sc_ex_scsoundserver/"},
      # {:sc_ex_synthdef, path: "../../github/sc_ex_synthdef/"},
      # {:portmidi, path: "../../github/ex-portmidi/"}
    ]
  end
end
