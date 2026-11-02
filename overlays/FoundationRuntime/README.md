# Offline matching Foundation runtime build (x86_64)


`build-runtime-inputs.sh` and `build-module-inputs.sh` compile the complete
existing overlay source sets with an explicit selected compiler and runtime.
They originate in darling-swift commit 9de50722116a2f6773b3b49d0db8f2bfddfcbde4;
the dependency pins remain unchanged, including swift-foundation at dbacc67779dc.
The additional sorting inputs are described below.
They do not implement the newer NSURLSession async data(for:delegate:) APIs.
The imports-sweep-a audit marks both imports weak; they remain unsupported.
Use these overlays only with the complete matching Swift 6.3.3 core/overlays,
never mixed into the Swift 5.2.2 runtime. See parallel/swift-runtime/README.md
in the fleet work area for the private configured-install selector.

The Foundation import manifest in tests/foundation-imports/exports.txt is a
regression set of demanded names provided by this real source build. The shared
Darwin dlopen fixture is in darling-foundation test/imports/load-exports.c.
Whole-module source compilation and static export availability do not establish
runtime or application compatibility. The orchestrator must run the dlopen test.

CocoaError.Code additionally exposes the ten audited getters from the published
Error/ErrorCodes.swift table at the same swift-foundation pin. Values agree with
vendored FoundationErrors.h; coderReadCorrupt=4864 is also specified in public
swift-corelibs-foundation NSError.swift. The Swift compiler emits their ABI.

The source selection also includes the unchanged pinned
FoundationEssentials/SortComparator.swift: SortComparator, SortOrder, optional
and comparable comparators, and collection sorting. It uses the existing
ComparisonResult alias; the compiler emits the Foundation ABI. String comparators
use the same pin's framework branch, patched privately by
prepare-sort-sources.sh because Darling already exposes NSString comparison.
Key-path comparators use the same pin, including the published Sendable
key-path adaptation from PredicateExpression.swift. The String special case uses
the framework branch so default string sorting stays localized-standard.
The compiler emits every exported entry point.
