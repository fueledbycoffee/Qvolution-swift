/* Native dlopen/dlsym probe. Inputs must name this lane's own built images. */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc < 3 || !(argc & 1)) {
        fprintf(stderr, "usage: %s IMAGE EXPORTS [IMAGE EXPORTS ...]\n", argv[0]);
        return 2;
    }
    unsigned checked = 0;
    for (int i = 1; i < argc; i += 2) {
        FILE *names = fopen(argv[i + 1], "r");
        if (!names) { perror(argv[i + 1]); return 2; }
        void *image = dlopen(argv[i], RTLD_NOW | RTLD_LOCAL);
        if (!image) { fprintf(stderr, "dlopen %s: %s\n", argv[i], dlerror()); return 1; }
        char symbol[2048];
        unsigned count = 0;
        while (fgets(symbol, sizeof(symbol), names)) {
            symbol[strcspn(symbol, "\r\n")] = 0;
            if (!symbol[0]) continue;
#ifdef __APPLE__
            const char *lookup = symbol[0] == '_' ? symbol + 1 : symbol;
#else
            const char *lookup = symbol;
#endif
            dlerror();
            void *address = dlsym(image, lookup);
            const char *error = dlerror();
            if (!address || error) {
                fprintf(stderr, "%s: missing %s (%s)\n", argv[i], symbol, error ? error : "null");
                return 1;
            }
            ++count;
        }
        if (ferror(names) || !count) { fprintf(stderr, "invalid or empty export list\n"); return 2; }
        fclose(names);
        dlerror();
        (void)dlsym(image, "qv_intentionally_missing_export");
        if (!dlerror()) { fprintf(stderr, "negative lookup unexpectedly succeeded\n"); return 1; }
        printf("%s: %u exports loaded; negative lookup passed\n", argv[i], count);
        checked += count;
        dlclose(image);
    }
    return checked ? 0 : 2;
}
