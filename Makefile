PYTHON ?= python3
SWIFT ?= swift

.PHONY: check test-python test-swift build-swift

# Run both clients against the shared contract fixtures without touching user files.
check: test-python test-swift build-swift

test-python:
	$(PYTHON) -m unittest discover -s Tests/Python -v

test-swift:
	sh Tools/check-swift.sh

build-swift:
	$(SWIFT) build
