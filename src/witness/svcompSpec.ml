(** SV-COMP specification strings and files. *)

open Batteries

type t =
  | UnreachCall of string
  | NoDataRace
  | NoOverflow
  | ValidFree
  | ValidDeref
  | ValidMemtrack
  | ValidMemcleanup

type multi = t list

let of_string s =
  let s = String.strip s in
  let regexp_single = Str.regexp "CHECK( init(main()), LTL(G \\(.*\\)) )" in
  let regexp_negated = Str.regexp "CHECK( init(main()), LTL(G ! \\(.*\\)) )" in
  if Str.string_match regexp_negated s 0 then
    let global_not = Str.matched_group 1 s in
    if global_not = "data-race" then
      NoDataRace
    else if global_not = "overflow" then
      NoOverflow
    else
      let call_regex = Str.regexp "call(\\(.*\\)())" in
      if Str.string_match call_regex global_not 0 then
        let f = Str.matched_group 1 global_not in
        UnreachCall f
      else
        failwith "Svcomp.Specification.of_string: unknown global not expression"
  else if Str.string_match regexp_single s 0 then
    let global = Str.matched_group 1 s in
    if global = "valid-free" then
      ValidFree
    else if global = "valid-deref" then
      ValidDeref
    else if global = "valid-memtrack" then
      ValidMemtrack
    else if global = "valid-memcleanup" then
      ValidMemcleanup
    else
      failwith "Svcomp.Specification.of_string: unknown global expression"
  else
    failwith "Svcomp.Specification.of_string: unknown expression"

let of_string s: multi =
  List.filter_map (fun line ->
      let line = String.strip line in
      if line = "" then
        None
      else
        Some (of_string line)
    ) (String.split_on_char '\n' s)

let of_file path =
  let s = BatFile.with_file_in path BatIO.read_all in
  of_string s

let of_option () =
  let s = GobConfig.get_string "ana.specification" in
  if Sys.file_exists s then
    of_file s
  else
    of_string s

let to_string spec =
  let print_output spec_str is_neg =
    if is_neg then
      Printf.sprintf "CHECK( init(main()), LTL(G ! %s) )" spec_str
    else
      Printf.sprintf "CHECK( init(main()), LTL(G %s) )" spec_str
  in
  let spec_str, is_neg = match spec with
    | UnreachCall f -> "call(" ^ f ^ "())", true
    | NoDataRace -> "data-race", true
    | NoOverflow -> "overflow", true
    | ValidFree -> "valid-free", false
    | ValidDeref -> "valid-deref", false
    | ValidMemtrack -> "valid-memtrack", false
    | ValidMemcleanup -> "valid-memcleanup", false
  in
  print_output spec_str is_neg

let to_string spec =
  String.concat "\n" (List.map to_string spec)
