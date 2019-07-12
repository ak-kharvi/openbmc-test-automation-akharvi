*** Settings ***
Documentation    Test BMC manager time functionality.
Resource                     ../../lib/resource.robot
Resource                     ../../lib/bmc_redfish_resource.robot
Resource                     ../../lib/common_utils.robot
Resource                     ../../lib/openbmc_ffdc.robot
Resource                     ../../lib/utils.robot
Resource                     ../../lib/rest_client.robot
Library                      ../../lib/gen_robot_valid.py

Test Teardown                Test Teardown Execution
Suite Setup                  Suite Setup Execution
Suite Teardown               Suite Teardown Execution

*** Variables ***
${max_time_diff_in_seconds}  6
${invalid_datetime}          "2019-04-251T12:24:46+00:00"
${ntp_server_1}              "9.9.9.9"
${ntp_server_2}              "2.2.3.3"
&{original_ntp}              &{EMPTY}

*** Test Cases ***

Verify Redfish BMC Time
    [Documentation]  Verify that date/time obtained via redfish matches
    ...  date/time obtained via BMC command line.
    [Tags]  Verify_Redfish_BMC_Time

    ${redfish_date_time}=  Redfish Get DateTime
    ${cli_date_time}=  CLI Get BMC DateTime
    ${time_diff}=  Subtract Date From Date  ${cli_date_time}
    ...  ${redfish_date_time}
    ${time_diff}=  Evaluate  abs(${time_diff})
    Rprint Vars  redfish_date_time  cli_date_time  time_diff
    Should Be True  ${time_diff} < ${max_time_diff_in_seconds}
    ...  The difference between Redfish time and CLI time exceeds the allowed time difference.


Verify Set Time Using Redfish
    [Documentation]  Verify set time using redfish API.
    [Tags]  Verify_Set_Time_Using_Redfish

    Rest Set Time Owner

    ${old_bmc_time}=  CLI Get BMC DateTime
    # Add 3 days to current date.
    ${new_bmc_time}=  Add Time to Date  ${old_bmc_time}  3 Days
    Redfish Set DateTime  ${new_bmc_time}
    ${cli_bmc_time}=  CLI Get BMC DateTime
    ${time_diff}=  Subtract Date From Date  ${cli_bmc_time}
    ...  ${new_bmc_time}
    ${time_diff}=  Evaluate  abs(${time_diff})
    Rprint Vars   old_bmc_time  new_bmc_time  cli_bmc_time  time_diff  max_time_diff_in_seconds
    Should Be True  ${time_diff} < ${max_time_diff_in_seconds}
    ...  The difference between Redfish time and CLI time exceeds the allowed time difference.
    # Setting back to old bmc time.
    Redfish Set DateTime  ${old_bmc_time}


Verify Set DateTime With Invalid Data Using Redfish
    [Documentation]  Verify error while setting invalid DateTime using Redfish.
    [Tags]  Verify_Set_DateTime_With_Invalid_Data_Using_Redfish

    Redfish Set DateTime  ${invalid_datetime}  valid_status_codes=[${HTTP_BAD_REQUEST}]


Verify DateTime Persists After Reboot
    [Documentation]  Verify date persists after BMC reboot.
    [Tags]  Verify_DateTime_Persists_After_Reboot

    # Synchronize BMC date/time to local system date/time.
    ${local_system_time}=  Get Current Date
    Redfish Set DateTime  ${local_system_time}
    Redfish OBMC Reboot (off)
    Redfish.Login
    ${bmc_time}=  CLI Get BMC DateTime
    ${local_system_time}=  Get Current Date
    ${time_diff}=  Subtract Date From Date  ${bmc_time}
    ...  ${local_system_time}
    ${time_diff}=  Evaluate  abs(${time_diff})
    Rprint Vars   local_system_time  bmc_time  time_diff  max_time_diff_in_seconds
    Should Be True  ${time_diff} < ${max_time_diff_in_seconds}
    ...  The difference between Redfish time and CLI time exceeds the allowed time difference.


Verify NTP Server Set
    [Documentation]  Verify NTP server set.
    [Tags]  Verify_NTP_Server_Set

    Redfish.Patch  ${REDFISH_NW_PROTOCOL_URI}  body={'NTPServers': ['${ntp_server_1}', '${ntp_server_2}']}
    ${network_protocol}=  Redfish.Get Properties  ${REDFISH_NW_PROTOCOL_URI}
    Should Contain  ${network_protocol["NTP"]["NTPServers"]}  ${ntp_server_1}
    ...  msg=NTP server value ${ntp_server_1} not stored.
    Should Contain  ${network_protocol["NTP"]["NTPServers"]}  ${ntp_server_2}
    ...  msg=NTP server value ${ntp_server_2} not stored.


