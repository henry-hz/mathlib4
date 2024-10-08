/-
Copyright (c) 2017 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sébastien Gouëzel, Floris van Doorn, Mario Carneiro, Martin Dvorak
-/
import Mathlib.Data.List.Basic

/-!
# Join of a list of lists

This file proves basic properties of `List.join`, which concatenates a list of lists. It is defined
in `Init.Data.List.Basic`.
-/

-- Make sure we don't import algebra
assert_not_exists Monoid

variable {α β : Type*}

namespace List

-- Porting note (#10618): simp can prove this
-- @[simp]
theorem join_singleton (l : List α) : [l].join = l := by rw [join, join, append_nil]

@[deprecated join_eq_nil_iff (since := "2024-07-10")]
theorem join_eq_nil : ∀ {L : List (List α)}, join L = [] ↔ ∀ l ∈ L, l = [] := join_eq_nil_iff


@[simp]
theorem join_filter_not_isEmpty  :
    ∀ {L : List (List α)}, join (L.filter fun l => !l.isEmpty) = L.join
  | [] => rfl
  | [] :: L => by
      simp [join_filter_not_isEmpty (L := L), isEmpty_iff_eq_nil]
  | (a :: l) :: L => by
      simp [join_filter_not_isEmpty (L := L)]

@[deprecated (since := "2024-02-25")] alias join_filter_isEmpty_eq_false := join_filter_not_isEmpty

@[simp]
theorem join_filter_ne_nil [DecidablePred fun l : List α => l ≠ []] {L : List (List α)} :
    join (L.filter fun l => l ≠ []) = L.join := by
  simp only [ne_eq, ← isEmpty_iff_eq_nil, Bool.not_eq_true, Bool.decide_eq_false,
    join_filter_not_isEmpty]

/-- See `List.length_join` for the corresponding statement using `List.sum`. -/
lemma length_join' (L : List (List α)) : length (join L) = Nat.sum (map length L) := by
  induction L <;> [rfl; simp only [*, join, map, Nat.sum_cons, length_append]]

/-- See `List.countP_join` for the corresponding statement using `List.sum`. -/
lemma countP_join' (p : α → Bool) :
    ∀ L : List (List α), countP p L.join = Nat.sum (L.map (countP p))
  | [] => rfl
  | a :: l => by rw [join, countP_append, map_cons, Nat.sum_cons, countP_join' _ l]

/-- See `List.count_join` for the corresponding statement using `List.sum`. -/
lemma count_join' [BEq α] (L : List (List α)) (a : α) :
    L.join.count a = Nat.sum (L.map (count a)) := countP_join' _ _

/-- See `List.length_bind` for the corresponding statement using `List.sum`. -/
lemma length_bind' (l : List α) (f : α → List β) :
    length (l.bind f) = Nat.sum (map (length ∘ f) l) := by rw [List.bind, length_join', map_map]

/-- See `List.countP_bind` for the corresponding statement using `List.sum`. -/
lemma countP_bind' (p : β → Bool) (l : List α) (f : α → List β) :
    countP p (l.bind f) = Nat.sum (map (countP p ∘ f) l) := by rw [List.bind, countP_join', map_map]

/-- See `List.count_bind` for the corresponding statement using `List.sum`. -/
lemma count_bind' [BEq β] (l : List α) (f : α → List β) (x : β) :
    count x (l.bind f) = Nat.sum (map (count x ∘ f) l) := countP_bind' _ _ _

@[simp]
theorem bind_eq_nil {l : List α} {f : α → List β} : List.bind l f = [] ↔ ∀ x ∈ l, f x = [] :=
  join_eq_nil_iff.trans <| by
    simp only [mem_map, forall_exists_index, and_imp, forall_apply_eq_imp_iff₂]

/-- In a join, taking the first elements up to an index which is the sum of the lengths of the
first `i` sublists, is the same as taking the join of the first `i` sublists.

See `List.take_sum_join` for the corresponding statement using `List.sum`. -/
theorem take_sum_join' (L : List (List α)) (i : ℕ) :
    L.join.take (Nat.sum ((L.map length).take i)) = (L.take i).join := by
  induction L generalizing i
  · simp
  · cases i <;> simp [take_append, *]

/-- In a join, dropping all the elements up to an index which is the sum of the lengths of the
first `i` sublists, is the same as taking the join after dropping the first `i` sublists.

See `List.drop_sum_join` for the corresponding statement using `List.sum`. -/
theorem drop_sum_join' (L : List (List α)) (i : ℕ) :
    L.join.drop (Nat.sum ((L.map length).take i)) = (L.drop i).join := by
  induction L generalizing i
  · simp
  · cases i <;> simp [drop_append, *]

/-- Taking only the first `i+1` elements in a list, and then dropping the first `i` ones, one is
left with a list of length `1` made of the `i`-th element of the original list. -/
theorem drop_take_succ_eq_cons_getElem (L : List α) (i : Nat) (h : i < L.length) :
    (L.take (i + 1)).drop i = [L[i]] := by
  induction' L with head tail ih generalizing i
  · exact (Nat.not_succ_le_zero i h).elim
  rcases i with _ | i
  · simp
  · simpa using ih _ (by simpa using h)

@[deprecated drop_take_succ_eq_cons_getElem (since := "2024-06-11")]
theorem drop_take_succ_eq_cons_get (L : List α) (i : Fin L.length) :
    (L.take (i + 1)).drop i = [get L i] := by
  simp [drop_take_succ_eq_cons_getElem]

/-- In a join of sublists, taking the slice between the indices `A` and `B - 1` gives back the
original sublist of index `i` if `A` is the sum of the lengths of sublists of index `< i`, and
`B` is the sum of the lengths of sublists of index `≤ i`.

See `List.drop_take_succ_join_eq_getElem` for the corresponding statement using `List.sum`. -/
theorem drop_take_succ_join_eq_getElem' (L : List (List α)) (i : Nat) (h : i <  L.length) :
    (L.join.take (Nat.sum ((L.map length).take (i + 1)))).drop (Nat.sum ((L.map length).take i)) =
      L[i] := by
  have : (L.map length).take i = ((L.take (i + 1)).map length).take i := by
    simp [map_take, take_take, Nat.min_eq_left]
  simp only [this, length_map, take_sum_join', drop_sum_join', drop_take_succ_eq_cons_getElem, h,
    join, append_nil]

@[deprecated drop_take_succ_join_eq_getElem' (since := "2024-06-11")]
theorem drop_take_succ_join_eq_get' (L : List (List α)) (i : Fin L.length) :
    (L.join.take (Nat.sum ((L.map length).take (i + 1)))).drop (Nat.sum ((L.map length).take i)) =
      get L i := by
   simp [drop_take_succ_join_eq_getElem']

/-- Two lists of sublists are equal iff their joins coincide, as well as the lengths of the
sublists. -/
theorem eq_iff_join_eq (L L' : List (List α)) :
    L = L' ↔ L.join = L'.join ∧ map length L = map length L' := by
  refine ⟨fun H => by simp [H], ?_⟩
  rintro ⟨join_eq, length_eq⟩
  apply ext_getElem
  · have : length (map length L) = length (map length L') := by rw [length_eq]
    simpa using this
  · intro n h₁ h₂
    rw [← drop_take_succ_join_eq_getElem', ← drop_take_succ_join_eq_getElem', join_eq, length_eq]

theorem join_drop_length_sub_one {L : List (List α)} (h : L ≠ []) :
    (L.drop (L.length - 1)).join = L.getLast h := by
  induction L using List.reverseRecOn
  · cases h rfl
  · simp

/-- We can rebracket `x ++ (l₁ ++ x) ++ (l₂ ++ x) ++ ... ++ (lₙ ++ x)` to
`(x ++ l₁) ++ (x ++ l₂) ++ ... ++ (x ++ lₙ) ++ x` where `L = [l₁, l₂, ..., lₙ]`. -/
theorem append_join_map_append (L : List (List α)) (x : List α) :
    x ++ (L.map (· ++ x)).join = (L.map (x ++ ·)).join ++ x := by
  induction' L with _ _ ih
  · rw [map_nil, join, append_nil, map_nil, join, nil_append]
  · rw [map_cons, join, map_cons, join, append_assoc, ih, append_assoc, append_assoc]


/-- Any member of `L : List (List α))` is a sublist of `L.join` -/
lemma sublist_join (L : List (List α)) {s : List α} (hs : s ∈ L) :
    s.Sublist L.join := by
  induction L with
  | nil =>
    exfalso
    exact not_mem_nil s hs
  | cons t m ht =>
    cases mem_cons.mp hs with
    | inl h =>
      rw [h]
      simp only [join_cons, sublist_append_left]
    | inr h =>
      simp only [join_cons]
      exact sublist_append_of_sublist_right (ht h)

end List
