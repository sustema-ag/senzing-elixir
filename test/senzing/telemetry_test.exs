defmodule Senzing.TelemetryTest do
  use Senzing.G2.EngineCase, async: false

  test "polling events are triggered" do
    ref =
      :telemetry_test.attach_event_handlers(self(), [
        [:senzing, :g2, :engine, :workload],
        [:senzing, :g2, :engine, :threads],
        [:senzing, :g2, :engine, :redo_records],
        [:senzing, :g2, :engine, :config]
      ])

    assert_receive {[:senzing, :g2, :engine, :workload], ^ref,
                    %{
                      added_records: 0,
                      deleted_records: 0,
                      reevaluations: 0,
                      repaired_entities: 0
                    }, %{api_version: "3." <> _rest}},
                   to_timeout(second: 10)

    assert_receive {[:senzing, :g2, :engine, :threads], ^ref,
                    %{
                      active: _,
                      data_latch_contention: _,
                      idle: _,
                      loader: _,
                      obs_ent_contention: _,
                      res_ent_contention: _,
                      resolver: _,
                      scoring: _,
                      sql_executing: _
                    }, %{api_version: "3." <> _rest}},
                   to_timeout(second: 10)

    assert_receive {[:senzing, :g2, :engine, :redo_records], ^ref, %{count: 0}, %{}},
                   to_timeout(second: 10)

    assert_receive {[:senzing, :g2, :engine, :config], ^ref, %{}, %{config: _}},
                   to_timeout(second: 10)
  end
end
