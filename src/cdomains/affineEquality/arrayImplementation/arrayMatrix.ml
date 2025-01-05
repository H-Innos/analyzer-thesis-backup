open AbstractVector
open RatOps
open ConvenienceOps
open AbstractMatrix

open Batteries
module Array = Batteries.Array

(** Array-based matrix implementation.
    It provides a normalization function to reduce a matrix into reduced row echelon form.
    Operations exploit that the input matrix/matrices are in reduced row echelon form already. *)
module ArrayMatrix: AbstractMatrix =
  functor (A: RatOps) (V: AbstractVector) ->
  struct
    include ConvenienceOps(A)
    module V = V(A)

    type t = A.t array array [@@deriving eq, ord, hash]

    let show x =
      Array.fold_left (^) "" (Array.map (fun v -> V.show @@ V.of_array v) x)

    let empty () =
      Array.make_matrix 0 0 A.zero

    let num_rows m =
      Array.length m

    let is_empty m =
      (num_rows m = 0)

    let num_cols m =
      if is_empty m then 0 else Array.length m.(0)

    let copy m =
      let cp = Array.make_matrix (num_rows m) (num_cols m) A.zero in
      Array.iteri (fun i x -> Array.blit x 0 cp.(i) 0 (num_cols m)) m; cp

    let copy m = Timing.wrap "copy" (copy) m

    let add_empty_columns m cols =
      Array.modifyi (+) cols;
      let nnc = Array.length cols in
      if is_empty m || nnc = 0 then m else
        let nr, nc = num_rows m, num_cols m in
        let m' = Array.make_matrix nr (nc + nnc) A.zero in
        for i = 0 to nr - 1 do
          let offset = ref 0 in
          for j = 0 to nc - 1 do
            while  !offset < nnc &&  !offset + j = cols.(!offset) do incr offset done;
            m'.(i).(j + !offset) <- m.(i).(j);
          done
        done;
        m'

    let add_empty_columns m cols = Timing.wrap "add_empty_cols" (add_empty_columns m) cols

    let append_row m row  =
      let size = num_rows m in
      let new_matrix = Array.make_matrix (size + 1) (num_cols m) A.zero in
      for i = 0 to size - 1 do
        new_matrix.(i) <- m.(i)
      done;
      new_matrix.(size) <- V.to_array row;
      new_matrix

    let get_row m n =
      V.of_array m.(n)

    let remove_row m n =
      let new_matrix = Array.make_matrix (num_rows m - 1) (num_cols m) A.zero in
      if not @@ is_empty new_matrix then
        if n = 0 then
          Array.blit m 1 new_matrix 0 (num_rows m - 1)
        else
          (Array.blit m 0 new_matrix 0 n;
           if n <> (num_rows m - 1) then
             Array.blit m (n + 1) new_matrix n (num_rows new_matrix - n)); new_matrix

    let get_col m n =
      V.of_array @@ Array.init (Array.length m) (fun i -> m.(i).(n))

    let get_col m n = Timing.wrap "get_col" (get_col m) n

    let set_col_with m new_col n =
      for i = 0 to num_rows m - 1 do
        m.(i).(n) <- V.nth new_col i
      done;
      m

    let set_col_with m new_col n = Timing.wrap "set_col" (set_col_with m new_col) n

    let set_col m new_col n =
      let copy = copy m in
      set_col_with copy new_col n

    let append_matrices m1 m2  =
      Array.append m1 m2

    let equal m1 m2 = Timing.wrap "equal" (equal m1) m2

    let reduce_col_with m j =
      if not @@ is_empty m then
        (let r = ref (-1) in
         for i' = 0 to num_rows m - 1 do
           let rev_i' = num_rows m - i' - 1 in
           if !r < 0 && m.(rev_i').(j) <>: A.zero then r := rev_i';
           if !r <> rev_i' then
             let g = m.(rev_i').(j) in
             if g <>: A.zero then
               let s = g /: m.(!r).(j) in
               for j' = 0 to num_cols m - 1 do
                 m.(rev_i').(j') <- m.(rev_i').(j') -: s *: m.(!r).(j')
               done
         done;
         if !r >= 0 then Array.fill m.(!r) 0 (num_cols m) A.zero)

    let reduce_col_with m j  = Timing.wrap "reduce_col_with" (reduce_col_with m) j
    let reduce_col m j =
      let copy = copy m in
      reduce_col_with copy j;
      copy

    let del_col m j =
      if is_empty m then m else
        let new_matrix = Array.make_matrix (num_rows m) (num_cols m - 1) A.zero in
        for i = 0 to num_rows m - 1 do
          new_matrix.(i) <- Array.remove_at j m.(i)
        done; new_matrix

    let del_cols m cols =
      let n_c = Array.length cols in
      if n_c = 0 || is_empty m then m
      else
        let m_r, m_c = num_rows m, num_cols m in
        if m_c = n_c then empty () else
          let m' = Array.make_matrix m_r (m_c - n_c) A.zero in
          for i = 0 to m_r - 1 do
            let offset = ref 0 in
            for j = 0 to (m_c - n_c) - 1 do
              while  !offset < n_c &&  !offset + j = cols.(!offset) do incr offset done;
              m'.(i).(j) <- m.(i).(j + !offset);
            done
          done;
          m'

    let del_cols m cols = Timing.wrap "del_cols" (del_cols m) cols

    let remove_zero_rows m =
      Array.filter (fun x -> Array.exists (fun y -> y <>: A.zero) x) m

    let rref_with m =
      (*Based on Cousot - Principles of Abstract Interpretation (2021)*)
      let swap_rows i1 i2 =
        let tmp = m.(i1) in
        m.(i1) <- m.(i2);
        m.(i2) <- tmp;
      in
      let exception Unsolvable in
      let num_rows = num_rows m in
      let num_cols = num_cols m in
      try (
        for i = 0 to num_rows-1 do
          let exception Found in
          try (
            for j = i to num_cols -2 do (* Find pivot *)
              for k = i to num_rows -1 do
                if m.(k).(j) <>: A.zero then
                  (
                    if k <> i then swap_rows k i;
                    let piv = m.(i).(j) in
                    Array.iteri(fun j' x -> m.(i).(j') <- x /: piv) m.(i); (* Normalize pivot *)
                    for l = 0 to num_rows-1 do (* Subtract from each row *)
                      if l <> i && m.(l).(j) <>: A.zero then (
                        let is_only_zero = ref true in
                        let m_lj = m.(l).(j) in
                        for k = 0 to num_cols - 2 do
                          m.(l).(k) <- m.(l).(k) -: m.(i).(k) *: m_lj /: m.(i).(j); (* Subtraction *)
                          if m.(l).(k) <>: A.zero then is_only_zero := false;
                        done;
                        let k_end = num_cols - 1 in
                        m.(l).(k_end) <- m.(l).(k_end) -: m.(i).(k_end) *: m_lj /: m.(i).(j);
                        if !is_only_zero && m.(l).(k_end) <>: A.zero then raise Unsolvable;
                      )
                    done;
                    raise Found
                  )
              done;
            done;
          )
          with Found -> ()
        done;
        true)
      with Unsolvable -> false

    let rref_with m = Timing.wrap "rref_with" rref_with m

    let init_with_vec v =
      let new_matrix = Array.make_matrix 1 (V.length v) A.zero in
      new_matrix.(0) <- (V.to_array v); new_matrix


    let reduce_col_with_vec m j v =
      for i = 0 to num_rows m - 1 do
        if m.(i).(j) <>: A.zero then
          let beta = m.(i).(j) /: v.(j) in
          Array.iteri (fun j' x ->  m.(i).(j') <- x -: beta *: v.(j')) m.(i)
      done


    let get_pivot_positions m =
      let pivot_elements = Array.make (num_rows m) 0
      in Array.iteri (fun i x -> pivot_elements.(i) <- Array.findi (fun z -> z =: A.one) x) m; pivot_elements

    let rref_vec_helper m pivot_positions v =
      let insert = ref (-1) in
      for j = 0 to Array.length v -2 do
        if v.(j) <>: A.zero then
          match Array.bsearch  Int.ord pivot_positions j with
          | `At i -> let beta = v.(j) /: m.(i).(j) in
            Array.iteri (fun j' x -> v.(j') <- x -: beta *: m.(i).(j')) v
          | _ -> if !insert < 0 then (let v_i = v.(j) in
                                      Array.iteri (fun j' x -> v.(j') <- x /: v_i) v; insert := j;
                                      reduce_col_with_vec m j v)

      done;
      if !insert < 0 then (
        if v.(Array.length v - 1) <>: A.zero then None
        else Some m
      )
      else
        let new_m = Array.make_matrix (num_rows m + 1) (num_cols m) A.zero
        in let (i, j) = Array.pivot_split Int.ord pivot_positions !insert in
        if i = 0 && j = 0 then (new_m.(0) <- v; Array.blit m 0 new_m 1 (num_rows m))
        else if i = num_rows m && j = num_rows m then (Array.blit m 0  new_m 0 j; new_m.(j) <- v)
        else (Array.blit m 0 new_m 0 i; new_m.(i) <- v; Array.blit m i new_m (i + 1) (Array.length m - j));
        Some new_m

    let normalize_with m =
      rref_with m

    let normalize_with m = Timing.wrap "normalize_with" normalize_with m

    let normalize m =
      let copy = copy m in
      if normalize_with copy then
        Some copy
      else
        None
    let rref_vec_with m v =
      (*This function yields the same result as appending vector v to m and normalizing it afterwards would. However, it is usually faster than performing those ops manually.*)
      (*m must be in rref form and contain the same num of cols as v*)
      (*If m is empty then v is simply normalized and returned*)
      (*let v = V.to_array v in
        if is_empty m then
        match Array.findi (fun x -> x <>: A.zero) v with
        | exception Not_found -> None
        | i -> if i = Array.length v - 1 then None else
            let v_i = v.(i) in
            Array.iteri (fun j x -> v.(j) <- x /: v_i) v; Some (init_with_vec @@ V.of_array v)
        else
        let pivot_elements = get_pivot_positions m in
        rref_vec_helper m pivot_elements v*)
      normalize @@ append_row m v

    let rref_vec_with m v = Timing.wrap "rref_vec_with" (rref_vec_with m) v

    let rref_vec m v = (* !! There was another rref_vec function that has been renamed to rref_vec_helper !!*)
      let m' = copy m in
      let v' = V.copy v in 
      match rref_vec_with m' v' with
      | Some res -> Some (remove_zero_rows res)
      | None -> None

    let rref_matrix_with m1 m2 =
      (*Similar to rref_vec_with but takes two matrices instead.*)
      (*ToDo Could become inefficient for large matrices since pivot_elements are always recalculated + many row additions*)
      let b_m, s_m = if num_rows m1 > num_rows m2 then m1, m2 else m2, m1 in
      let b = ref b_m in
      let exception Unsolvable in
      try (
        for i = 0 to num_rows s_m - 1 do
          let pivot_elements = get_pivot_positions !b in
          let res = rref_vec_helper !b pivot_elements s_m.(i) in
          match res with
          | None -> raise Unsolvable
          | Some res -> b := res
        done;
        Some !b
      )
      with Unsolvable -> None

    let rref_matrix_with m1 m2 = Timing.wrap "rref_matrix_with" (rref_matrix_with m1) m2

    let rref_matrix m1 m2 = 
      let m1' = copy m1 in
      let m2' = copy m2 in 
      match rref_matrix_with m1' m2' with
      | Some m -> Some m
      | None -> None

    let is_covered_by m1 m2 =
      (*Performs a partial rref reduction to check if concatenating both matrices and afterwards normalizing them would yield a matrix <> m2 *)
      (*Both input matrices must be in rref form!*)
      if num_rows m1 > num_rows m2 then false else
        let p2 = lazy (get_pivot_positions m2) in
        try (
          for i = 0 to num_rows m1 - 1 do
            (* check if there are rows in m1 and m2 that aren't equal *)
            if Array.exists2 (<>:) m1.(i) m2.(i) then
              let m1_i = Array.copy m1.(i) in
              for j = 0 to Array.length m1_i - 2 do
                if m1_i.(j) <>: A.zero then
                  match Array.bsearch Int.ord (Lazy.force p2) j with
                  | `At pos -> let beta =  m1_i.(j) in
                    Array.iteri (fun j' x -> m1_i.(j') <- m1_i.(j') -: beta *: m2.(pos).(j') ) m1_i
                  | _ -> raise Stdlib.Exit;
              done;
              if m1_i. (num_cols m1 - 1) <>: A.zero then
                raise Stdlib.Exit
          done;
          true
        )
        with Stdlib.Exit -> false;;

    let is_covered_by m1 m2 = Timing.wrap "is_covered_by" (is_covered_by m1) m2

    let find_opt f m =
      let f' x = f (V.of_array x) in Option.map V.of_array (Array.find_opt f' m)


    let map2_with f m v =
      if num_rows m = V.length v then
        Array.iter2i (fun i x y -> m.(i) <- V.to_array @@ f (V.of_array x) y) m (V.to_array v)
      else
        for i = 0 to Stdlib.min (num_rows m) (V.length v) -1  do
          m.(i) <- V.to_array @@ f (V.of_array m.(i)) (V.nth v i)
        done

    let map2_with f m v = Timing.wrap "map2_with" (map2_with f m) v

    let map2 f m v =
      let m' = copy m in
      map2_with f m' v;
      m'

    let map2i_with f m v =
      if num_rows m = V.length v then
        Array.iter2i (fun i x y -> m.(i) <- V.to_array @@ f i (V.of_array x) y) m (V.to_array v)
      else
        for i = 0 to Stdlib.min (num_rows m) (V.length v) -1 do
          m.(i) <- V.to_array @@ f i (V.of_array m.(i)) (V.nth v i)
        done

    let map2i_with f m v = Timing.wrap "map2i_with" (map2i_with f m) v    

    let map2i f m v =
      let m' = copy m in
      map2i_with f m' v;
      m'

    let swap_rows m j k =
      failwith "TODO"

  end