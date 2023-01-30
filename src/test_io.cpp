#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#define IP_ADDRESS "127.0.0.1"
#define PORT_NUMBER 77777

int main()
{
    std::string ip;
    std::string s_port;
    uint32_t i_port = PORT_NUMBER;
    int strlen;
    char message[] = "";

    while(true){
        std::cout << "[Command] Enter IP address. Enter is using dafault (default = 127.0.0.1) : ";
        std::getline(std::cin, ip);
        static uint8_t cnt = 0;
        
        // set default
        if(ip == "") {std::cout << IP_ADDRESS << std::endl; break;}
        // set manual
        for(int i=0; i<ip.length(); i++) { if(ip[i] == '.') cnt++; }
        if(cnt != 3) std::cout << "[ERROR] Check your ip address (3 .)" << std::endl;
        else break;
    }
    while(true){
        std::cout << "[Command] Enter Port. Enter is using dafault (default = " << PORT_NUMBER << ") : ";
        std::getline(std::cin, s_port);
        uint8_t tf = 0;

        // set default
        if(s_port=="") {std::cout << i_port << std::endl; break;}
        // set manual
        for(int i=0; i<s_port.length(); i++)
        {
            tf = isdigit(s_port[i]);
            if(tf==0)
            {
                std::cout << "[ERROR] Check your Port Number (int)" << std::endl;
                break;
            }
        }
        if(tf) 
        {   
            i_port = std::stoi(s_port);
            break;
        }
    }
    std::cout << i_port << std::endl;
    std::cout << ip.length() << std::endl;

    return 0;
}