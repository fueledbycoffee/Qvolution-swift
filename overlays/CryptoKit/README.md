# AEAD support for the Darling CryptoKit framework

The shipped CryptoKit subset supplies SHA256 and HMAC. This focused build retains
that source and adds the public AES-GCM and ChaCha20-Poly1305 API declarations from
upstream swift-crypto 3.12.3. Both source revisions are pinned in `build.sh`; source
files are extracted into the build directory without modifying the supplied clone.
The upstream files retain their Apache-2.0 notices. `AEAD.swift` routes the APIs to
the runtime's existing LibreSSL implementation through `aead.c`.

The bridge returns failure when authentication fails and clears partial plaintext.
It supports AES keys of 128, 192 and 256 bits and 256-bit ChaCha20 keys. It does
not add other CryptoKit algorithms. The current C backend links libcrypto.44.

Use the same environment as `../build.sh`, plus:

- `DARLING_SOURCE_ROOT`: the Darling superproject checkout.
- `CRYPTOKIT_SOURCE`: a clone of `https://github.com/cristim/swift-crypto.git`
  containing base commit `c4105ade5fbe6866375ec65146cac733d53a1146` and upstream
  3.12.3 commit `e8d6eba1fef23ae5b359c46b03f7d94be2f41fed`.
  The base includes the runtime's existing Darling SHA256/HMAC backend.
- `OVERLAY_BUILD_DIR`: an overlay build containing the Foundation Swift module.
- `CRYPTOKIT_FRAMEWORK_PATH`: optional directory containing the installed
  `CryptoKit.framework`, for the test client. The default is the build directory.
  The test links with `-framework CryptoKit` and still uses the matching emitted
  source module from the build directory to compile.
- `CRYPTOKIT_ARCH`: `arm64` (default) or `x86_64`. The C backend, Swift module,
  framework link and test client all use this architecture.
- `CRYPTOKIT_BUILD_DIR`: optional separate output directory. Defaults to `build`
  for arm64 and `build-x86_64` for x86_64, so the two builds do not overwrite each
  other.

The selected target also requires matching Darwin Swift standard library modules
and shims in `SWIFT_RESOURCE_DIR`, matching source-built Foundation/Darwin modules
in `OVERLAY_BUILD_DIR/modules`, and matching Darling libraries and `DARLING_CRT1`.
A Linux Swift compiler alone does not supply Darwin standard library modules.
Build these from licensed Swift sources and Darling headers; this script does not
extract modules or headers from an Apple SDK. An arm64 Foundation module cannot
serve as the x86_64 input. The compiler rejects a module for the wrong target.

Run `CRYPTOKIT_ARCH=x86_64 sh build.sh` for x86_64 or `sh build.sh` for arm64. The output is `CryptoKit` in the build directory; the shipped
framework is not replaced automatically. `tests/main.swift` checks NIST GCM
vectors, RFC 8439 section 2.8.2, authentication rejection, key and nonce validation,
and the existing SHA256 API. Compile it against the emitted CryptoKit module and
run it under the same Darling prefix that will run the application.

The motivating imports came from the unmodified Roon 2.74 build 1712 guest's
`libSystem.Security.Cryptography.Native.Apple.dylib`, using only `llvm-nm -u -m`
for interface names. No binary implementation was inspected.

To include the generated executable in a staged Darling installation, configure
Darling with `-DDARLING_CRYPTOKIT_BINARY=/absolute/build/path/CryptoKit` after this
build completes, then use its normal staged install. This explicit option
works for either architecture and changes the executable installed in the existing
versioned framework layout, always named `CryptoKit`;
it does not commit or copy compiled output into the source tree. Without the
option, arm64 installation retains the repository's existing prebuilt subset;
other architectures do not install that arm64 artifact. Select the generated
artifact for the configured runtime target. The superproject's Swift dylib map
must use the same override when linking clients.

Run `sh tests/run.sh` with the same environment, including `CRYPTOKIT_ARCH`, to compile the authored vector
fixture. It prints the executable path; run that executable under Darling with
this build directory supplied through `DYLD_FRAMEWORK_PATH` (the script creates
the framework layout). No application data or secret test keys are used.

An emitted module and a matching module name do not establish full Swift ABI
compatibility. Before installing a new target, verify the architecture on your
own build output, run the typed vector client (including RFC 4231 HMAC-SHA256),
and compile and run a normal client against the installed framework. The vectors
cover only the implemented SHA256/HMAC and AEAD surface. SHA384/512, SHA3,
MD5/SHA1, HKDF, signatures and key agreement remain outside this focused build;
application compatibility requires exercising the application's actual imports.

For the installed-client check, set `CRYPTOKIT_FRAMEWORK_PATH` to the staged
runtime's `System/Library/Frameworks` directory, compile with `tests/run.sh`, and
run that client using the installed runtime. The script never modifies this
explicit framework directory. Run without a framework search override when
checking normal installed loader resolution.
