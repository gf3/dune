open Stdune

let default_root_path () =
  Path.L.relative
    (Path.of_filename_relative_to_initial_cwd Xdg.cache_dir)
    [ "dune"; "db" ]

let root_path =
  let var = "DUNE_CACHE_ROOT" in
  match Sys.getenv_opt var with
  | None -> default_root_path ()
  | Some path ->
    if Filename.is_relative path then
      failwith (sprintf "%s should be an absolute path, but is %s" var path);
    Path.of_filename_relative_to_initial_cwd path

let ( / ) = Path.relative

let temp_path = root_path / "temp"

let cache_path ~dir ~hex =
  let two_first_chars = sprintf "%c%c" hex.[0] hex.[1] in
  dir / two_first_chars / hex

(* List all entries in a given storage directory. *)
let list_entries ~storage =
  let open Result.O in
  let entries dir =
    match
      String.length dir = 2 && String.for_all ~f:Char.is_lowercase_hex dir
    with
    | false ->
      (* Ignore directories whose name isn't a two-character hex value. *)
      Ok []
    | true ->
      let dir = storage / dir in
      Path.readdir_unsorted dir
      >>| List.filter_map ~f:(fun entry_name ->
              match Digest.from_hex entry_name with
              | None ->
                (* Ignore entries whose names are not hex values. *)
                None
              | Some digest -> Some (dir / entry_name, digest))
  in
  match Path.readdir_unsorted storage >>= Result.List.concat_map ~f:entries with
  | Ok res -> res
  | Error ENOENT -> []
  | Error e -> User_error.raise [ Pp.text (Unix.error_message e) ]

module Versioned = struct
  let metadata_storage_path t =
    root_path / "meta" / Version.Metadata.to_string t

  let file_storage_path t = root_path / "files" / Version.File.to_string t

  let value_storage_path t = root_path / "values" / Version.Value.to_string t

  let metadata_path t =
    let dir = metadata_storage_path t in
    fun ~rule_or_action_digest ->
      cache_path ~dir ~hex:(Digest.to_string rule_or_action_digest)

  let file_path t =
    let dir = file_storage_path t in
    fun ~file_digest -> cache_path ~dir ~hex:(Digest.to_string file_digest)

  let value_path t =
    let dir = value_storage_path t in
    fun ~value_digest -> cache_path ~dir ~hex:(Digest.to_string value_digest)

  let list_metadata_entries t = list_entries ~storage:(metadata_storage_path t)

  let list_file_entries t = list_entries ~storage:(file_storage_path t)

  let list_value_entries t = list_entries ~storage:(value_storage_path t)
end

let metadata_storage_path =
  Versioned.metadata_storage_path Version.Metadata.current

let metadata_path = Versioned.metadata_path Version.Metadata.current

let file_storage_path = Versioned.file_storage_path Version.File.current

let file_path = Versioned.file_path Version.File.current

let value_storage_path = Versioned.value_storage_path Version.Value.current

let value_path = Versioned.value_path Version.Value.current

let create_cache_directories () =
  List.iter
    [ temp_path; metadata_storage_path; file_storage_path; value_storage_path ]
    ~f:(fun path ->
      ignore (Fpath.mkdir_p (Path.to_string path) : Fpath.mkdir_p_result))
