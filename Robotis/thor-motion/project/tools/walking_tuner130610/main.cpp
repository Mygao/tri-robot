/*
 * main.cpp
 *
 *  Created on: 2013. 2. 5.
 *      Author: hjsong
 */



#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <term.h>
#include <ncurses.h>
#include <signal.h>
#include <libgen.h>
#include "cmd_process.h"


using namespace Thor;

void sighandler(int sig)
{
    struct termios term;
    tcgetattr( STDIN_FILENO, &term );
    term.c_lflag |= ICANON | ECHO;
    tcsetattr( STDIN_FILENO, TCSANOW, &term );

    exit(0);
}

void PrintErrorCode(int ErrorCode)
{
	printf("ErrorCode : %d (0x%X)\n", ErrorCode, ErrorCode);
    if(ErrorCode & ERRBIT_VOLTAGE)
        printf("Input voltage error!\n");

    if(ErrorCode & ERRBIT_ANGLE)
        printf("Angle limit error!\n");

    if(ErrorCode & ERRBIT_OVERHEAT)
        printf("Overheat error!\n");

    if(ErrorCode & ERRBIT_RANGE)
        printf("Out of range error!\n");

    if(ErrorCode & ERRBIT_CHECKSUM)
        printf("Checksum error!\n");

    if(ErrorCode & ERRBIT_OVERLOAD)
        printf("Overload error!\n");

    if(ErrorCode & ERRBIT_INSTRUCTION)
        printf("Instruction code error!\n");
}

