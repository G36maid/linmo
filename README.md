# Linmo: A Simple Multi-tasking Operating System Kernel
```
      ▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▖
      ▐██████████████
      ▐█████▜▆▆▛█████
    ▗███▉▜██▟▀▀▙██▇███▆▖
   ▗█████▜██▅▅▅▅██▀████▉
   ▕███▙▇███▛▘▝████▆███▛     ▝▇▇▇▘    ▝▇▇▛▘▝▇▇▄  ▝▇▛▘     ▇▇▙    ▇▇▀  ▗▅▇▀▀▇▅▖
    ▝████▛▀▔    ▔▀▜███▉       ▐█▋      ██▍  ▐██▙▖ ▐▌      ▐██▖  ▟██▎ ▗█▛    ██▖
    █▔█▍▝▀▀▀╸  ━▀▀▀ █▛▜▋      ▐█▋      ██▍  ▐▋▝▜█▃▐▌      █▎▜█▖▐▛▐█▌ ██▌    ▐█▋
    ▜▖▜▌╺▄▃▄╸ ┓╺▄▄━ █▋▟▍      ▐█▋   ▅▏ ██▍  ▐▋  ▜██▌      █▏ ███ ▐█▋ ▐█▙    ▟█▘
    ▐▛▀▊      ▝    ▕█▀█      ▗▟██▅▅▇▛ ▅██▙▖▗▟█▖  ▝█▌     ▅█▅ ▝█▘╶▟██▖ ▝▜▇▅▄▇▀▘
    ▝▙▅█▖   ▀━┷▘   ▟█▅▛
    ▗██▌█▖ ╺━▇▇━  ▄▊▜█▉                 ▆▍                       ▕▆
   ▗██▛▗█▛▅▂▝▀▀▁▃▇██▝██▙                █▍▅▛ ▗▆▀▜▅ ▇▆▀▕▇┻▀▆ ▗▇▀▇▖▕█
  ▄███▇██▎ ▀▀▀▀▀▔ ▐█████▙▁              █▛▜▄ ▜█▀▜▉ █▎ ▕█▏ █▎▜▛▀▜▉▕█
  ▀▀▔▔▜▄▀▜▅▄▂▁▁▃▄▆▀▚▟▀▔▀▀▘              ▀▘ ▀▘ ▀▀▀▔ ▀   ▀  ▀  ▀▀▀▔ ▀
       ▝▀▆▄▃████▃▄▆▀▔
```

Linmo is a preemptive, multi-tasking operating system kernel built as an educational showcase for resource-constrained systems.
It offers a lightweight environment where all tasks share a single address space,
keeping the memory footprint to a minimum.

