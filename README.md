# Senzing Elixir NIF

[![Main Branch](https://github.com/sustema-ag/senzing-elixir/actions/workflows/branch_main.yml/badge.svg?branch=main)](https://github.com/sustema-ag/senzing-elixir/actions/workflows/branch_main.yml)
[![Module Version](https://img.shields.io/hexpm/v/senzing.svg)](https://hex.pm/packages/senzing)
[![Total Download](https://img.shields.io/hexpm/dt/senzing.svg)](https://hex.pm/packages/senzing)
[![License](https://img.shields.io/hexpm/l/senzing.svg)](https://github.com/sustema-ag/senzing-elixir/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/sustema-ag/senzing-elixir.svg)](https://github.com/sustema-ag/senzing-elixir/commits/master)
[![Coverage Status](https://coveralls.io/repos/github/sustema-ag/senzing-elixir/badge.svg?branch=main)](https://coveralls.io/github/sustema-ag/senzing-elixir?branch=main)

<!-- MDOC -->

Elixir NIF for [Senzing©](https://senzing.com/) Entity Resolution API.

<br clear="left"/>

<picture style="margin-right: 15px; float: left;">
  <source
    media="(prefers-color-scheme: dark)"
    srcset="assets/logo-full-dark.svg"
    width="170px"
    align="left"
  />
  <source
    media="(prefers-color-scheme: light)"
    srcset="assets/logo-full-light.svg"
    width="170px"
    align="left"
  />
  <img
    src="assets/logo-full-light.svg"
    alt="Sustema Logo"
    width="170px"
    align="left"
  />
</picture>

This library was developed and is provided at no cost by
[Sustema AG](https://sustema.io), a company dedicated to fostering innovation
and supporting the open-source community.

<br clear="left"/>

## Senzing Entity Resolution API

Senzing software makes it easy and affordable to add advanced entity resolution
capabilities to your enterprise systems and commercial applications.

The Senzing API provides highly accurate data matching and relationship
detection to improve analytics, insights and outcomes with no entity resolution
experts required.

You can be up and running in minutes and deploy into production in weeks.

<https://senzing.com/entity-resolution-buyers-guide/>

## Installation

To be able to run this package, Senzing has to be installed by following the
Linux setup guide: <https://docs.senzing.com/quickstart/quickstart_api/>

Especially make sure to load all environment variables as described in the
[Configure Environment](https://docs.senzing.com/quickstart/quickstart_api/)
section.

The package can be installed by adding `senzing` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:senzing, "~> 0.1.0"}
  ]
end
```

## Docs

* NIF: <https://hexdocs.pm/senzing>
* Senzing Developer Docs: <https://senzing.com/developer/>
