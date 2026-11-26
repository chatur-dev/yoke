.PHONY: app install test dmg release

app:
	scripts/build-app.sh

install:
	scripts/build-app.sh --install

test:
	swift test

dmg:
	scripts/release.sh

release:
	scripts/release.sh --publish
