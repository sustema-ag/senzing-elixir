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

  fn get_and_clear_last_exception(env: beam.env) !beam.term {
      var slice = try beam.allocator.alloc(u8, 1024);
      defer beam.allocator.free(slice);

      var size: usize = @intCast(G2ConfigMgr.G2ConfigMgr_getLastException(slice.ptr, 1024));

      if (size == 0) {
          return beam.make(env, .unknown_error, .{});
      }

      // Size contains zero byte
      slice = try beam.allocator.realloc(slice, size - 1);

      var code = G2ConfigMgr.G2ConfigMgr_getLastExceptionCode();

      G2ConfigMgr.G2ConfigMgr_clearLastException();

      return beam.make(env, .{ code, slice }, .{});
  }

  fn resize_pointer(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
    _ = ptr;
    const newPtr = beam.allocator.alloc([*c]u8, size) catch return null;
    return @as(*anyopaque, @ptrCast(newPtr.ptr));
  }

  pub fn init(env: beam.env, name: []u8, ini_params: []u8, verbose_logging: bool) !beam.term {
    var g2_name = try beam.allocator.dupeZ(u8, name);
    var g2_ini_params = try beam.allocator.dupeZ(u8, ini_params);
    var g2_verbose_logging: i8 = if(verbose_logging) 1 else 0;

    if (G2ConfigMgr.G2ConfigMgr_init(g2_name, g2_ini_params, g2_verbose_logging) != 0) {
      var reason = try get_and_clear_last_exception(env);
      _ = G2ConfigMgr.G2ConfigMgr_destroy();
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .@"ok", .{});
  }

  pub fn destroy(env: beam.env) !beam.term {
    if(G2ConfigMgr.G2ConfigMgr_destroy() != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }
    return beam.make(env, .@"ok", .{});
  }

  pub fn add_config(env: beam.env, config: []u8, comment: []u8) !beam.term {
    var g2_config = try beam.allocator.dupeZ(u8, config);
    var g2_comment = try beam.allocator.dupeZ(u8, comment);
    var config_id: c_longlong = 0;

    if (G2ConfigMgr.G2ConfigMgr_addConfig(g2_config, g2_comment, &config_id) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", config_id}, .{});
  }

  pub fn get_config(env: beam.env, config_id: c_longlong) !beam.term {
    var bufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, bufSize);
    defer beam.allocator.free(initialResponseBuf);
    var responseBuf: [*c]u8 = initialResponseBuf.ptr;

    if (G2ConfigMgr.G2ConfigMgr_getConfig(config_id, &responseBuf, &bufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", responseBuf}, .{});
  }

  pub fn list_configs(env: beam.env) !beam.term {
    var bufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, bufSize);
    defer beam.allocator.free(initialResponseBuf);
    var responseBuf: [*c]u8 = initialResponseBuf.ptr;

    if (G2ConfigMgr.G2ConfigMgr_getConfigList(&responseBuf, &bufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", responseBuf}, .{});
  }

  pub fn get_default_config_id(env: beam.env) !beam.term {
    var config_id: c_longlong = 0;

    if (G2ConfigMgr.G2ConfigMgr_getDefaultConfigID(&config_id) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", config_id}, .{});
  }

  pub fn set_default_config_id(env: beam.env, config_id: c_longlong) !beam.term {
    if (G2ConfigMgr.G2ConfigMgr_setDefaultConfigID(config_id) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .@"ok", .{});
  }

  pub fn replace_default_config_id(env: beam.env, new_config_id: c_longlong, old_config_id: c_longlong) !beam.term {
    if (G2ConfigMgr.G2ConfigMgr_replaceDefaultConfigID(old_config_id, new_config_id) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .@"ok", .{});
  }
  """
end
