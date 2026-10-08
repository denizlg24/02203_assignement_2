# macOS: pixel inversion build and student subsystem test

Run the commands below from the project root. These steps use Homebrew's RISC-V compiler and Verilator. The repository's `make test_ss` target calls Questa (`vlib`, `vlog`, `vopt`, and `vsim`), so use the Verilator command below on macOS.

## One-time setup

```sh
brew install riscv64-elf-gcc coreutils verilator
```

The software Makefile expects the `riscv64-unknown-elf-*` tool names. Homebrew uses `riscv64-elf-*`. If the links are not already present in `~/.local/bin`, create them with:

```sh
mkdir -p "$HOME/.local/bin"
for tool in gcc size objcopy objdump; do
  ln -s "$(brew --prefix)/bin/riscv64-elf-$tool" \
    "$HOME/.local/bin/riscv64-unknown-elf-$tool"
done
export PATH="$HOME/.local/bin:$PATH"
```

Add `~/.local/bin` to your shell's `PATH` for future terminal sessions if it is not there already.

## Build the pixel inversion firmware

```sh
PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH" \
make build_test TEST=pixel_inversion \
  ARCH_FLAGS='-march=rv32imc -mabi=ilp32 -ffreestanding'
```

The firmware is written to `build/sw/pixel_inversion.elf` and `build/sw/pixel_inversion.hex`. The `-ffreestanding` flag lets this bare metal program use GCC's integer types header without a separate C library. GNU coreutils supplies the `wc` and `head` behavior expected by the Makefile.

## Simulate the standalone student subsystem

```sh
cd sim
verilator --binary --timing -Wno-fatal --top-module tb_student_ss \
  --Mdir ../build/verilator_ss \
  ../src/tb/tb_student_ss.sv \
  ../src/rtl/Student_area_0.sv \
  ../src/rtl/pixel_acc.sv
../build/verilator_ss/Vtb_student_ss
cd ..
```

The testbench writes `src/tb/out_images/pattern_result.pgm`. With the supplied pixel inversion RTL, each output pixel should equal `255 - input pixel`. This standalone simulation does not use the firmware built in the previous step.
