(ns bbbridge.core)

(defn publics [ns]
  (->> (ns-publics ns)
       (map (fn [[k v]]
              [k (assoc (select-keys (meta v) [:doc])
                        :is-fn (or (fn? (deref v))
                                   ;; defmulti?
                                   (contains? (meta v) :arglists)))]))
       (into {})))
