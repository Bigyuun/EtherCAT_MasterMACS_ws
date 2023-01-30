/*********************************************************************
**
**    This sample provides a prototype of an Aposs state machine
** program.  The state machine consists of two substates.  A timer
** is used to toggle between the substates.
*/
#pragma once
#include <SysDef.mh>
#include "..\include\SDK\SDK_ApossC.mc"
#include "..\include\user_definition.mh"
#include "..\include\EtherCAT_config.mc"

/*********************************************************************
** Application Defines
*********************************************************************/
// DY
long status_sm = -1;

#define DEBUG_FLAG 					1
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

/*********************************************************************
** State Machine Setup Parameters
*********************************************************************/

#pragma SmConfig {  1,            // Runtime flags.
                    200,          // Event pool size.
                    10,           // Maximum number of timers.
                    400,          // Subscribe pool size.
                    400,          // Parameter pool size.
                    0,
                    20	}         // Position pool size.

/*********************************************************************
** Event Definitions
*********************************************************************/
SmEvent TICK_Configure_SineWave{}
SmEvent TICK_TCP_Receive{}
SmEvent TICK_TCP_Send{}

/*********************************************************************
** State Definitions
*********************************************************************/
/***********************************************************************************************/
// DY - TCP/IP Handler -> 2 timer(SmPeriod 1ms). each timer preceed the receive and send the data
// 2022.11.12 - TICK_Configure_Sinewave test for checking timer in 1 ms
SmState TCPIP_Handler{

	// DY
	SIG_INIT = {
		print("TCP/IP Handler Initializing");
		print("data(tcp) = ", data[0]);

		SmPeriod(1, id, TICK_Configure_SineWave);
		SmPeriod(1, id, TICK_TCP_Receive);
		SmPeriod(1, id, TICK_TCP_Send);

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

SmMachine SM_TCP {STATE_MACHINE_ID_TCP, init_sm_tcp, TCPIP_Handler, 400, 20}

/*********************************************************************
** State Machine Initialization Functions
*********************************************************************/
// DY
long init_sm_tcp(long id, long data[])
{
	data[0]=1;

	return(0);
}

/*********************************************************************
** Aposs Main Program
*********************************************************************/
long main(void)
{
    /*
    ** Start the state machine.
    */

	//long handle = EthernetOpenServer(PROT_TCP, 9800);
	//print("TCP return : ", handle);

	long socketHandle, status;
	long receiveData[10];
	wchar charArray[10];
	long retVal;

//	socketHandle = EthernetOpenServer(PROT_TCP, 77777);
	socketHandle = EthernetOpenClient(PROT_TCP, 172.16.1.7 ,77777);
	//socketHandle = EthernetOpenClient(PROT_TCP, 127.0.0.1,77777);
	if(socketHandle < 0) printf("There was an error: %ld \r\n", socketHandle);

	else printf("Success. The handle is: %ld \r\n", socketHandle);


	/*
	* status of ethernet connection
	SOCK_STATUS_INIT = 0,
	SOCK_STATUS_WAITING = 1,
	SOCK_STATUS_CONNECTING = 2,
	SOCK_STATUS_READY = 3,
	SOCK_STATUS_CLOSED = 4,
	SOCK_STATUS_ERRORSENDING = -1,
	SOCK_STATUS_ERROR = -2
	*/
	status = EthernetGetConnectionStatus(socketHandle);

	print("status : ", status);



	while(1)
	{
	/*
	This command can be used to receive a telegram if there is one in the buffer.
	The socket connection previously has to be setup with EthernetOpenClient or EthernetOpenServer. The connection status has to be SOCK_STATUS_READY = 3.
	*/
	retVal = EthernetReceiveTelegram(socketHandle, receiveData);

	print("first byte: %ld, second byte: %ld", receiveData[0], receiveData[1]);

	retVal = EthernetReceiveTelegram(socketHandle, charArray);

	print(charArray); //print the whole array

	Delay(2000);
	}



    SmRun(SM_TCP);

    return(0);
}