Verify NTP Server Value Not Duplicated
    [Documentation]  Verify NTP servers value not same for both primary and secondary server.
    [Tags]  Verify_NTP_Server_Value_Not_Duplicated

    Redfish.Patch  ${REDFISH_NW_PROTOCOL_URI}  body={'NTPServers': ['${ntp_server_1}', '${ntp_server_1}']}
    ${network_protocol}=  Redfish.Get Properties  ${REDFISH_NW_PROTOCOL_URI}
    Should Contain X Times  ${network_protocol["NTP"]["NTPServers"]}  ${ntp_server_1}  1
    ...  msg=NTP primary and secondary server values should not be same.


Verify NTP Server Setting Persist After BMC Reboot
    [Documentation]  Verify NTP server setting persist after BMC reboot.
    [Tags]  Verify_NTP_Server_Setting_Persist_After_BMC_Reboot

    Redfish.Patch  ${REDFISH_NW_PROTOCOL_URI}  body={'NTPServers': ['${ntp_server_1}', '${ntp_server_2}']}
    Redfish OBMC Reboot (off)
    Redfish.Login
    ${network_protocol}=  Redfish.Get Properties  ${REDFISH_NW_PROTOCOL_URI}
    Should Contain  ${network_protocol["NTP"]["NTPServers"]}  ${ntp_server_1}
    ...  msg=NTP server value ${ntp_server_1} not stored.
    Should Contain  ${network_protocol["NTP"]["NTPServers"]}  ${ntp_server_2}
    ...  msg=NTP server value ${ntp_server_2} not stored.


Verify Enable NTP
    [Documentation]  Verify NTP protocol mode can be enabled.
    [Teardown]  Restore NTP Mode
    [Tags]  Verify_Enable_NTP

    ${original_ntp}=  Redfish.Get Attribute  ${REDFISH_NW_PROTOCOL_URI}  NTP
    Set Suite Variable  ${original_ntp}
    Rprint Vars  original_ntp  fmt=terse
    # The following patch command should set the ["NTP"]["ProtocolEnabled"] property to "True".
    Redfish.Patch  ${REDFISH_NW_PROTOCOL_URI}  body={u'NTPEnabled': ${True}}
    ${ntp}=  Redfish.Get Attribute  ${REDFISH_NW_PROTOCOL_URI}  NTP
    Rprint Vars  ntp  fmt=terse
    Rvalid Value  ntp["ProtocolEnabled"]  valid_values=[True]


*** Keywords ***


Test Teardown Execution
    [Documentation]  Do the post test teardown.

    FFDC On Test Case Fail


Redfish Get DateTime
    [Documentation]  Returns BMC Datetime value from Redfish.

    ${date_time}=  Redfish.Get Attribute  ${REDFISH_BASE_URI}Managers/bmc  DateTime
    [Return]  ${date_time}


Redfish Set DateTime
    [Documentation]  Set DateTime using Redfish.
    [Arguments]  ${date_time}  &{kwargs}
    # Description of argument(s):
    # date_time                     New time to set for BMC (eg.
    #                               "2019-06-30 09:21:28").
    # kwargs                        Additional parms to be passed directly to
    #                               th Redfish.Patch function.  A good use for
    #                               this is when testing a bad date-time, the
    #                               caller can specify
    #                               valid_status_codes=[${HTTP_BAD_REQUEST}].

    Redfish.Patch  ${REDFISH_BASE_URI}Managers/bmc  body={'DateTime': '${date_time}'}
    ...  &{kwargs}


Rest Set Time Owner
    [Documentation]  Set time owner of the system via REST.

    # BMC_OWNER is defined in variable.py.
    ${data}=  Create Dictionary  data=${BMC_OWNER}
    Write Attribute  ${TIME_MANAGER_URI}owner  TimeOwner  data=${data}  verify=${TRUE}

Restore NTP Mode
    [Documentation]  Restore the original NTP mode.


    Return From Keyword If  &{original_ntp} == &{EMPTY}
    Print Timen  Restore NTP Mode.
    Redfish.Patch  ${REDFISH_NW_PROTOCOL_URI}
    ...  body={u'NTPEnabled': ${original_ntp["ProtocolEnabled"]}}


Suite Setup Execution
    [Documentation]  Do the suite level setup.

    Printn
    Redfish.Login
    Rest Set Time Owner

Suite Teardown Execution
    [Documentation]  Do the suite level teardown.
    Rest Set Time Owner
    Redfish.Logout
