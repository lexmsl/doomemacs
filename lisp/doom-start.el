;;; lisp/doom-start.el --- bootstraps interactive sessions -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'doom-modules)


;;
;;; Custom hooks

(defvar doom-first-input-hook nil
  "Transient hooks run before the first user input.")
(put 'doom-first-input-hook 'permanent-local t)

(defvar doom-first-file-hook nil
  "Transient hooks run before the first interactively opened file.")
(put 'doom-first-file-hook 'permanent-local t)

(defvar doom-first-buffer-hook nil
  "Transient hooks run before the first interactively opened buffer.")
(put 'doom-first-buffer-hook 'permanent-local t)


;;
;;; Reasonable defaults for interactive sessions

;;; Runtime optimizations
;; A second, case-insensitive pass over `auto-mode-alist' is time wasted.
(setq auto-mode-case-fold nil)

;; Disable bidirectional text scanning for a modest performance boost. I've set
;; this to `nil' in the past, but the `bidi-display-reordering's docs say that
;; is an undefined state and suggest this to be just as good:
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)

;; Disabling the BPA makes redisplay faster, but might produce incorrect display
;; reordering of bidirectional text with embedded parentheses and other bracket
;; characters whose 'paired-bracket' Unicode property is non-nil.
(setq bidi-inhibit-bpa t)  ; Emacs 27+ only

;; Reduce rendering/line scan work for Emacs by not rendering cursors or regions
;; in non-focused windows.
(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil)

;; More performant rapid scrolling over unfontified regions. May cause brief
;; spells of inaccurate syntax highlighting right after scrolling, which should
;; quickly self-correct.
(setq fast-but-imprecise-scrolling t)

