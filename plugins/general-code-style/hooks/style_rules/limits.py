"""The caps every part of the plugin measures against.

One definition, imported by the hook, the sweep, and the tests, so a post-write advisory
and a whole-tree sweep can never disagree about a limit.
"""

FILE_LIMIT = 250          # 200 target + 50 spare
FUNCTION_LIMIT = 10       # 7 target + 3 spare
PARAM_LIMIT = 3
DECL_SPAN = 12            # lines a parameter list may wrap across before we give up
MAX_WARNINGS = 5          # advisories shown before the rest are summarised as a count

BRACE_LANGS = {'.kt', '.kts', '.java', '.js', '.jsx', '.ts', '.tsx', '.swift', '.c', '.cc',
               '.cpp', '.h', '.hpp', '.cs', '.go', '.rs', '.scala', '.php', '.dart',
               '.gradle', '.groovy'}
INDENT_LANGS = {'.py'}
MEASURED_LANGS = BRACE_LANGS | INDENT_LANGS
# Measured for file length only — no body strategy fits them. Ruby needs `def`/`end`
# matching, .vue and .svelte mix markup with script, and the rest are simply languages the
# declaration patterns were never written for.
FILE_ONLY_LANGS = {'.rb', '.sh', '.bash', '.zsh', '.ps1', '.sql', '.m', '.mm', '.vue',
                   '.svelte', '.lua', '.pl', '.pm', '.r', '.jl', '.ex', '.exs', '.erl',
                   '.hs', '.clj', '.cljs', '.elm', '.zig', '.nim', '.cr', '.tf', '.proto',
                   '.vb', '.pas', '.rkt', '.scm', '.el', '.d'}

# The one scope. The hook measures a written file only if its extension is here, and the
# sweep opens a file only if its extension is here, so the two can never disagree about
# whether something is in scope.
#
# An allow-list rather than a deny-list because the sweep reads whole files: anything else
# means walking a tree full of images, archives, and build output. The cost is that a
# language nobody listed goes unmeasured — add it above rather than widening the rule.
#
# Prose (.md, .rst, .txt) and data (.json, .yaml, .xml, .lock) are absent on purpose. A long
# document is a document and a long resource table is additive; neither becomes harder to
# read at line 251, and "split it into child classes" is not advice that applies to them.
SOURCE_EXTS = MEASURED_LANGS | FILE_ONLY_LANGS
