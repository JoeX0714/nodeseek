SHELL := /bin/bash
.SHELLFLAGS := -e -u -o pipefail -c

PROJECT ?= nodeseek.xcodeproj
SCHEME ?= nodeseek
CONFIGURATION ?= Debug
SIMULATOR_ID ?= F1FA4EFA-0399-438E-AC84-9326D32938E4
DERIVED_DATA ?= .build/XcodeDerivedData
SOURCE_PACKAGES ?= .build/SourcePackages

CORE_TEST_CLASSES := \
	KannaNodeSeekParserTests \
	ChallengeDetectorTests \
	DetailImageLayoutTests \
	NodeSeekServiceTests \
	NodeSeekCommentSubmitterTests \
	CommentComposerContentBuilderTests

XCODE_COMMON = \
	-project "$(PROJECT)" \
	-scheme "$(SCHEME)" \
	-configuration "$(CONFIGURATION)" \
	-destination "platform=iOS Simulator,id=$(SIMULATOR_ID)" \
	-derivedDataPath "$(DERIVED_DATA)" \
	-clonedSourcePackagesDirPath "$(SOURCE_PACKAGES)" \
	CODE_SIGNING_ALLOWED=NO \
	-parallel-testing-enabled NO \
	-maximum-concurrent-test-simulator-destinations 1

.PHONY: help spm-test xcode-build-tests xcode-test-core xcode-test-class xcode-test-full

help:
	@printf '%s\n' \
		'Available commands:' \
		'  make help' \
		'  make spm-test' \
		'  make xcode-build-tests' \
		'  make xcode-test-core' \
		'  make xcode-test-class TEST=KannaNodeSeekParserTests' \
		'  make xcode-test-full'

spm-test:
	swift test

xcode-build-tests:
	xcodebuild -quiet build-for-testing $(XCODE_COMMON)

xcode-test-core: xcode-build-tests
	xcodebuild -quiet test-without-building $(XCODE_COMMON) $(addprefix -only-testing:nodeseekTests/,$(CORE_TEST_CLASSES))

xcode-test-class: xcode-build-tests
	@test -n "$(TEST)" || { echo "Usage: make xcode-test-class TEST=KannaNodeSeekParserTests" >&2; exit 2; }
	TEST="$(TEST)"; xcodebuild -quiet test-without-building $(XCODE_COMMON) -only-testing:nodeseekTests/$$TEST

xcode-test-full:
	xcodebuild -quiet test $(XCODE_COMMON)