;; Don't ping things that look like domain names.
(setq ffap-machine-p-known 'reject)

;; Emacs "updates" its ui more often than it needs to, so slow it down slightly
(setq idle-update-delay 1.0)  ; default is 0.5

;; Font compacting can be terribly expensive, especially for rendering icon
;; fonts on Windows. Whether disabling it has a notable affect on Linux and Mac
;; hasn't been determined, but do it anyway, just in case. This increases memory
;; usage, however!
(setq inhibit-compacting-font-caches t)

;; PGTK builds only: this timeout adds latency to frame operations, like
;; `make-frame-invisible', which are frequently called without a guard because
;; it's inexpensive in non-PGTK builds. Lowering the timeout from the default
;; 0.1 should make childframes and packages that manipulate them (like `lsp-ui',
;; `company-box', and `posframe') feel much snappier. See emacs-lsp/lsp-ui#613.
(eval-when! (boundp 'pgtk-wait-for-event-timeout)
  (setq pgtk-wait-for-event-timeout 0.001))

;; Increase how much is read from processes in a single chunk (default is 4kb).
;; This is further increased elsewhere, where needed (like our LSP module).
(setq read-process-output-max (* 64 1024))  ; 64kb

;; Introduced in Emacs HEAD (b2f8c9f), this inhibits fontification while
;; receiving input, which should help a little with scrolling performance.
(setq redisplay-skip-fontification-on-input t)

;; Performance on Windows is considerably worse than elsewhere. We'll need
;; everything we can get.
(eval-when! (boundp 'w32-get-true-file-attributes)
  (setq w32-get-true-file-attributes nil    ; decrease file IO workload
        w32-pipe-read-delay 0               ; faster IPC
        w32-pipe-buffer-size (* 64 1024))) ; read more at a time (was 4K)

;; The GC introduces annoying pauses and stuttering into our Emacs experience,
;; so we use `gcmh' to stave off the GC while we're using Emacs, and provoke it
;; when it's idle. However, if the idle delay is too long, we run the risk of
;; runaway memory usage in busy sessions. If it's too low, then we may as well
;; not be using gcmh at all.
(setq gcmh-idle-delay 'auto  ; default is 15s
      gcmh-auto-idle-delay-factor 10
      gcmh-high-cons-threshold (* 16 1024 1024))  ; 16mb
(add-hook 'doom-first-buffer-hook #'gcmh-mode)


;;; Startup optimizations
;; Resizing the Emacs frame can be a terribly expensive part of changing the
;; font. By inhibiting this, we halve startup times, particularly when we use
;; fonts that are larger than the system default (which would resize the frame).
(setq frame-inhibit-implied-resize t)

;; Remove command line options that aren't relevant to our current OS; means
;; slightly less to process at startup.
(eval-when! (not IS-MAC)   (setq command-line-ns-option-alist nil))
(eval-when! (not IS-LINUX) (setq command-line-x-option-alist nil))

;; HACK: `tty-run-terminal-initialization' is *tremendously* slow for some
;;   reason; inexplicably doubling startup time for terminal Emacs. Keeping it
;;   disabled will have nasty side-effects, so we simply delay it instead, and
;;   invoke it later, at which point it runs quickly; how mysterious!
(unless (or (daemonp) init-file-debug)
  (advice-add #'tty-run-terminal-initialization :override #'ignore)
  (defun doom-init-tty-h ()
    (advice-remove #'tty-run-terminal-initialization #'ignore)
    (tty-run-terminal-initialization (selected-frame) nil t))
  (add-hook 'window-setup-hook #'doom-init-tty-h))

;; Reduce *Message* noise at startup. An empty scratch buffer (or the dashboard)
;; is more than enough, and faster to display.
(setq inhibit-startup-screen t
      inhibit-startup-echo-area-message user-login-name
      inhibit-default-init t)
;; Get rid of "For information about GNU Emacs..." message at startup. It's
;; redundant with our dashboard and incurs a redraw. In daemon sessions it says
;; "Starting Emacs daemon" instead, which is fine.
(unless (daemonp)
  (advice-add #'display-startup-echo-area-message :override #'ignore))

;; Shave seconds off startup time by starting the scratch buffer in
;; `fundamental-mode', rather than, say, `org-mode' or `text-mode', which pull
;; in a ton of packages. `doom/open-scratch-buffer' provides a better scratch
;; buffer anyway.
(setq initial-major-mode 'fundamental-mode
      initial-scratch-message nil)


;;; Language
;; Contrary to what many Emacs users have in their configs, you don't need more
;; than this to make UTF-8 the default coding system:
(set-language-environment "UTF-8")
;; ...but `set-language-environment' also sets `default-input-method', which is
;; a step too opinionated.
(setq default-input-method nil)
;; ...And the clipboard on Windows could be in a wider encoding (UTF-16), so
;; leave Emacs to its own devices.
(eval-when! IS-WINDOWS
  (setq selection-coding-system 'utf-8))


;;; User interface
;; GUIs are inconsistent across systems, will rarely match our active Emacs
;; theme, and impose their shortcut key paradigms suddenly. Let's just avoid
;; them altogether and have Emacs handle the prompting.
(setq use-dialog-box nil)
(when (bound-and-true-p tooltip-mode)
  (tooltip-mode -1))
(eval-when! IS-LINUX
  (setq x-gtk-use-system-tooltips nil))

;; Favor vertical splits over horizontal ones, since monitors are trending
;; toward wide rather than tall.
(setq split-width-threshold 160
      split-height-threshold nil)

;; Add support for additional file extensions.
(dolist (entry '(("/\\.doom\\(?:rc\\|project\\|module\\|profile\\)\\'" . emacs-lisp-mode)
                 ("/LICENSE\\'" . text-mode)
                 ("\\.log\\'" . text-mode)
                 ("rc\\'" . conf-mode)
                 ("\\.\\(?:hex\\|nes\\)\\'" . hexl-mode)))
  (push entry auto-mode-alist))


;;
;;; MODE-local-vars-hook

;; File+dir local variables are initialized after the major mode and its hooks
;; have run. If you want hook functions to be aware of these customizations, add
;; them to MODE-local-vars-hook instead.
(defvar doom-inhibit-local-var-hooks nil)

(defun doom-run-local-var-hooks-h ()
  "Run MODE-local-vars-hook after local variables are initialized."
  (unless (or doom-inhibit-local-var-hooks delay-mode-hooks)
    (setq-local doom-inhibit-local-var-hooks t)
    (doom-run-hooks (intern (format "%s-local-vars-hook" major-mode)))))

;; If the user has disabled `enable-local-variables', then
;; `hack-local-variables-hook' is never triggered, so we trigger it at the end
;; of `after-change-major-mode-hook':
(defun doom-run-local-var-hooks-maybe-h ()
  "Run `doom-run-local-var-hooks-h' if `enable-local-variables' is disabled."
  (unless enable-local-variables
    (doom-run-local-var-hooks-h)))


;;
;;; Incremental lazy-loading

(defvar doom-incremental-packages '(t)
  "A list of packages to load incrementally after startup. Any large packages
here may cause noticeable pauses, so it's recommended you break them up into
sub-packages. For example, `org' is comprised of many packages, and can be
broken up into:

  (doom-load-packages-incrementally
   '(calendar find-func format-spec org-macs org-compat
     org-faces org-entities org-list org-pcomplete org-src
     org-footnote org-macro ob org org-clock org-agenda
     org-capture))

This is already done by the lang/org module, however.

If you want to disable incremental loading altogether, either remove
`doom-load-packages-incrementally-h' from `emacs-startup-hook' or set
`doom-incremental-first-idle-timer' to nil. Incremental loading does not occur
in daemon sessions (they are loaded immediately at startup).")

(defvar doom-incremental-first-idle-timer (if (daemonp) 0 2.0)
  "How long (in idle seconds) until incremental loading starts.

Set this to nil to disable incremental loading.
Set this to 0 to load all incrementally deferred packages immediately at
`emacs-startup-hook'.")

(defvar doom-incremental-idle-timer 0.75
  "How long (in idle seconds) in between incrementally loading packages.")

(defun doom-load-packages-incrementally (packages &optional now)
  "Registers PACKAGES to be loaded incrementally.

If NOW is non-nil, load PACKAGES incrementally, in `doom-incremental-idle-timer'
intervals."
  (let ((gc-cons-threshold most-positive-fixnum))
    (if (not now)
        (cl-callf append doom-incremental-packages packages)
      (while packages
        (let ((req (pop packages))
              idle-time)
          (if (featurep req)
              (doom-log "start:iloader: Already loaded %s (%d left)" req (length packages))
            (condition-case-unless-debug e
                (and
                 (or (null (setq idle-time (current-idle-time)))
                     (< (float-time idle-time) doom-incremental-first-idle-timer)
                     (not
                      (while-no-input
                        (doom-log "start:iloader: Loading %s (%d left)" req (length packages))
                        ;; If `default-directory' doesn't exist or is
                        ;; unreadable, Emacs throws file errors.
                        (let ((default-directory doom-emacs-dir)
                              (inhibit-message t)
                              (file-name-handler-alist
                               (list (rassq 'jka-compr-handler file-name-handler-alist))))
                          (require req nil t)
                          t))))
                 (push req packages))
              (error
               (message "Error: failed to incrementally load %S because: %s" req e)
               (setq packages nil)))
            (if (null packages)
                (doom-log "start:iloader: Finished!")
              (run-at-time (if idle-time
                               doom-incremental-idle-timer
                             doom-incremental-first-idle-timer)
                           nil #'doom-load-packages-incrementally
                           packages t)
              (setq packages nil))))))))

(defun doom-load-packages-incrementally-h ()
  "Begin incrementally loading packages in `doom-incremental-packages'.

If this is a daemon session, load them all immediately instead."
  (when (numberp doom-incremental-first-idle-timer)
    (if (zerop doom-incremental-first-idle-timer)
        (mapc #'require (cdr doom-incremental-packages))
      (run-with-idle-timer doom-incremental-first-idle-timer
                           nil #'doom-load-packages-incrementally
                           (cdr doom-incremental-packages) t))))


;;
;;; Benchmark

(defvar doom-init-time nil
  "The time it took, in seconds, for Doom Emacs to initialize.")

(defun doom-display-benchmark-h (&optional return-p)
  "Display a benchmark including number of packages and modules loaded.

If RETURN-P, return the message as a string instead of displaying it."
  (funcall (if return-p #'format #'message)
           "Doom loaded %d packages across %d modules in %.03fs"
           (- (length load-path) (length (get 'load-path 'initial-value)))
           (hash-table-count doom-modules)
           (or doom-init-time
               (setq doom-init-time
                     (float-time (time-subtract (current-time) before-init-time))))))


;; Doom caches a lot of information in `doom-autoloads-file'. Module and package
;; autoloads, autodefs like `set-company-backend!', and variables like
;; `doom-modules', `doom-disabled-packages', `load-path', `auto-mode-alist', and
;; `Info-directory-list'. etc. Compiling them into one place is a big reduction
;; in startup time.
(condition-case-unless-debug e
    ;; Avoid `file-name-sans-extension' for premature optimization reasons.
    ;; `string-remove-suffix' is cheaper because it performs no file sanity
    ;; checks; just plain ol' string manipulation.
    (load (string-remove-suffix ".el" doom-autoloads-file) nil 'nomessage)
  (file-missing
   ;; If the autoloads file fails to load then the user forgot to sync, or
   ;; aborted a doom command midway!
   (if (locate-file doom-autoloads-file load-path)
       ;; Something inside the autoloads file is triggering this error;
       ;; forward it to the caller!
       (signal 'doom-autoload-error e)
     (signal 'doom-error
             (list "Doom is in an incomplete state"
                   "run 'doom sync' on the command line to repair it")))))

(when (and (or (display-graphic-p)
               (daemonp))
           doom-env-file)
  (setq-default process-environment (get 'process-environment 'initial-value))
  (doom-load-envvars-file doom-env-file 'noerror))

;; Bootstrap the interactive session
(add-hook 'after-change-major-mode-hook #'doom-run-local-var-hooks-h 100)
(add-hook 'hack-local-variables-hook #'doom-run-local-var-hooks-h)
(add-hook 'emacs-startup-hook #'doom-load-packages-incrementally-h)
(add-hook 'window-setup-hook #'doom-display-benchmark-h 105)
(doom-run-hook-on 'doom-first-buffer-hook '(find-file-hook doom-switch-buffer-hook))
(doom-run-hook-on 'doom-first-file-hook   '(find-file-hook dired-initial-position-hook))
(doom-run-hook-on 'doom-first-input-hook  '(pre-command-hook))

;; There's a chance the user will later use package.el or straight in this
;; interactive session. If they do, make sure they're properly initialized
;; when they do.
(autoload 'doom-initialize-packages "doom-packages")
(eval-after-load 'package '(require 'doom-packages))
(eval-after-load 'straight '(doom-initialize-packages))

;; Load all things.
(doom-initialize-modules)

(provide 'doom-start)
;;; doom-start.el ends here
