#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Unit testing library for BeakerLib
#   Author: Ales Zelinka <azelinka@redhat.com>
#   Author: Petr Splichal <psplicha@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a simple unit testing library for BeakerLib.
#   Have a look at the README file to learn more about it.


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertLog comment [result] --- log a comment (with optional result)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertLog() {
    local comment="$1"
    local result="${2:-INFO}"

    # colorify known results if run on terminal
    if [ -t 1 ]; then
        case $result in
            INFO) result="\033[0;34mINFO\033[0m";;
            PASS) result="\033[0;32mPASS\033[0m";;
            FAIL) result="\033[0;31mFAIL\033[0m";;
            WARN) result="\033[0;33mWARN\033[0m";;
        esac
    fi

    # echo!
    echo -e " [ $result ] $comment"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertRun command [status] [comment] --- run command, check status, log
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertRun() {
    local command="$1"
    local expected="${2:-0}"
    local comment="${3:-Running $command}"

    # no output unless in debug mode
    if [ "$DEBUG" == "1" ]; then
        eval "$command"
    else
        eval "$command" &> /dev/null
    fi
    local status=$?

    # check status
    if [ "$status" -eq "$expected" ]; then
        assertLog "$comment" 'PASS'
        ((__INTERNAL_ASSERT_PASSED++))
    else
        assertLog "$comment" 'FAIL'
        ((__INTERNAL_ASSERT_FAILED++))
        [ "$DEBUG" == "1" ] && assertLog "Expected $expected, got $status"
    fi
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertStart name --- start an assert phase
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertStart() {
    local phase="$1"
    echo
    assertLog "Testing $phase"
    __INTERNAL_ASSERT_PHASE="$phase"
    __INTERNAL_ASSERT_PASSED="0"
    __INTERNAL_ASSERT_FAILED="0"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertEnd --- short phase summary (returns number of failed asserts)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertEnd() {
    local failed="$__INTERNAL_ASSERT_FAILED"
    local passed="$__INTERNAL_ASSERT_PASSED"
    local name="$__INTERNAL_ASSERT_PHASE"

    if [ "$failed" -gt "0" ]; then
        assertLog "Testing $name finished: $passed passed, $failed failed" "FAIL"
        [ $failed -gt 255 ] && return 255 || return $failed
    elif [ "$passed" -gt "0" ]; then
        assertLog "Testing $name finished: $passed passed, $failed failed" "PASS"
        return 0
    else
        assertLog "Testing $name finished: No assserts run" "WARN"
        return 1
    fi
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertTrue comment command --- check that command succeeded
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertTrue() {
    local comment="$1"
    local command="$2"

    assertRun "$command" 0 "$comment"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertFalse comment command --- check that command failed
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertFalse() {
    local comment="$1"
    local command="$2"

    assertRun "$command" 1 "$comment"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertGoodBad command good bad --- check for good/bad asserts in journal
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertGoodBad() {
    local command="$1"
    local good="$2"
    local bad="$3"

    if [[ -n "$good" ]]; then
        rm $BEAKERLIB_JOURNAL; rlJournalStart
        assertTrue "$good good logged for '$command'" \
                "rlPhaseStart FAIL; $command; rlPhaseEnd;
                rlJournalPrintText | grep '$good *good'"
    fi

    if [[ -n "$bad" ]]; then
        rm $BEAKERLIB_JOURNAL; rlJournalStart
        assertTrue "$bad bad logged for '$command'" \
                "rlPhaseStart FAIL; $command; rlPhaseEnd;
                rlJournalPrintText | grep '$bad *bad'"
    fi
    rm $BEAKERLIB_JOURNAL; rlJournalStart
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertParameters assert --- check missing parameters
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertParameters() {
	rm $BEAKERLIB_JOURNAL; rlJournalStart
	assertTrue "running '$1' (all parameters) must succeed" \
	"rlPhaseStart FAIL; $1 ; rlPhaseEnd ;  rlJournalPrintText |grep '1 *good'"
	local CMD=""
	for i in $1 ; do
		CMD="${CMD}${i} "
		if [ "x$CMD" == "x$1 " ] ; then break ; fi
		#echo "--$1-- --$CMD--"
		rm $BEAKERLIB_JOURNAL; rlJournalStart
		assertFalse "running just '$CMD' (missing parameters) must not succeed" \
	    "rlPhaseStart FAIL; $CMD ; rlPhaseEnd ;  rlJournalPrintText |grep '1 *good'"
	done
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Fake rhts-report-result
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rhts-report-result(){
  echo "ANCHOR NAME: $1\nRESULT: $2\n LOGFILE: $3\nSCORE: $4"
}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Self test --- run a simple self test if called as 'test.sh test'
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if [ "$1" == "test" ]; then
    result="0"

    assertStart "logging"
        assertLog "Some comment with a pass" "PASS"
        assertLog "Some comment with a fail" "FAIL"
    assertEnd
    [ "$?" -eq "1" ] || result="1"

    assertStart "passing asserts"
        assertRun "true"
        assertRun "true" 0
        assertRun "true" 0 "Checking true with assertRun"
        assertRun "false" 1
        assertRun "false" 1 "Checking false with assertRun"
        assertTrue "Checking true with assertTrue" "true"
        assertFalse "Checking false with assertFalse" "false"
    assertEnd
    [ "$?" -eq "0" ] || result="1"

    assertStart "failing asserts"
        assertRun "false"
        assertRun "false" 0
        assertRun "false" 0 "Checking false with assertRun"
        assertRun "true" 1
        assertRun "true" 1 "Checking true with assertRun"
        assertTrue "Checking false with assertTrue" "false"
        assertFalse "Checking true with assertFalse" "true"
    assertEnd
    [ "$?" -eq "7" ] || result="1"

    exit $result
fi



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Run the tests
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# set important variables & start journal
export BEAKERLIB="$PWD/.."
export TESTID='123456'
export TEST='beakerlib-unit-tests'
. ../beakerlib.sh
export __INTERNAL_JOURNALIST="$BEAKERLIB/python/journalling.py"
export OUTPUTFILE=`mktemp`
rlJournalStart

TotalFails="0"
FileList=""
TestList=""

# check parameters for test list
for arg in "$@"; do
    # selected test function
    [[ "$arg" =~ 'test_' ]] && TestList="$TestList $arg"
    # test file
    [[ "$arg" =~ 'Test.sh' ]] && FileList="$FileList $arg"
done

# unless test files specified run all available
[[ -z "$FileList" ]] && FileList="`ls *Test.sh`"

# load all test functions
for file in $FileList; do
    . $file || { echo "Could not load $file"; exit 1; }
done

# run all tests
if [[ -z "$TestList" ]]; then
    for file in $FileList; do
        assertStart ${file%Test.sh}
        for test in `grep -o '^test_[^ (]*' $file`; do
            assertLog "Running $test"
            $test
        done
        assertEnd
        ((TotalFails+=$?))
    done
# run selected tests only
else
    for test in $TestList; do
        assertStart "$test"
        $test
        assertEnd
        ((TotalFails+=$?))
    done
fi

# clean up
rm -rf $BEAKERLIB_DIR

# print summary
echo
assertLog "Total summary" "INFO"
if [ $TotalFails -gt 0 ]; then
    assertLog "$TotalFails tests failed" "FAIL"
else
    assertLog "All tests passed" "PASS"
fi

# exit
echo
[ $TotalFails -gt 255 ] && exit 255 || exit $TotalFails
