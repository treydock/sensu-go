#!/usr/bin/env bash
set -o pipefail
set -e

REPO_PATH="github.com/sensu/sensu-go"

eval $(go env)

cmd=${1:-"all"}

if [ "$GOARCH" == "amd64" ]; then
	RACE="-race"
fi

install_deps () {
	go get github.com/axw/gocov/gocov
	go get gopkg.in/alecthomas/gometalinter.v1
	go get github.com/gordonklaus/ineffassign
	go get github.com/jgautheron/goconst/cmd/goconst
	go get -u github.com/golang/lint/golint
}

build_tool_binary () {
	local goos=$1
	local goarch=$2
	local cmd=$3

	local outfile="target/${goos}-${goarch}/${cmd}"

	GOOS=$goos GOARCH=$goarch go build -o $outfile ${REPO_PATH}/tools/${cmd}/...

	echo $outfile
}

build_binary () {
	local goos=$1
	local goarch=$2
	local cmd=$3

	local outfile="target/${goos}-${goarch}/sensu-${cmd}"

	GOOS=$goos GOARCH=$goarch go build -o $outfile ${REPO_PATH}/${cmd}/cmd/...

	echo $outfile
}

build_tools () {
	echo "Running tool builds..."

	for cmd in cat false sleep true; do
		build_tool $cmd
	done
}

build_tool () {
	local cmd=$1

	if [ ! -d bin/ ]; then
		mkdir -p bin/
	fi

	echo "Building $cmd for ${GOOS}-${GOARCH}"
	out=$(build_tool_binary $GOOS $GOARCH $cmd)
	rm -f bin/$(basename $out)
	cp ${out} bin
}

build_commands () {
	echo "Running build..."

	for cmd in agent backend cli; do
		build_command $cmd
	done
}

build_command () {
	local cmd=$1

	if [ ! -d bin/ ]; then
		mkdir -p bin/
	fi

	echo "Building $cmd for ${GOOS}-${GOARCH}"
	out=$(build_binary $GOOS $GOARCH $cmd)
	rm -f bin/$(basename $out)
	cp ${out} bin
}

linter_commands () {
	echo "Running linter..."

	gometalinter.v1 --vendor --disable-all --enable=vet --enable=vetshadow --enable=golint --enable=ineffassign --enable=goconst --tests ./...
	if [ $? -ne 0 ]; then
		echo "Linting failed..."
		exit 1
	fi
}

test_commands () {
	echo "Running tests..."

	echo "" > coverage.txt
	for pkg in $(go list ./... | egrep -v '(testing|vendor)'); do
		go test -timeout=60s -v $RACE -coverprofile=profile.out -covermode=atomic $pkg
		if [ -f profile.out ]; then
			cat profile.out >> coverage.txt
			rm profile.out
		fi
	done
}

e2e_commands () {
	echo "Running e2e tests..."

	go test -v ${REPO_PATH}/testing/e2e
}

docker_commands () {
	for cmd in agent backend; do
		echo "Building $cmd for linux-amd64"
		out=$(build_binary linux amd64 $cmd)
	done
	docker build -t sensu/sensu .
}

if [ "$cmd" == "deps" ]; then
	install_deps
elif [ "$cmd" == "quality" ]; then
	linter_commands
	test_commands
elif [ "$cmd" == "lint" ]; then
	linter_commands
elif [ "$cmd" == "unit" ]; then
	test_commands
elif [ "$cmd" == "build_tools" ]; then
	build_tools
elif [ "$cmd" == "e2e" ]; then
	e2e_commands
elif [ "$cmd" == "build" ]; then
	build_commands
elif [ "$cmd" == "docker" ]; then
	docker_commands
elif [ "$cmd" == "build_agent" ]; then
	build_command agent
elif [ "$cmd" == "build_backend" ]; then
	build_command backend
elif [ "$cmd" == "build_cli" ]; then
	build_command cli
else
	install_deps
	linter_commands
	build_tools
	test_commands
	build_commands
	e2e_commands
fi