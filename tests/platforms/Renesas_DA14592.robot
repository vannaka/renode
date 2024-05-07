*** Variables ***
${echo_i2c_peripheral}              ${CURDIR}/echo-i2c-peripheral.py
${URL}                              https://dl.antmicro.com/projects/renode
${HELLO_WORLD_ELF}                  ${URL}/renesas-da1459x-uart_hello_world.elf-s_1302844-67f230aeae16f04f9e6e9e1ac1ab1ceb133dc2a1
${HELLO_WORLD_BIN}                  ${URL}/renesas-da1459x-uart_hello_world.bin-s_42820-89e34783fa568d03c826357dceaa80c3637c14e1
${WATCHDOG_ELF}                     ${URL}/renesas-da1459x-watchdog_sample.elf-s_1303312-8bc26c376a46712a15126400d9ededc496fd2037
${WATCHDOG_BIN}                     ${URL}/renesas-da1459x-watchdog_sample.bin-s_41400-a4756b01832abd9bd41143bd7c27db7b39db6031
${ADC_ELF}                          ${URL}/renesas-da1459x-adc_sample.elf-s_1412432-54c1b6468094ec1439f16264fe4a9447b4d69567
${ADC_BIN}                          ${URL}/renesas-da1459x-adc_sample.bin-s_42412-84790dc8f65a890e952e59353e80f4708ca4325f
${ADC_RESD}                         ${URL}/renesas_da14_gpadc.resd-s_49-d7ebebfafe5c44561381ab5c3ffe65266f0a8ad3
${GPIO_ELF}                         ${URL}/renesas-da1459x-gpio_sample.elf-s_1309028-7708a94edad0e9f9d64725c562dd18e2aebb0d96
${GPIO_BIN}                         ${URL}/renesas-da1459x-gpio_sample.bin-s_45084-d1c4c9a304a8b3176b3dc6feb89237ae3d48351a
${GPT_ELF}                          ${URL}/renesas-da1459x-gpt_sample.elf-s_1305560-b68c731499af957e243d1abdd346d8bf7c59c30f
${GPT_BIN}                          ${URL}/renesas-da1459x-gpt_sample.bin-s_44196-90bb5fd7a2da259e36db86eccfb9b6b4f6177b87
${DMA_BIN}                          ${URL}/renesas-da1459x-dma_mem_to_mem.bin-s_45332-cb73b4ea7fc562627ba10e9d64d2128527917273
${DMA_ELF}                          ${URL}/renesas-da1459x-dma_mem_to_mem.elf-s_1301508-5370b27c1b1a252e07446758579c5fefaff168a9
${FREERTOS_RETARGET_ELF}            ${URL}/renesas-da1459x-freertos_retarget.elf-s_1379120-5728b9a9cca03e23e66c32db302e356532fcfc52
${FREERTOS_RETARGET_BIN}            ${URL}/renesas-da1459x-freertos_retarget.bin-s_63072-e28ce2134937840990ae4be78a3da330595f48e8
${SPI_BIN}                          ${URL}/renesas-da1459x-spi_sample.bin-s_43188-944034990fb62e11fe2738530f1420b6e232819a
${SPI_ELF}                          ${URL}/renesas-da1459x-spi_sample.elf-s_1490188-9f030ab673cc588fb2c19ed3da3fde7d973259e7
${I2C_BIN}                          ${URL}/renesas-da1459x-i2c_sample.bin-s_36032-0cb6f278b3467dfbbf80f14b8504db7f2552c113
${I2C_ELF}                          ${URL}/renesas-da1459x-i2c_sample.elf-s_1500812-4323681e8ecb9c7ca31db357a86e0348477c6894

*** Keywords ***
Create Machine
    [Arguments]                     ${bin}  ${symbolsElf}
    Execute Command                 set bin @${bin}
    Execute Command                 set symbolsElf @${symbolsElf}
    Execute Command                 include @scripts/single-node/renesas-da14592.resc

Check Acceleration Values
    [Arguments]                     ${x}  ${y}  ${z}
    Execute Command                 sysbus.spi.adxl372 AccelerationX ${x}
    Execute Command                 sysbus.spi.adxl372 AccelerationY ${y}
    Execute Command                 sysbus.spi.adxl372 AccelerationZ ${z}

    Wait For Line On Uart           X = ${x}, Y = ${y}, Z = ${z}

Create Echo Peripheral
    Execute Command                 machine LoadPlatformDescriptionFromString "dummy: Mocks.DummyI2CSlave @ i2c 0x75"
    Execute Command                 include @${echo_i2c_peripheral}
    Execute Command                 setup_echo_i2c_peripheral "sysbus.i2c.dummy"

*** Test Cases ***
UART Should Work
    Create Machine                  ${HELLO_WORLD_BIN}    ${HELLO_WORLD_ELF}
    Create Terminal Tester          sysbus.uart1

    Wait For Line On Uart           Hello, world!

