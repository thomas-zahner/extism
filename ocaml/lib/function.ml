open Ctypes

type t = {
  mutable pointer : unit ptr;
  mutable user_data : unit ptr;
  name : string;
}

let free t =
  let () =
    if not (is_null t.user_data) then
      let () = Root.release t.user_data in
      t.user_data <- null
  in
  if not (is_null t.pointer) then
    let () = Bindings.extism_function_free t.pointer in
    t.pointer <- null

let free_all l = List.iter free l

let create name ?namespace ~params ~results ~user_data f =
  let inputs = CArray.of_list Bindings.Extism_val_type.t params in
  let n_inputs = Unsigned.UInt64.of_int (CArray.length inputs) in
  let outputs = CArray.of_list Bindings.Extism_val_type.t results in
  let n_outputs = Unsigned.UInt64.of_int (CArray.length outputs) in
  let free' = Some Root.release in
  let user_data = Root.create user_data in
  let f current inputs n_inputs outputs n_outputs user_data =
    let user_data = Root.get user_data in
    let inputs = CArray.from_ptr inputs (Unsigned.UInt64.to_int n_inputs) in
    let outputs = CArray.from_ptr outputs (Unsigned.UInt64.to_int n_outputs) in
    f current inputs outputs user_data
  in
  let pointer =
    Bindings.extism_function_new name (CArray.start inputs) n_inputs
      (CArray.start outputs) n_outputs f user_data free'
  in
  let () =
    Option.iter (Bindings.extism_function_set_namespace pointer) namespace
  in
  let t = { pointer; user_data; name } in
  Gc.finalise free t;
  t

let with_namespace f ns =
  Bindings.extism_function_set_namespace f.pointer ns;
  f
