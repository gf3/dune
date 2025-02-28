(** Digests (MD5) *)

type t

module Set : Set.S with type elt = t

module Map : Map.S with type key = t

val to_dyn : t -> Dyn.t

val hash : t -> int

val equal : t -> t -> bool

val compare : t -> t -> Ordering.t

val to_string : t -> string

val from_hex : string -> t option

val file : Path.t -> t

val string : string -> t

val to_string_raw : t -> string

val generic : 'a -> t

(** Digest a file and its stats. Does something sensible for directories. *)
val file_with_stats : Path.t -> Unix.stats -> t

(** Digest a file taking its executable bit into account. Should not be called
    on a directory. *)
val file_with_executable_bit : executable:bool -> Path.t -> t
