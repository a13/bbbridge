;;; bbbridge.el --- Babashka bridge                  -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Dmytro

;; Version: 0.0.1
;; Author: Dmytro <dk@darkhorizon>
;; Homepage: https://github.com/a13/bbbridge
;; Keywords: languages

;; Package-Requires: ((emacs "27.1") (cider "1.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; Require Clojure namespaces as Emacs features.
;;

;;; Code:

(require 'cider)

(defvar bbbridge--connection nil)

;; TODO:
(defcustom bbbridge-classpath "" "doc")

(defcustom bbbridge-cider-timeout
  0.5
  ""
  :group 'bbbridge)

(defcustom bbbridge-cider-sleep
  0.05
  "Cider connection check polling interval."
  :group 'bbbridge)

(defun bbbridge--eval (form)
  "Eval FORM in cider and parse the response."
  (let ((res (cider-nrepl-sync-request:eval form bbbridge--connection)))
    (if-let ((err (nrepl-dict-get res "err")))
        (user-error "Error evaluating %S: %s" form err)
      (parseedn-read-str (nrepl-dict-get res "value")))))

(defun bbbridge-add-classpath (path)
  (thread-last path
               (format "(babashka.classpath/add-classpath \"%s\")")
               bbbridge--eval))

(defun bbbridge-require-clj (ns alias)
  (let ((form (format "(require '[%s :as %s] :reload)" ns alias)))
    (bbbridge--eval form)))

(defun bbbridge-def (alias fn meta)
  "Generate a wrapper for FN from NS/ALIAS, extract docstring from META."
  (let* ((doc (and (hash-table-p meta)
                   (gethash :doc meta)))
         (lisp-name (substring-no-properties (format "%s-%s" alias fn)))
         (clj-name (substring-no-properties (format "%s/%s" alias fn))))
    (if (or (and (hash-table-p meta)
                 (gethash :is-fn meta))
            ;; FIXME: workaroung for publics
            (null meta))
        (let* ((form-fmt (substring-no-properties
                          (format "(apply %s '%%s)" clj-name)))
               ;; TODO: generate proper arglist?
               (fn
                `(lambda (&rest args)
                   ,doc
                   (let* ((args* (seq-map #'parseedn-print-str args))
                          (form (format ,form-fmt args*)))
                     (bbbridge--eval form)))))
          (fset (intern lisp-name) fn))
      ;; parseedn doesn't support #object
      (ignore-errors
        (let ((value (bbbridge--eval clj-name)))
          (set (intern lisp-name) value)
          (put (intern lisp-name) 'variable-documentation doc))))))

(declare-function core-publics "bbbridge.el")

(defun bbbridge-require (ns alias)
  "Require NS as ALIAS."
  (bbbridge-require-clj 'bbbridge.core "core")
  (bbbridge-require-clj ns alias)
  (bbbridge-def "core" "publics" nil)
  (let ((res (core-publics ns)))
    (maphash (apply-partially #'bbbridge-def alias)
             res)))

;; TODO: is there a better way?
(defun bbbridge--cider-buffer (nrepl-process)
  (seq-some (lambda (session)
              (with-current-buffer (cadr session)
                (when (eq nrepl-server-buffer
                          (process-buffer nrepl-process))
                  (current-buffer))))
            (sesman-sessions 'CIDER)))

;; FIXME: reuse params?
(defun bbbridge-jack-in (_params)
  (interactive "P")
  (unless (buffer-live-p bbbridge--connection)
    (let* ((params (list :project-type 'babashka
                         :session-name "bbbridge"))
           (cider-repl-pop-to-buffer-on-connect nil)
           (nrepl-process (cider-jack-in-clj params)))
      (with-timeout (bbbridge-cider-timeout
                     (user-error "CIDER initialization timed out"))
        (while (not (cider-connected-p))
          (sleep-for bbbridge-cider-sleep))
        (message "CIDER is initialized and connected."))
      (setq bbbridge--connection (bbbridge--cider-buffer nrepl-process)))))

(provide 'bbbridge)
;;; bbbridge.el ends here
