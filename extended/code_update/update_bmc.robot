*** Settings ***
Documentation     Trigger code update to a target BMC.
...               Execution Method :
...               python -m robot -v OPENBMC_HOST:<hostname>
...               -v FILE_PATH:<path/*all.tar>  update_bmc.robot
...
...               Code update method BMC using REST
...               Update work flow sequence:
...                 - User input BMC File existence check
...                 - Ping Test and REST authentication
...                 - Set Host Power host setting Policy to RESTORE_LAST_STATE
...                   On reboot this policy would ensure the BMC comes
...                   online and stays at HOST_POWERED_OFF state.
...                 - Issue poweroff
...                 - Prune archived journal logs
...                 - Prepare for Update
...                 - Wait for BMC to come online clean
...                 - Wait for BMC_READY state
...                 - Apply preserve BMC Network setting
...                 - SCP image to BMC
...                 - Activate the flash image
...                 - Warm Reset BMC to activate code
...                 - Wait for BMC to come online time out 30 minutes
...                 - Version check post update

Resource          code_update_utils.robot
Resource          ../../lib/boot/boot_resource_master.robot
Resource          ../../lib/state_manager.robot
Resource          ../../lib/utils.robot

*** Variables ***

${FILE_PATH}       ${EMPTY}

# There are two reboots issued by code update.
${MAX_BOOT_COUNT}  ${2}

*** Test Cases ***

Test Basic BMC Performance Before Code Update
    [Documentation]   Check performance of memory, CPU & file system of BMC.
    [Tags]  Test_Basic_BMC_Performance_Before_Code_Update
    Open Connection And Log In
    Check BMC CPU Performance
    Check BMC Mem Performance
    Check BMC File System Performance

Initiate Code Update BMC
    [Documentation]  BMC code update process initiation
    [Setup]  Set State Interface Version
    [Tags]  Initiate_Code_Update_BMC

    Check If File Exist  ${FILE_PATH}
    System Readiness Test
    ${status}=   Run Keyword and Return Status
    ...   Validate BMC Version   before

    Run Keyword if  '${status}' == '${False}'
    ...     Pass Execution   Same Driver version installed

    Check Boot Count And Time
    Prune Journal Log
    Power Off Request
    Run Keyword And Ignore Error
    ...   Set Policy Setting   RESTORE_LAST_STATE
    Prepare For Update

    # Wait time is increased temporary to 10 mins due
    # to openbmc/openbmc#673
    Check If BMC is Up    10 min   10 sec
    Check Boot Count And Time

    Wait For BMC Ready

    # TODO: openbmc/openbmc#815
    Sleep  1 min

    Preserve BMC Network Setting
    SCP Tar Image File to BMC   ${FILE_PATH}

    Activate BMC flash image

    Run Keyword And Ignore Error    Trigger Warm Reset
    # Warm reset adds 3 seconds delay before forcing reboot
    # To minimize race conditions, we wait for 7 seconds
    Sleep  7s
    ${session_active}=   Check If warmReset is Initiated
    Run Keyword If   '${session_active}' == '${True}'
    ...    Trigger Warm Reset via Reboot

    Check If BMC is Up    30 min   10 sec
    Check Boot Count And Time
    Sleep  1 min
    Validate BMC Version

    # Now that the code update is completed, make sure we use the correct
    # interface while checking for BMC ready state.
    Set State Interface Version
    Wait For BMC Ready
    Check Boot Count And Time
    Run Keyword If  ${BOOT_COUNT} == ${1}
    ...  Log  Boot Time not Updated by Kernel!!!  level=WARN


Test Basic BMC Performance At Ready State
    [Documentation]   Check performance of memory, CPU & file system of BMC.
    [Tags]  Test_Basic_BMC_Performance_At_Ready_State
    Open Connection And Log In
    Check BMC CPU Performance
    Check BMC Mem Performance
    Check BMC File System Performance

*** Keywords ***

Check Boot Count And Time
    [Documentation]  Check for unexpected reboots.
    Set BMC Reset Reference Time
    Log To Console  \n Boot Count: ${BOOT_COUNT}
    Log To Console  \n Boot Time: ${BOOT_TIME}
    Run Keyword If  ${BOOT_COUNT} > ${MAX_BOOT_COUNT}
    ...  Log  Phantom Reboot!!! Unexpected reboot detected  level=WARN

