#!/bin/sh
# Fixtures for the member-order rule.
#
# Asks: is a member in the right place, and — far more important — does the check stay quiet
# about the shapes that are already right? A rule that fires on idiomatic code is worse than no
# rule at all, because every finding after the first one stops being read.
#
# Three orderings are measured: properties above the methods, properties widest-visibility
# first, methods widest-visibility first. The call-order half of the rule is deliberately not
# measured — it needs a call graph, and this engine reads lines — so nothing here asserts on it.
#
# The must-not-flag half is where the value is. Four shapes would each produce a wall of false
# findings on real code:
#
#   the Kotlin backing-property pair, which is public-after-private on purpose
#   a constructor sitting between the fields and the methods, which is not a method
#   a local val inside a method body, which is not a member
#   a nested type, whose members belong to it rather than to its parent
#
# Run: sh plugins/general-code-style/tests/test_member_order.sh

set -u
HERE=$(dirname "$0")
LIB=$HERE/../hooks/lib
WORK=${TMPDIR:-/tmp}/member-order-test.$$
FAILURES=0

trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK"

check() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2" >&2
    FAILURES=$((FAILURES + 1))
}

# The findings themselves, one per line as "name<TAB>line<TAB>reason".
order_of() {
    awk -f "$LIB/limits.awk" -f "$LIB/text.awk" -f "$LIB/sizes.awk" -f "$LIB/blocks.awk" \
        -f "$LIB/members.awk" -f "$LIB/comments.awk" -f "$HERE/probe.awk" \
        -v mode=order -v path="x.$1" -v ext="$1" -- "$2"
}

# The members the walk found, one per line as "name<TAB>kind<TAB>visibility<TAB>line".
members_of() {
    awk -f "$LIB/limits.awk" -f "$LIB/text.awk" -f "$LIB/sizes.awk" -f "$LIB/blocks.awk" \
        -f "$LIB/members.awk" -f "$LIB/comments.awk" -f "$HERE/probe.awk" \
        -v mode=members -v path="x.$1" -v ext="$1" -- "$2"
}

count_order() { order_of "$1" "$2" | grep -c . | tr -d ' '; }
reason_for()  { order_of "$1" "$2" | awk -v n="$3" '$1 == n { print $3 }'; }

# --- must flag ---------------------------------------------------------------

cat > "$WORK/bad.kt" <<'EOF'
class Order {
    private val a = 1
    val b = 2

    fun submit() {
        check()
    }

    private val late = 3

    private fun check() {
        verify()
    }

    fun cancel() {
        undo()
    }
}
EOF

check "a public property below a private one is flagged" \
    "$(reason_for kt "$WORK/bad.kt" b)" "property-visibility"
check "a property among the methods is flagged" \
    "$(reason_for kt "$WORK/bad.kt" late)" "property-below-method"
check "a public method below a private one is flagged" \
    "$(reason_for kt "$WORK/bad.kt" cancel)" "method-visibility"
check "and nothing else in it is" "$(count_order kt "$WORK/bad.kt")" "3"

# A misplaced property is reported once, as a move, rather than twice for its visibility too.
check "one finding per member" \
    "$(order_of kt "$WORK/bad.kt" | awk '$1 == "late"' | grep -c . | tr -d ' ')" "1"

cat > "$WORK/Acct.java" <<'EOF'
public class Acct {
    public static final String TAG = "acct";
    private final Ledger ledger;

    public Acct(Ledger ledger) {
        this.ledger = ledger;
    }

    public void post(int cents) {
        ledger.add(cents);
    }

    private int fee;

    private void audit() {
        ledger.flush();
    }

    public void close() {
        audit();
    }
}
EOF

check "a typed field among the methods is flagged" \
    "$(reason_for java "$WORK/Acct.java" fee)" "property-below-method"
check "a public method after a private one is flagged" \
    "$(reason_for java "$WORK/Acct.java" close)" "method-visibility"

cat > "$WORK/svc.ts" <<'EOF'
export class Svc {
  private readonly http: Http;
  public label: string;

  constructor(http: Http) {
    this.http = http;
  }

  private send(): void {
    this.http.go();
  }

  public run(): void {
    this.send();
  }
}
EOF

# TypeScript methods carry no declaration keyword, so blocks.awk cannot see them at all. If
# member_method_at() regresses, this file goes silent rather than wrong — which is why the
# method finding is asserted here and not only the property one.
check "a TypeScript field's visibility is read" \
    "$(reason_for ts "$WORK/svc.ts" label)" "property-visibility"
