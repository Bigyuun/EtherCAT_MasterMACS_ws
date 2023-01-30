#pragma once
#include <SysDef.mh>
//#include "C:\Users\bigyu\Desktop\Github repositories_Bigyuun\EtherCAT_MasterMACS_ws\include\SDK\SDK_ApossC.mc"
#include "..\include\SDK\SDK_ApossC.mc"
#include "..\include\user_definition.mh"
#include "..\include\EtherCAT_config.mc"

long slaveCount, i,j,k, homingState,slaveState;

// DY
long status_sm = -1;

#define DEBUG_FLAG 					0
#define SINE_WAVE_TEST_FLAG 		1

#define STATE_MACHINE_ID_EtherCAT 	1
#define STATE_MACHINE_ID_TCP		2

#define PI 3.1415926
#define SINE_WAVE_NORMAL_TIME		2.0 * PI			// normal
#define SINE_WAVE_TIME  			2000				// time per 1 wave (ms)
#define SINE_WAVE_AMP				10
#define SINE_WAVE_TIMER_FREQ        1000   // 1 kHz
#define SINE_WAVE_TIMER_DURATION    1/SINE_WAVE_TIMER_FREQ  // 1 ms

dim double pos[7]={0}, vel[7]={0}, acc[7]={0};
long cnt_sine_wave = 0;


#if 1
/*********************************************************************
**              State Machine Version of Program
*********************************************************************/

/*********************************************************************
** State Machine Setup Parameters
*********************************************************************/

#pragma SmConfig {    1,        // Runtime flags.
                      200,       // Event pool size.
                      10,        // Maximum number of timers.
                      400,        // Subscribe pool size.
                      400,       // Param pool size.
                      0,        // Position pool size.
                      20 }       // System signal pool size (used for SmSystem.)
/*********************************************************************
** Event Definitions
*********************************************************************/

SmEvent SIG_PLAY { }
SmEvent SIG_STOP { }
SmEvent SIG_CLEAR { }
SmEvent SIG_REINIT { }
SmEvent SIG_PREOP { }
SmEvent SIG_OP { }
SmEvent SIG_ENABLE { }
SmEvent SIG_DISABLE { }

SmEvent TICK_EtherCAT_MasterCommand{}
SmEvent TICK_EtherCAT_Callback_SlaveFeedback{}
SmEvent TICK_Configure_SineWave{}
SmEvent TICK_TCP_Receive{}
SmEvent TICK_TCP_Send{}

long configure_EtherCAT();
/*********************************************************************
** State Definitions
*********************************************************************/


