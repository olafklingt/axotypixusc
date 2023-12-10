defmodule Axotypixusc.MixProject do
  use Mix.Project

  def project do
    [
      app: :axotypixusc,
      version: "0.1.0",
      elixir: "~> 1.10",
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [:sc_ex_scsoundserver, :sc_ex_synthdef, :sc_ex_lib]
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
      # warning: UGen.mul/2 defined in application :sc_ex_synthdef is used by the current application but the current application does not directly depend on :sc_ex_synthdef. To fix this, you must do one of:
      #
      # 1. If :sc_ex_synthdef is part of Erlang/Elixir, you must include it under :extra_applications inside "def application" in your mix.exs
      #
      # 2. If :sc_ex_synthdef is a dependency, make sure it is listed under "def deps" in your mix.exs
      #
      # 3. In case you don't want to add a requirement to :sc_ex_synthdef, you may optionally skip this warning by adding [xref: [exclude: UGen] to your "def project" in mix.exs

      # this warning should not be there maybe its a bug in mix or elixir or i misunderstand the error message
      # anyway adding dependencies to applications solves the problem :-/
      applications: [:portmidi, :sc_ex_lib, :sc_ex_scsoundserver, :sc_ex_synthdef]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  def deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},

      {:portmidi, git: "https://github.com/olafklingt/ex-portmidi"},
      {:sc_ex_lib, git: "https://github.com/olafklingt/sc_ex_lib"},
      #{:sc_ex_scsoundserver, git: "https://github.com/olafklingt/sc_ex_scsoundserver"},
      {:sc_ex_synthdef, git: "https://github.com/olafklingt/sc_ex_synthdef"},

      #{:portmidi, path: "../../github/ex-portmidi/"},
      #{:sc_ex_lib, path: "../../github/sc_ex_lib/"},
      {:sc_ex_scsoundserver, path: "../sc_ex_scsoundserver/", override: true},
      #{:sc_ex_synthdef, path: "../../github/sc_ex_synthdef/"}
    ]
  end
end
