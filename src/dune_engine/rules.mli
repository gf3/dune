(** A collection of rules across a known finite set of directories *)

open! Stdune

(** Represent a set of rules producing files in a given directory *)
module Dir_rules : sig
  type t

  val empty : t

  val union : t -> t -> t

  module Alias_spec : sig
    type t = { expansions : (Loc.t * unit Action_builder.t) Appendable_list.t }
    [@@unboxed]
  end

  (** A ready to process view of the rules of a directory *)
  type ready =
    { rules : Rule.t list
    ; aliases : Alias_spec.t Alias.Name.Map.t
    }

  val consume : t -> ready

  val is_subset : t -> of_:t -> bool

  val is_empty : t -> bool

  val to_dyn : t -> Dyn.t
end

(** A value of type [t] holds a set of rules for multiple directories *)
type t

val to_map : t -> Dir_rules.t Path.Build.Map.t

module Produce : sig
  (* CR-someday aalekseyev: the below comments are not quite right *)

  (** Add a rule to the system. This function must be called from the
      [gen_rules] callback. All the target of the rule must be in the same
      directory.

      Assuming that [gen_rules ~dir:a] calls [add_rule r] where [r.dir] is [b],
      one of the following assumption must hold:

      - [a] and [b] are the same - [gen_rules ~dir:b] calls [load_dir ~dir:a]

      The call to [load_dir ~dir:a] from [gen_rules ~dir:b] declares a directory
      dependency from [b] to [a]. There must be no cyclic directory
      dependencies. *)
  val rule : Rule.t -> unit Memo.Build.t

  module Alias : sig
    type t = Alias.t

    (** [add_deps store alias deps] arrange things so that all the dependencies
        registered by [deps] are considered as a part of alias expansion of
        [alias]. *)
    val add_deps :
      t -> ?loc:Stdune.Loc.t -> unit Action_builder.t -> unit Memo.Build.t

    val add_static_deps :
      t -> ?loc:Stdune.Loc.t -> Path.Set.t -> unit Memo.Build.t

    (** [add_action store alias ~stamp action] arrange things so that [action]
        is executed as part of the build of alias [alias]. [stamp] is any
        S-expression that is unique and persistent S-expression. *)
    val add_action :
         t
      -> context:Build_context.t
      -> loc:Loc.t option
      -> Action.Full.t Action_builder.t
      -> unit Memo.Build.t
  end
end

val implicit_output : t Memo.Implicit_output.t

val empty : t

val union : t -> t -> t

val produce_dir : dir:Path.Build.t -> Dir_rules.t -> unit Memo.Build.t

val produce : t -> unit Memo.Build.t

val produce_opt : t option -> unit Memo.Build.t

val is_subset : t -> of_:t -> bool

val map_rules : t -> f:(Rule.t -> Rule.t) -> t

val collect : (unit -> 'a Memo.Build.t) -> ('a * t) Memo.Build.t

val collect_opt : (unit -> 'a Memo.Build.t) -> ('a * t option) Memo.Build.t

val collect_unit : (unit -> unit Memo.Build.t) -> t Memo.Build.t

(** returns [Dir_rules.empty] for non-build paths *)
val find : t -> Path.t -> Dir_rules.t
