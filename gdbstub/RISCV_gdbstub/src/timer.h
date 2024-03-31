#pragma once

#include <time.h>

typedef struct Timer {
    clock_t start;
} Timer;

void init_timer(Timer * timer);
double timer_click(Timer* timer);