SmState EtherCAT_Handler
{
                SIG_INIT = {
                            //long cnt = 0;
                            //print(status_sm) 	// 전역변수 전달 필요
                            SmSubscribe(id, SIG_ERROR);
                            SmParam (0x01220105, 1, SM_PARAM_EQUAL, id, SIG_PLAY);
                            SmParam (0x01220105, 2, SM_PARAM_EQUAL, id, SIG_STOP);
                            SmParam (0x01220105, 3, SM_PARAM_EQUAL, id, SIG_CLEAR);
                            SmParam (0x01220105, 4, SM_PARAM_EQUAL, id, SIG_REINIT);
                            SmParam (0x01220105, 5, SM_PARAM_EQUAL, id, SIG_PREOP);
                            SmParam (0x01220105, 6, SM_PARAM_EQUAL, id, SIG_OP);
                            SmParam (0x01220105, 7, SM_PARAM_EQUAL, id, SIG_ENABLE);
                            SmParam (0x01220105, 8, SM_PARAM_EQUAL, id, SIG_DISABLE);
                            print("State Machine(EtherCAT) Init done");
                            print("pos[0] = ", pos[0]);
                            return(SmTrans(->Standing));
                            }

                SIG_ERROR = {
                            long errAxis, errNo;
                            errAxis = ErrorAxis();
                            errNo = ErrorNo();
                            print("errAxis : ", errAxis, " / errNo : ", errNo);
                            return(SmTrans(->Standing));
                            }

	SmState Standing
    {
				SIG_ENTRY  = 	{
                                SmPeriod(1, id, TICK_EtherCAT_MasterCommand);
                                print("into the Standing State ");
                                print("Default User Parameter(USER_PARAM) = ", USER_PARAM(5));
                                USER_PARAM(5) = 7;
								}

				SIG_START = 	{
								data[0]++;
								if(data[0]%5000==0) print("data[0] = ", data[0]);
								if(data[0] == 200000) data[0]=0;
								print("data[0] = ", data[0]);
								Delay(1);
								}

				SIG_IDLE = 		{
								data[1]++;
								if(data[1]%5000==0) print("data[1] = ", data[1]);
								if(data[1] == 100000) data[1]=0;
								print("data[1] = ", data[1]);
								Delay(1);

								}

                // DY - If TCP state machine receive the message, this timer will be update the value
                TICK_EtherCAT_MasterCommand =
                			{
                          	Cvel(C_AXIS1, pos[0]);	// set velocity (CSV)
  							USER_PARAM(5) = 1;		// start moving
                            }




                SIG_PLAY	  = {
                				#if DEBUG_FLAG
                                print("PLAY");
                                #endif

                                AxisCvelStart(C_AXIS1);
                                Sysvar[0x01220105] = 0;
                            }
                SIG_STOP	  = {
                                print("STOP");
                                AxisStop(AXALL);
                                Sysvar[0x01220105] = 0;
                            }
                SIG_REINIT =  {
                				return(SmTrans(Standing));
                				}

                SIG_PREOP  =  {
                				return(SmTrans(Standing));
                				}
                SIG_OP 	  =  {
                				return(SmTrans(Standing));
                				}

                SIG_CLEAR  = {
                                print("CLEAR");
                                ErrorClear();
                                AmpErrorClear(AXALL);
                                Sysvar[0x01220105] = 0;
                            }
                SIG_ENABLE = {
                                print("Motor Enable");
                                AxisControl(AXALL,ON);
                            }
                SIG_DISABLE = {
                                print("Disable");
                                AxisControl(AXALL,OFF);
                                }
    }
}

/***********************************************************************************************/
// DY - TCP/IP Handler -> 2 timer(SmPeriod 1ms). each timer preceed the receive and send the data
// 2022.11.12 - TICK_Configure_Sinewave test for checking timer in 1 ms
SmState TCPIP_Handler{

	// DY
	SIG_INIT = {
		print("TCP/IP Handler Initializing");
		print("data(tcp) = ", data[0]);

		return(0);
	}

	// DY - test for debuging gloabal variable is updates in each SM.
	TICK_Configure_SineWave = {

		#if SINE_WAVE_TEST_FLAG
		cnt_sine_wave ++;   // increase 1 in every 1 ms
		pos[0] = (double)SINE_WAVE_AMP * sin( SINE_WAVE_NORMAL_TIME * (1.0/(long)SINE_WAVE_TIME)*cnt_sine_wave);         // update global variable 'pos'

		if(cnt_sine_wave >= SINE_WAVE_TIME)
		{
			cnt_sine_wave = 0;
		}

		#if DEBUG_FLAG
		if(cnt_sine_wave%100 == 0) {print("sin cnt = ", cnt_sine_wave, "/", pos[0]);}
		#endif

		#endif
    }

	// DY
	// Receive data
	// 1 ms term
    TICK_TCP_Receive = {
        // TCP receive function will be filled in.
    }

    // DY
    // Send data
	// 1 ms term
    TICK_TCP_Send = {
        // TCP send function will be filled in.
    }

}


/*********************************************************************
** State Machine Definitions
*********************************************************************/

//SmMachine Operation {1, *, MyMachine, 20, 2}
// DY
SmMachine SM_EtherCAT {STATE_MACHINE_ID_EtherCAT, init_sm_EtherCAT, EtherCAT_Handler, 400, 20}
SmMachine SM_TCP {STATE_MACHINE_ID_TCP, init_sm_tcp, TCPIP_Handler, 400, 20}


long main(void)
{
	long res;
	print(status_sm);

	print("DY header : ", DY);

	print("Operation Start");
	printf("State Machines Run...");
  	status_sm = SmRun(SM_EtherCAT, SM_TCP); // Opearation 이라는 이름의 Statemachine을 실행.

  	// DY
  	// Sm Run 이후는 실행되지 않음.
	if(status_sm==0) {printf("Done");}
	else {printf("#Error during Running State Machines!");}

    return(0);
}

