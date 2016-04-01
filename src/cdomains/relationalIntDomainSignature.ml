module ID = IntDomain.IntDomTuple

module type S =
sig
  include Lattice.S
  val add_variable_value_list: (Cil.lhost * ID.t) list -> t -> t
  val add_variable_value_pair: (Cil.lhost * ID.t) -> t -> t
  val eval_assert_cil_exp: Cil.exp -> t -> t
  val eval_assign_int_value: (ID.t * Cil.exp) -> t -> t
  val eval_assign_cil_exp: (Cil.exp * Cil.exp) -> t -> t
  val get_value_of_variable: Cil.varinfo -> t -> ID.t
  val meet_local_and_global_state: t -> t -> t
  val remove_all_local_variables:  t -> t
  val remove_all_top_variables:  t -> t
  val remove_variable: Cil.varinfo -> t -> t
end
