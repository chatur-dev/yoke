.PHONY: app install test

app:
	scripts/build-app.sh

install:
	scripts/build-app.sh --install

test:
	swift test