check "a TypeScript method with no keyword is still a method" \
    "$(reason_for ts "$WORK/svc.ts" run)" "method-visibility"

cat > "$WORK/two.kt" <<'EOF'
class First {
    val ok = 1

    fun go() {
        run()
    }
}

class Second {
    private val a = 1
    val b = 2
}
EOF

check "each type is measured on its own" "$(count_order kt "$WORK/two.kt")" "1"
check "and the finding belongs to the second one" \
    "$(reason_for kt "$WORK/two.kt" b)" "property-visibility"

# --- must not flag -----------------------------------------------------------

cat > "$WORK/vm.kt" <<'EOF'
class FooViewModel : ViewModel() {

    private val _state = MutableStateFlow(UiState())
    val state = _state.asStateFlow()

    private val _events = MutableSharedFlow<Event>()
    val events = _events.asSharedFlow()

    fun onClick() {
        helper()
    }

    private fun helper() {
        doThing()
    }

    companion object {
        const val TAG = "Foo"
    }
}
EOF

# The single most common shape in the stack this plugin ships beside. Flagging it would make
# the rule unusable on any Kotlin project.
check "the backing-property pair is not a finding" "$(count_order kt "$WORK/vm.kt")" "0"
check "and a companion object at the bottom is not one either" \
    "$(members_of kt "$WORK/vm.kt" | grep -c TAG | tr -d ' ')" "0"

cat > "$WORK/near.kt" <<'EOF'
class Near {
    private val a = 1
    val b = 2
}
EOF

# The carve-out is a reference to the private member, not mere adjacency. `val b = 2` holds an
# `a` inside `val`, so a substring test rather than an identifier test would go quiet here.
check "adjacency alone does not excuse a public property" \
    "$(reason_for kt "$WORK/near.kt" b)" "property-visibility"

cat > "$WORK/Ctor.java" <<'EOF'
public class Ctor {
    public String name;

    public Ctor(String name) {
        this.name = name;
    }

    private int cache;

    public void go() {
        cache = 1;
    }
}
EOF

# typed_name() matches `public Ctor(String name) {`, so without constructor classification every
# field below a constructor becomes a finding.
check "a constructor is not a method" "$(count_order java "$WORK/Ctor.java")" "0"

cat > "$WORK/locals.kt" <<'EOF'
class Calc {
    private val rate = 2

    fun total(items: List<Int>): Int {
        val sum = items.sum()
        var out = sum * rate
        return out
    }
}
EOF

check "a local val is not a member" "$(count_order kt "$WORK/locals.kt")" "0"
check "and the walk sees only the real ones" \
    "$(members_of kt "$WORK/locals.kt" | grep -c . | tr -d ' ')" "2"

cat > "$WORK/nested.kt" <<'EOF'
class Outer {
    val visible = 1

    fun run() {
        go()
    }

    class Inner {
        private val hidden = 2
        val shown = 3
    }
}
EOF

check "a nested type's members are not its parent's" "$(count_order kt "$WORK/nested.kt")" "0"

cat > "$WORK/iface.kt" <<'EOF'
interface Gateway {
    val id: String
    fun charge(cents: Int): Boolean
    fun refund(cents: Int): Boolean
}
EOF

check "an interface with no bodies is quiet" "$(count_order kt "$WORK/iface.kt")" "0"

cat > "$WORK/tidy.kt" <<'EOF'
class Tidy {
    val name = "n"
    internal val scope = 1
    protected val guard = 2
    private val secret = 3

    fun open() {
        prepare()
    }

    internal fun sync() {
        prepare()
    }

    private fun prepare() {
        touch()
    }
}
EOF

check "a correctly ordered type is quiet" "$(count_order kt "$WORK/tidy.kt")" "0"

cat > "$WORK/real.kt" <<'EOF'
class ReporteViewModel : ViewModel() {

    private val _input = MutableStateFlow(ReporteInput())
    private val dateFormat = SimpleDateFormat("dd MMM yyyy", Locale("es"))
    private val itemDateFormat = SimpleDateFormat("d MMM, HH:mm", Locale("es"))

    val uiState = combine(
        _input,
        repository.observe()
    ) { input, rows ->
        buildState(input, rows)
    }

    private fun buildState(input: ReporteInput, rows: List<Row>): State {
        return State(rows)
    }
}
EOF

# The exposed property names its backing field on a continuation line, and two unrelated private
# properties sit between the pair. Matching only the line above, or only the property directly
# above, reports this — and it is ordinary Kotlin.
check "a backing field named below the declaration line still counts" \
    "$(count_order kt "$WORK/real.kt")" "0"

