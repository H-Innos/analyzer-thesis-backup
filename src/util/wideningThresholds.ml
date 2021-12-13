open Cil
module Thresholds = Set.Make(Z)


class extractConstantsVisitor(widening_thresholds) = object
  inherit nopCilVisitor

  method! vexpr e =
    match e with
    | Const (CInt(i,ik,_)) ->
      widening_thresholds := Thresholds.add i !widening_thresholds;
      (* Adding double value of all constants so that we can establish for single variables that they are <= const*)
      (* This is only needed for Apron, one might want to remove it later *)
      widening_thresholds := Thresholds.add (Z.mul (Z.of_int 2) i) !widening_thresholds;
      DoChildren
    | _ -> DoChildren
end

let widening_thresholds = lazy (
  let set = ref Thresholds.empty in
  let thisVisitor = new extractConstantsVisitor(set) in
  visitCilFileSameGlobals thisVisitor (!Cilfacade.current_file);
  Thresholds.elements !set)

let thresholds () =
  Lazy.force widening_thresholds
