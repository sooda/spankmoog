#ifndef SPANK_SEQ_H
#define SPANK_SEQ_H

#include <rtems.h>

#define SEQ_EVTYPE_KEYON 0
#define SEQ_EVTYPE_KEYOFF 1

#define SEQ_FLAG_USED 1

struct seqevent {
	int instrument;
	int type;
	rtems_unsigned32 param1, param2;
	struct seqevent* next;
	int flags;
};

int seq_add_event(int time, int instrument, int type, rtems_unsigned32 param);
int seq_add_event2(int time, int instrument, int type, rtems_unsigned32 param1, rtems_unsigned32 param2);
struct seqevent* seq_events_at(int time);
void seq_init(void);

#endif
