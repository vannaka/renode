*** Variables ***
${AGT_ELF}                          https://dl.antmicro.com/projects/renode/renesas_ek_ra8m1--agt.elf-s_390120-5dfd54a412e405b4527aba3b32e9590e668fbfcf
${UART_ELF}                         https://dl.antmicro.com/projects/renode/renesas_ek_ra8m1--sci_uart.elf-s_533288-8f668c5fbab3d6a4f0ddfb9ea4f475f623d3c001
${SPI_ELF}                          https://dl.antmicro.com/projects/renode/renesas_ek_ra8m1--sci_spi.elf-s_440972-22ac9393b23602f53292b175c4070a840135cbc8

*** Keywords ***
Prepare Machine
    [Arguments]                     ${elf}
    Execute Command                 using sysbus
    Execute Command                 mach create "ra8m1"

    Execute Command                 machine LoadPlatformDescription @platforms/boards/ek-ra8m1.repl

    Execute Command                 set bin @${elf}
    Execute Command                 macro reset "sysbus LoadELF $bin"
    Execute Command                 runMacro $reset

Prepare Segger RTT
    [Arguments]                     ${pauseEmulation}=true
    Execute Command                 machine CreateVirtualConsole "segger_rtt"
    Execute Command                 include @scripts/single-node/renesas-segger-rtt.py
    Execute Command                 setup_segger_rtt sysbus.segger_rtt
    Create Terminal Tester          sysbus.segger_rtt  defaultPauseEmulation=${pauseEmulation}

Prepare LED Tester
    Create Led Tester               sysbus.port6.led_blue

*** Test Cases ***
Should Run Periodically Blink LED
    Prepare Machine                 ${AGT_ELF}
    Prepare LED Tester
    Prepare Segger RTT

    Execute Command                 agt0 IRQ AddStateChangedHook "Antmicro.Renode.Logging.Logger.Log(LogLevel.Error, 'AGT0 ' + str(state))"
    # Timeout is only used for checking whether the IRQ has been handled
    Create Log Tester               0.001  defaultPauseEmulation=true

    # Configuration is roughly in ms
    Wait For Prompt On Uart         One-shot mode:
    Write Line To Uart              10  waitForEcho=false
    Wait For Line On Uart           Time period for one-shot mode timer: 10

    Wait For Prompt On Uart         Periodic mode:
    Write Line To Uart              5  waitForEcho=false
    Wait For Line On Uart           Time period for periodic mode timer: 5

    Wait For Prompt On Uart         Enter any key to start or stop the timers
    Write Line To Uart              waitForEcho=false

    # Timeout is extended by an additional 1ms to account for rounding errors
    Wait For Log Entry              AGT0 True  level=Error  timeout=0.011
    Wait For Log Entry              AGT0 False  level=Error
    # move to the beginning of a True state
    Assert Led State                True  timeout=0.01  pauseEmulation=true
    # Run test for 5 cycles
    Assert Led Is Blinking          testDuration=0.05  onDuration=0.005  offDuration=0.005  tolerance=0.2  pauseEmulation=true
    Assert Led State                True  timeout=0.005  pauseEmulation=true

    # Stop timers, clear log tester history and check whether the periodic timer stops
    Write Line To Uart              waitForEcho=false
    Wait For Line On Uart           Periodic timer stopped. Enter any key to start timers.
    Assert And Hold Led State       True  0.0  0.05

Should Read And Write On UART
    Prepare Machine                 ${UART_ELF}
    Execute Command                 cpu AddHook `sysbus GetSymbolAddress "bsp_clock_init"` "cpu.PC = cpu.LR"

    Create Terminal Tester          sysbus.sci2

    Wait For Line On Uart           Starting UART demo

    Write Line To Uart              56  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 56
    Wait For Line On Uart           Set next value

    Write Line To Uart              1  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 1
    Wait For Line On Uart           Set next value

    Write Line To Uart              100  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 100
    Wait For Line On Uart           Set next value

    Write Line To Uart              371  waitForEcho=false
    Wait For Line On Uart           Invalid input. Input range is from 1 - 100

    Write Line To Uart              74  waitForEcho=false
    Wait For Line On Uart           Setting intensity to: 74
    Wait For Line On Uart           Set next value

Should Read Temperature From SPI
    Prepare Machine                 ${SPI_ELF}
    Execute Command                 cpu AddHook `sysbus GetSymbolAddress "bsp_clock_init"` "cpu.PC = cpu.LR"
    Prepare Segger RTT

    # Sample expects the MAX31723PMB1 temperature sensor which there is no model for in Renode
    Execute Command                 machine LoadPlatformDescriptionFromString "sensor: Sensors.GenericSPISensor @ sci2"

    # Sensor initialization values
    Execute Command                 sci2.sensor FeedSample 0x80
    Execute Command                 sci2.sensor FeedSample 0x6
    Execute Command                 sci2.sensor FeedSample 0x0

    # Temperature of 15 °C
    Execute Command                 sci2.sensor FeedSample 0x0
    Execute Command                 sci2.sensor FeedSample 0xF
    Execute Command                 sci2.sensor FeedSample 0x0

    # Temperature of 10 °C
    Execute Command                 sci2.sensor FeedSample 0x0
    Execute Command                 sci2.sensor FeedSample 0xA
    Execute Command                 sci2.sensor FeedSample 0x0

    # Temperature of 2 °C
    Execute Command                 sci2.sensor FeedSample 0x0
    Execute Command                 sci2.sensor FeedSample 0x2
    Execute Command                 sci2.sensor FeedSample 0x0

    Wait For Line On Uart           Temperature:${SPACE*2}15.000000 *C
    Wait For Line On Uart           Temperature:${SPACE*2}10.000000 *C
    Wait For Line On Uart           Temperature:${SPACE*2}2.000000 *C
    Wait For Line On Uart           Temperature:${SPACE*2}0.000000 *C