Test Watchdog
    Create Machine          ${WATCHDOG_BIN}  ${WATCHDOG_ELF}

    Create Log Tester       10
    Execute Command         logLevel -1 sysbus.wdog

    Wait For Log Entry      wdog: Ticker value set to: 0x1FFF

    # The application initializes the wdog and then loops to refresh the watchdog 100 times.
    FOR  ${i}  IN RANGE  100
        Wait For Log Entry      wdog: Ticker value set to: 0x1FFF
    END

    # After NMI exception, binary falls into while(true) loop while waiting for the watchdog to reset the machine.
    # We set the quantum and advance immediately to speed up the test.
    Execute Command         emulation SetGlobalQuantum "0.001"
    Execute Command         emulation SetAdvanceImmediately true
    # The application loops waiting for the watchdog to reset the machine.
    Wait For Log Entry      wdog: Limit reached     timeout=85
    Wait For Log Entry      wdog: Triggering IRQ
    Execute Command         pause
    # It should take about 160ms of virtual time after NMI to reset the machine.
    Execute Command         emulation RunFor "0.17"
    Wait For Log Entry      wdog: Limit reached
    Wait For Log Entry      wdog: Reseting machine

Test GPADC
    Create Machine                  ${ADC_BIN}   ${ADC_ELF}
    Create Terminal Tester          sysbus.uart1
    Execute Command                 sysbus.gpadc FeedSamplesFromRESD @${ADC_RESD} 6 6

    Wait For Line On Uart           ADC read completed
    Wait For Line On Uart           Number of samples: 21, ADC result value: 19026

GPIO Should Work
    Create Machine                  ${GPIO_BIN}    ${GPIO_ELF}
    Create Terminal Tester          sysbus.uart1

    FOR  ${i}  IN RANGE  2
        FOR  ${j}  IN RANGE  2
            Wait For Line On Uart           Initial GPIO port: ${i} pin: ${j} val: 0
            Wait For Line On Uart           Updated GPIO port: ${i} pin: ${j} val: 1
        END
    END

Timer Should Work
    Create Machine                  ${GPT_BIN}     ${GPT_ELF}
    # Sample code doesn't reload the watchdog
    Execute Command                 sysbus.wdog Enabled false
    Create Terminal Tester          sysbus.uart1  defaultPauseEmulation=true

    Wait For Line On Uart           Hello, world!
    # Timer is configured to fire approx. once per second
    Wait For Line On Uart           Timer tick!  timeout=1.1
    Wait For Line On Uart           Timer tick!  timeout=1.1
    Wait For Line On Uart           Timer tick!  timeout=1.1

DMA Should Work
    Create Machine                  ${DMA_BIN}    ${DMA_ELF}
    # Sample code doesn't reload the watchdog
    Execute Command                 sysbus.wdog Enabled false
    Create Terminal Tester          sysbus.uart1

    Wait For Line On Uart           SRC: { 0 1 2 3 4 5 6 7 8 9 }
    Wait For Line On Uart           DEST: { 0 0 0 0 0 0 0 0 0 0 }
    Wait For Line On Uart           Transfer completed
    Wait For Line On Uart           DEST: { 0 1 2 3 4 5 6 7 8 9 }

freertos_retarget Should work
    Create Machine                  ${FREERTOS_RETARGET_BIN}     ${FREERTOS_RETARGET_ELF}

    Create Terminal Tester          sysbus.uart1
    Create Log Tester               10

    # Wait for the bootrom to finish
    # At the end, it remaps the eflash to 0x0 and restarts the machine
    Wait For Log Entry              Succesfully remapped eflash to address 0x0. Restarting machine.
    Wait For Log Entry              cpu_m33: PC set to 0x200, SP set to 0x20005EF8

    Wait For Prompt On Uart           \#

Should Read Samples From ADXL372 Over SPI
    Create Machine                  ${SPI_BIN}  ${SPI_ELF}
    Execute Command                 machine LoadPlatformDescriptionFromString "adxl372: Sensors.ADXL372 @ spi 1"

    Create Terminal Tester          sysbus.uart1  defaultPauseEmulation=true

    Wait For Line On Uart           Starting SPI app test
    Wait For Line On Uart           Device ID: 0xAD
    Wait For Line On Uart           Part ID: 0xFA

    Check Acceleration Values       0  0  0
    Check Acceleration Values       1  0  0
    Check Acceleration Values       5  3  7
    Check Acceleration Values       3  56  12

Should Pass Communication Test With Sample Echo Slave
    [Tags]                   skip_windows
    Create Machine                  ${I2C_BIN}  ${I2C_ELF}

    Create Echo Peripheral
    Create Log Tester               1

    Wait For Log Entry              i2c.dummy: Test suite passed  level=Info
