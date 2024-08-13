defmodule Senzing.G2.Engine.Nif do
  @moduledoc false

  use Senzing.Nif,
    resources: [:ExportResource],
    nifs: [
      init: [:dirty_io],
      init_with_config_id: [:dirty_io],
      reinit: [:dirty_io],
      prime: [:dirty_io],
      get_active_config_id: [:dirty_io],
      export_config: [:dirty_io],
      get_repository_last_modified: [:dirty_io],
      add_record: [:dirty_io],
      replace_record: [:dirty_io],
      reevaluate_record: [:dirty_io],
      reevaluate_entity: [:dirty_io],
      count_redo_records: [:dirty_io],
      get_redo_record: [:dirty_io],
      process_redo_record: [:dirty_io],
      process_next_redo_record: [:dirty_io],
      delete_record: [:dirty_io],
      get_record: [:dirty_io],
      get_entity_by_record_id: [:dirty_io],
      get_entity: [:dirty_io],
      get_virtual_entity: [:dirty_io],
      search_by_attributes: [:dirty_io],
      find_path_by_entity_id: [:dirty_io],
      find_path_by_record_id: [:dirty_io],
      find_network_by_entity_id: [:dirty_io],
      find_network_by_record_id: [:dirty_io],
      why_records: [:dirty_io],
      why_entity_by_record_id: [:dirty_io],
      why_entity_by_entity_id: [:dirty_io],
      why_entities: [:dirty_io],
      how_entity_by_entity_id: [:dirty_io],
      export_csv_entity_report: [:dirty_io],
      export_json_entity_report: [:dirty_io],
      export_fetch_next: [:dirty_io],
      export_close: [:dirty_io],
      purge_repository: [:dirty_io],
      stats: [:dirty_io],
      destroy: [:dirty_io]
    ]

  ~z"""
  const beam = @import("beam");
  const G2 = @cImport(@cInclude("libg2.h"));
  const root = @import("root");

  pub const ExportResource = beam.Resource(G2.ExportHandle, root, .{});

  fn get_and_clear_last_exception() !beam.term {
      var slice = try beam.allocator.alloc(u8, 1024);
      defer beam.allocator.free(slice);

      const size: usize = @intCast(G2.G2_getLastException(slice.ptr, 1024));

      if (size == 0) {
          return beam.make(.unknown_error, .{});
      }

      // Size contains zero byte
      slice = try beam.allocator.realloc(slice, size - 1);

      const code = G2.G2_getLastExceptionCode();

      G2.G2_clearLastException();

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

    if (G2.G2_init(g2_name, g2_ini_params, g2_verbose_logging) != 0) {
      const reason = try get_and_clear_last_exception();
      _ = G2.G2_destroy();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.@"ok", .{});
  }

  pub fn init_with_config_id(name: []u8, ini_params: []u8, config_id: i64, verbose_logging: bool) !beam.term {
    const g2_name = try beam.allocator.dupeZ(u8, name);
    const g2_ini_params = try beam.allocator.dupeZ(u8, ini_params);
    const g2_verbose_logging: i8 = if(verbose_logging) 1 else 0;

    if (G2.G2_initWithConfigID(g2_name, g2_ini_params, config_id, g2_verbose_logging) != 0) {
      const reason = try get_and_clear_last_exception();
      _ = G2.G2_destroy();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.@"ok", .{});
  }

  pub fn reinit(config_id: i64) !beam.term {
    if (G2.G2_reinit(config_id) != 0) {
      const reason = try get_and_clear_last_exception();
      _ = G2.G2_destroy();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.@"ok", .{});
  }

  pub fn prime() !beam.term {
    if (G2.G2_primeEngine() != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.@"ok", .{});
  }

  pub fn get_active_config_id() !beam.term {
    var config_id: c_longlong = 0;
    if (G2.G2_getActiveConfigID(&config_id) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{.@"ok", config_id}, .{});
  }

  pub fn export_config() !beam.term {
    var config_id: c_longlong = 0;

    var bufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, bufSize);
    defer beam.allocator.free(initialResponseBuf);
    var responseBuf: [*c]u8 = initialResponseBuf.ptr;

    if (G2.G2_exportConfigAndConfigID(&responseBuf, &bufSize, resize_pointer, &config_id) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{.@"ok", .{responseBuf, config_id}}, .{});
  }

  pub fn get_repository_last_modified() !beam.term {
    var time: c_longlong = 0;
    if (G2.G2_getRepositoryLastModifiedTime(&time) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{.@"ok", time}, .{});
  }

  pub fn add_record(dataSource: []u8, recordId: ?[]u8, record: []u8, loadId: ?[]u8, returnRecordId: bool, returnInfo: bool) !beam.term {
    const g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    const g2_record = try beam.allocator.dupeZ(u8, record);
    const g2_loadId = if (loadId) |id| try beam.allocator.dupeZ(u8, id) else try beam.allocator.dupeZ(u8, "");
    const g2_flags: c_longlong = 0; // Reserved for future use, not currently used

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    var recordIdBuf: [*c]u8 = null;
    const recordIdBufSize: usize = 256;
    const initialRecordIdBuf = try beam.allocator.alloc(u8, recordIdBufSize);
    defer beam.allocator.free(initialRecordIdBuf);
    recordIdBuf = initialRecordIdBuf.ptr;

    if (recordId) |id| {
      recordIdBuf = try beam.allocator.dupeZ(u8, id);
    }

    var success: c_longlong = -3;

    if (returnInfo) {
      if (recordId) |id| {
        const g2_recordId = try beam.allocator.dupeZ(u8, id);
        success = G2.G2_addRecordWithInfo(g2_dataSource, g2_recordId, g2_record, g2_loadId, g2_flags, &responseBuf, &responseBufSize, resize_pointer);
      } else {
        success = G2.G2_addRecordWithInfoWithReturnedRecordID(g2_dataSource, g2_record, g2_loadId, g2_flags, recordIdBuf, recordIdBufSize, &responseBuf, &responseBufSize, resize_pointer);
      }
    } else {
      if (recordId) |id| {
        const g2_recordId = try beam.allocator.dupeZ(u8, id);
        success = G2.G2_addRecord(g2_dataSource, g2_recordId, g2_record, g2_loadId);
      } else {
        success = G2.G2_addRecordWithReturnedRecordID(g2_dataSource, g2_record, g2_loadId, recordIdBuf, recordIdBufSize);
      }
    }

    if (success != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    if (returnInfo and returnRecordId) {
      return beam.make(.{ .ok, .{ recordIdBuf, responseBuf } }, .{});
    }
    if (returnInfo) {
      return beam.make(.{ .ok, .{ .nil, responseBuf } }, .{});
    }
    if (returnRecordId) {
      return beam.make(.{ .ok, .{ recordIdBuf, .nil } }, .{});
    }

    return beam.make(.ok, .{});
  }

  pub fn replace_record(dataSource: []u8, recordId: []u8, record: []u8, loadId: ?[]u8, returnInfo: bool) !beam.term {
    const g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    const g2_recordId = try beam.allocator.dupeZ(u8, recordId);
    const g2_record = try beam.allocator.dupeZ(u8, record);
    const g2_loadId = if (loadId) |id| try beam.allocator.dupeZ(u8, id) else try beam.allocator.dupeZ(u8, "");
    const g2_flags: c_longlong = 0; // Reserved for future use, not currently used

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    var success: c_longlong = -3;

    if (returnInfo) {
      success = G2.G2_replaceRecordWithInfo(g2_dataSource, g2_recordId, g2_record, g2_loadId, g2_flags, &responseBuf, &responseBufSize, resize_pointer);
    } else {
      success = G2.G2_replaceRecord(g2_dataSource, g2_recordId, g2_record, g2_loadId);
    }

    if (success != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    if (returnInfo) {
      return beam.make(.{ .ok, responseBuf }, .{});
    }

    return beam.make(.ok, .{});
  }

  pub fn reevaluate_record(dataSource: []u8, recordId: []u8, returnInfo: bool) !beam.term {
    const g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    const g2_recordId = try beam.allocator.dupeZ(u8, recordId);
    const g2_flags: c_longlong = 0; // Reserved for future use, not currently used

    if (returnInfo) {
      var responseBuf: [*c]u8 = null;
      var responseBufSize: usize = 1024;
      const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
      defer beam.allocator.free(initialResponseBuf);
      responseBuf = initialResponseBuf.ptr;

      if (G2.G2_reevaluateRecordWithInfo(g2_dataSource, g2_recordId, g2_flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
        const reason = try get_and_clear_last_exception();
        return beam.make_error_pair(reason, .{});
      }

      return beam.make(.{ .ok, responseBuf }, .{});
    } else {
      if (G2.G2_reevaluateRecord(g2_dataSource, g2_recordId, g2_flags) != 0) {
        const reason = try get_and_clear_last_exception();
        return beam.make_error_pair(reason, .{});
      }

      return beam.make(.ok, .{});
    }
  }

  pub fn reevaluate_entity(entityId: c_longlong, returnInfo: bool) !beam.term {
    const g2_flags: c_longlong = 0; // Reserved for future use, not currently used

    if (returnInfo) {
      var responseBuf: [*c]u8 = null;
      var responseBufSize: usize = 1024;
      const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
      defer beam.allocator.free(initialResponseBuf);
      responseBuf = initialResponseBuf.ptr;

      const result = G2.G2_reevaluateEntityWithInfo(entityId, g2_flags, &responseBuf, &responseBufSize, resize_pointer);

      if (result != 0) {
        const reason = try get_and_clear_last_exception();
        return beam.make_error_pair(reason, .{});
      }

      return beam.make(.{ .ok, responseBuf }, .{});
    } else {
      if (G2.G2_reevaluateEntity(entityId, g2_flags) != 0) {
        const reason = try get_and_clear_last_exception();
        return beam.make_error_pair(reason, .{});
      }

      return beam.make(.ok, .{});
    }
  }

  pub fn count_redo_records() !beam.term {
    const redoRecordCount = G2.G2_countRedoRecords();

    return beam.make(.{ .ok, redoRecordCount }, .{});
  }

  pub fn get_redo_record() !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getRedoRecord(&responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn process_redo_record(record: []u8, returnInfo: bool) !beam.term {
    const g2_record = try beam.allocator.dupeZ(u8, record);

    if (returnInfo) {
      const g2_flags: c_longlong = 0; // Reserved for future use, not currently used

      var responseBuf: [*c]u8 = null;
      var responseBufSize: usize = 1024;
      const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
      defer beam.allocator.free(initialResponseBuf);
      responseBuf = initialResponseBuf.ptr;

      if (G2.G2_processWithInfo(g2_record, g2_flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
        const reason = try get_and_clear_last_exception();
        return beam.make_error_pair(reason, .{});
      }

      return beam.make(.{ .ok, responseBuf }, .{});
    }

    if (G2.G2_process(g2_record) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.ok, .{});
  }

  pub fn process_next_redo_record(returnInfo: bool) !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if(returnInfo) {
      const g2_flags: c_longlong = 0; // Reserved for future use, not currently used

      var infoBuf: [*c]u8 = null;
      var infoBufSize: usize = 1024;
      const initialInfoBuf = try beam.allocator.alloc(u8, infoBufSize);
      defer beam.allocator.free(initialInfoBuf);
      infoBuf = initialInfoBuf.ptr;

      if (G2.G2_processRedoRecordWithInfo(g2_flags, &responseBuf, &responseBufSize, &infoBuf, &infoBufSize, resize_pointer) != 0) {
        const reason = try get_and_clear_last_exception();
        return beam.make_error_pair(reason, .{});
      }

      return beam.make(.{ .ok, .{ responseBuf, infoBuf } }, .{});
    }

    if (G2.G2_processRedoRecord(&responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn delete_record(dataSource: []u8, recordId: []u8, loadId: ?[]u8, withInfo: bool) !beam.term {
    const g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    const g2_recordId = try beam.allocator.dupeZ(u8, recordId);
    const g2_loadId = if (loadId) |id| try beam.allocator.dupeZ(u8, id) else try beam.allocator.dupeZ(u8, "");

    if (withInfo) {
      const g2_flags: c_longlong = 0; // Reserved for future use, not currently used

      var responseBuf: [*c]u8 = null;
      var responseBufSize: usize = 1024;
      const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
      defer beam.allocator.free(initialResponseBuf);
      responseBuf = initialResponseBuf.ptr;

      if (G2.G2_deleteRecordWithInfo(g2_dataSource, g2_recordId, g2_loadId, g2_flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
        const reason = try get_and_clear_last_exception();
        return beam.make_error_pair(reason, .{});
      }

      return beam.make(.{ .ok, responseBuf }, .{});
    }

    if (G2.G2_deleteRecord(g2_dataSource, g2_recordId, g2_loadId) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.ok, .{});
  }

  pub fn get_record(dataSource: []u8, recordId: []u8, flags: c_longlong) !beam.term {
    const g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    const g2_recordId = try beam.allocator.dupeZ(u8, recordId);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getRecord_V2(g2_dataSource, g2_recordId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn get_entity_by_record_id(dataSource: []u8, recordId: []u8, flags: c_longlong) !beam.term {
    const g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);
    const g2_recordId = try beam.allocator.dupeZ(u8, recordId);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getEntityByRecordID_V2(g2_dataSource, g2_recordId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn get_entity(entityId: c_longlong, flags: c_longlong) !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getEntityByEntityID_V2(entityId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn get_virtual_entity(recordIds: []u8, flags: c_longlong) !beam.term {
    const g2_recordIds = try beam.allocator.dupeZ(u8, recordIds);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_getVirtualEntityByRecordID_V2(g2_recordIds, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn search_by_attributes(attributes: []u8, searchProfile: []u8, flags: c_longlong) !beam.term {
    const g2_attributes = try beam.allocator.dupeZ(u8, attributes);
    const g2_searchProfile = try beam.allocator.dupeZ(u8, searchProfile);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_searchByAttributes_V3(g2_attributes, g2_searchProfile, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn find_path_by_entity_id(startEntityId: c_longlong, endEntityId: c_longlong, maxDegree: c_longlong, flags: c_longlong, exclude: ?[]u8, includedDataSources: ?[]u8) !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    var success: c_longlong = -3;

    if(includedDataSources) |dataSources| {
      const g2_include = try beam.allocator.dupeZ(u8, dataSources);
      const g2_excluded = if (exclude) |excluded| try beam.allocator.dupeZ(u8, excluded) else try beam.allocator.dupeZ(u8, "{\"RECORDS\":[]}");

      success = G2.G2_findPathIncludingSourceByEntityID_V2(startEntityId, endEntityId, maxDegree, g2_excluded, g2_include, flags, &responseBuf, &responseBufSize, resize_pointer);
    } else if (exclude) |excludeIds| {
      const g2_exclude = try beam.allocator.dupeZ(u8, excludeIds);
      success = G2.G2_findPathExcludingByEntityID_V2(startEntityId, endEntityId, maxDegree, g2_exclude, flags, &responseBuf, &responseBufSize, resize_pointer);
    } else {
      success = G2.G2_findPathByEntityID_V2(startEntityId, endEntityId, maxDegree, flags, &responseBuf, &responseBufSize, resize_pointer);
    }

    if (success != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn find_path_by_record_id(startRecordId: []u8, startRecordDataSource: []u8, endRecordId: []u8, endRecordDataSource: []u8, maxDegree: c_longlong, flags: c_longlong, exclude: ?[]u8, includedDataSources: ?[]u8) !beam.term {
    const g2_startRecordId = try beam.allocator.dupeZ(u8, startRecordId);
    const g2_startRecordDataSource = try beam.allocator.dupeZ(u8, startRecordDataSource);
    const g2_endRecordId = try beam.allocator.dupeZ(u8, endRecordId);
    const g2_endRecordDataSource = try beam.allocator.dupeZ(u8, endRecordDataSource);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    var success: c_longlong = -3;

    if(includedDataSources) |dataSources| {
      const g2_include = try beam.allocator.dupeZ(u8, dataSources);
      const g2_excluded = if (exclude) |excluded| try beam.allocator.dupeZ(u8, excluded) else try beam.allocator.dupeZ(u8, "{\"RECORDS\":[]}");

      success = G2.G2_findPathIncludingSourceByRecordID_V2(g2_startRecordDataSource, g2_startRecordId, g2_endRecordDataSource, g2_endRecordId, maxDegree, g2_excluded, g2_include, flags, &responseBuf, &responseBufSize, resize_pointer);
    } else if (exclude) |excludeIds| {
      const g2_exclude = try beam.allocator.dupeZ(u8, excludeIds);
      success = G2.G2_findPathExcludingByRecordID_V2(g2_startRecordDataSource, g2_startRecordId, g2_endRecordDataSource, g2_endRecordId, maxDegree, g2_exclude, flags, &responseBuf, &responseBufSize, resize_pointer);
    } else {
      success = G2.G2_findPathByRecordID_V2(g2_startRecordDataSource, g2_startRecordId, g2_endRecordDataSource, g2_endRecordId, maxDegree, flags, &responseBuf, &responseBufSize, resize_pointer);
    }

    if (success != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn find_network_by_entity_id(entityIds: []u8, maxDegree: c_longlong, buildoutDegree: c_longlong, maxEntities: c_longlong, flags: c_longlong) !beam.term {
    const g2_entityIds = try beam.allocator.dupeZ(u8, entityIds);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_findNetworkByEntityID_V2(g2_entityIds, maxDegree, buildoutDegree, maxEntities, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn find_network_by_record_id(recordIds: []u8, maxDegree: c_longlong, buildoutDegree: c_longlong, maxEntities: c_longlong, flags: c_longlong) !beam.term {
    const g2_recordIds = try beam.allocator.dupeZ(u8, recordIds);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_findNetworkByRecordID_V2(g2_recordIds, maxDegree, buildoutDegree, maxEntities, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn why_records(leftRecordId: []u8, leftDataSource: []u8, rightRecordId: []u8, rightDataSource: []u8, flags: c_longlong) !beam.term {
    const g2_leftRecordId = try beam.allocator.dupeZ(u8, leftRecordId);
    const g2_leftDataSource = try beam.allocator.dupeZ(u8, leftDataSource);
    const g2_rightRecordId = try beam.allocator.dupeZ(u8, rightRecordId);
    const g2_rightDataSource = try beam.allocator.dupeZ(u8, rightDataSource);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_whyRecords_V2(g2_leftDataSource, g2_leftRecordId, g2_rightDataSource, g2_rightRecordId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn why_entity_by_record_id(recordId: []u8, dataSource: []u8, flags: c_longlong) !beam.term {
    const g2_recordId = try beam.allocator.dupeZ(u8, recordId);
    const g2_dataSource = try beam.allocator.dupeZ(u8, dataSource);

    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_whyEntityByRecordID_V2(g2_dataSource, g2_recordId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn why_entity_by_entity_id(entityId: c_longlong, flags: c_longlong) !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_whyEntityByEntityID_V2(entityId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn why_entities(leftEntityId: c_longlong, rightEntityId: c_longlong, flags: c_longlong) !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_whyEntities_V2(leftEntityId, rightEntityId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn how_entity_by_entity_id(entityId: c_longlong, flags: c_longlong) !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_howEntityByEntityID_V2(entityId, flags, &responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{ .ok, responseBuf }, .{});
  }

  pub fn export_csv_entity_report(columnList: []u8, flags: c_longlong) !beam.term {
    const g2_columnList = try beam.allocator.dupeZ(u8, columnList);

    var handle: G2.ExportHandle = null;

    if(G2.G2_exportCSVEntityReport(g2_columnList, flags, &handle) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    const resource = try ExportResource.create(handle, .{});

    return beam.make(.{.@"ok", resource}, .{});
  }

  pub fn export_json_entity_report(flags: c_longlong) !beam.term {
    var handle: G2.ExportHandle = null;

    if(G2.G2_exportJSONEntityReport(flags, &handle) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    const resource = try ExportResource.create(handle, .{});

    return beam.make(.{.@"ok", resource}, .{});
  }

  pub fn export_fetch_next(exportResource: beam.term) !beam.term {
    const res = try beam.get(ExportResource, exportResource, .{});
    const handle = res.unpack();

    var responseBuf: [*c]u8 = null;
    const responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    const result = G2.G2_fetchNext(handle, responseBuf, responseBufSize);

    if(result < 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    } else if(result == 0) {
      return beam.make(.{.@"ok", .@"eof"}, .{});
    }

    return beam.make(.{.@"ok", responseBuf}, .{});
  }

  pub fn export_close(exportResource: beam.term) !beam.term {
    const res = try beam.get(ExportResource, exportResource, .{});
    const handle = res.unpack();

    if(G2.G2_closeExport(handle) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    res.update(null);

    return beam.make(.@"ok", .{});
  }

  pub fn purge_repository() !beam.term {
    if (G2.G2_purgeRepository() != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.@"ok", .{});
  }

  pub fn stats() !beam.term {
    var responseBuf: [*c]u8 = null;
    var responseBufSize: usize = 1024;
    const initialResponseBuf = try beam.allocator.alloc(u8, responseBufSize);
    defer beam.allocator.free(initialResponseBuf);
    responseBuf = initialResponseBuf.ptr;

    if (G2.G2_stats(&responseBuf, &responseBufSize, resize_pointer) != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }

    return beam.make(.{.@"ok", responseBuf}, .{});
  }

  pub fn destroy() !beam.term {
    if(G2.G2_destroy() != 0) {
      const reason = try get_and_clear_last_exception();
      return beam.make_error_pair(reason, .{});
    }
    return beam.make(.@"ok", .{});
  }
  """
end
