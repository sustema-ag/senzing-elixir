defmodule Senzing.G2.Config.Nif do
  @moduledoc false

  use Senzing.Nif, resources: [:ConfigResource]

  ~z"""
  const beam = @import("beam");
  const G2Config = @cImport(@cInclude("libg2config.h"));
  const root = @import("root");

  pub const ConfigResource = beam.Resource(G2Config.ConfigHandle, root, .{});

  fn get_and_clear_last_exception(env: beam.env) !beam.term {
      var slice = try beam.allocator.alloc(u8, 1024);
      defer beam.allocator.free(slice);

      var size: usize = @intCast(G2Config.G2Config_getLastException(slice.ptr, 1024));

      if (size == 0) {
          return beam.make(env, .unknown_error, .{});
      }

      // Size contains zero byte
      slice = try beam.allocator.realloc(slice, size - 1);

      var code = G2Config.G2Config_getLastExceptionCode();

      G2Config.G2Config_clearLastException();

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

    if (G2Config.G2Config_init(g2_name, g2_ini_params, g2_verbose_logging) != 0) {
      var reason = try get_and_clear_last_exception(env);
      _ = G2Config.G2Config_destroy();
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .@"ok", .{});
  }

  pub fn create(env: beam.env) !beam.term {
    var handle: G2Config.ConfigHandle = null;

    if(G2Config.G2Config_create(&handle) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    const resource = try ConfigResource.create(handle, .{});

    return beam.make(env, .{.@"ok", resource}, .{});
  }

  pub fn save(env: beam.env, config: beam.term) !beam.term {
    const res = try beam.get(ConfigResource, env, config, .{});
    const handle = res.unpack();

    var bufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, bufSize);
    defer beam.allocator.free(initialResponseBuf);
    var responseBuf: [*c]u8 = initialResponseBuf.ptr;

    if(G2Config.G2Config_save(handle, &responseBuf, &bufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", responseBuf}, .{});
  }

  pub fn load_it(env: beam.env, json: []u8) !beam.term {
    var handle: G2Config.ConfigHandle = null;
    var g2_json = try beam.allocator.dupeZ(u8, json);

    if(G2Config.G2Config_load(g2_json, &handle) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    const resource = try ConfigResource.create(handle, .{});

    return beam.make(env, .{.@"ok", resource}, .{});
  }

  pub fn list_data_sources(env: beam.env, config: beam.term) !beam.term {
    const res = try beam.get(ConfigResource, env, config, .{});
    const handle = res.unpack();

    var bufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, bufSize);
    defer beam.allocator.free(initialResponseBuf);
    var responseBuf: [*c]u8 = initialResponseBuf.ptr;

    if(G2Config.G2Config_listDataSources(handle, &responseBuf, &bufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", responseBuf}, .{});
  }

  pub fn add_data_source(env: beam.env, config: beam.term, data_source: []u8) !beam.term {
    const res = try beam.get(ConfigResource, env, config, .{});
    const handle = res.unpack();
    var g2_data_source = try beam.allocator.dupeZ(u8, data_source);

    var bufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, bufSize);
    defer beam.allocator.free(initialResponseBuf);
    var responseBuf: [*c]u8 = initialResponseBuf.ptr;

    if(G2Config.G2Config_addDataSource(handle, g2_data_source, &responseBuf, &bufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", responseBuf}, .{});
  }

  pub fn delete_data_source(env: beam.env, config: beam.term, data_source: []u8) !beam.term {
    const res = try beam.get(ConfigResource, env, config, .{});
    const handle = res.unpack();
    var g2_data_source = try beam.allocator.dupeZ(u8, data_source);

    if(G2Config.G2Config_deleteDataSource(handle, g2_data_source) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .@"ok", .{});
  }

  pub fn close(env: beam.env, config: beam.term) !beam.term {
    const res = try beam.get(ConfigResource, env, config, .{});
    var handle = res.unpack();

    if(G2Config.G2Config_close(handle) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    res.update(null);

    return beam.make(env, .@"ok", .{});
  }

  pub fn destroy(env: beam.env) !beam.term {
    if(G2Config.G2Config_destroy() != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }
    return beam.make(env, .@"ok", .{});
  }
  """
end
