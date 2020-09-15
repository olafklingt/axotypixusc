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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      # {:portmidi, git: "https://github.com/zenwerk/ex-portmidi.git", override: true},
      # {:portmidi, git: "https://github.com/Kovak/ex-portmidi", override: true},
      # {:sc_ex_scsynth, git: "https://github.com/olafklingt/sc_ex_scsynth"}
      # {:sc_ex_synthdef, git: "https://github.com/olafklingt/sc_ex_synthdef"}
      # {:sc_ex_scsynth, path: "../../github/sc_ex_scsynth/"},
      {:sc_ex_scsoundserver, path: "../../github/sc_ex_scsoundserver/"},
      {:sc_ex_synthdef, path: "../../github/sc_ex_synthdef/"},
      {:portmidi, path: "../../github/ex-portmidi/"}
    ]
  end
end
