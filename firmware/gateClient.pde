#include <SPI.h>
#include <Wire.h>
#include <Ethernet.h>
#include <OneWire.h>

#define USER
#define PORT 7628

#define RETRIES 30
#define LEDPIN 15

#define SCK 13
#define MISO 12
#define MOSI 11
#define SS 10
#define RESET 9
#define CS 8

#define IN1 2
#define IN2 3

#define DEBOUNCE 15

#define ONEWIRE_CRC 0
#define ONEWIRE_SEARCH 0



int tries=0;

#if defined SERVER
  byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x00 };
  byte ip[] = { 10,21,50,206 };
  #warning server
#elif defined SOFTWARE
  byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01 };
  byte ip[] = { 10,21,50,207 };
  #warning software
#elif defined USER
  byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x02 };
  byte ip[] = { 10,21,50,201 };
#elif defined PROJECT
  byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x03 };
  byte ip[] = { 10,21,50,205 };
  #warning project
#elif defined LOUNGE
  byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x04 };
  byte ip[] = { 10,21,50,208 };

  //redefine SS because the lounge board has a defect
  #undef SS
  #define SS 7
  #warning lounge
  
#elif defined RESEARCH
  byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x05 };
  byte ip[] = { 10,21,50,209 };
  #warning research
#else
  #error Must define doorlock to be built
#endif


byte gateway[] = { 10,21,50,254 };
byte subnet[] = { 255,255,255,0 };

byte server[] = { 10,21,50,204}; //gatekeeper

// Initialize the Ethernet client library
Client client (server, PORT);

char rxbuffer[50];
char *rxptr=rxbuffer;

char doorID=0;

char asciiAddr[18];

OneWire iButton= OneWire(14);
byte addr[8];

boolean locked=false;
boolean debounce = false;


void unlock(){
  locked=false;
  digitalWrite(IN1,HIGH);
  digitalWrite(IN2,LOW);
  delay(100);
  digitalWrite(IN1,LOW);
  digitalWrite(IN2,LOW);
  Serial.println("unlocked!");
}


void lock(){
  locked=true;
  digitalWrite(IN1,LOW);
  digitalWrite(IN2,HIGH);
  delay(100);
  digitalWrite(IN1,LOW);
  digitalWrite(IN2,LOW);
  Serial.println("locked!");
}

void door_toggle(){
  if (locked){
     unlock();
  }
  else{
    lock();
  }
}


void setup() {

  // start the Ethernet connection and the server:
  pinMode(RESET,OUTPUT);//reset
  pinMode(SS,OUTPUT);//ss
  pinMode(SCK,OUTPUT);
  pinMode(MOSI,OUTPUT);
  pinMode(MISO,INPUT);
  
  digitalWrite(SS,LOW); //assert SS low
  digitalWrite(CS,HIGH); //assert CS high
  
  pinMode(LEDPIN,OUTPUT);
  digitalWrite(LEDPIN,HIGH); //active low
  
  pinMode(IN1,OUTPUT);
  pinMode(IN2,OUTPUT);
  digitalWrite(IN1,LOW);
  digitalWrite(IN2,LOW);
  
  // give the Ethernet shield a second to initialize:
  resetETH();
  delay(500);
  
  // start the Ethernet connection:
  Ethernet.begin(mac, ip, gateway, subnet);
  // start the serial library:
  Serial.begin(9600);
  Serial.println("Started!");

  lock(); 


}

