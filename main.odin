package main

import "core:sys/windows"
import "core:time"
import "core:math"
import "core:fmt"
import "core:math/rand"

MIN_LINE_HEIGHT :: 8
MAX_LINE_HEIGHT :: 12
MAX_INTENSITY   :: 12

MAX_SPEED       :: 2
MAX_CHARS       :: 32

INTENSITY := []string {
    "\033[38;5;255m",
    "\033[38;5;253m",
    "\033[38;5;251m",
    "\033[38;5;249m",
    "\033[38;5;247m",
    "\033[38;5;245m",
    "\033[38;5;243m",
    "\033[38;5;241m",
    "\033[38;5;239m",
    "\033[38;5;237m",
    "\033[38;5;235m",
    "\033[38;5;233m",
    "\033[38;5;232m",
}

ENCODED_RUNES := []byte {
    '1', '2', '3', '4', 
    '5', '6', '7', '8',
    'a', 'b', 'c', 'd',
    'e', 'f', 'g', 'h',
    'i', 'j', 'k', 'l',
    'm', 'n', 'n', 'o',
    'p', 'q', 'r', 's',
    't', 'u', 'v', 'w'
} 

Line :: struct {
    chars: [MAX_LINE_HEIGHT] byte,
    height: u8,
    speed: f32,
    y: f32,
}

Viewport :: struct {
    lines: [dynamic] Line,  
    width: u32,
    height: u32,
}

viewport_create :: proc(width, height: u32) -> ^Viewport {
    viewport: ^Viewport = new(Viewport)
    viewport.width  = width
    viewport.height = height
    viewport.lines  = make([dynamic]Line, width + 1)

    viewport_startup(viewport)

    return viewport
}

viewport_startup :: proc(viewport: ^Viewport) {
    if len(viewport.lines) > 0 {
        clear(&viewport.lines)
    }

    for x in 0..< viewport.width {
        height := MIN_LINE_HEIGHT + u32(rand.float32() * f32(MAX_LINE_HEIGHT - MIN_LINE_HEIGHT))
        chars: [MAX_LINE_HEIGHT]byte
 
        for y in 0..< height {
            chars[height - y] = u8(rand.float32() * MAX_CHARS)
        } 
        line := Line {
            chars = chars,
            height = u8(height),
            speed = 1. + rand.float32() * MAX_SPEED,
            y = 1.
        }

        append(&viewport.lines, line)
    }
}

viewport_resize :: proc (viewport: ^Viewport, width, height: u32) {
    if viewport.lines != nil {
        delete(viewport.lines)
    }

    viewport.width  = width
    viewport.height = height
    viewport.lines  = make([dynamic]Line, width)

    viewport_startup(viewport)
}

viewport_tick :: proc (viewport: ^Viewport) {
    for x in 1..< viewport.width {
        has_moved := false
        
        old_y := viewport.lines[x].y
        viewport.lines[x].y += viewport.lines[x].speed

        // the character changes on every slide down
        // but the intensity doesn't change
        if math.round(old_y) != math.round(viewport.lines[x].y) {
            has_moved = true
            for c in 0 ..< len(viewport.lines[x].chars) {
                viewport.lines[x].chars[c] = u8(rand.float32() * MAX_CHARS)
            }
        }

        // fill the buffer with empty chars
        for y in 1..< viewport.height {
            fmt.print("\033[30m", flush = false)
            fmt.printf("\033[%d;%dH%c", y, x, ' ', flush = false)
            fmt.print("\033[0m", flush = false)    
        } 

        // have we gone off screen
        if (viewport.lines[x].y - f32(viewport.lines[x].height)) > f32(viewport.height) {
            viewport.lines[x].y = 1.
        }

        for i in 0..< viewport.lines[x].height {
            y := 1. + viewport.lines[x].y - f32(i)
            
            fmt.print(INTENSITY[i], flush = false)
            fmt.printf("\033[%d;%dH%c", u32(math.round(y)), x, ENCODED_RUNES[viewport.lines[x].chars[i]], flush = false)
            fmt.print("\033[0m", flush = false)
        }
    } 
    
    fmt.print("") // flush to terminal
    
}

viewport_destroy :: proc(viewport: ^Viewport) {
    if viewport != nil { 
        delete(viewport.lines)
    }
}




main :: proc () { 
    width, height: u32
    when ODIN_OS == .Windows {

        info: windows.CONSOLE_SCREEN_BUFFER_INFO

        if !windows.GetConsoleScreenBufferInfo(windows.GetStdHandle(windows.STD_OUTPUT_HANDLE), &info) {
            fmt.eprint("Unable to get console screen buffer")
            return
        } 

        width = u32(info.srWindow.Right - info.srWindow.Left) + 1
        height = u32(info.srWindow.Bottom - info.srWindow.Top) + 1
    } else when ODIN_OS == .Linux {
        fmt.eprint("To be done!")
        return
    }

    fmt.print("\033[2J") // clear terminal

    

    viewport := viewport_create(width, height)
    defer viewport_destroy(viewport)
 
    
    fmt.print("\x1b[?25l"); // hide cursor
    fmt.print("\033[2J") // clear terminal

    
    for {
        viewport_tick(viewport)
    //     // time.sleep(10 << 10)       
    } 
    
    fmt.print("\x1b[?25h") // show cursor
}