// DY
long init_sm_EtherCAT(long id, long data[])
{
	data[0] = 0;
	//configure_EtherCAT();
	EtherCAT_configuration();

	return(0);
}

// DY
long init_sm_tcp(long id, long data[])
{
	data[0]=1;
	SmPeriod(1, id, TICK_Configure_SineWave);
	SmPeriod(1, id, TICK_TCP_Receive);
	SmPeriod(1, id, TICK_TCP_Send);

	return(0);
}


long configure_EtherCAT()
{
	long slaveCount, i, retval, retval1, res, retval2;

	print("main loop");
	print("Error clear & setup updating...");

	ErrorClear();
	AmpErrorClear(C_AXIS1); // Clear error on EPOS4
	//AmpErrorClear(C_AXIS2); // Clear error on EPOS4
	//AmpErrorClear(C_AXIS3); // Clear error on EPOS4
    //AmpErrorClear(C_AXIS4);
    //AmpErrorClear(C_AXIS5); // Clear error on EPOS4
    //AmpErrorClear(C_AXIS6);

	ECatMasterCommand(0x1000, 0);


	//----------------------------------------------------------------
	// Application Setup
	//----------------------------------------------------------------

	slaveCount = sdkEtherCATMasterInitialize();
	print("slavecount: ",slaveCount);

	// initialising maxon drives
    sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID1, C_PDO_NUMBER, C_AXIS1_POLARITY, EPOS4_OP_CSV );
	//sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID2, C_PDO_NUMBER, C_AXIS2_POLARITY, EPOS4_OP_CSP );
	//sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID3, C_PDO_NUMBER, C_AXIS3_POLARITY, EPOS4_OP_CSP );
    //sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID4, C_PDO_NUMBER, C_AXIS4_POLARITY, EPOS4_OP_CSP );
    //sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID5, C_PDO_NUMBER, C_AXIS5_POLARITY, EPOS4_OP_CSP );
    //sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID6, C_PDO_NUMBER, C_AXIS6_POLARITY, EPOS4_OP_CSP );

	//for (i = 1; i <= 6; i++) {
	//   sdkEtherCATSetupDC(i, C_EC_CYCLE_TIME, C_EC_OFFSET);    // Setup EtherCAT DC  (cycle_time [ms], offset [us]
    //}

    sdkEtherCATMasterDoMapping();
    //print(sdkEtherCATMasterDoMapping());
    for (i = 1; i <= 1; i++) {
	   sdkEtherCATSetupDC(i, C_EC_CYCLE_TIME, C_EC_OFFSET);    // Setup EtherCAT DC  (cycle_time [ms], offset [us]
    }


	// starting the ethercat
	sdkEtherCATMasterStart();

	// setup EtherCAT bus module for csp mode
	sdkEpos4_SetupECatBusModule(C_AXIS1, C_DRIVE_BUSID1, C_PDO_NUMBER, EPOS4_OP_CSV);
	//sdkEpos4_SetupECatBusModule(C_AXIS2, C_DRIVE_BUSID2, C_PDO_NUMBER, EPOS4_OP_CSP);
	//sdkEpos4_SetupECatBusModule(C_AXIS3, C_DRIVE_BUSID3, C_PDO_NUMBER, EPOS4_OP_CSP);
    //sdkEpos4_SetupECatBusModule(C_AXIS4, C_DRIVE_BUSID4, C_PDO_NUMBER, EPOS4_OP_CSP);
    //sdkEpos4_SetupECatBusModule(C_AXIS5, C_DRIVE_BUSID5, C_PDO_NUMBER, EPOS4_OP_CSP);
    //sdkEpos4_SetupECatBusModule(C_AXIS6, C_DRIVE_BUSID6, C_PDO_NUMBER, EPOS4_OP_CSP);

	// setup virtual amplifier for csp mode
	sdkEpos4_SetupECatVirtAmp(C_AXIS1, C_AXIS1_MAX_RPM, EPOS4_OP_CSV);
	//sdkEpos4_SetupECatVirtAmp(C_AXIS2, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
	//sdkEpos4_SetupECatVirtAmp(C_AXIS3, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
    //sdkEpos4_SetupECatVirtAmp(C_AXIS4, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
	//sdkEpos4_SetupECatVirtAmp(C_AXIS5, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
    //sdkEpos4_SetupECatVirtAmp(C_AXIS6, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
	//
	// setup irtual counter for csp mode
	sdkEpos4_SetupECatVirtCntin(C_AXIS1, EPOS4_OP_CSV);
	//sdkEpos4_SetupECatVirtCntin(C_AXIS2, EPOS4_OP_CSP);
	//sdkEpos4_SetupECatVirtCntin(C_AXIS3, EPOS4_OP_CSP);
    //sdkEpos4_SetupECatVirtCntin(C_AXIS4, EPOS4_OP_CSP);
    //sdkEpos4_SetupECatVirtCntin(C_AXIS5, EPOS4_OP_CSP);
    //sdkEpos4_SetupECatVirtCntin(C_AXIS6, EPOS4_OP_CSP);

	// All axis have in this example the same parameters
	for (i = 0; i < 1; i++) {
		// Movement parameters for the axis
		sdkSetupAxisMovementParam(	i,
									C_AXIS1_VELRES,
									C_AXIS1_MAX_RPM,
									C_AXIS1_RAMPTYPE,
									C_AXIS1_RAMPMIN,
									C_AXIS1_JERKMIN
									);

		// Definition of the user units
		sdkSetupAxisUserUnits(		i,
									C_AXIS1_POSENCREV,
									C_AXIS1_POSENCQC,
									C_AXIS1_POSFACT_Z,
									C_AXIS1_POSFACT_N,
									C_AXIS1_FEEDREV,
									C_AXIS1_FEEDDIST
									);
		// Position control setup
		sdkSetupPositionPIDControlExt( 	i,
										C_AXIS1_KPROP,
										C_AXIS1_KINT,
										C_AXIS1_KDER,
										C_AXIS1_KILIM,
										C_AXIS1_KILIMTIME,
										C_AXIS1_BANDWIDTH,
										C_AXIS1_FFVEL,
										C_AXIS1_KFFAC,
										C_AXIS1_KFFDEC
										);
	}



	//----------------------------------------------------------------
	// End of Application Setup
	//----------------------------------------------------------------

	ErrorClear();

	//Vel(C_AXIS1,20,C_AXIS5,20,C_AXIS6,20);   // 속도 지정
	//Acc(C_AXIS1,40,C_AXIS5,40,C_AXIS6,40);   // 가속도 지정
	//Dec(C_AXIS1,50,C_AXIS5,50,C_AXIS6,50);   // 감속도 지정

	Vel(C_AXIS1,200);   // 속도 지정
	Acc(C_AXIS1,500);   // 가속도 지정
	Dec(C_AXIS1,500);   // 감속도 지정
}


