#include <stdio.h>
#include <SDL3/SDL.h>

int main(void) {
    printf("size: 0x%llX, %d\n", sizeof(SDL_Event), SDL_EVENT_QUIT);

    return 0;
}