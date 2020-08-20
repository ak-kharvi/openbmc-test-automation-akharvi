*** Settings ***

Documentation  Test OpenBMC GUI "Server power operations" sub-menu of "Server control".

Resource        ../../lib/resource.robot

Suite Setup     Launch Browser And Login GUI
Suite Teardown  Close Browser
Test Setup      Test Setup Execution


*** Variables ***

${xpath_enable_onetime_boot_checkbox}      //*[contains(@class,'custom-checkbox')]
${xpath_boot_option_select}                //*[@id='boot-option']

${xpath_shutdown_button}    //*[@data-test-id='serverPowerOperations-button-shutDown']
${xpath_reboot_button}      //*[@data-test-id='serverPowerOperations-button-reboot']
${xpath_poweron_button}     //*[@data-test-id='serverPowerOperations-button-powerOn']


*** Test Cases ***

Verify Existence Of All Input Boxes In Host Os Boot Settings
    [Documentation]  Verify existence of all input boxes in host os boot settings.
    [Tags]  Verify_Existence_Of_Input_Boxes_In_Host_Os_Boot_Settings

    Page Should Contain Element  ${xpath_enable_onetime_boot_checkbox}
    Page Should Contain Element  ${xpath_boot_option_select}


Verify Existence Of All Sections In Host Os Boot Settings
    [Documentation]  Verify existence of all sections in host os boot settings.
    [Tags]  Verify_Existence_Of_All_Sections_In_Host_Os_Boot_Settings

    Page Should Contain  Boot settings override
    Page Should Contain  TPM required policy


Verify Existence Of All Sections In Server Power Operations Page
    [Documentation]  Verify existence of all sections in Server Power Operations page.
    [Tags]  Verify_Existence_Of_All_Sections_In_Server_Power_Operations_Page

    Page Should Contain  Current status
    Page Should Contain  Host OS boot settings
    Page Should Contain  Operations


Verify PowerOn Button Should Present At Power Off
    [Documentation]  Verify existence of poweron button at power off.
    [Tags]  Verify_PowerOn_Button_Should_Present_At_Power_Off

    Redfish Power Off  stack_mode=skip
    # TODO: Implement power off using GUI later.
    Page Should Contain Element  ${xpath_poweron_button}


Verify Shutdown And Reboot Buttons Presence At Power On
    [Documentation]  Verify existence of shutdown and reboot buttons at power on.
    [Tags]  Verify_Shutdown_And_Reboot_Buttons_Presence_At_Power_On

    Redfish Power On  stack_mode=skip
    # TODO: Implement power on using GUI later.
    Page Should Contain Element  ${xpath_shutdown_button}
    Page Should Contain Element  ${xpath_reboot_button}


*** Keywords ***

Test Setup Execution
    [Documentation]  Do test case setup tasks.

    Click Element  ${xpath_control_menu}
    Click Element  ${xpath_server_power_operations_sub_menu}
    Wait Until Keyword Succeeds  30 sec  10 sec  Location Should Contain  server-power-operations