int main(int argc, char *argv[])
{
    signal(SIGABRT, &sighandler);
    signal(SIGTERM, &sighandler);
    signal(SIGQUIT, &sighandler);
    signal(SIGINT, &sighandler);

    minIni* ini = new minIni("config.ini");


    //////////////////// Framework Initialize ////////////////////////////
    if(MotionManager::GetInstance()->Initialize() == false)
    {
        printf("Fail to initialize Motion Manager!\n");
        return 0;
    }
	//MotionManager::GetInstance()->LoadINISettings(ini);


//    Action::GetInstance()->LoadFile("motion_4096.bin");
//    MotionManager::GetInstance()->AddModule((MotionModule*)Action::GetInstance());
//    MotionManager::GetInstance()->StartTimer();
//    Action::GetInstance()->Start(31);
//    while(Action::GetInstance()->IsRunning())
//    	usleep(8000);
//
//    MotionManager::GetInstance()->StopTimer();
//    MotionManager::GetInstance()->RemoveModule((MotionModule*)Action::GetInstance());

    for(int i = 0; i < 36 ; i++)
    {
    	if(i != 25 && i != 26)
    		MotionStatus::m_EnableList[i].uID = "Walking130610";
    }

    Ins *ins = new Ins();
    if(ins->Connect("ttyACM0", 921600) !=MIP_INTERFACE_OK)
    {
    	printf("fail to connect\n");
    	return 0;
    }
    printf( "\n===== start initializing ins  =====\n\n");
    if(ins->Initialize() != MIP_INTERFACE_OK)
    {
    	printf("fail to init\n");
    	return 0;
    }
    printf( "\n===== set enalble data callback =====\n\n");
	//ins->SetEnableNavDataCallBack();
	if(ins->SetEnableAHRSDataCallBack() != MIP_INTERFACE_OK)
    {
    	printf("fail to init\n");
    	return 0;
    }
	//ins->SetEnableGPSDataCallBack();

	ins->StartSensingDataUpdate();


	for(unsigned int index = 0; index < MotionStatus::m_CurrentJoints.size(); index++)
	{
		int id = MotionStatus::m_CurrentJoints[index].m_ID;

		int err, val;
		MotionStatus::m_CurrentJoints[index].m_DXL_Comm->GetDXLInstance()->WriteDWord(id, PRO54::P_GOAL_ACCELATION_LL, 0, &err);
		printf("id : %d  ", id);
		PrintErrorCode(err);

		usleep(1000);

	}

//	for(unsigned int index = 0; index < MotionStatus::m_CurrentJoints.size(); index++)
//	{
//		int id = MotionStatus::m_CurrentJoints[index].m_ID;
//
//		if(id > 12 && id <25)
//			MotionStatus::m_CurrentJoints[index].m_DXL_Comm->GetDXLInstance()->WriteWord(id, PRO54::P_VELOCITY_I_GAIN_L, 0, 0);
//	}


	MotionManager::GetInstance()->LoadINISettings(ini);
	Walking130610::GetInstance()->LoadINISettings(ini);
    DrawIntro(MotionManager::GetInstance());
    MotionManager::GetInstance()->AddModule((MotionModule*)Walking130610::GetInstance());

    MotionManager::GetInstance()->StartTimer();
    /////////////////////////////////////////////////////////////////////
	Walking130610::GetInstance()->BALANCE_ENABLE = false;
	//Walking130610::GetInstance()->FB_ALL_BALANCE_ENABLE = true;
	//Walking130610::GetInstance()->RL_ALL_BALANCE_ENABLE = true;

   //

    while(1)
    {

    	int ch = _getch();
        if(ch == 0x1b)
        {
            ch = _getch();
            if(ch == 0x5b)
            {
                ch = _getch();
                if(ch == 0x41) // Up arrow key
                    MoveUpCursor();
                else if(ch == 0x42) // Down arrow key
                    MoveDownCursor();
                else if(ch == 0x44) // Left arrow key
                    MoveLeftCursor();
                else if(ch == 0x43)
                    MoveRightCursor();
            }
        }
        else if( ch == '[' )
            DecreaseValue(false);
        else if( ch == ']' )
            IncreaseValue(false);
        else if( ch == '{' )
            DecreaseValue(true);
        else if( ch == '}' )
            IncreaseValue(true);
        else if( ch >= 'A' && ch <= 'z' )
        {
            char input[128] = {0,};
            char *token;
            int input_len;
            char cmd[80];
            char strParam[20][30];
            int num_param;

            int idx = 0;

            BeginCommandMode();

            printf("%c", ch);
            input[idx++] = (char)ch;

            while(1)
            {
                ch = _getch();
                if( ch == 0x0A )
                    break;
                else if( ch == 0x7F )
                {
                    if(idx > 0)
                    {
                        ch = 0x08;
                        printf("%c", ch);
                        ch = ' ';
                        printf("%c", ch);
                        ch = 0x08;
                        printf("%c", ch);
                        input[--idx] = 0;
                    }
                }
                else if( ch >= 'A' && ch <= 'z' )
                {
                    if(idx < 127)
                    {
                        printf("%c", ch);
                        input[idx++] = (char)ch;
                    }
                }
            }

            fflush(stdin);
            input_len = strlen(input);
            if(input_len > 0)
            {
                token = strtok( input, " " );
                if(token != 0)
                {
                    strcpy( cmd, token );
                    token = strtok( 0, " " );
                    num_param = 0;
                    while(token != 0)
                    {
                        strcpy(strParam[num_param++], token);
                        token = strtok( 0, " " );
                    }

                    if(strcmp(cmd, "exit") == 0)
                    {
                        if(AskSave() == false)
                            break;
                    }
                    if(strcmp(cmd, "re") == 0)
                        DrawScreen();
                    else if(strcmp(cmd, "save") == 0)
                    {
                        Walking130610::GetInstance()->SaveINISettings(ini);
                        SaveCmd();
                    }
                    else if(strcmp(cmd, "mon") == 0)
                    {
                        MonitorCmd();
                    }
                    else if(strcmp(cmd, "init") == 0)
                    {
                        Walking130610::GetInstance()->SetInitialEulerAngle();
                    }
                    else if(strcmp(cmd, "help") == 0)
                        HelpCmd();
                    else if(strcmp(cmd, "log") == 0)
                        MotionManager::GetInstance()->TempStartLogging();
                    else if(strcmp(cmd, "end") == 0)
                        MotionManager::GetInstance()->TempStopLogging();
                    else if(strcmp(cmd, "fbon") == 0)
                    	Walking130610::GetInstance()->FB_BALANCE_ENABLE = true;
                    else if(strcmp(cmd, "rlon") == 0)
                    	Walking130610::GetInstance()->RL_BALANCE_ENABLE = true;
                    else if(strcmp(cmd, "fboff") == 0)
                    	Walking130610::GetInstance()->FB_BALANCE_ENABLE = false;
                    else if(strcmp(cmd, "rloff") == 0)
                    	Walking130610::GetInstance()->RL_BALANCE_ENABLE = false;
                    else if(strcmp(cmd, "fbaon") == 0)
                    	Walking130610::GetInstance()->FB_ALL_BALANCE_ENABLE = true;
                    else if(strcmp(cmd, "rlaon") == 0)
                    	Walking130610::GetInstance()->RL_ALL_BALANCE_ENABLE = true;
                    else if(strcmp(cmd, "fbaoff") == 0)
                    	Walking130610::GetInstance()->FB_ALL_BALANCE_ENABLE = false;
                    else if(strcmp(cmd, "rlaoff") == 0)
                    	Walking130610::GetInstance()->RL_ALL_BALANCE_ENABLE = false;
                    else
                        PrintCmd("Bad command! please input 'help'");
                }
            }

            EndCommandMode();
        }
    }

    DrawEnding();
    ins->StopSensingDataUpdate();
    delete ins;
    return 0;
}

