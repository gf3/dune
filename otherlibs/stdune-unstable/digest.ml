type t = string

module D = Stdlib.Digest
module Set = String.Set
module Map = String.Map

let hash = Hashtbl.hash

let equal = String.equal

let file p = D.file (Path.to_string p)

let compare x y = Ordering.of_int (D.compare x y)

let to_string = D.to_hex

let to_dyn s =
  let open Dyn.Encoder in
  constr "digest" [ string (to_string s) ]

let from_hex s =
  match D.from_hex s with
  | s -> Some s
  | exception Invalid_argument _ -> None

let string = D.string

let to_string_raw s = s

(* We use [No_sharing] to avoid generating different digests for inputs that
   differ only in how they share internal values. Without [No_sharing], if a
   command line contains duplicate flags, such as multiple occurrences of the
   flag [-I], then [Marshal.to_string] will produce different digests depending
   on whether the corresponding strings ["-I"] point to the same memory location
   or to different memory locations. *)
let generic a = string (Marshal.to_string a [ No_sharing ])

let file_with_executable_bit ~executable path =
  (* We follow the digest scheme used by Jenga. *)
  let string_and_bool ~digest_hex ~bool =
    D.string
      (digest_hex
      ^
      if bool then
        "\001"
      else
        "\000")
  in
  let content_digest = file path in
  string_and_bool ~digest_hex:content_digest ~bool:executable

let file_with_stats path (stats : Unix.stats) =
  match stats.st_kind with
  | S_DIR ->
    generic (stats.st_size, stats.st_perm, stats.st_mtime, stats.st_ctime)
  | _ ->
    let executable = stats.st_perm land 0o100 <> 0 in
    file_with_executable_bit ~executable path
