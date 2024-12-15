(ns bbbridge.example)

(defn with-docs
  "Sum three numbers."
  [x y z]
  (+ x y z))

(def somevar
  "Somevar documentation"
  "somevar value")

(def somefn
  (partial + 10))

(defn take-foo
  [{:keys [foo]}]
  foo)

(defn keys-and-vectors
  [{:keys [foo]} [a [b c]]]
  (str foo ", " a " " b " " c))

(defn join-newlines
  [strs]
  (clojure.string/join "\n" strs))
