#!/bin/bash
set -e

# Toolchain Configuration
TOOLCHAIN_REPO="https://github.com/riscv-collab/riscv-gnu-toolchain"
TOOLCHAIN_VERSION="2025.10.18"
TOOLCHAIN_OS="ubuntu-24.04"
TOOLCHAIN_TYPE="${1:-gnu}"

# Setup RISC-V toolchain (unified for GNU and LLVM)
setup_toolchain() {
	local toolchain=$1
	local compiler_name

	# Determine compiler package name
	case "$toolchain" in
	gnu) compiler_name="gcc" ;;
	llvm) compiler_name="llvm" ;;
	*)
		echo "Error: Unknown toolchain type '$toolchain'"
		echo "Usage: $0 [gnu|llvm]"
		exit 1
		;;
	esac

	echo "[+] Setting up ${toolchain^^} RISC-V toolchain..."

	# Construct download URL
	local archive="riscv32-elf-${TOOLCHAIN_OS}-${compiler_name}.tar.xz"
	#local archive="riscv32-elf-${TOOLCHAIN_OS}-${compiler_name}-nightly-${TOOLCHAIN_VERSION}-nightly.tar.xz"
	local url="${TOOLCHAIN_REPO}/releases/download/${TOOLCHAIN_VERSION}/${archive}"

	# Download and extract
	echo "[+] Downloading $archive..."
	wget -q "$url"

	echo "[+] Extracting toolchain..."
	tar -xf "$archive"

	# Export to GitHub Actions environment
	echo "[+] Exporting toolchain to PATH..."
	echo "$PWD/riscv/bin" >>"$GITHUB_PATH"
	echo "CROSS_COMPILE=riscv32-unknown-elf-" >>"$GITHUB_ENV"
	echo "TOOLCHAIN_TYPE=$toolchain" >>"$GITHUB_ENV"

	# Cleanup
	rm -f "$archive"

	echo "[+] Toolchain setup complete: $toolchain"
}

# Validate toolchain type and setup
case "$TOOLCHAIN_TYPE" in
gnu | llvm)
	setup_toolchain "$TOOLCHAIN_TYPE"
	;;
*)
	echo "Error: Unknown toolchain type '$TOOLCHAIN_TYPE'"
	echo "Usage: $0 [gnu|llvm]"
	exit 1
	;;
esac