cat > "$WORK/companion.kt" <<'EOF'
class CrearUsuarioViewModel : ViewModel() {

    private companion object {
        const val TAG = "CrearUsuarioViewModel"
    }

    private val _state = MutableStateFlow(FormState())
    val state = _state.asStateFlow()

    fun onSubmit() {
        save()
    }

    private fun save() {
        repository.store()
    }
}
EOF

# `private companion object {` has no name, so a type check that requires one reads it as a
# property called `object` and its constants as members of the class around it.
check "a private companion object is a type, not a property" \
    "$(count_order kt "$WORK/companion.kt")" "0"
check "and its constants are not the parent's members" \
    "$(members_of kt "$WORK/companion.kt" | grep -c TAG | tr -d ' ')" "0"

cat > "$WORK/data.kt" <<'EOF'
class Builder {
    private val cache = mutableMapOf<String, String>()

    fun build(): Content {
        return render(Request("a", "b"))
    }

    private fun render(request: Request): Content {
        return Content(request.first)
    }

    private data class Request(
        val first: String,
        val second: String
    )

    private data class Content(
        val text: String
    )
}
EOF

# A nested data class with no body: end_of_block() counts braces from the line it is handed, so
# on `private data class Request(` it returns the next line and the walk falls into the primary
# constructor, reading `val first` and `val second` as properties of Builder.
check "a body-less nested data class is stepped over whole" \
    "$(count_order kt "$WORK/data.kt")" "0"
check "and its constructor properties are not the parent's" \
    "$(members_of kt "$WORK/data.kt" | grep -c 'first\|second' | tr -d ' ')" "0"

# --- languages outside the set -----------------------------------------------

cat > "$WORK/out.js" <<'EOF'
class Thing {
  constructor() { this.a = 1; }
  run() { this.help(); }
  help() { return 2; }
}
EOF

cat > "$WORK/out.py" <<'EOF'
class Thing:
    def run(self):
        return self.help()

    def help(self):
        return 2
EOF

# Every check reads a visibility keyword. A language without one is not measured rather than
# guessed at, so these must produce nothing at all.
check "javascript is outside the rule" "$(count_order js "$WORK/out.js")" "0"
check "python is outside the rule" "$(count_order py "$WORK/out.py")" "0"

# --- the advisory the hook actually prints -----------------------------------

advise_for() {
    awk -f "$LIB/limits.awk" -f "$LIB/text.awk" -f "$LIB/sizes.awk" -f "$LIB/blocks.awk" \
        -f "$LIB/members.awk" -f "$LIB/comments.awk" -f "$LIB/measure.awk" \
        -v path="$2" -v ext="$1" -- "$3" \
        | awk -f "$LIB/limits.awk" -f "$LIB/findings.awk" -f "$LIB/advise.awk" -v scope=""
}

advisory=$(advise_for kt Order.kt "$WORK/bad.kt")

check "the advisory names the member" \
    "$(printf '%s' "$advisory" | grep -c 'property `late`' | tr -d ' ')" "1"
check "and says where it belongs" \
    "$(printf '%s' "$advisory" | grep -c 'property block at the top' | tr -d ' ')" "1"
check "and names the tier order for a method" \
    "$(printf '%s' "$advisory" | grep -c 'method `cancel`' | tr -d ' ')" "1"

# --- the identity key, which is what carries a finding to a hook --------------

keys_for() {
    awk -f "$LIB/limits.awk" -f "$LIB/text.awk" -f "$LIB/sizes.awk" -f "$LIB/blocks.awk" \
        -f "$LIB/members.awk" -f "$LIB/comments.awk" -f "$LIB/measure.awk" \
        -v path="$2" -v ext="$1" -- "$3" \
        | awk -f "$LIB/limits.awk" -f "$LIB/keys.awk" -v emit=1
}

# A record type with no key_of() case returns "" and is dropped by both introduced.awk and
# unseen.awk — measured, visible in the sweep, and silently never reaching a hook.
check "an ordering finding has an identity key" \
    "$(keys_for kt Order.kt "$WORK/bad.kt" | grep -c '^ORDER:' | tr -d ' ')" "3"
check "and the key is the reason and the name, not the line" \
    "$(keys_for kt Order.kt "$WORK/bad.kt" | grep -c '^ORDER:property-below-method:late$' | tr -d ' ')" "1"

if [ "$FAILURES" -eq 0 ]; then
    echo "PASSED — 0 failures"
    exit 0
fi
printf 'FAILED — %s failures\n' "$FAILURES"
exit 1
