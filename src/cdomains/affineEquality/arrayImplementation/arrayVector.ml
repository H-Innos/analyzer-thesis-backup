open AbstractVector
open RatOps
open ConvenienceOps

open Batteries
module Array = Batteries.Array


(** Array-based vector implementation. *)
module ArrayVector: AbstractVector =
  functor (A: RatOps) ->
  struct
    include ConvenienceOps (A)
    include Array
    type t = A.t array [@@deriving eq, ord, hash]

    let show t =
      let t = Array.to_list t in
      let rec list_str l =
        match l with
        | [] -> "]"
        | x :: xs -> (A.to_string x) ^" "^(list_str xs)
      in
      "["^list_str t^"\n"

    let keep_vals v n =
      if n >= Array.length v then v else
        Array.filteri (fun i x -> i < n) v (* TODO: take? *)

    let compare_length_with v len =
      Int.compare (Array.length v) len

    let remove_nth v n =
      if n >= Array.length v then failwith "n outside of Array range" else
        Array.init (Array.length v - 1) (fun i -> if i < n then Array.get v i else Array.get v (i + 1)) (* TODO: remove_at? *)

    let remove_at_indices v idx = failwith "TODO"

    let insert_zero_at_indices v idx count = failwith "TODO"

    let set_nth_with v n new_val =
      if n >= Array.length v then failwith "n outside of Array range" else
        Array.set v n new_val

    let set_nth v n new_val =
      let copy = copy v in
      set_nth_with copy n new_val; copy

    let insert_val_at n new_val v =
      if n > Array.length v then failwith "n too large" else
        Array.init (Array.length v + 1) (fun i -> if i < n then Array.get v i else if i = n then new_val else Array.get v (i -1)) (* insert? *)

    let apply_with_c f c v =
      Array.map (fun x -> f x c) v

    let zero_vec n = Array.make n A.zero

    let is_zero_vec v = not (Array.exists (fun x -> x <>: A.zero) v)

    let is_const_vec v =
      compare_length_with (filteri (fun i x -> (*Inefficient*)
          compare_length_with v (i + 1) > 0 && x <>: A.zero) v) 1 = 0

    let nth = Array.get

    let map2i f v1 v2 =
      let f' i = uncurry (f i) in
      Array.mapi f' (Array.combine v1 v2) (* TODO: iter2i? *)

    let find2i f v1 v2 =
      Array.findi (uncurry f) (Array.combine v1 v2) (* TODO: iter2i? *)

    let find2i_f_false_at_zero f v v' =
      find2i f v v'

    let to_array v = v

    let of_array v = v

    let rev v = Array.rev v

    let map f v = Array.map f v

    let map2_with f v1 v2 = Array.iter2i (fun i x y -> v1.(i) <- f x y) v1 v2

    let map2 f v1 v2 =
      let copy_v1 = copy v1 in
      map2_with f copy_v1 v2; copy_v1

    let copy v = Array.copy v

    let mapi_with f v = Array.iteri (fun i x -> v.(i) <- f i x) v

    let mapi f v =
      let copy = copy v in
      mapi_with f copy; copy

    let of_sparse_list col_count ls =
      let vec = Array.make col_count A.zero in
      List.iter (fun (idx, value) -> vec.(idx) <- value) ls;
      vec

    let to_sparse_list v = 
      let rec aux idx acc =
        if idx < 0 then acc
        else
          let value = v.(idx) in
          let acc = if value <> A.zero then (idx, value):: acc else acc in
          aux (idx - 1) acc
      in aux (length v - 1) []


    let find_opt f v =
      failwith "Never implemented!"

    let map_f_preserves_zero f v =
      map f v

    let map2_f_preserves_zero f v1 v2 =
      map2 f v1 v2

    let mapi_f_preserves_zero f v =
      mapi f v

    let map2i_f_preserves_zero f v v' =
      map2i f v v'

    let fold_left_f_preserves_zero f acc v =
      failwith "Never implemented!"

    let fold_left2_f_preserves_zero f acc v v' =
      failwith "Never implemented!"

    let findi_val_opt f v =
      failwith "Never implemented!"

    let exists2 f v1 v1 =
      failwith "Never implemented!"

    let starting_from_nth n v =
      failwith "Never implemented!"

    let find_first_non_zero v =
      failwith "Never implemented!"

    let apply_with_c_f_preserves_zero f c v =
      apply_with_c f c v
  end