void loop()
{
    digitalWrite(SS,LOW);//ss
    if (client.connected()) {
      parseMessages();
      if (search(addr)){
        
        sprintf(asciiAddr,"%02X%02X%02X%02X%02X%02X%02X%02X\0",
                    addr[7],addr[6],addr[5],addr[4],
                    addr[3],addr[2],addr[1],addr[0]);
         
        asciiAddr[16]=0;
        Serial.println(asciiAddr);
        if (!debounce){
          debounce=true;
          sendMessage('I', '=',asciiAddr);
          delay(100);
        }
      }
      else{
        if (debounce){
          debounce = false;
        }
      }
    }
    else{
      Serial.print("connecting to");
      for (int i=0;i<4;i++){
       Serial.print(server[i],DEC);;
       Serial.print("."); 
      }
      Serial.print("Port:");
      Serial.print(PORT,DEC);
      Serial.print("..");
      if(client.connect()){
        //successful. Return to process
        Serial.println("Connected!");
        return;
        
      }else{
       //connection is failing. Go to local access mode.
        if (++tries>=RETRIES){
          Serial.println("resetting device");
          client.stop();
          resetETH();
          delay(500);
          Ethernet.begin(mac, ip, gateway, subnet);
          client.stop();
          delay(500);
          tries=0;
        }
        Serial.println("failed!");
        flash(7);
      }
    }
    
    digitalWrite(LEDPIN,LOW);
    if (locked){
      delay(50);
      digitalWrite(LEDPIN,HIGH);
      delay(50);
    }
}


void parseMessages(){
  if (client.available()){//if there are bytes waiting
    if (rxptr<rxbuffer+255){
      *rxptr=client.read(); //read the byte
      Serial.print(*rxptr);
      if(*rxptr == '\n'){ //if the packet is done, pass it to handler
          handleMessage(rxbuffer,rxptr-rxbuffer);
          rxptr=rxbuffer; //reset buffer
      }
      else{
        rxptr++;
      }
    }
      
    else{
       //message too long.. error. 
      rxptr=rxbuffer;
      while(client.available() && client.read() != '\n'){}
      Serial.println("message too big!");
    }
  }
}

void flash(int flashes){
  Serial.print("Flashing:");
  Serial.println(flashes, DEC);
  if (flashes>0)
  {
    for (int i=0;i<flashes;i++){
      digitalWrite(LEDPIN,LOW);
      delay(20);
      digitalWrite(LEDPIN,HIGH);
      delay(20); 
    }
  }
}

void resetETH(){
  digitalWrite(RESET,LOW);//reset
  delay(1);
  digitalWrite(RESET,HIGH);//not reset
  delay(10);
  
}


void handleMessage(char * packet, int numChars){
 
  if (numChars<2)
   return;//error
  
  
  switch(packet[0]){
  case 'Q': //Queries the state of the door. Will return L (locked) or U (unlocked)
    if (locked){
       sendMessage('R',packet[1],"L");
    }
    else{
      sendMessage('R',packet[1],"U" );
    }
  case 'R': //Sends the door ID and the response
    break;
  case 'L': //Locks the door. Will return L (success).
    sendMessage('R',packet[1],"L");
    lock();
    break;
  case 'U': //Unlocks the door. Will return U (success).
    sendMessage('R',packet[1],"U");
    unlock();
    break;
  case 'P': //Unlocks the door, pauses, and then relocks the door. Will return L (success).  
    sendMessage('R',packet[1],"L");
    unlock();
    delay(3000);
    lock();
    break;
  case 'A': //Comma-seperated list of iButton IDs to be appended to the local access list. Will return Y (success).
    break;
  case 'S': //Causes the door to flash the status code to the user. Will return Y (success).
       flash(packet[2]);
       sendMessage('R',packet[1],"Y");
    break;
  case 'I': //Sends the iButton ID.
    sendMessage('E',packet[1],"Not supported by client");
    break;
  case 'E': //Sends an error code. 
    break;
  case 'D': //Sets the door ID. This number is used in all future communications. Will return Y (success).
    Serial.print("Doorid:");
    doorID=packet[2];
    Serial.println(doorID,DEC);
    break;
  default:
    sendMessage('E',packet[1],"Invalid message");     
 }
}


void sendMessage(char messageCode, char messageID, char* payload){
   
  char msg[40];
 
  
  sprintf(msg,">Sending: %c : %x: %x: %s\n",messageCode, messageID, doorID,payload);
  Serial.println(msg);
  
  sprintf(msg,"%c%c%c%s\n",messageCode,messageID,doorID,payload);
  

  Serial.print(">");
  Serial.println(msg);
 
  client.print(msg);
 
  
  
  
}

boolean search(byte* addr){
  
  if ( !iButton.search(addr)) {
      iButton.reset_search();
      return false;
  }
  
  iButton.reset();
  
  return true;
}



