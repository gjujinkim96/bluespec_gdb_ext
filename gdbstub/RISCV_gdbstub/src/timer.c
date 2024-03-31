#include <time.h>
typedef struct Timer {
    clock_t start;
} Timer;

void init_timer(Timer * timer) {
    timer->start = clock();
}

double timer_click(Timer* timer) {
    clock_t cur = clock();
    double ret = (double) (cur - timer->start);
    timer->start = cur;
    return ret;
}