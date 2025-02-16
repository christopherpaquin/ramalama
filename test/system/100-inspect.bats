#!/usr/bin/env bats

load helpers
load helpers.registry
load setup_suite

# bats test_tags=distro-integration
@test "ramalama inspect GGUF model" {
    run_ramalama inspect tiny

    is "${lines[0]}" "tinyllama" "model name"
    is "${lines[1]}" "   Path: .*models/ollama/tinyllama:latest" "model path"
    is "${lines[2]}" "   Registry: ollama" "model registry"
    is "${lines[3]}" "   Format: GGUF" "model format"
    is "${lines[4]}" "   Version: 3" "model format version"
    is "${lines[5]}" "   Endianness: little" "model endianness"
    is "${lines[6]}" "   Metadata: 23 entries" "# of metadata entries"
    is "${lines[7]}" "   Tensors: 201 entries" "# of tensor entries"
}

# bats test_tags=distro-integration
@test "ramalama inspect GGUF model with --all" {
    run_ramalama inspect --all tiny

    is "${lines[0]}" "tinyllama" "model name"
    is "${lines[1]}" "   Path: .*models/ollama/tinyllama:latest" "model path"
    is "${lines[2]}" "   Registry: ollama" "model registry"
    is "${lines[3]}" "   Format: GGUF" "model format"
    is "${lines[4]}" "   Version: 3" "model format version"
    is "${lines[5]}" "   Endianness: little" "model endianness"
    is "${lines[6]}" "   Metadata: " "metadata header"
    is "${lines[7]}" "      general.architecture: llama" "metadata general.architecture"
}

# vim: filetype=sh
