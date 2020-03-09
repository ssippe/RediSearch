#!/bin/bash

set -e
set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT=$(realpath $HERE/..)
cd $ROOT

./.circleci/ci_get_deps.sh

SAN_PREFIX=/opt/san

mode=$1
extra_flags=""

if [[ $ASAN == 1 ]]; then
	mode=asan
    extra_flags="-DUSE_ASAN=ON"
elif [[ $MASN == 1 ]]; then
	mode=masn
    extra_flags="-DUSE_MSAN=ON -DMSAN_PREFIX=${SAN_PREFIX}"
else
    echo "Should define either ASAN=1 or MASN=1"
    exit 1
fi

mkdir -p build-${mode}
cd build-${mode}

cmake -DCMAKE_BUILD_TYPE=DEBUG \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DRS_RUN_TESTS=ON \
    $extra_flags \
    ..

if [[ -z $CI_CONCURRENCY ]]; then
	CI_CONCURRENCY=$($ROOT/deps/readies/bin/nproc)
fi

make -j$CI_CONCURRENCY

## Add some configuration options to our rltest file

cat >rltest.config <<EOF
--oss-redis-path=${SAN_PREFIX}/bin/redis-server-${mode}
--no-output-catch
--exit-on-failure
--check-exitcode
--unix
EOF

export ASAN_OPTIONS=detect_odr_violation=0

# FIXME: Need to change the image once this actually works..
ln -sf /usr/bin/llvm-symbolizer-4.0 /usr/bin/llvm-symbolizer || true

ctest --output-on-failure -j$CI_CONCURRENCY