*** Settings ***
Library                       DateTime

*** Test Cases ***
Should Pause Renode
    # we test if pausing can interrupt the execution before the end of the quantum (hence testing against a value lower than 10)
    ${pause_limit}=           Convert Time           9
                              Execute Command        i @scripts/single-node/miv.resc
                              Execute Command        cpu PerformanceInMips 1
    # treat WFI as NOP because WFI might make virtual time advance too far if it has fallen behind host time
                              Execute Command        cpu WfiAsNop true
                              Execute Command        emulation SetGlobalQuantum "10"
    # we assume that starting/pausing of the simulation happens during the same quantum;
    # it seems to be a resonable expectation for the quantum value of 10 virtual seconds
                              Execute Command        s
                              Execute Command        p
    ${time_source_info}=      Execute Command        emulation GetTimeSourceInfo
    ${elapsed_matches}=       Get Regexp Matches     ${time_source_info}    Elapsed Virtual Time: ([0-9:.]+)    1
    ${elapsed}=               Convert Time           ${elapsed_matches[0]}

    Should Be True            ${elapsed} < ${pause_limit}

Should Print Last Logs
    Execute Command           i @scripts/single-node/miv.resc        
    ${logs} =                 Execute Command  lastLog
    Should Contain            ${logs}  [INFO] cpu: Setting PC value to 0x80000000.

Should Overflow Buffer
    FOR    ${i}    IN RANGE    1000
        Execute Command  log "Test-${i}-Log"
    END
    ${logs} =                 Execute Command  lastLog 1000
    Should Contain            ${logs}  Test-0-Log
    Should Contain            ${logs}  Test-999-Log
    Should Not Contain        ${logs}  Test-1000-Log
    Execute Command           log "Test-1000-Log"
    ${logs} =                 Execute Command  lastLog 1000
    Should Not Contain        ${logs}  Test-0-Log
    Should Contain            ${logs}  Test-1-Log
    Should Contain            ${logs}  Test-1000-Log

Should Load Python Standard Library
    ${result} =               Execute Command  python "import SimpleHTTPServer"
    Should Not Contain        ${result}  No module named

Should Set Proper Types To Variables

    Execute Command           \$var1=1234
    Execute Command           set var2 2345

    Execute Command           emulation SetSeed $var1
    Execute Command           emulation SetSeed $var2

Should Not Call Conditional Set

    Execute Command           \$var1=1234
    Execute Command           \$var1?=5678

    ${res}=  Execute Command  echo $\var1
    Should Be Equal           ${res.strip()}   1234

Should Call Conditional Set

    Execute Command           \$var1?=5678

    ${res}=  Execute Command  echo $\var1
    Should Be Equal           ${res.strip()}   5678

Should Call GPIO Set
    Execute Command           i @scripts/single-node/nrf52840.resc
    ${gpioState}=             Execute Command   uart0 IRQ
    Should Contain            ${gpioState}  GPIO: unset 
    Execute Command           uart0 IRQ Set true
    ${gpioState}=             Execute Command   uart0 IRQ
    Should Contain            ${gpioState}  GPIO: set 
