#ifndef SPANK_SEQ_H
#define SPANK_SEQ_H

#define SEQ_EVTYPE_KEYON 0
#define SEQ_EVTYPE_KEYOFF 1

#define SEQ_FLAG_USED 1

struct seqevent {
	int instrument;
	int type;
	int param;
	struct seqevent* next;
	int flags;
};

int seq_add_event(int time, int instrument, int type, int param);
struct seqevent* seq_events_at(int time);
void seq_init(void);

#endif
