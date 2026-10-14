#pragma once

#include <SDL2/SDL.h>

// A fullscreen emulator can change the compositor's fullscreen owner while
// the frontend waits. Re-request desktop fullscreen even if SDL's cached
// flags still describe the original fullscreen window.
inline bool restoreFrontendWindow(
    SDL_Window* window,
    SDL_Renderer* renderer,
    int logicalWidth,
    int logicalHeight)
{
    if (SDL_SetWindowFullscreen(window, 0) != 0 ||
        SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN_DESKTOP) != 0)
    {
        return false;
    }

    SDL_ShowWindow(window);
    SDL_RaiseWindow(window);
    SDL_PumpEvents();

    // Recalculate the viewport for the restored window, including desktop
    // scaling. A viewport left over from gameplay must not clip the menu.
    return SDL_RenderSetClipRect(renderer, nullptr) == 0 &&
           SDL_RenderSetViewport(renderer, nullptr) == 0 &&
           SDL_RenderSetLogicalSize(renderer, logicalWidth, logicalHeight) == 0;
}
