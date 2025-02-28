(** Dune representation of the source tree *)
open! Stdune

open! Import

module Dune_file : sig
  val fname : string

  val alternative_fname : string

  type kind = private
    | Plain
    | Ocaml_script

  type t

  (** We release the memory taken by s-exps as soon as it is used, unless
      [kind = Ocaml_script]. In which case that optimization is incorrect as we
      need to re-parse in every context. *)
  val get_static_sexp_and_possibly_destroy : t -> Dune_lang.Ast.t list

  val kind : t -> kind

  val path : t -> Path.Source.t
end

module Dir : sig
  type t

  type error = Missing_run_t of Cram_test.t

  val cram_tests : t -> (Cram_test.t, error) result list Memo.Build.t

  val path : t -> Path.Source.t

  val files : t -> String.Set.t

  val file_paths : t -> Path.Source.Set.t

  type sub_dir

  val sub_dirs : t -> sub_dir String.Map.t

  val sub_dir_as_t : sub_dir -> t Memo.Build.t

  module Make_map_reduce (M : Memo.Build) (Outcome : Monoid) : sig
    (** Traverse sub-directories recursively, pass them to [f] and combine
        intermediate results into a single one via [M.combine]. *)
    val map_reduce :
         t
      -> traverse:Sub_dirs.Status.Set.t
      -> f:(t -> Outcome.t M.t)
      -> Outcome.t M.t
  end

  val sub_dir_paths : t -> Path.Source.Set.t

  val sub_dir_names : t -> String.Set.t

  val vcs : t -> Vcs.t option

  val status : t -> Sub_dirs.Status.t

  (** Return the contents of the dune (or jbuild) file in this directory *)
  val dune_file : t -> Dune_file.t option

  (** Return the project this directory is part of *)
  val project : t -> Dune_project.t

  val to_dyn : t -> Dyn.t
end

module Settings : sig
  (** Global source tree settings. *)
  type t

  val builtin_default : t

  (** The default vcs. If there is no vcs at the root of the workspace, then
      this is the vcs that will be used for the root. *)
  val set_ancestor_vcs : Vcs.t option -> t -> t

  (** The default execution parameters. *)
  val set_execution_parameters : Execution_parameters.t -> t -> t
end

(** Set the global settings for this module. This function must be called
    exactly once at the beginning of the process. *)
val init : Settings.t Memo.Build.t -> unit

val root : unit -> Dir.t Memo.Build.t

module Make_map_reduce_with_progress (M : Memo.Build) (Outcome : Monoid) : sig
  (** Traverse starting from the root and report progress in the status line *)
  val map_reduce :
       traverse:Sub_dirs.Status.Set.t
    -> f:(Dir.t -> Outcome.t M.t)
    -> Outcome.t M.t
end

val find_dir : Path.Source.t -> Dir.t option Memo.Build.t

(** [nearest_dir t fn] returns the directory with the longest path that is an
    ancestor of [fn]. *)
val nearest_dir : Path.Source.t -> Dir.t Memo.Build.t

(** [nearest_vcs t fn] returns the version control system with the longest root
    path that is an ancestor of [fn]. *)

val nearest_vcs : Path.Source.t -> Vcs.t option Memo.Build.t

val files_of : Path.Source.t -> Path.Source.Set.t Memo.Build.t

(** [true] iff the path is a directory *)
val dir_exists : Path.Source.t -> bool Memo.Build.t

(** [true] iff the path is a vendored directory *)
val is_vendored : Path.Source.t -> bool Memo.Build.t

(** [true] iff the path is a file *)
val file_exists : Path.Source.t -> bool Memo.Build.t

val find_dir_specified_on_command_line : dir:Path.Source.t -> Dir.t Memo.Build.t

(** Return the execution parameters for the following directory *)
val execution_parameters_of_dir :
  Path.Source.t -> Execution_parameters.t Memo.Build.t
