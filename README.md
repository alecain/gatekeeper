Gatekeeper
==========

Overview
--------

This is a door entry system for CSH's common rooms. This allows members to gain
access to common rooms using just their iButtons, eliminating the need for
keys. The hardware reads iButtons and authenicates against the central access
server using XBees to wirelessly communicate.


Features
--------
* Server can query door state (locked, unlocked)
* Server can send commands to doors (lock, unlock, pop)
* Doors can store a local access list
  * Users on this list have 24/7 access
  * Does not require the network to authenticate users
* Doors can query the access server to determine if users are allowed access
* Access server can push local access lists to each door
* Doors can flash error codes using an LED


Protocol
--------

The message frame appears as follows:  
<tt>  
+---------+----+--------------------+------------+  
| Command | ID | Payload (Optional) | Terminator |  
+---------+----+--------------------+------------+  
</tt>  
Terminator: \n (newline)  
  
* The command specifies which operation needs to be performed.
* The ID is a single byte that identifies the message. If the message requires a
   response, the
  response will have the same ID.
* The payload (which is optional) contains any additional data needed for the
   command.
  
  
<b>Commands</b>  
<tt>  
+---------+-------------+----------------------------------------------------+  
| Command | Payload     | Description                                        |  
+---------+-------------+----------------------------------------------------+  
|    Q    |     N/A     | Queries the state of the door. Will return         |  
|         |             |  L (locked) or U (unlocked).                       |  
|    R    |  Response   | Sends a response.                                  |  
|    L    |     N/A     | Locks the door.                                    |  
|    U    |     N/A     | Unlocks the door.                                  |  
|    P    |     N/A     | Unlocks the door, pauses, and then relocks the     |  
|         |             |  door.                                             |  
|    C    |     N/A     | Clears the local access list.                      |  
|    A    | iButton(s)  | Comma-seperated list of iButton IDs to be appended |  
|         |             |  to the local access list.                         |  
|    S    | Status Code | Causes the door to flash the status code to the    |  
|         |             |  user.                                             |  
|    I    |   iButton   | Sends the iButton ID.                              |  
|    E    | Error Code  | Sends an error code.                               |  
+---------+-------------+----------------------------------------------------+  
</tt>

