*** Keywords ***
Test Memory
    [Arguments]  ${address}  ${expected_value}
    ${actual_value}=         Execute Command  sysbus ReadDoubleWord ${address}
    Should Be Equal As Numbers    ${actual_value}  ${expected_value}

Execute Loop And Verify Counter
    [Arguments]  ${expected_value}
    Execute Command          sysbus.cpu Step 2
    Test Memory              0xf0000004  ${expected_value}

*** Test Cases ***
Should Parse Monitor in CPU Hook
    Execute Command          include @scripts/single-node/miv.resc
    Execute Command          cpu AddHook `cpu PC` "monitor.Parse('log \\"message from the cpu hook\\"')"

    Create Log Tester        1
    Start Emulation

    Wait For Log Entry       message from the cpu hook


Should Stop On Peripheral Read Watchpoint
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString "cpu: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    Execute Command          machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command          machine PyDevFromFile @scripts/pydev/counter.py 0xf0000004 0x4 True "ctr"

    # counter should increment on every read on sysbus
    Test Memory              0xf0000004  0x0
    Test Memory              0xf0000004  0x1

    # ldrb r0, [r1]
    Execute Command          sysbus WriteDoubleWord 0x10 0xe5d10000
    # b 0x10
    Execute Command          sysbus WriteDoubleWord 0x14 0xeafffffd

    Execute Command          sysbus.cpu PC 0x10
    Execute Command          sysbus.cpu SetRegisterUnsafe 1 0xf0000004
    Execute Command          sysbus.cpu ExecutionMode SingleStepBlocking
    Execute Command          start

    # add an empty watchpoint
    Execute Command          sysbus AddWatchpointHook 0xf0000004 1 Read ""

    # make sure nothing read the counter after adding the watchpoint
    Test Memory              0xf0000004  0x2

    # it's expected for counter to increase by 2 as a result of
    # executing the `ldrb` instruction followed by the memory test
    Execute Loop And Verify Counter   0x4
    Execute Loop And Verify Counter   0x6
    Execute Loop And Verify Counter   0x8


Should Count Correct Number Of Instructions On Read Watchpoint
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString "cpu: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    Execute Command          machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command          sysbus.cpu PC 0x10

    # prepare a block of code
    # containing precisely 12 instructions
    # consisting mostly of `nops` with
    # a single `ldrb` inbetween

    #  1: nop
    Execute Command          sysbus WriteDoubleWord 0x10 0xe320f000
    #  2: nop
    Execute Command          sysbus WriteDoubleWord 0x14 0xe320f000
    #  3: nop
    Execute Command          sysbus WriteDoubleWord 0x18 0xe320f000
    #  4: nop
    Execute Command          sysbus WriteDoubleWord 0x1c 0xe320f000
    #  5: nop
    Execute Command          sysbus WriteDoubleWord 0x20 0xe320f000
    #  6: nop
    Execute Command          sysbus WriteDoubleWord 0x24 0xe320f000
    #  7: nop
    Execute Command          sysbus WriteDoubleWord 0x28 0xe320f000
    #  8: ldrb r0, [r1]
    Execute Command          sysbus WriteDoubleWord 0x2c 0xe5d10000
    #  9: nop
    Execute Command          sysbus WriteDoubleWord 0x30 0xe320f000
    # 10: nop
    Execute Command          sysbus WriteDoubleWord 0x34 0xe320f000
    # 11: nop
    Execute Command          sysbus WriteDoubleWord 0x38 0xe320f000
    # 12: nop
    Execute Command          sysbus WriteDoubleWord 0x3c 0xe320f000

    # add a logging watchpoint
    Execute Command          sysbus AddWatchpointHook 0x0 1 Read "cpu.Log(LogLevel.Info, 'Watchpoint hook at PC: {}'.format(cpu.PC))"
    # add a block begin hook to verify if we count executed instructions correctly
    Execute Command          sysbus.cpu SetHookAtBlockBegin "cpu.Log(LogLevel.Info, 'BlockBegin hook at PC: {} with {} executed instructions'.format(cpu.PC, cpu.ExecutedInstructions))"

    Create Log Tester        0

    ${cnt}=                  Execute Command  sysbus.cpu ExecutedInstructions
    Should Be Equal As Numbers          ${cnt}  0

    # execute precisely 12 instructions
    Execute Command          sysbus.cpu PerformanceInMips 1
    Execute Command          emulation RunFor "0.000012"

    # verify if the watchpoint was triggered on a correct instruction
    Wait For Log Entry       Watchpoint hook at PC: 0x2c

    # verify if we count executed instructions corectly; the watchpoint should:
    # * interrupt the block and start a new one;
    # * trigger before executing the `ldrb` instruction, hence 7
    Wait For Log Entry       BlockBegin hook at PC: 0x2c with 7 executed instructions

    # make sure we don't see any other log entries related to watchpoints or block begin hooks
    Should Not Be In Log     Watchpoint hook
    Should Not Be In Log     BlockBegin hook

    # verify if we executed the block to the end (after handling the watchpoint once)
    ${cnt}=                  Execute Command  sysbus.cpu PC
    Should Be Equal As Numbers          ${cnt}  0x40

    ${cnt}=                  Execute Command  sysbus.cpu ExecutedInstructions
    Should Be Equal As Numbers          ${cnt}  12


Should Count on Uart Access
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString "cpu: CPU.ARMv7A @ sysbus { cpuType: \\"cortex-a9\\" }"
    Execute Command          machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x1000 }"
    Execute Command          machine LoadPlatformDescriptionFromString "uart: UART.TrivialUart @ sysbus 0x2000"
    Execute Command          sysbus.cpu PC 0x10

    Create Terminal Tester   sysbus.uart

    # prepare a block of code
    # containing precisely 12 instructions
    # consisting mostly of `nops` with
    # a single `strb` inbetween

    #  1: nop
    Execute Command          sysbus WriteDoubleWord 0x10 0xe320f000
    #  2: nop
    Execute Command          sysbus WriteDoubleWord 0x14 0xe320f000
    #  3: nop
    Execute Command          sysbus WriteDoubleWord 0x18 0xe320f000
    #  4: nop
    Execute Command          sysbus WriteDoubleWord 0x1c 0xe320f000
    #  5: nop
    Execute Command          sysbus WriteDoubleWord 0x20 0xe320f000
    #  6: nop
    Execute Command          sysbus WriteDoubleWord 0x24 0xe320f000
    #  7: nop
    Execute Command          sysbus WriteDoubleWord 0x28 0xe320f000
    #  8: strb r0, [r1]
    Execute Command          sysbus WriteDoubleWord 0x2c 0xe5c10000
    #  9: nop
    Execute Command          sysbus WriteDoubleWord 0x30 0xe320f000
    # 10: nop
    Execute Command          sysbus WriteDoubleWord 0x34 0xe320f000
    # 11: nop
    Execute Command          sysbus WriteDoubleWord 0x38 0xe320f000
    # 12: nop
    Execute Command          sysbus WriteDoubleWord 0x3c 0xe320f000

    # 'x'
    Execute Command          sysbus.cpu SetRegisterUnsafe 0 120
    Execute Command          sysbus.cpu SetRegisterUnsafe 1 0x2000

    Wait For Prompt On Uart  x     pauseEmulation=true

    ${cnt}=                  Execute Command  sysbus.cpu PC
    Should Be Equal As Numbers          ${cnt}  0x2c

    ${cnt}=                  Execute Command  sysbus.cpu ExecutedInstructions
    Should Be Equal As Numbers          ${cnt}  8
