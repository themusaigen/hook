local binaries = {
  x86 = "hde32",
  x64 = "hde64"
}

return require(binaries[jit.arch])
