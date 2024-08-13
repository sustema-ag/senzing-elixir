defmodule Senzing.G2.ConfigManager.Nif do
  @moduledoc false

  use Senzing.Nif,
    nifs: [
      init: [:dirty_io],
      destroy: [:dirty_io],
      add_config: [:dirty_io],
      get_config: [:dirty_io],
      list_configs: [:dirty_io],
      get_default_config_id: [:dirty_io],
      set_default_config_id: [:dirty_io],
      replace_default_config_id: [:dirty_io]
    ]

  ~z"""
  const beam = @import("beam");
  const G2ConfigMgr = @cImport(@cInclude("libg2configmgr.h"));

  fn get_and_clear_last_exception() !beam.term {
      var slice = try beam.allocator.alloc(u8, 1024);
      defer beam.allocator.free(slice);

      const size: usize = @intCast(G2ConfigMgr.G2ConfigMgr_getLastException(slice.ptr, 1024));

      if (size == 0) {
          return beam.make(.unknown_error, .{});
      }

      // Size contains zero byte
      slice = try beam.allocator.realloc(slice, size - 1);

      const code = G2ConfigMgr.G2ConfigMgr_getLastExceptionCode();

      G2ConfigMgr.G2ConfigMgr_clearLastException();

      return beam.make(.{ code, slice }, .{});
  }

  fn resize_pointer(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
    _ = ptr;
    const newPtr = beam.allocator.alloc([*c]u8, size) catch return null;
    return @as(*anyopaque, @ptrCast(newPtr.ptr));
  }

  pub fn init(name: []u8, ini_params: []u8, verbose_logging: bool) !beam.term {
    const g2_name = try beam.allocator.dupeZ(u8, name);
    const g2_ini_params = try beam.allocator.dupeZ(u8, ini_params);
    const g2_verbose_logging: i8 = if(verbose_logging) 1 else 0;

    if (G2ConfigMgr.G2ConfigMgr_init(g2_name, g2_ini_params, g2_verbose_logging) != 0) {
      const reason = try get_and_clear_last_exception();
      _ = G2ConfigMgr.G2ConfigMgr_destroy();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.@"ok", .{});
  }

  pub fn destroy() !beam.term {
    if(G2ConfigMgr.G2ConfigMgr_destroy() != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }
    return beam.make(.@"ok", .{});
  }

  pub fn add_config(config: []u8, comment: []u8) !beam.term {
    const g2_config = try beam.allocator.dupeZ(u8, config);
    const g2_comment = try beam.allocator.dupeZ(u8, comment);
    var config_id: c_longlong = 0;

    if (G2ConfigMgr.G2ConfigMgr_addConfig(g2_config, g2_comment, &config_id) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{.@"ok", config_id}, .{});
  }

  pub fn get_config(config_id: c_longlong) !beam.term {
    var bufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, bufSize);
    defer beam.allocator.free(initialResponseBuf);
    var responseBuf: [*c]u8 = initialResponseBuf.ptr;

    if (G2ConfigMgr.G2ConfigMgr_getConfig(config_id, &responseBuf, &bufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{.@"ok", responseBuf}, .{});
  }

  pub fn list_configs() !beam.term {
    var bufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, bufSize);
    defer beam.allocator.free(initialResponseBuf);
    var responseBuf: [*c]u8 = initialResponseBuf.ptr;

    if (G2ConfigMgr.G2ConfigMgr_getConfigList(&responseBuf, &bufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{.@"ok", responseBuf}, .{});
  }

  pub fn get_default_config_id() !beam.term {
    var config_id: c_longlong = 0;

    if (G2ConfigMgr.G2ConfigMgr_getDefaultConfigID(&config_id) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{.@"ok", config_id}, .{});
  }

  pub fn set_default_config_id(config_id: c_longlong) !beam.term {
    if (G2ConfigMgr.G2ConfigMgr_setDefaultConfigID(config_id) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.@"ok", .{});
  }

  pub fn replace_default_config_id(new_config_id: c_longlong, old_config_id: c_longlong) !beam.term {
    if (G2ConfigMgr.G2ConfigMgr_replaceDefaultConfigID(old_config_id, new_config_id) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.@"ok", .{});
  }
  """
end
