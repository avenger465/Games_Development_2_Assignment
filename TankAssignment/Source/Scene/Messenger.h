/*******************************************
	Messenger.h

	Entity messenger class definitions
********************************************/

#pragma once

#include <map>
using namespace std;

#include "Defines.h"
#include "Entity.h"

namespace gen
{

/////////////////////////////////////
//	Public types

// Some basic message types
enum EMessageType
{
	Msg_Go,   // Start moving
	Msg_Stop, // Stop all action
};

// A message contains a type and the UID that sent it.
// The message types for this exercise don't currently require extra data, but it is possible
// to use a union to add additional data for new message types (see the space game code)
struct SMessage
{
	// Need to provide copy constructor and assignment operator in case you later add a union to this structure
	// The compiler does not know which of the union contents are in use so it cannot provide default versions
	SMessage() {} // Need to explicitly write default constructor when other constructors are provided
	SMessage(const SMessage& o)
	{
		memcpy(this, &o, sizeof(SMessage)); // Use of memcpy is only safe if SMessage is a "POD" type - data
											// only, no members that need construction. A fair restriction
											// for messages, but does require programmer care.
	}
	SMessage& operator=(const SMessage& o)
	{
		memcpy(this, &o, sizeof(SMessage)); return *this;
	}


	//*** Message data
	EMessageType type;
	TEntityUID   from;
};


// Messenger class allows the sending and receipt of messages between entities - addressed by UID
class CMessenger
{
/////////////////////////////////////
//	Constructors/Destructors
public:
	// Default constructor
	CMessenger() {}

	// No destructor needed

private:
	// Disallow use of copy constructor and assignment operator (private and not defined)
	CMessenger( const CMessenger& );
	CMessenger& operator=( const CMessenger& );


/////////////////////////////////////
//	Public interface
public:

	/////////////////////////////////////
	// Message sending/receiving

	// Send the given message to a particular UID, does not check if the UID exists
	void SendMessage( TEntityUID to, const SMessage& msg );

	// Fetch the next available message for the given UID, returns the message through the given 
	// pointer. Returns false if there are no messages for this UID
	bool FetchMessage( TEntityUID to, SMessage* msg );


/////////////////////////////////////
//	Private interface
private:

	// A multimap has properties similar to a hash map - mapping a key to a value. Here we
	// have the key as an entity UID and the value as a message for that UID. The stored
	// key/value pairs in a multimap are sorted by key, which means all the messages for a
	// particular UID are together. Key look-up is somewhat slower than for a hash map though
	// Define some types to make usage easier
	typedef multimap<TEntityUID, SMessage> TMessages;
	typedef TMessages::iterator TMessageIter;
    typedef pair<TEntityUID, SMessage> UIDMsgPair; // The type stored by the multimap

	TMessages m_Messages;
};


} // namespace gen
