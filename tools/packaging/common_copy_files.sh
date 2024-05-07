rm -rf $DIR
mkdir -p $DIR/{bin,licenses,tests,tools,plugins}

#copy the main content
cp -r $BASE/output/bin/$TARGET/*.dll $DIR/bin
cp -r $BASE/output/bin/$TARGET/libllvm-disas.* $DIR/bin
cp -r $BASE/output/bin/$TARGET/*.dll.config $DIR/bin 2>/dev/null || true

if ls $BASE/output/bin/$TARGET/*.exe
then
    cp -r $BASE/output/bin/$TARGET/*.exe $DIR/bin
fi

cp -r $BASE/{.renode-root,scripts,platforms} $DIR
cp -r $BASE/tools/execution_tracer $DIR/tools
cp -r $BASE/tools/gdb_compare $DIR/tools
cp -r $BASE/tools/metrics_analyzer $DIR/tools
cp -r $BASE/tools/sel4_extensions $DIR/tools
cp -r $BASE/tools/csv2resd $DIR/tools
cp -r $BASE/src/Plugins/VerilatorPlugin/VerilatorIntegrationLibrary $DIR/plugins

#copy the test instrastructure and update the paths
cp -r $BASE/tests/metrics-analyzer $DIR/tests/metrics-analyzer
cp -r $BASE/tests/network-server $DIR/tests/network-server
cp -r $BASE/tests/peripherals $DIR/tests/peripherals
cp -r $BASE/tests/platforms $DIR/tests/platforms
cp -r $BASE/tests/{robot_tests_provider,run_tests,tests_engine,robot_output_formatter,robot_output_formatter_verbose,helper}.py $DIR/tests
cp -r $BASE/tests/{renode-keywords,example}.robot $DIR/tests
cp -r $BASE/tests/tools $DIR/tests/tools
cp -r $BASE/tests/unit-tests $DIR/tests/unit-tests
$SED_COMMAND '/nunit/d' $DIR/tests/run_tests.py

# `tests.yaml` should only list robot files included in the original tests.yaml
sed '/csproj$/d' $BASE/tests/tests.yaml > $DIR/tests/tests.yaml

cp $BASE/lib/resources/styles/robot.css $DIR/tests/robot.css
cp $BASE/tests/requirements.txt $DIR/tests/requirements.txt

$BASE/tools/packaging/common_copy_licenses.sh $DIR/licenses $OS_NAME

$BASE/tools/packaging/common_copy_dts2repl_version_script.sh $BASE $DIR

function copy_bash_tests_scripts() {
    TEST_SCRIPT=$1
    COMMON_SCRIPT=$2
    RUNNER=$3

    cp -r $BASE/renode-test $TEST_SCRIPT
    $SED_COMMAND 's#tools/##' $TEST_SCRIPT
    $SED_COMMAND 's#tests/run_tests.py#run_tests.py#' $TEST_SCRIPT
    $SED_COMMAND 's#--properties-file.*#--robot-framework-remote-server-full-directory='"$INSTALL_DIR"'/bin --css-file='"$INSTALL_DIR"'/tests/robot.css -r $(pwd) --runner='$RUNNER' "$@"#' $TEST_SCRIPT
    $SED_COMMAND 's#^ROOT_PATH=".*#ROOT_PATH="'"$INSTALL_DIR"'/tests"#g' $TEST_SCRIPT
    $SED_COMMAND '/TESTS_FILE/d' $TEST_SCRIPT
    $SED_COMMAND '/TESTS_RESULTS/d' $TEST_SCRIPT

    cp -r $BASE/tools/common.sh $COMMON_SCRIPT
}
