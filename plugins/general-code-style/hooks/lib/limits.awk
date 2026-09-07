# The caps every part of the plugin measures against.
#
# One definition, loaded by the hooks, the sweep, and the tests, so a post-write advisory and
# a whole-tree sweep can never disagree about a limit. Extensions are held without their dot.

function init_limits(   t, n, i) {
    FILE_LIMIT = 250          # 200 target + 50 spare
    FUNCTION_LIMIT = 10       # 7 target + 3 spare
    PARAM_LIMIT = 3
    DECL_SPAN = 12            # lines a parameter list may wrap across before we give up
    MAX_WARNINGS = 5          # advisories shown before the rest are summarised as a count

    # Growth that makes an already-oversized file the turn's problem rather than inherited
    # debt. A turn that adds a line to a 260-line file did not create that file's shape; one
    # that adds this many owns the result. Set to the spare above the 200-line target, so
    # raising FILE_LIMIT's allowance moves both together.
    GROWTH_LIMIT = 50

    n = split("kt kts java js jsx ts tsx swift c cc cpp h hpp cs go rs scala php dart " \
              "gradle groovy", t, " ")
    for (i = 1; i <= n; i++) { BRACE[t[i]] = 1; MEASURED[t[i]] = 1; SOURCE[t[i]] = 1 }

    INDENT["py"] = 1; MEASURED["py"] = 1; SOURCE["py"] = 1

    # Measured for file length only — no body strategy fits them. Ruby needs def/end
    # matching, .vue and .svelte mix markup with script, and the rest are simply languages
    # the declaration patterns were never written for.
    n = split("rb sh bash zsh ps1 awk sql m mm vue svelte lua pl pm r jl ex exs erl " \
              "hs clj cljs elm zig nim cr tf proto vb pas rkt scm el d", t, " ")
    for (i = 1; i <= n; i++) { FILE_ONLY[t[i]] = 1; SOURCE[t[i]] = 1 }

    # Languages whose declarations key on a keyword, so the typed Java/C# pattern is not
    # consulted for them.
    n = split("kt kts swift go rs js jsx ts tsx php scala dart gradle groovy", t, " ")
    for (i = 1; i <= n; i++) KEYWORD[t[i]] = 1

    # Languages whose member order is measured. Narrower than BRACE on purpose: every check
    # reads a visibility keyword off a declaration, so a language that has none cannot be
    # measured honestly. js/jsx, go and dart have no visibility keywords, rs puts `pub` on
    # items in an impl block, the C family uses `public:` section labels — a different shape
    # entirely — and py has only the leading-underscore convention. Adding one here means its
    # fields must match property_at() first.
    n = split("kt kts java cs ts tsx swift php scala", t, " ")
    for (i = 1; i <= n; i++) ORDERED[t[i]] = 1

    # Class members with no declaration keyword to key on. blocks.awk cannot see these:
    # decl_name() needs fun/func/function, and typed_name() is not consulted for a KEYWORD
    # language. The member walk recognises them itself, which is only safe because it runs at
    # depth 1 of a type body, where a control-flow line cannot appear.
    n = split("ts tsx", t, " ")
    for (i = 1; i <= n; i++) IMPLICIT_METHOD[t[i]] = 1

    n = split("@Composable|@Preview|React.FC|: FC<|some View", t, "|")
    UI_N = n
    for (i = 1; i <= n; i++) UI_MARKERS[i] = t[i]
}