//long EtherCAT_REINIT (long id, long signal, long event[], long data[]) // EtherCAT NMT 상태를 재부팅하여 Operational 상태로 만듦.
//{
//    long slaveCount, i,retval,res;
//    print("REINIT");
//
//    ECatMasterCommand(0x1000, 0);
//
//	slaveCount = sdkEtherCATMasterInitialize();
//    sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID1, C_PDO_NUMBER, C_AXIS1_POLARITY, EPOS4_OP_CSV );
//	//sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID2, C_PDO_NUMBER, C_AXIS2_POLARITY, EPOS4_OP_CSP );
//	//sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID3, C_PDO_NUMBER, C_AXIS3_POLARITY, EPOS4_OP_CSP );
//    //sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID4, C_PDO_NUMBER, C_AXIS4_POLARITY, EPOS4_OP_CSP );
//    //sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID5, C_PDO_NUMBER, C_AXIS5_POLARITY, EPOS4_OP_CSP );
//    //sdkEpos4_SetupECatSdoParam(C_DRIVE_BUSID6, C_PDO_NUMBER, C_AXIS6_POLARITY, EPOS4_OP_CSP );
//
//	for (i = 1; i <= 1; i++) {
//	                          sdkEtherCATSetupDC(i, C_EC_CYCLE_TIME, C_EC_OFFSET);    // Setup EtherCAT DC  (cycle_time [ms], offset [us]
//                             }
//
//
//    sdkEtherCATMasterStart();
//    sdkEpos4_SetupECatBusModule(C_AXIS1, C_DRIVE_BUSID1, C_PDO_NUMBER, EPOS4_OP_CSV);
//	//sdkEpos4_SetupECatBusModule(C_AXIS2, C_DRIVE_BUSID2, C_PDO_NUMBER, EPOS4_OP_CSP);
//	//sdkEpos4_SetupECatBusModule(C_AXIS3, C_DRIVE_BUSID3, C_PDO_NUMBER, EPOS4_OP_CSP);
//    //sdkEpos4_SetupECatBusModule(C_AXIS4, C_DRIVE_BUSID4, C_PDO_NUMBER, EPOS4_OP_CSP);
//    //sdkEpos4_SetupECatBusModule(C_AXIS5, C_DRIVE_BUSID5, C_PDO_NUMBER, EPOS4_OP_CSP);
//    //sdkEpos4_SetupECatBusModule(C_AXIS6, C_DRIVE_BUSID6, C_PDO_NUMBER, EPOS4_OP_CSP);
//
//	// setup virtual amplifier for csp mode
//	sdkEpos4_SetupECatVirtAmp(C_AXIS1, C_AXIS1_MAX_RPM, EPOS4_OP_CSV);
//	//sdkEpos4_SetupECatVirtAmp(C_AXIS2, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
//	//sdkEpos4_SetupECatVirtAmp(C_AXIS3, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
//    //sdkEpos4_SetupECatVirtAmp(C_AXIS4, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
//	//sdkEpos4_SetupECatVirtAmp(C_AXIS5, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
//    //sdkEpos4_SetupECatVirtAmp(C_AXIS6, C_AXIS_MAX_RPM, EPOS4_OP_CSP);
//	//
//
//	// setup irtual counter for csp mode
//	sdkEpos4_SetupECatVirtCntin(C_AXIS1, EPOS4_OP_CSV);
//	//sdkEpos4_SetupECatVirtCntin(C_AXIS2, EPOS4_OP_CSP);
//	//sdkEpos4_SetupECatVirtCntin(C_AXIS3, EPOS4_OP_CSP);
//    //sdkEpos4_SetupECatVirtCntin(C_AXIS4, EPOS4_OP_CSP);
//    //sdkEpos4_SetupECatVirtCntin(C_AXIS5, EPOS4_OP_CSP);
//    //sdkEpos4_SetupECatVirtCntin(C_AXIS6, EPOS4_OP_CSP);
//
//	ErrorClear();
//    AmpErrorClear(AXALL);
//
//
//
//
//
//    //AxisControl(C_AXIS1,ON,C_AXIS2,ON,C_AXIS3,ON,C_AXIS4,ON,C_AXIS5,ON,C_AXIS6,ON);
//    AxisControl(C_AXIS1,ON);
//	Sysvar[0x01220105] = 0;
//    return(SmTrans(Standing));
//    //return(0);
//
//}
//
//
//long EtherCAT_PREOP (long id, long signal, long event[], long data[])  // EtherCAT NMT State를 PRE operational 상태로 바꿈
//{
//	// DY
//	print("EtherCAT PREOP set...");
//
//	ECatMasterCommand(0x1000,1);
//	Delay(10);
//	SdoWrite(1000001,0x6040,0,0x80);
//	//SdoWrite(1000002,0x6040,0,0x80);
//	//SdoWrite(1000003,0x6040,0,0x80);
//	//SdoWrite(1000004,0x6040,0,0x80);
//	//SdoWrite(1000005,0x6040,0,0x80);
//	//SdoWrite(1000006,0x6040,0,0x80);
//	Delay(10);
//
//	for (i = 1; i <= 1; i++) {
//	   sdkEtherCATSetupDC(i, C_EC_CYCLE_TIME, C_EC_OFFSET);    // Setup EtherCAT DC  (cycle_time [ms], offset [us]
//							 }
//	return(SmTrans(Standing));
//	//return(0);
//}
//
//long EtherCAT_OP (long id, long signal, long event[], long data[]) // EtherCAT NMT State를 Operational 상태로 바꿈
//{
//	//DY
//	print("EtherCAT OP set...");
//
//	sdkEtherCATMasterStart();
//	AmpErrorClear(AXALL);
//
//	return(SmTrans(Standing));
//	//return(0);
//}