The name Linmo pays tribute to Lin Mo (林默), the mortal name of the Chinese sea goddess [Mazu](https://en.wikipedia.org/wiki/Mazu) (媽祖),
who was a legendary figure from 10th-century Fujian later deified as the guardian of sailors and fishermen across the Chinese-speaking world.
Just as Mazu was believed to provide calm and guidance in turbulent seas,
Linmo aims to offer a structured learning environment within the constrained and often chaotic domain of embedded system education.

Target Platform:
* RISC-V (32-bit): RV32I architecture, tested with QEMU.

Features:
* Minimal kernel size.
* Lightweight task model with a shared address space.
* Preemptive and cooperative scheduling using a priority-based round-robin algorithm.
* Support for a user-defined real-time scheduler.
* Task synchronization and IPC primitives: semaphores, mutex / condition variable, pipes, and message queues.
* Software timers with callback functionality.
* Dynamic memory allocation.
* A compact C library.

## Getting Started
This section guides you through building the Linmo kernel and running example applications.

### Prerequisites
* A RISC-V cross-compilation toolchain: `riscv-none-elf`, which can be download via [riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain).
* The QEMU emulator for RISC-V: `qemu-system-riscv32`.

### Building the Kernel
To build the kernel, run the following command:

```bash
make
```

This command compiles the kernel into a static library (`liblinmo.a`) located in the `build/target` directory.
This library can then be linked against user applications.

### Building and Running an Application
To build and run an application (e.g., the `hello` example) on QEMU for 32-bit RISC-V:
1.  Build the application:
    ```bash
    make hello
    ```
2.  Run the application in QEMU:
    ```bash
    make run
    ```
    To exit QEMU, press `Ctrl+a` then `x`.

## Core Concepts

### Tasks
Tasks are the fundamental units of execution in Linmo.
Each task is a function that typically runs in an infinite loop.
All tasks operate within a shared memory space.
At startup, the kernel initializes all registered tasks and allocates a dedicated stack for each.

### Memory Management

#### Stack Allocation
Each task is allocated a dedicated stack from the system heap.
The heap is a shared memory region managed by Linmo's dynamic memory allocator and is available to both the kernel and the application.

A task's stack stores local variables, function call frames, and the CPU context during interrupts or context switches.
The stack size is configurable per-task and must be specified upon task creation.
Each target architecture defines a default stack size through the `DEFAULT_STACK_SIZE` macro in its HAL.
It is crucial to tune the stack size for each task based on its memory requirements.

#### Dynamic Memory Allocation
Linmo provides standard dynamic memory allocation functions (`malloc`, `calloc`, `realloc`, `free`) for both the kernel and applications.

### Scheduling
Linmo supports both cooperative and preemptive multitasking.
The scheduling mode is determined by the return value of the `app_main()` function at startup:
* Cooperative Scheduling (return value `0`): Tasks retain control of the CPU until they explicitly yield it by calling `mo_task_yield()`.
  This mode gives the developer full control over when a context switch occurs.
* Preemptive Scheduling (return value `1`): The kernel automatically schedules tasks based on a periodic interrupt,
  ensuring that each task gets a fair share of CPU time without needing to yield manually.

The default scheduler uses a priority-based round-robin algorithm.
All tasks are initially assigned `TASK_PRIO_NORMAL`, and the scheduler allocates equal time slices to tasks of the same priority.
Task priorities can be set during initialization in `app_main()` or dynamically at runtime using the `mo_task_priority()` function.

The available priority levels are:
* `TASK_PRIO_CRIT` (Critical)
* `TASK_PRIO_REALTIME` (Real-time)
* `TASK_PRIO_HIGH` (High)
* `TASK_PRIO_ABOVE` (Above Normal)
* `TASK_PRIO_NORMAL` (Normal)
* `TASK_BELOW_PRIO` (Below Normal)
* `TASK_PRIO_LOW` (Low)
* `TASK_PRIO_IDLE` (Lowest)

For more advanced scheduling needs, Linmo supports a user-defined real-time scheduler.
If provided, this scheduler overrides the default round-robin policy for tasks designated as real-time.
Real-time tasks are configured using the `mo_task_rt_priority()` function and linked to the custom scheduler via the kernel's control block.

### Inter-Task Communication (IPC)
Linmo provides several primitives for task synchronization and data exchange, which are essential for building complex embedded applications:
* Semaphores: Counting semaphores for mutual exclusion (mutex) and signaling between tasks.
* Pipes: Unidirectional, byte-oriented channels for streaming data between tasks.
* Message Queues and Event Queues: For structured message passing and event-based signaling (can be enabled in the configuration).

These IPC mechanisms ensure safe and coordinated interactions between concurrent tasks in the shared memory environment.

## Hardware Abstraction Layer (HAL)
Linmo uses a Hardware Abstraction Layer (HAL) to separate the portable kernel code from the underlying hardware-specific details.
This design allows applications to be compiled for different target architectures without modification.

## C Library Support (LibC)
Linmo includes a minimal C library to reduce the overall footprint of the system.
The provided functions are implemented as macros that alias internal library functions.
For applications requiring more features or full standard compliance, these macros can be overridden or removed in the HAL to link against an external C library.

Functions like `printf()` are simplified implementations that provide only essential functionality, optimized for code size.

The following table lists the supported C library functions:

| LibC         |             |             |             |             |
| :----------- | :---------- | :---------- | :---------- | :---------- |
| `strcpy()`   | `strncpy()` | `strcat()`  | `strncat()` | `strcmp()`  |
| `strncmp()`  | `strstr()`  | `strlen()`  | `strchr()`  | `strpbrk()` |
| `strsep()`   | `strtok()`  | `strtok_r()`| `strtol()`  | `atoi()`    |
| `itoa()`     | `memcpy()`  | `memmove()` | `memcmp()`  | `memset()`  |
| `random_r()` | `random()`  | `srand()`   | `puts()`    | `gets()`    |
| `fgets()`    | `getline()` | `printf()`  | `sprintf()` | `free()`    |
| `malloc()`   | `calloc()`  | `realloc()` | `abs()`     |             |

## License                                                                                                                                             
`linmo` is available under a permissive MIT-style license.
Use of this source code is governed by a MIT license that can be found in the [LICENSE](LICENSE) file.

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Reference
* [Operating System in 1000 Lines](https://operating-system-in-1000-lines.vercel.app/en/)
* [egos-2000](https://github.com/yhzhang0128/egos-2000)
