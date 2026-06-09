# XplorerRemap — build & bundle without Xcode or an Apple Developer account.

APP       = XplorerRemap
BUNDLE_ID = com.brody.xplorer-remap
VERSION  ?= 0.1.0
DIST      = dist
FLAGS    ?=
# Ad-hoc signature by default; set SIGN_ID="My Self-Signed Cert" for a stable
# identity that survives rebuilds (keeps the Accessibility grant valid).
SIGN_ID  ?= -

BUNDLE = $(DIST)/$(APP).app

.PHONY: build universal app zip run dev probe test clean

build:
	swift build -c release $(FLAGS)

# Universal (arm64 + x86_64) binary — SPM lipos it automatically.
universal:
	$(MAKE) build FLAGS="--arch arm64 --arch x86_64"

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp "$$(swift build -c release $(FLAGS) --show-bin-path)/$(APP)" $(BUNDLE)/Contents/MacOS/$(APP)
	sed -e 's/__VERSION__/$(VERSION)/g' Support/Info.plist > $(BUNDLE)/Contents/Info.plist
	printf 'APPL????' > $(BUNDLE)/Contents/PkgInfo
	codesign --force -s "$(SIGN_ID)" --identifier $(BUNDLE_ID) $(BUNDLE)
	@echo "→ $(BUNDLE)"

zip: app
	ditto -c -k --keepParent $(BUNDLE) $(DIST)/$(APP)-$(VERSION).zip
	@echo "→ $(DIST)/$(APP)-$(VERSION).zip"

run: app
	open $(BUNDLE)

# Dev loop: launched from the terminal, so the *terminal's* Accessibility
# grant covers CGEventPost — no per-rebuild TCC re-granting.
dev:
	swift run $(APP)

probe:
	swift run xplorer-probe

test:
	swift test

clean:
	swift package clean
	rm -rf $(DIST)
