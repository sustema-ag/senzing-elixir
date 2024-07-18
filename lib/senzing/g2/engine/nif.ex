defmodule Senzing.G2.Engine.Nif do
  @moduledoc false

  use Senzing.Nif

  ~z"""
  const beam = @import("beam");
  const G2 = @cImport(@cInclude("libg2.h"));
  const std = @import("std");

  fn get_and_clear_last_exception(env: beam.env) !beam.term {
      var slice = try beam.allocator.alloc(u8, 1024);
      defer beam.allocator.free(slice);

      var size: usize = @intCast(G2.G2_getLastException(slice.ptr, 1024));

      if (size == 0) {
          return beam.make(env, .unknown_error, .{});
      }

      // Size contains zero byte
      slice = try beam.allocator.realloc(slice, size - 1);

      var code = G2.G2_getLastExceptionCode();

      G2.G2_clearLastException();

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

    if (G2.G2_init(g2_name, g2_ini_params, g2_verbose_logging) != 0) {
      var reason = try get_and_clear_last_exception(env);
      _ = G2.G2_destroy();
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .@"ok", .{});
  }

  pub fn init_with_config_id(env: beam.env, name: []u8, ini_params: []u8, config_id: i64, verbose_logging: bool) !beam.term {
    var g2_name = try beam.allocator.dupeZ(u8, name);
    var g2_ini_params = try beam.allocator.dupeZ(u8, ini_params);
    var g2_verbose_logging: i8 = if(verbose_logging) 1 else 0;

    if (G2.G2_initWithConfigID(g2_name, g2_ini_params, config_id, g2_verbose_logging) != 0) {
      var reason = try get_and_clear_last_exception(env);
      _ = G2.G2_destroy();
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .@"ok", .{});
  }

  pub fn reinit(env: beam.env, config_id: i64) !beam.term {
    if (G2.G2_reinit(config_id) != 0) {
      var reason = try get_and_clear_last_exception(env);
      _ = G2.G2_destroy();
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .@"ok", .{});
  }

  pub fn prime(env: beam.env) !beam.term {
    if (G2.G2_primeEngine() != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .@"ok", .{});
  }

  pub fn get_active_config_id(env: beam.env) !beam.term {
    var config_id: c_longlong = 0;
    if (G2.G2_getActiveConfigID(&config_id) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", config_id}, .{});
  }

  pub fn export_config(env: beam.env) !beam.term {
    var config_id: c_longlong = 0;

    var bufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, bufSize);
    defer beam.allocator.free(initialResponseBuf);
    var responseBuf: [*c]u8 = initialResponseBuf.ptr;

    if (G2.G2_exportConfigAndConfigID(&responseBuf, &bufSize, resize_pointer, &config_id) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", .{responseBuf, config_id}}, .{});
  }

  pub fn get_repository_last_modified(env: beam.env) !beam.term {
    var time: c_longlong = 0;
    if (G2.G2_getRepositoryLastModifiedTime(&time) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{.@"ok", time}, .{});
  }

  pub fn add_record(env: beam.env, dataSource: []u8, recordId: ?[]u8, record: []u8, loadId: ?[]u8, returnRecordId: bool, returnInfo: bool) !beam.term {
    var g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    var g2_record = try beam.allocator.dupeZ(u8, record);
    var g2_loadId = if (loadId) |id| try beam.allocator.dupeZ(u8, id) else try beam.allocator.dupeZ(u8, "");
    var g2_flags: c_longlong = 0; // Reserved for future use, not currently used

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    var recordIdBuf: [*c]u8 = null;
    var recordIdBufSize: usize = 256;
    var initialRecordIdBuf = try beam.allocator.alloc(u8, recordIdBufSize);
    defer beam.allocator.free(initialRecordIdBuf);
    recordIdBuf = initialRecordIdBuf.ptr;

    if (recordId) |id| {
      recordIdBuf = try beam.allocator.dupeZ(u8, id);
    }

    var success: c_longlong = -3;

    if (returnInfo) {
      if (recordId) |id| {
        var g2_recordId = try beam.allocator.dupeZ(u8, id);
        success = G2.G2_addRecordWithInfo(g2_dataSource, g2_recordId, g2_record, g2_loadId, g2_flags, &responseBuf, &responseBufSize, resize_pointer);
      } else {
        success = G2.G2_addRecordWithInfoWithReturnedRecordID(g2_dataSource, g2_record, g2_loadId, g2_flags, recordIdBuf, recordIdBufSize, &responseBuf, &responseBufSize, resize_pointer);
      }
    } else {
      if (recordId) |id| {
        var g2_recordId = try beam.allocator.dupeZ(u8, id);
        success = G2.G2_addRecord(g2_dataSource, g2_recordId, g2_record, g2_loadId);
      } else {
        success = G2.G2_addRecordWithReturnedRecordID(g2_dataSource, g2_record, g2_loadId, recordIdBuf, recordIdBufSize);
      }
    }

    if (success != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    if (returnInfo and returnRecordId) {
      return beam.make(env, .{ .ok, .{ recordIdBuf, responseBuf } }, .{});
    }
    if (returnInfo) {
      return beam.make(env, .{ .ok, .{ .nil, responseBuf } }, .{});
    }
    if (returnRecordId) {
      return beam.make(env, .{ .ok, .{ recordIdBuf, .nil } }, .{});
    }

    return beam.make(env, .ok, .{});
  }

  pub fn replace_record(env: beam.env, dataSource: []u8, recordId: []u8, record: []u8, loadId: ?[]u8, returnInfo: bool) !beam.term {
    var g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    var g2_recordId = try beam.allocator.dupeZ(u8, recordId);
    var g2_record = try beam.allocator.dupeZ(u8, record);
    var g2_loadId = if (loadId) |id| try beam.allocator.dupeZ(u8, id) else try beam.allocator.dupeZ(u8, "");
    var g2_flags: c_longlong = 0; // Reserved for future use, not currently used

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    var success: c_longlong = -3;

    if (returnInfo) {
      success = G2.G2_replaceRecordWithInfo(g2_dataSource, g2_recordId, g2_record, g2_loadId, g2_flags, &responseBuf, &responseBufSize, resize_pointer);
    } else {
      success = G2.G2_replaceRecord(g2_dataSource, g2_recordId, g2_record, g2_loadId);
    }

    if (success != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    if (returnInfo) {
      return beam.make(env, .{ .ok, responseBuf }, .{});
    }

    return beam.make(env, .ok, .{});
  }

  pub fn reevaluate_record(env: beam.env, dataSource: []u8, recordId: []u8, returnInfo: bool) !beam.term {
    var g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    var g2_recordId = try beam.allocator.dupeZ(u8, recordId);
    var g2_flags: c_longlong = 0; // Reserved for future use, not currently used

    if (returnInfo) {
      var responseBuf: [*c]u8 = null;
      var responseBufSize: usize = 1024;
      var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
      defer beam.allocator.free(initialResponseBuf);
      responseBuf = initialResponseBuf.ptr;

      if (G2.G2_reevaluateRecordWithInfo(g2_dataSource, g2_recordId, g2_flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
        var reason = try get_and_clear_last_exception(env);
        return beam.make_error_pair(env, reason, .{});
      }

      return beam.make(env, .{ .ok, responseBuf }, .{});
    } else {
      if (G2.G2_reevaluateRecord(g2_dataSource, g2_recordId, g2_flags) != 0) {
        var reason = try get_and_clear_last_exception(env);
        return beam.make_error_pair(env, reason, .{});
      }

      return beam.make(env, .ok, .{});
    }
  }

  pub fn reevaluate_entity(env: beam.env, entityId: c_longlong, returnInfo: bool) !beam.term {
    var g2_flags: c_longlong = 0; // Reserved for future use, not currently used

    if (returnInfo) {
      var responseBuf: [*c]u8 = null;
      var responseBufSize: usize = 1024;
      var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
      defer beam.allocator.free(initialResponseBuf);
      responseBuf = initialResponseBuf.ptr;

      if (G2.G2_reevaluateEntityWithInfo(entityId, g2_flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
        var reason = try get_and_clear_last_exception(env);
        return beam.make_error_pair(env, reason, .{});
      }

      return beam.make(env, .{ .ok, responseBuf }, .{});
    } else {
      if (G2.G2_reevaluateEntity(entityId, g2_flags) != 0) {
        var reason = try get_and_clear_last_exception(env);
        return beam.make_error_pair(env, reason, .{});
      }

      return beam.make(env, .ok, .{});
    }
  }

  pub fn count_redo_records(env: beam.env) !beam.term {
    const redoRecordCount = G2.G2_countRedoRecords();

    return beam.make(env, .{ .ok, redoRecordCount }, .{});
  }

  pub fn get_redo_record(env: beam.env) !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getRedoRecord(&responseBuf, &responseBufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{ .ok, responseBuf }, .{});
  }

  pub fn process_redo_record(env: beam.env, record: []u8, returnInfo: bool) !beam.term {
    var g2_record = try beam.allocator.dupeZ(u8, record);

    if (returnInfo) {
      var g2_flags: c_longlong = 0; // Reserved for future use, not currently used

      var responseBuf: [*c]u8 = null;
      var responseBufSize: usize = 1024;
      var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
      defer beam.allocator.free(initialResponseBuf);
      responseBuf = initialResponseBuf.ptr;

      if (G2.G2_processWithInfo(g2_record, g2_flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
        var reason = try get_and_clear_last_exception(env);
        return beam.make_error_pair(env, reason, .{});
      }

      return beam.make(env, .{ .ok, responseBuf }, .{});
    }

    if (G2.G2_process(g2_record) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .ok, .{});
  }

  pub fn process_next_redo_record(env: beam.env, returnInfo: bool) !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if(returnInfo) {
      var g2_flags: c_longlong = 0; // Reserved for future use, not currently used

      var infoBuf: [*c]u8 = null;
      var infoBufSize: usize = 1024;
      var initialInfoBuf = try beam.allocator.alloc(u8, infoBufSize);
      defer beam.allocator.free(initialInfoBuf);
      infoBuf = initialInfoBuf.ptr;

      if (G2.G2_processRedoRecordWithInfo(g2_flags, &responseBuf, &responseBufSize, &infoBuf, &infoBufSize, resize_pointer) != 0) {
        var reason = try get_and_clear_last_exception(env);
        return beam.make_error_pair(env, reason, .{});
      }

      return beam.make(env, .{ .ok, .{ responseBuf, infoBuf } }, .{});
    }

    if (G2.G2_processRedoRecord(&responseBuf, &responseBufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{ .ok, responseBuf }, .{});
  }

  pub fn delete_record(env: beam.env, dataSource: []u8, recordId: []u8, loadId: ?[]u8, withInfo: bool) !beam.term {
    var g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    var g2_recordId = try beam.allocator.dupeZ(u8, recordId);
    var g2_loadId = if (loadId) |id| try beam.allocator.dupeZ(u8, id) else try beam.allocator.dupeZ(u8, "");

    if (withInfo) {
      var g2_flags: c_longlong = 0; // Reserved for future use, not currently used

      var responseBuf: [*c]u8 = null;
      var responseBufSize: usize = 1024;
      var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
      defer beam.allocator.free(initialResponseBuf);
      responseBuf = initialResponseBuf.ptr;

      if (G2.G2_deleteRecordWithInfo(g2_dataSource, g2_recordId, g2_loadId, g2_flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
        var reason = try get_and_clear_last_exception(env);
        return beam.make_error_pair(env, reason, .{});
      }

      return beam.make(env, .{ .ok, responseBuf }, .{});
    }

    if (G2.G2_deleteRecord(g2_dataSource, g2_recordId, g2_loadId) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .ok, .{});
  }

  pub fn get_record(env: beam.env, dataSource: []u8, recordId: []u8, flags: c_longlong) !beam.term {
    var g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    var g2_recordId = try beam.allocator.dupeZ(u8, recordId);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getRecord_V2(g2_dataSource, g2_recordId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{ .ok, responseBuf }, .{});
  }

  pub fn get_entity_by_record_id(env: beam.env, dataSource: []u8, recordId: []u8, flags: c_longlong) !beam.term {
    var g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    var g2_recordId = try beam.allocator.dupeZ(u8, recordId);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getEntityByRecordID_V2(g2_dataSource, g2_recordId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{ .ok, responseBuf }, .{});
  }

  pub fn get_entity(env: beam.env, entityId: c_longlong, flags: c_longlong) !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getEntityByEntityID_V2(entityId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{ .ok, responseBuf }, .{});
  }

  pub fn get_virtual_entity(env: beam.env, recordIds: []u8, flags: c_longlong) !beam.term {
    var g2_recordIds = try beam.allocator.dupeZ(u8, recordIds);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getVirtualEntityByRecordID_V2(g2_recordIds, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{ .ok, responseBuf }, .{});
  }

  pub fn search_by_attributes(env: beam.env, attributes: []u8, searchProfile: []u8, flags: c_longlong) !beam.term {
    var g2_attributes = try beam.allocator.dupeZ(u8, attributes);
    var g2_searchProfile = try beam.allocator.dupeZ(u8, searchProfile);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    var initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_searchByAttributes_V3(g2_attributes, g2_searchProfile, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }

    return beam.make(env, .{ .ok, responseBuf }, .{});
  }

  pub fn destroy(env: beam.env) !beam.term {
    if(G2.G2_destroy() != 0) {
      var reason = try get_and_clear_last_exception(env);
      return beam.make_error_pair(env, reason, .{});
    }
    return beam.make(env, .@"ok", .{});
  }
  """
end
